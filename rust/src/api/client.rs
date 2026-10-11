use matrix_sdk::Client;
use std::path::PathBuf;
use std::sync::OnceLock;
use tokio::sync::Mutex;
use tokio::task::AbortHandle;

/// `None` until first use, and again after `reset_client`. A tokio Mutex so the
/// lock can be held across `build().await` (no two callers race to build).
static CLIENT_STATE: Mutex<Option<ClientState>> = Mutex::const_new(None);
static STORE_CONFIG: OnceLock<StoreConfig> = OnceLock::new();

struct StoreConfig {
    path: PathBuf,
    passphrase: String,
}

struct ClientState {
    client: Client,
    /// Background tasks holding a clone of `client` (sync loop, room list streams).
    /// Aborted on reset, otherwise they'd keep the old client and its store alive.
    tasks: Vec<AbortHandle>,
    sync_task: Option<AbortHandle>,
}

/// Must be called once at startup, before any other bridge call that needs the client.
/// The store holds E2EE keys, so it's encrypted with `passphrase`.
pub fn set_store(path: String, passphrase: String) -> Result<(), String> {
    STORE_CONFIG
        .set(StoreConfig { path: PathBuf::from(path), passphrase })
        .map_err(|_| "Store already configured".to_string())
}

/// Drops the client, stops its background tasks and deletes the store (state + E2EE keys).
/// The next call needing a client builds a fresh one. Doesn't touch the server,
/// see `auth::logout` for that.
pub async fn reset_client() -> Result<(), String> {
    if let Some(state) = CLIENT_STATE.lock().await.take() {
        for task in state.tasks.iter().chain(&state.sync_task) {
            task.abort();
        }
    }

    let store = STORE_CONFIG
        .get()
        .ok_or("Store not configured, call set_store first".to_string())?;
    match std::fs::remove_dir_all(&store.path) {
        Ok(()) => Ok(()),
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => Ok(()),
        Err(e) => Err(e.to_string()),
    }
}

pub(crate) async fn get_or_create_client(svr_url: &str) -> Result<Client, String> {
    let mut state = CLIENT_STATE.lock().await;
    if let Some(state) = state.as_ref() {
        return Ok(state.client.clone());
    }

    let store = STORE_CONFIG
        .get()
        .ok_or("Store not configured, call set_store first".to_string())?;

    let client = Client::builder()
        .homeserver_url(svr_url)
        .sqlite_store(&store.path, Some(&store.passphrase))
        .build()
        .await
        .map_err(|e| e.to_string())?;

    *state = Some(ClientState { client: client.clone(), tasks: Vec::new(), sync_task: None });
    Ok(client)
}

/// The current client, without creating one.
pub(crate) async fn current_client() -> Option<Client> {
    CLIENT_STATE.lock().await.as_ref().map(|state| state.client.clone())
}

/// Registers a background task to abort on reset. If there's no client anymore
/// (reset in the meantime), the task is aborted right away.
pub(crate) async fn track_task(task: AbortHandle) {
    match CLIENT_STATE.lock().await.as_mut() {
        Some(state) => {
            state.tasks.retain(|task| !task.is_finished());
            state.tasks.push(task);
        }
        None => task.abort(),
    }
}

/// Calls `spawn` (which should start the sync loop) unless a sync task is already
/// running for the current client.
pub(crate) async fn start_sync_task_once(spawn: impl FnOnce() -> AbortHandle) {
    let mut state = CLIENT_STATE.lock().await;
    let Some(state) = state.as_mut() else {
        return;
    };
    if state.sync_task.as_ref().is_some_and(|task| !task.is_finished()) {
        return;
    }
    state.sync_task = Some(spawn());
}
