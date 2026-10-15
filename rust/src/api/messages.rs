use std::collections::HashMap;
use std::sync::{Arc, LazyLock, Mutex, Weak};
use tokio::task::AbortHandle;
use eyeball_im::Vector;
use futures_util::StreamExt;
use matrix_sdk::Client;
use matrix_sdk_base::crypto::types::events::UtdCause;
use matrix_sdk::ruma::{RoomId, UserId};
use matrix_sdk::ruma::events::room::message::{MessageType, RoomMessageEventContent};
use matrix_sdk_ui::timeline::{EncryptedMessage, MsgLikeContent, MsgLikeKind, RoomExt, Timeline, TimelineItem, TimelineItemContent};
use crate::api::client::{get_or_create_client, track_task};
use crate::api::media::{media_info, MediaInfo};
use crate::frb_generated::StreamSink;

/// Max pagination requests per `paginate_backwards` call, see there.
const MAX_PAGINATION_ROUNDS: usize = 5;

/// Timelines of the rooms currently watched, so `paginate_backwards` can reach them.
/// Weak: the watch task owns the timeline, the entry dies with it.
static TIMELINES: LazyLock<Mutex<HashMap<String, Weak<Timeline>>>> = LazyLock::new(Default::default);

/// Running `watch_room_timeline` tasks by the caller's watch id, so
/// `unwatch_room_timeline` can stop one right away.
static WATCHES: LazyLock<Mutex<HashMap<i64, AbortHandle>>> = LazyLock::new(Default::default);

#[derive(Clone, Copy)]
pub enum MessageKind {
    Text,
    /// Usually from bots, shown muted.
    Notice,
    /// `/me` action, `body` is the action without the sender ("waves").
    Emote,
    /// Missing keys. The SDK retries when keys arrive, the item then turns into a message.
    UnableToDecrypt,
    Redacted,
    /// `media` is set, `body` is the caption (empty without one).
    Image,
    /// Also videos and audio (not playable in the app yet). `media` is set,
    /// `body` is the caption (empty without one).
    File,
    /// Anything not rendered yet (stickers, polls, locations...). `body` is
    /// the event's fallback text when it has one (often a file name), else empty.
    Unsupported,
}

/// Why an `UnableToDecrypt` message can't be read, the SDK's `UtdCause` grouped
/// by what it means for the user.
#[derive(Clone, Copy)]
pub enum UtdReason {
    /// No known cause (keys may still arrive, the SDK retries).
    Unknown,
    /// Sent while we weren't a member of the room.
    SentBeforeJoined,
    /// Sent before this device existed, and the keys aren't available here
    /// (no key backup, or the device isn't verified to use it).
    SentBeforeThisDevice,
    /// The sender didn't share the keys with this device.
    WithheldBySender,
    /// Refused by the SDK's trust rules: the sender's device or identity isn't trusted.
    UntrustedSender,
}

#[derive(Clone)]
pub struct MessageSummary {
    /// Stable across a local echo becoming the sent event, use it as the list key.
    pub id: String,
    pub kind: MessageKind,
    pub sender: String,
    /// Empty for kinds without text (`UnableToDecrypt`, `Redacted`), the UI shows a placeholder.
    pub body: String,
    pub timestamp_ms: i64,
    pub is_own: bool,
    /// Edits are already applied to `body`, this only drives the "(edited)" label.
    pub is_edited: bool,
    /// In the order they were first added.
    pub reactions: Vec<ReactionSummary>,
    /// Set for `Image` and `File`.
    pub media: Option<MediaInfo>,
    /// Set for `UnableToDecrypt`.
    pub utd_reason: Option<UtdReason>,
}

#[derive(Clone)]
pub struct ReactionSummary {
    /// Usually an emoji, but any string is allowed.
    pub key: String,
    pub count: u32,
    pub reacted_by_me: bool,
}

