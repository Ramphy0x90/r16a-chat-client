use matrix_sdk::Client;
use matrix_sdk::event_handler::EventHandlerHandle;
use matrix_sdk::room::MessagesOptions;
use matrix_sdk::ruma::events::room::message::{MessageType, OriginalSyncRoomMessageEvent, RoomMessageEventContent};
use matrix_sdk::ruma::events::{AnySyncMessageLikeEvent, AnySyncTimelineEvent, SyncMessageLikeEvent};
use matrix_sdk::ruma::{RoomId, UInt, UserId};
use crate::api::client::get_or_create_client;
use crate::frb_generated::StreamSink;

#[derive(Clone)]
pub struct MessageSummary {
    pub event_id: String,
    pub sender: String,
    pub body: String,
    pub timestamp_ms: i64,
    pub is_own: bool,
}

/// Latest `limit` text messages of a room, oldest first.
pub async fn get_messages(homeserver_url: String, room_id: String, limit: u32) -> Result<Vec<MessageSummary>, String> {
    let client = get_or_create_client(&homeserver_url).await?;
    let room = get_room(&client, &room_id)?;
    let own_user_id = client.user_id();

    let mut options = MessagesOptions::backward();
    options.limit = UInt::from(limit);

    let response = room.messages(options).await.map_err(|e| e.to_string())?;

    // Backward pagination returns newest first, flip it for display order.
    let messages = response
        .chunk
        .iter()
        .rev()
        .filter_map(|event| {
            // Events that fail to deserialize (or aren't text messages) are skipped.
            let AnySyncTimelineEvent::MessageLike(AnySyncMessageLikeEvent::RoomMessage(
                SyncMessageLikeEvent::Original(message),
            )) = event.raw().deserialize().ok()?
            else {
                return None;
            };
            to_summary(message, own_user_id)
        })
        .collect();

    Ok(messages)
}

/// Streams new text messages of a room as they arrive through the sync loop
/// (already decrypted). Stops when Dart cancels the stream.
/// Errors go into the stream (a returned Err would never reach the Dart listener).
pub async fn watch_room_messages(homeserver_url: String, room_id: String, sink: StreamSink<MessageSummary>) {
    let room = match get_or_create_client(&homeserver_url).await.and_then(|client| get_room(&client, &room_id)) {
        Ok(room) => room,
        Err(e) => {
            let _ = sink.add_error(e);
            return;
        }
    };

    room.add_event_handler(
        move |event: OriginalSyncRoomMessageEvent, client: Client, handle: EventHandlerHandle| {
            let sink = sink.clone();
            async move {
                let Some(summary) = to_summary(event, client.user_id()) else {
                    return;
                };
                // Sending fails once Dart cancelled the stream, so clean up.
                if sink.add(summary).is_err() {
                    client.remove_event_handler(handle);
                }
            }
        },
    );
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

fn get_room(client: &Client, room_id: &str) -> Result<matrix_sdk::Room, String> {
    let room_id = RoomId::parse(room_id).map_err(|e| e.to_string())?;
    client
        .get_room(&room_id)
        .ok_or_else(|| format!("Room {room_id} not found"))
}

/// Only text messages for now, everything else is skipped.
fn to_summary(message: OriginalSyncRoomMessageEvent, own_user_id: Option<&UserId>) -> Option<MessageSummary> {
    let MessageType::Text(text) = message.content.msgtype else {
        return None;
    };

    Some(MessageSummary {
        event_id: message.event_id.to_string(),
        is_own: own_user_id == Some(&*message.sender),
        sender: message.sender.to_string(),
        body: text.body,
        timestamp_ms: i64::from(message.origin_server_ts.0),
    })
}
