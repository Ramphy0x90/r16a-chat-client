use std::sync::LazyLock;
use std::time::Duration;
use matrix_sdk::config::SyncSettings;
use matrix_sdk::ruma::api::error::ErrorKind;
use matrix_sdk::{Client, LoopCtrl};
use tokio::sync::watch;
use crate::api::client::{get_or_create_client, start_sync_task_once};
use crate::frb_generated::StreamSink;

const SYNC_TIMEOUT: Duration = Duration::from_secs(30);
const RETRY_DELAY: Duration = Duration::from_secs(5);

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum SyncState {
    /// No sync loop started yet.
    Idle,
    /// Loop started, waiting for the first response.
    Connecting,
    /// Last sync succeeded.
    Connected,
    /// Last sync failed (offline, server error), retrying.
    Disconnected,
    /// The server rejected the access token (`M_UNKNOWN_TOKEN`: logged out
    /// from another device, or expired). The loop has stopped, the user must log in again.
    SessionExpired,
}

/// Global rather than per client: there's only one sync loop at a time.
static SYNC_STATE: LazyLock<watch::Sender<SyncState>> =
    LazyLock::new(|| watch::Sender::new(SyncState::Idle));

/// Starts the background sync loop, no-op if it's already running.
/// Needs an authenticated client (call after login / restore_session).
pub async fn start_sync(homeserver_url: String) -> Result<(), String> {
    let client = get_or_create_client(&homeserver_url).await?;
    if client.user_id().is_none() {
        return Err("Cannot sync without a logged-in session".to_string());
    }

    start_sync_task_once(|| {
        set_state(SyncState::Connecting);
        flutter_rust_bridge::spawn(run_sync_loop(client)).abort_handle()
    })
    .await;
    Ok(())
}

/// Streams the sync state: the current one right away, then every change.
/// Stops at the first change after Dart cancels the stream.
pub async fn watch_sync_state(sink: StreamSink<SyncState>) {
    let mut receiver = SYNC_STATE.subscribe();
    loop {
        let state = *receiver.borrow_and_update();
        if sink.add(state).is_err() {
            return;
        }
        // Only errors if the sender is dropped, which a static never is.
        if receiver.changed().await.is_err() {
            return;
        }
    }
}

/// Called with `Idle` on reset (the aborted loop can't update it itself).
pub(crate) fn set_state(state: SyncState) {
    // Notifies only on actual changes: a successful sync every 30s isn't news.
    SYNC_STATE.send_if_modified(|current| std::mem::replace(current, state) != state);
}

/// Syncs until the session becomes invalid. Network/server errors are retried
/// (the SDK retries first, this adds a delay on top before trying again).
async fn run_sync_loop(client: Client) {
    let settings = SyncSettings::default().timeout(SYNC_TIMEOUT);

    let _ = client
        .sync_with_result_callback(settings, |result| async move {
            match result {
                Ok(_) => {
                    set_state(SyncState::Connected);
                    Ok(LoopCtrl::Continue)
                }
                // Token revoked / expired: retrying won't help, stop the loop.
                Err(e) if matches!(e.client_api_error_kind(), Some(ErrorKind::UnknownToken(_))) => {
                    set_state(SyncState::SessionExpired);
                    Err(e)
                }
                Err(_) => {
                    set_state(SyncState::Disconnected);
                    tokio::time::sleep(RETRY_DELAY).await;
                    Ok(LoopCtrl::Continue)
                }
            }
        })
        .await;
}
