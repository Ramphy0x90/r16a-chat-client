use matrix_sdk::Client;
use std::path::PathBuf;
use std::sync::OnceLock;

static MATRIX_CLIENT: OnceLock<Client> = OnceLock::new();
static STORE_CONFIG: OnceLock<StoreConfig> = OnceLock::new();

struct StoreConfig {
    path: PathBuf,
    passphrase: String,
}

/// Must be called once at startup, before any other bridge call that needs the client.
/// The store holds E2EE keys, so it's encrypted with `passphrase`.
pub fn set_store(path: String, passphrase: String) -> Result<(), String> {
    STORE_CONFIG
        .set(StoreConfig { path: PathBuf::from(path), passphrase })
        .map_err(|_| "Store already configured".to_string())
}

pub(crate) async fn get_or_create_client(svr_url: &str) -> Result<Client, String> {
    if let Some(client) = MATRIX_CLIENT.get() {
        return Ok(client.clone());
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

    let _ = MATRIX_CLIENT.set(client.clone());
    Ok(client)
}