/// Streams the room's messages (oldest first) as a full list: once right away with
/// what's cached locally, then again on every change (new messages, older ones from
/// `paginate_backwards`, decryption catching up). Stopped by
/// `unwatch_room_timeline(watch_id)`; `watch_id` is unique per call (chosen by
/// Dart), not per room, so a second watch of the same room isn't affected.
/// Without the unwatch it would only stop at the first change after Dart
/// cancels the stream (sending fails then).
/// Errors go into the stream (a returned Err would never reach the Dart listener).
pub async fn watch_room_timeline(
    homeserver_url: String,
    room_id: String,
    watch_id: i64,
    sink: StreamSink<Vec<MessageSummary>>,
) {
    let timeline = match build_timeline(&homeserver_url, &room_id).await {
        Ok(timeline) => Arc::new(timeline),
        Err(e) => {
            let _ = sink.add_error(e);
            return;
        }
    };
    {
        let mut timelines = TIMELINES.lock().unwrap_or_else(|e| e.into_inner());
        timelines.retain(|_, timeline| timeline.strong_count() > 0);
        timelines.insert(room_id, Arc::downgrade(&timeline));
    }

    let own_user_id = timeline.room().own_user_id().to_owned();
    let (mut items, mut updates) = timeline.subscribe().await;
    if sink.add(summaries(&items, &own_user_id)).is_err() {
        return;
    }

    let task = flutter_rust_bridge::spawn(async move {
        // Keeps the timeline alive for as long as Dart listens.
        let _timeline = timeline;
        while let Some(diffs) = updates.next().await {
            for diff in diffs {
                diff.apply(&mut items);
            }
            // Sending fails once Dart cancelled the stream.
            if sink.add(summaries(&items, &own_user_id)).is_err() {
                break;
            }
        }
        lock_watches().remove(&watch_id);
    });
    {
        let mut watches = lock_watches();
        watches.retain(|_, task| !task.is_finished());
        watches.insert(watch_id, task.abort_handle());
    }
    // Aborted on logout, the timeline holds the client.
    track_task(task.abort_handle()).await;
}

/// Stops a `watch_room_timeline` (dropping its timeline). Call it when
/// cancelling the stream. A no-op if it already ended; if it hasn't started its
/// task yet, it ends at its first change instead.
pub fn unwatch_room_timeline(watch_id: i64) {
    if let Some(task) = lock_watches().remove(&watch_id) {
        task.abort();
    }
}

fn lock_watches() -> std::sync::MutexGuard<'static, HashMap<i64, AbortHandle>> {
    WATCHES.lock().unwrap_or_else(|e| e.into_inner())
}

/// Loads older messages into the watched timeline (they arrive through
/// `watch_room_timeline`). Returns whether the start of the room was reached.
///
/// Repeats while no new message shows up: a page can be made only of events
/// that aren't displayed (state events), and the UI only asks
/// again when the list grows. Capped so a room full of hidden events can't loop
/// for long; the UI can still ask for more.
pub async fn paginate_backwards(room_id: String, count: u16) -> Result<bool, String> {
    let timeline = TIMELINES
        .lock()
        .unwrap_or_else(|e| e.into_inner())
        .get(&room_id)
        .and_then(Weak::upgrade)
        .ok_or_else(|| format!("Room {room_id} isn't being watched"))?;

    let own_user_id = timeline.room().own_user_id();
    let before = summaries(&timeline.items().await, own_user_id).len();
    for _ in 0..MAX_PAGINATION_ROUNDS {
        let reached_start = timeline.paginate_backwards(count).await.map_err(|e| e.to_string())?;
        if reached_start {
            return Ok(true);
        }
        if summaries(&timeline.items().await, own_user_id).len() > before {
            break;
        }
    }
    Ok(false)
}

/// Sends a plain-text message, returns its event ID.
pub async fn send_text_message(homeserver_url: String, room_id: String, body: String) -> Result<String, String> {
    let client = get_or_create_client(&homeserver_url).await?;
    let room = get_room(&client, &room_id)?;

    let result = room
        .send(RoomMessageEventContent::text_plain(body))
        .await
        .map_err(|e| e.to_string())?;

    Ok(result.response.event_id.to_string())
}

async fn build_timeline(homeserver_url: &str, room_id: &str) -> Result<Timeline, String> {
    let client = get_or_create_client(homeserver_url).await?;
    let room = get_room(&client, room_id)?;
    room.timeline().await.map_err(|e| e.to_string())
}

