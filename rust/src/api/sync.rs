use std::sync::LazyLock;
use std::time::{Duration, Instant};
use matrix_sdk::config::SyncSettings;
use matrix_sdk::ruma::api::error::ErrorKind;
use matrix_sdk::send_queue::SendQueueRoomError;
use matrix_sdk::{Client, LoopCtrl};
use futures_util::future;
use tokio::sync::{broadcast, watch};
use crate::api::client::{get_or_create_client, start_sync_task_once};
use crate::frb_generated::StreamSink;

const SYNC_TIMEOUT: Duration = Duration::from_secs(30);
const RETRY_DELAY: Duration = Duration::from_secs(5);
/// Send queue resumes back off from `RETRY_DELAY` up to this...
const MAX_RESUME_DELAY: Duration = Duration::from_secs(300);
/// ...and start over after this long without send errors.
const RESUME_BACKOFF_RESET: Duration = Duration::from_secs(600);

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
        flutter_rust_bridge::spawn(sync_task(client)).abort_handle()
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

async fn sync_task(client: Client) {
    // Subscribed first: the respawned queues can fail right away (offline start).
    let errors = client.send_queue().subscribe_errors();
    // Messages still queued from the last run (the queue is persisted).
    client.send_queue().respawn_tasks_for_rooms_with_unsent_requests().await;
    // Resuming the send queue depends on the sync state, so it lives and dies
    // with the sync loop.
    // Box::pin rather than pin!: flutter_rust_bridge's parser rejects the macro.
    future::select(
        Box::pin(run_sync_loop(client.clone())),
        Box::pin(resume_send_queues(client, errors)),
    )
    .await;
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

/// The SDK pauses a room's send queue after *any* send error.
/// - Unrecoverable (server rejected it): the message is parked as `Failed` and
///   never picked again, so the room is resumed right away for the messages
///   behind it. The user decides about the failed one (`retry_send` / `delete_unsent`).
/// - Recoverable (offline, server hiccup): the message stays queued. Resume
///   once the sync is connected again, after a delay that backs off while
///   sends keep failing (the sync can be fine while `/send` isn't).
async fn resume_send_queues(client: Client, mut errors: broadcast::Receiver<SendQueueRoomError>) {
    let mut delay = RETRY_DELAY;
    loop {
        let waiting_since = Instant::now();
        match errors.recv().await {
            Ok(error) if !error.is_recoverable => {
                if let Some(room) = client.get_room(&error.room_id) {
                    room.send_queue().set_enabled(true);
                }
                continue;
            }
            // Lagged: missed some errors, the client-wide resume below covers them.
            Ok(_) | Err(broadcast::error::RecvError::Lagged(_)) => {}
            Err(broadcast::error::RecvError::Closed) => return,
        }
        if waiting_since.elapsed() > RESUME_BACKOFF_RESET {
            delay = RETRY_DELAY;
        }

        tokio::time::sleep(delay).await;
        let mut state = SYNC_STATE.subscribe();
        // Only errors if the sender is dropped, which a static never is.
        let _ = state.wait_for(|state| *state == SyncState::Connected).await;

        // Errors from other rooms piled up meanwhile: one client-wide resume
        // covers them all (parked `Failed` messages stay parked).
        while !matches!(
            errors.try_recv(),
            Err(broadcast::error::TryRecvError::Empty | broadcast::error::TryRecvError::Closed)
        ) {}
        client.send_queue().set_enabled(true).await;
        delay = (delay * 2).min(MAX_RESUME_DELAY);
    }
}
