use matrix_sdk::Client;
use matrix_sdk::authentication::matrix::MatrixSession;

pub async fn login(homeserver_url: String, username: String, password: String) -> Result<String, String> {
    let client = Client::builder()
        .homeserver_url(&homeserver_url)
        .build()
        .await
        .map_err(|e| e.to_string())?;

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
    let client = Client::builder()
        .homeserver_url(&homeserver_url)
        .build()
        .await
        .map_err(|e| e.to_string())?;

    let session: MatrixSession = serde_json::from_str(&session_json).map_err(|e| e.to_string())?;

    client
        .restore_session(session)
        .await
        .map_err(|e| e.to_string())?;

    Ok(true)
}