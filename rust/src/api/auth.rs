use matrix_sdk::Client;

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

    Ok("Logged in successfully".to_string())
}