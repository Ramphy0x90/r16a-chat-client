use std::collections::HashMap;
use std::sync::{Arc, LazyLock, Mutex, Weak};
use eyeball_im::Vector;
use futures_util::StreamExt;
use matrix_sdk::Client;
use matrix_sdk::ruma::RoomId;
use matrix_sdk::ruma::events::room::message::{MessageType, RoomMessageEventContent};
use matrix_sdk_ui::timeline::{MsgLikeKind, RoomExt, Timeline, TimelineItem, TimelineItemContent};
use crate::api::client::{get_or_create_client, track_task};
use crate::frb_generated::StreamSink;

/// Max pagination requests per `paginate_backwards` call, see there.
const MAX_PAGINATION_ROUNDS: usize = 5;

/// Timelines of the rooms currently watched, so `paginate_backwards` can reach them.
/// Weak: the watch task owns the timeline, the entry dies with it.
static TIMELINES: LazyLock<Mutex<HashMap<String, Weak<Timeline>>>> = LazyLock::new(Default::default);

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
    /// Anything not rendered yet (images, files, stickers, polls...). `body` is
    /// the event's fallback text when it has one (often a file name), else empty.
    Unsupported,
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
}

/// Streams the room's messages (oldest first) as a full list: once right away with
/// what's cached locally, then again on every change (new messages, older ones from
/// `paginate_backwards`, decryption catching up). Stops at the first change after
/// Dart cancels the stream.
/// Errors go into the stream (a returned Err would never reach the Dart listener).
pub async fn watch_room_timeline(homeserver_url: String, room_id: String, sink: StreamSink<Vec<MessageSummary>>) {
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

    let (mut items, mut updates) = timeline.subscribe().await;
    if sink.add(summaries(&items)).is_err() {
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
            if sink.add(summaries(&items)).is_err() {
                break;
            }
        }
    });
    // Aborted on logout, the timeline holds the client.
    track_task(task.abort_handle()).await;
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

    let before = summaries(&timeline.items().await).len();
    for _ in 0..MAX_PAGINATION_ROUNDS {
        let reached_start = timeline.paginate_backwards(count).await.map_err(|e| e.to_string())?;
        if reached_start {
            return Ok(true);
        }
        if summaries(&timeline.items().await).len() > before {
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
fn summaries(items: &Vector<Arc<TimelineItem>>) -> Vec<MessageSummary> {
    items
        .iter()
        .filter_map(|item| {
            let event = item.as_event()?;
            let TimelineItemContent::MsgLike(content) = event.content() else {
                return None;
            };
            let (kind, body) = kind_and_body(&content.kind);
            Some(MessageSummary {
                id: item.unique_id().0.clone(),
                kind,
                sender: event.sender().to_string(),
                body,
                timestamp_ms: i64::from(event.timestamp().0),
                is_own: event.is_own(),
            })
        })
        .collect()
}

fn kind_and_body(kind: &MsgLikeKind) -> (MessageKind, String) {
    match kind {
        MsgLikeKind::Message(message) => match message.msgtype() {
            MessageType::Text(text) => (MessageKind::Text, text.body.clone()),
            MessageType::Notice(notice) => (MessageKind::Notice, notice.body.clone()),
            MessageType::Emote(emote) => (MessageKind::Emote, emote.body.clone()),
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
