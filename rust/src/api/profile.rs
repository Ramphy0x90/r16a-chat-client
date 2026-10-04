use std::io::Cursor;
use std::time::Duration;

use image::{DynamicImage, ImageDecoder, ImageFormat, ImageReader, Limits};
use image::imageops::FilterType;
use matrix_sdk::media::{MediaFormat, MediaThumbnailSettings};
use matrix_sdk::ruma::UInt;
use crate::api::client::get_or_create_client;
use crate::frb_generated::FLUTTER_RUST_BRIDGE_HANDLER;

/// Avatars are only shown small, so fetch a thumbnail instead of the full upload.
const AVATAR_THUMBNAIL_SIZE: u32 = 256;
/// Longest side of the avatar we upload.
const AVATAR_UPLOAD_SIZE: u32 = 512;
const MAX_AVATAR_INPUT_BYTES: usize = 5 * 1024 * 1024;
/// Rejects decompression bombs (tiny files with huge dimensions) before decoding.
const MAX_AVATAR_INPUT_DIMENSION: u32 = 8192;
const AVATAR_UPLOAD_RETRIES: usize = 3;
const AVATAR_UPLOAD_TIMEOUT: Duration = Duration::from_secs(60);

pub struct ProfileInfo {
    pub user_id: String,
    pub display_name: Option<String>,
    pub avatar: Option<Vec<u8>>,
}

pub async fn get_profile(homeserver_url: String) -> Result<ProfileInfo, String> {
    let client = get_or_create_client(&homeserver_url).await?;
    let user_id = client.user_id().ok_or("Not logged in".to_string())?.to_string();
    let account = client.account();

    let display_name = account.get_display_name().await.map_err(|e| e.to_string())?;

    let size = UInt::from(AVATAR_THUMBNAIL_SIZE);
    let format = MediaFormat::Thumbnail(MediaThumbnailSettings::new(size, size));
    // A broken or missing avatar file shouldn't hide the rest of the profile,
    // the UI falls back to the initial letter.
    let avatar = account.get_avatar(format).await.ok().flatten();

    Ok(ProfileInfo { user_id, display_name, avatar })
}

/// An empty (or whitespace-only) name clears the display name.
pub async fn set_display_name(homeserver_url: String, name: String) -> Result<(), String> {
    let client = get_or_create_client(&homeserver_url).await?;
    let name = name.trim();
    let name = (!name.is_empty()).then_some(name);

    client.account().set_display_name(name).await.map_err(|e| e.to_string())
}

/// Re-encodes the image and makes it the account avatar.
/// Avatars are public and unencrypted, so the original file never leaves the device.
pub async fn set_avatar(homeserver_url: String, data: Vec<u8>) -> Result<(), String> {
    // CPU-heavy, keep it off the async worker threads.
    let png = flutter_rust_bridge::spawn_blocking_with(
        move || reencode_avatar(&data),
        FLUTTER_RUST_BRIDGE_HANDLER.thread_pool(),
    )
    .await
    .map_err(|e| e.to_string())??;
    let client = get_or_create_client(&homeserver_url).await?;

    // By default the SDK retries 5xx responses for up to 15 minutes, which looks
    // like a frozen spinner. Fail after a few attempts so the user sees an error.
    let config = client
        .request_config()
        .retry_limit(AVATAR_UPLOAD_RETRIES)
        .timeout(AVATAR_UPLOAD_TIMEOUT);
    let response = client
        .media()
        .upload(&mime::IMAGE_PNG, png, Some(config))
        .await
        .map_err(|e| e.to_string())?;

    client
        .account()
        .set_avatar_url(Some(&response.content_uri))
        .await
        .map_err(|e| e.to_string())
}

pub async fn remove_avatar(homeserver_url: String) -> Result<(), String> {
    let client = get_or_create_client(&homeserver_url).await?;
    client.account().set_avatar_url(None).await.map_err(|e| e.to_string())
}

/// Decodes the image (format sniffed from its bytes, not trusted from the file name),
/// downscales it and encodes it as PNG. Re-encoding drops all metadata (EXIF/GPS,
/// camera info, embedded thumbnails), so the orientation is applied to the pixels first.
fn reencode_avatar(data: &[u8]) -> Result<Vec<u8>, String> {
    if data.len() > MAX_AVATAR_INPUT_BYTES {
        return Err("Image is too large (max 5 MB)".to_string());
    }

    let mut reader = ImageReader::new(Cursor::new(data))
        .with_guessed_format()
        .map_err(|e| e.to_string())?;
    let mut limits = Limits::default();
    limits.max_image_width = Some(MAX_AVATAR_INPUT_DIMENSION);
    limits.max_image_height = Some(MAX_AVATAR_INPUT_DIMENSION);
    reader.limits(limits);

    let mut decoder = reader.into_decoder().map_err(|e| e.to_string())?;
    let orientation = decoder.orientation().map_err(|e| e.to_string())?;
    let mut image = DynamicImage::from_decoder(decoder).map_err(|e| e.to_string())?;
    image.apply_orientation(orientation);

    if image.width() > AVATAR_UPLOAD_SIZE || image.height() > AVATAR_UPLOAD_SIZE {
        image = image.resize(AVATAR_UPLOAD_SIZE, AVATAR_UPLOAD_SIZE, FilterType::Lanczos3);
    }

    let mut png = Vec::new();
    image
        .write_to(Cursor::new(&mut png), ImageFormat::Png)
        .map_err(|e| e.to_string())?;
    Ok(png)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn encode(image: &DynamicImage, format: ImageFormat) -> Vec<u8> {
        let mut bytes = Vec::new();
        image.write_to(Cursor::new(&mut bytes), format).unwrap();
        bytes
    }

    #[test]
    fn reencode_downscales_to_png() {
        let jpeg = encode(&DynamicImage::new_rgb8(1000, 500), ImageFormat::Jpeg);

        let output = reencode_avatar(&jpeg).unwrap();

        assert_eq!(image::guess_format(&output).unwrap(), ImageFormat::Png);
        let decoded = image::load_from_memory(&output).unwrap();
        assert_eq!((decoded.width(), decoded.height()), (512, 256));
    }

    #[test]
    fn reencode_keeps_small_images_as_is() {
        let png = encode(&DynamicImage::new_rgba8(64, 64), ImageFormat::Png);

        let decoded = image::load_from_memory(&reencode_avatar(&png).unwrap()).unwrap();

        assert_eq!((decoded.width(), decoded.height()), (64, 64));
    }

    #[test]
    fn reencode_rejects_non_images() {
        assert!(reencode_avatar(b"%PDF-1.7 definitely not an image").is_err());
    }

    #[test]
    fn reencode_rejects_oversized_dimensions() {
        let png = encode(&DynamicImage::new_luma8(MAX_AVATAR_INPUT_DIMENSION + 1, 1), ImageFormat::Png);

        assert!(reencode_avatar(&png).is_err());
    }
}

