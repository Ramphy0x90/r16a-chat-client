use matrix_sdk::Client;
use tokio::sync::broadcast::error::RecvError;
use crate::api::client::get_or_create_client;
use crate::frb_generated::StreamSink;

pub struct RoomSummary {
    pub id: String,
    pub name: String
}

/// Streams the room list: once right away (from the local store), then again
/// whenever the sync loop updates any room. Stops when Dart cancels the stream.
/// Errors go into the stream (a returned Err would never reach the Dart listener).
pub async fn watch_rooms(homeserver_url: String, sink: StreamSink<Vec<RoomSummary>>) {
    let client = match get_or_create_client(&homeserver_url).await {
        Ok(client) => client,
        Err(e) => {
            let _ = sink.add_error(e);
            return;
        }
    };
    // Subscribe before the first emit so no update slips in between.
    let mut updates = client.subscribe_to_all_room_updates();

    if sink.add(room_summaries(&client)).is_err() {
        return;
    }

    flutter_rust_bridge::spawn(async move {
        // Lagged only means we missed some updates, the list is rebuilt fresh anyway.
        while let Ok(_) | Err(RecvError::Lagged(_)) = updates.recv().await {
            // Sending fails once Dart cancelled the stream.
            if sink.add(room_summaries(&client)).is_err() {
                break;
            }
        }
    });
}

fn room_summaries(client: &Client) -> Vec<RoomSummary> {
    client
        .rooms()
        .into_iter()
        .map(|room| RoomSummary {
            id: room.room_id().to_string(),
            name: room.name().unwrap_or_else(|| "Unnamed Room".to_string())
        })
        .collect()
}
