use crate::api::client::get_or_create_client;

pub struct RoomSummary {
    pub id: String,
    pub name: String
}

pub async fn get_rooms(homeserver_url: String) -> Result<Vec<RoomSummary>, String> {
    let client = get_or_create_client(&homeserver_url).await?;

    // TODO: handle sync better
    client.sync_once(matrix_sdk::config::SyncSettings::default())
        .await
        .map_err(|e| e.to_string())?;

    let rooms = client
        .rooms()
        .into_iter()
        .map(|room| RoomSummary {
            id: room.room_id().to_string(),
            name: room.name().unwrap_or_else(|| "Unnamed Room".to_string())
        }).collect();

    Ok(rooms)
}