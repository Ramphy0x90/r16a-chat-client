use matrix_sdk::media::{MediaFormat, MediaRequestParameters, MediaThumbnailSettings};
use matrix_sdk::ruma::UInt;
use matrix_sdk::ruma::events::room::MediaSource;
use matrix_sdk::ruma::events::room::message::MessageType;
use serde::{Deserialize, Serialize};
use crate::api::client::get_or_create_client;
use crate::frb_generated::FLUTTER_RUST_BRIDGE_HANDLER;

/// Requested size of server-side thumbnails (unencrypted media only).
const PREVIEW_SIZE: u32 = 800;
/// Encrypted images without a thumbnail are previewed from the full file.
const MAX_PREVIEW_BYTES: u64 = 20 * 1024 * 1024;
/// The image viewer keeps the whole file in memory (Rust and Dart side).
const MAX_VIEW_BYTES: u64 = 50 * 1024 * 1024;

#[derive(Clone)]
pub struct MediaInfo {
    /// Opaque to Dart, pass it back to `load_media_preview` / `load_media` / `save_media`.
    /// Holds the decryption key of encrypted media: never log or persist it.
    pub handle: String,
    pub filename: String,
    pub mimetype: Option<String>,
    /// As declared by the sender, not verified.
    pub size_bytes: Option<i64>,
    pub width: Option<i32>,
    pub height: Option<i32>,
}

#[derive(Serialize, Deserialize)]
struct MediaHandle {
    source: MediaSource,
    thumbnail_source: Option<MediaSource>,
    size: Option<u64>,
}

/// Images, files, videos and audio; `None` for other message types.
pub(crate) fn media_info(msgtype: &MessageType) -> Option<MediaInfo> {
    match msgtype {
        MessageType::Image(c) => {
            let info = c.info.as_deref();
            build(&c.source, c.filename(), info.and_then(|i| i.thumbnail_source.as_ref()),
                info.and_then(|i| i.mimetype.as_deref()), info.and_then(|i| i.size),
                info.and_then(|i| i.width), info.and_then(|i| i.height))
        }
        MessageType::File(c) => {
            let info = c.info.as_deref();
            build(&c.source, c.filename(), info.and_then(|i| i.thumbnail_source.as_ref()),
                info.and_then(|i| i.mimetype.as_deref()), info.and_then(|i| i.size), None, None)
        }
        MessageType::Video(c) => {
            let info = c.info.as_deref();
            build(&c.source, c.filename(), info.and_then(|i| i.thumbnail_source.as_ref()),
                info.and_then(|i| i.mimetype.as_deref()), info.and_then(|i| i.size),
                info.and_then(|i| i.width), info.and_then(|i| i.height))
        }
        MessageType::Audio(c) => {
            let info = c.info.as_deref();
            build(&c.source, c.filename(), None,
                info.and_then(|i| i.mimetype.as_deref()), info.and_then(|i| i.size), None, None)
        }
        _ => None,
    }
}

fn build(
    source: &MediaSource,
    filename: &str,
    thumbnail_source: Option<&MediaSource>,
    mimetype: Option<&str>,
    size: Option<UInt>,
    width: Option<UInt>,
    height: Option<UInt>,
) -> Option<MediaInfo> {
    let handle = MediaHandle {
        source: source.clone(),
        thumbnail_source: thumbnail_source.cloned(),
        size: size.map(u64::from),
    };
    Some(MediaInfo {
        // Only fails on non-string map keys, which these types don't have.
        handle: serde_json::to_string(&handle).ok()?,
        filename: filename.to_string(),
        mimetype: mimetype.map(str::to_string),
        size_bytes: size.and_then(|s| i64::try_from(u64::from(s)).ok()),
        width: width.and_then(|w| i32::try_from(u64::from(w)).ok()),
        height: height.and_then(|h| i32::try_from(u64::from(h)).ok()),
    })
}