fn get_room(client: &Client, room_id: &str) -> Result<matrix_sdk::Room, String> {
    let room_id = RoomId::parse(room_id).map_err(|e| e.to_string())?;
    client
        .get_room(&room_id)
        .ok_or_else(|| format!("Room {room_id} not found"))
}

/// Message-like events only. Virtual items (date dividers, read marker) and
/// state events (membership, room name changes...) are skipped.
fn summaries(items: &Vector<Arc<TimelineItem>>, own_user_id: &UserId) -> Vec<MessageSummary> {
    items
        .iter()
        .filter_map(|item| {
            let event = item.as_event()?;
            let TimelineItemContent::MsgLike(content) = event.content() else {
                return None;
            };
            let (kind, body) = kind_and_body(&content.kind);
            let media = content.as_message().and_then(|message| media_info(message.msgtype()));
            Some(MessageSummary {
                id: item.unique_id().0.clone(),
                kind,
                sender: event.sender().to_string(),
                body,
                timestamp_ms: i64::from(event.timestamp().0),
                is_own: event.is_own(),
                is_edited: content.as_message().is_some_and(|message| message.is_edited()),
                reactions: reaction_summaries(content, own_user_id),
                media,
                utd_reason: match &content.kind {
                    MsgLikeKind::UnableToDecrypt(message) => Some(utd_reason(message)),
                    _ => None,
                },
            })
        })
        .collect()
}

fn reaction_summaries(content: &MsgLikeContent, own_user_id: &UserId) -> Vec<ReactionSummary> {
    content
        .reactions
        .iter()
        // Defensive: a key with no senders left would render as a "0" chip.
        .filter(|(_, senders)| !senders.is_empty())
        .map(|(key, senders)| ReactionSummary {
            key: key.clone(),
            count: u32::try_from(senders.len()).unwrap_or(u32::MAX),
            reacted_by_me: senders.contains_key(own_user_id),
        })
        .collect()
}

fn kind_and_body(kind: &MsgLikeKind) -> (MessageKind, String) {
    match kind {
        MsgLikeKind::Message(message) => match message.msgtype() {
            MessageType::Text(text) => (MessageKind::Text, text.body.clone()),
            MessageType::Notice(notice) => (MessageKind::Notice, notice.body.clone()),
            MessageType::Emote(emote) => (MessageKind::Emote, emote.body.clone()),
            MessageType::Image(image) => (MessageKind::Image, caption(image.caption())),
            MessageType::File(file) => (MessageKind::File, caption(file.caption())),
            MessageType::Video(video) => (MessageKind::File, caption(video.caption())),
            MessageType::Audio(audio) => (MessageKind::File, caption(audio.caption())),
            other => (MessageKind::Unsupported, other.body().to_string()),
        },
        MsgLikeKind::UnableToDecrypt(_) => (MessageKind::UnableToDecrypt, String::new()),
        MsgLikeKind::Redacted => (MessageKind::Redacted, String::new()),
        MsgLikeKind::Sticker(sticker) => (MessageKind::Unsupported, sticker.content().body.clone()),
        MsgLikeKind::Poll(_) | MsgLikeKind::Other(_) | MsgLikeKind::LiveLocation(_) => {
            (MessageKind::Unsupported, String::new())
        }
    }
}

fn utd_reason(message: &EncryptedMessage) -> UtdReason {
    let EncryptedMessage::MegolmV1AesSha2 { cause, .. } = message else {
        return UtdReason::Unknown;
    };
    match cause {
        UtdCause::Unknown => UtdReason::Unknown,
        UtdCause::SentBeforeWeJoined => UtdReason::SentBeforeJoined,
        UtdCause::HistoricalMessageAndBackupIsDisabled
        | UtdCause::HistoricalMessageAndDeviceIsUnverified => UtdReason::SentBeforeThisDevice,
        UtdCause::WithheldForUnverifiedOrInsecureDevice | UtdCause::WithheldBySender => {
            UtdReason::WithheldBySender
        }
        UtdCause::VerificationViolation | UtdCause::UnsignedDevice | UtdCause::UnknownDevice => {
            UtdReason::UntrustedSender
        }
    }
}

fn caption(caption: Option<&str>) -> String {
    caption.unwrap_or_default().to_string()
}
