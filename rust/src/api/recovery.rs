use matrix_sdk::encryption::recovery::RecoveryState;
use crate::api::client::get_or_create_client;

/// Whether the user's message keys are backed up so they can be restored on a
/// new login ("recovery": key backup + secret storage, unlocked by one recovery key).
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum RecoveryStatus {
    /// Couldn't be checked (e.g. offline at login). Ask again later.
    Unknown,
    /// Set up, and this device has all the keys: nothing to do.
    Enabled,
    /// Never set up: logging out makes encrypted history unreadable.
    Disabled,
    /// Set up (on another device, or before logging out), but this device
    /// needs the recovery key (`recover`).
    Incomplete,
    /// Never set up, but there's a backup on the server without a recovery key
    /// (made by another app, or by an older build of this one), which this
    /// device can't open. `enable_recovery` must delete it first.
    UnusableBackup,
}

/// Checked by the SDK in the background after login / restore, this waits for it.
pub async fn get_recovery_status(homeserver_url: String) -> Result<RecoveryStatus, String> {
    let client = get_or_create_client(&homeserver_url).await?;
    client.encryption().wait_for_e2ee_initialization_tasks().await;

    Ok(match client.encryption().recovery().state() {
        RecoveryState::Unknown => RecoveryStatus::Unknown,
        RecoveryState::Enabled => RecoveryStatus::Enabled,
        RecoveryState::Disabled => {
            let backups = client.encryption().backups();
            // A backup this device uses (not set up for recovery yet) is fine:
            // `enable_recovery` keeps it.
            if !backups.are_enabled().await
                && backups.fetch_exists_on_server().await.map_err(|e| e.to_string())?
            {
                RecoveryStatus::UnusableBackup
            } else {
                RecoveryStatus::Disabled
            }
        }
        RecoveryState::Incomplete => RecoveryStatus::Incomplete,
    })
}

/// Sets up recovery (for `Disabled`) and returns the new recovery key, which
/// the user must save: it's the only way to read encrypted history on a new
/// login. Never log or store it. Waits until the existing room keys are uploaded
/// to the backup, so logging out right after doesn't lose any.
///
/// `delete_old_backup` (for `UnusableBackup`, after the user agreed) deletes the
/// backup on the server first; the SDK refuses to replace it otherwise. Keys
/// only in that backup are lost (they already were for this device).
pub async fn enable_recovery(homeserver_url: String, delete_old_backup: bool) -> Result<String, String> {
    let client = get_or_create_client(&homeserver_url).await?;
    if delete_old_backup {
        client.encryption().backups().disable_and_delete().await.map_err(|e| e.to_string())?;
    }
    client
        .encryption()
        .recovery()
        .enable()
        .wait_for_backups_to_upload()
        .await
        .map_err(|e| e.to_string())
}

/// Unlocks the backup with the user's recovery key (for `Incomplete`). Messages
/// that couldn't be decrypted then get their keys from the backup and turn
/// readable in the timeline.
pub async fn recover(homeserver_url: String, recovery_key: String) -> Result<(), String> {
    let client = get_or_create_client(&homeserver_url).await?;
    client
        .encryption()
        .recovery()
        .recover(recovery_key.trim())
        .await
        .map_err(|e| e.to_string())
}

/// Replaces the recovery key (for `Enabled`, e.g. the user lost it but is
/// still logged in here) and returns the new one; the old key stops working.
/// Same rules as `enable_recovery`: show it once, never log or store it.
pub async fn reset_recovery_key(homeserver_url: String) -> Result<String, String> {
    let client = get_or_create_client(&homeserver_url).await?;
    client.encryption().recovery().reset_key().await.map_err(|e| e.to_string())
}