/// Small version for the timeline: the sender's thumbnail if there is one, else a
/// server-side thumbnail (unencrypted), else the full file (encrypted, size-capped:
/// the server can't thumbnail what it can't decrypt). Cached in the store.
pub async fn load_media_preview(homeserver_url: String, handle: String) -> Result<Vec<u8>, String> {
    let handle = parse(&handle)?;
    let request = match (handle.thumbnail_source, handle.source) {
        (Some(thumbnail), _) => preview_request(thumbnail),
        (None, source @ MediaSource::Plain(_)) => preview_request(source),
        (None, source @ MediaSource::Encrypted(_)) => {
            check_size(handle.size, MAX_PREVIEW_BYTES, "preview")?;
            MediaRequestParameters { source, format: MediaFormat::File }
        }
    };
    download(&homeserver_url, &request, true).await
}

/// The full file, for the image viewer. Cached in the store.
pub async fn load_media(homeserver_url: String, handle: String) -> Result<Vec<u8>, String> {
    let handle = parse(&handle)?;
    check_size(handle.size, MAX_VIEW_BYTES, "view")?;
    let request = MediaRequestParameters { source: handle.source, format: MediaFormat::File };
    download(&homeserver_url, &request, true).await
}

/// Downloads (and decrypts) the full file to `path`. Not cached: saved files can
/// be large and would bloat the store.
pub async fn save_media(homeserver_url: String, handle: String, path: String) -> Result<(), String> {
    let handle = parse(&handle)?;
    let request = MediaRequestParameters { source: handle.source, format: MediaFormat::File };
    let content = download(&homeserver_url, &request, false).await?;

    flutter_rust_bridge::spawn_blocking_with(
        move || std::fs::write(&path, content),
        FLUTTER_RUST_BRIDGE_HANDLER.thread_pool(),
    )
    .await
    .map_err(|e| e.to_string())?
    .map_err(|e| e.to_string())
}

fn parse(handle: &str) -> Result<MediaHandle, String> {
    serde_json::from_str(handle).map_err(|e| e.to_string())
}

/// Thumbnails of encrypted sources are their own encrypted file, fetched as-is.
fn preview_request(source: MediaSource) -> MediaRequestParameters {
    let format = match source {
        MediaSource::Plain(_) => {
            let size = UInt::from(PREVIEW_SIZE);
            MediaFormat::Thumbnail(MediaThumbnailSettings::new(size, size))
        }
        MediaSource::Encrypted(_) => MediaFormat::File,
    };
    MediaRequestParameters { source, format }
}

/// Uses the size declared by the sender; an unknown size is allowed through.
fn check_size(size: Option<u64>, max: u64, action: &str) -> Result<(), String> {
    match size {
        Some(size) if size > max => Err(format!("File is too large to {action} ({} MB max)", max / 1024 / 1024)),
        _ => Ok(()),
    }
}

async fn download(homeserver_url: &str, request: &MediaRequestParameters, use_cache: bool) -> Result<Vec<u8>, String> {
    let client = get_or_create_client(homeserver_url).await?;
    client.media().get_media_content(request, use_cache).await.map_err(|e| e.to_string())
}

#[cfg(test)]
mod tests {
    use super::*;
    use matrix_sdk::ruma::events::room::message::{FileMessageEventContent, MessageType};
    use matrix_sdk::ruma::mxc_uri;

    #[test]
    fn handle_round_trips() {
        let content = FileMessageEventContent::plain("report.pdf".to_string(), mxc_uri!("mxc://example.org/abc").to_owned());

        let info = media_info(&MessageType::File(content)).unwrap();
        let handle = parse(&info.handle).unwrap();

        assert!(matches!(handle.source, MediaSource::Plain(uri) if uri == "mxc://example.org/abc"));
        assert_eq!(info.filename, "report.pdf");
    }

    #[test]
    fn check_size_allows_unknown_and_rejects_oversized() {
        assert!(check_size(None, 10, "view").is_ok());
        assert!(check_size(Some(10), 10, "view").is_ok());
        assert!(check_size(Some(11), 10, "view").is_err());
    }
}
