use std::sync::atomic::{AtomicBool, Ordering};
use std::time::Duration;
use matrix_sdk::config::SyncSettings;
use matrix_sdk::ruma::api::error::ErrorKind;
use matrix_sdk::{Client, LoopCtrl};
use crate::api::client::get_or_create_client;

static SYNC_RUNNING: AtomicBool = AtomicBool::new(false);

const SYNC_TIMEOUT: Duration = Duration::from_secs(30);
const RETRY_DELAY: Duration = Duration::from_secs(5);

/// Starts the background sync loop, no-op if it's already running.
/// Needs an authenticated client (call after login / restore_session).
pub async fn start_sync(homeserver_url: String) -> Result<(), String> {
    let client = get_or_create_client(&homeserver_url).await?;
    if client.user_id().is_none() {
        return Err("Cannot sync without a logged-in session".to_string());
    }
    if SYNC_RUNNING.swap(true, Ordering::SeqCst) {
        return Ok(());
    }

    flutter_rust_bridge::spawn(async move {
        run_sync_loop(client).await;
        SYNC_RUNNING.store(false, Ordering::SeqCst);
    });

    Ok(())
}

/// Syncs until the session becomes invalid. Network/server errors are retried
/// (the SDK retries first, this adds a delay on top before trying again).
async fn run_sync_loop(client: Client) {
    let settings = SyncSettings::default().timeout(SYNC_TIMEOUT);

    let _ = client
        .sync_with_result_callback(settings, |result| async move {
            match result {
                Ok(_) => Ok(LoopCtrl::Continue),
                // Token revoked / expired: retrying won't help, stop the loop.
                Err(e) if matches!(e.client_api_error_kind(), Some(ErrorKind::UnknownToken(_))) => Err(e),
                Err(_) => {
                    tokio::time::sleep(RETRY_DELAY).await;
                    Ok(LoopCtrl::Continue)
                }
            }
        })
        .await;
}
