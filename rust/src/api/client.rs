use matrix_sdk::Client;
use std::sync::{OnceLock};

static MATRIX_CLIENT: OnceLock<Client> = OnceLock::new();

pub(crate) async fn get_or_create_client(svr_url: &str) -> Result<Client, String> {
    if let Some(client) = MATRIX_CLIENT.get() {
        return Ok(client.clone());
    }

    let client = Client::builder()
        .homeserver_url(svr_url)
        .build()
        .await
        .map_err(|e| e.to_string())?;

    let _ = MATRIX_CLIENT.set(client.clone());
    Ok(client)
}