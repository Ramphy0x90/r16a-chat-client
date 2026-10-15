use std::time::Duration;
use matrix_sdk::authentication::matrix::MatrixSession;
use crate::api::client::{current_client, get_or_create_client, reset_client};

pub async fn login(homeserver_url: String, username: String, password: String) -> Result<String, String> {
    let client = get_or_create_client(&homeserver_url).await?;

    client
        .matrix_auth()
        .login_username(&username, &password)
        .send()
        .await
        .map_err(|e| e.to_string())?;

    let session = client
        .matrix_auth()
        .session()
        .ok_or("No session after login".to_string())?;

    serde_json::to_string(&session).map_err(|e| e.to_string())
}

pub async fn restore_session(homeserver_url: String, session_json: String) -> Result<bool, String> {
    let client = get_or_create_client(&homeserver_url).await?;

    let session: MatrixSession = serde_json::from_str(&session_json).map_err(|e| e.to_string())?;

    client
        .restore_session(session)
        .await
        .map_err(|e| e.to_string())?;

    Ok(true)
}

/// How long `logout` waits for pending room keys to reach the backup.
const BACKUP_UPLOAD_TIMEOUT: Duration = Duration::from_secs(10);

/// Invalidates the session on the server (best effort), then drops the client and
/// deletes the local store. Always logs out locally: an offline user or an already
/// revoked token (`M_UNKNOWN_TOKEN`) shouldn't leave the user stuck logged in.
pub async fn logout() -> Result<(), String> {
    if let Some(client) = current_client().await {
        // The store (with the room keys) is deleted below: give the backup a
        // moment to upload the latest ones. Best effort too (offline: they're lost).
        let backups = client.encryption().backups();
        if backups.are_enabled().await {
            let _ = tokio::time::timeout(BACKUP_UPLOAD_TIMEOUT, backups.wait_for_steady_state()).await;
        }
        // Ignored on purpose, see above. If it fails, the device stays in the
        // server's device list until removed from another session.
        let _ = client.logout().await;
    }
    reset_client().await
}
