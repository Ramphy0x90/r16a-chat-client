//! Decoding of untrusted images (avatar uploads, media from other users).
//! Crate-internal on purpose: lives outside `api/` so flutter_rust_bridge doesn't scan it.

use std::io::Cursor;

use image::imageops::FilterType;
use image::{DynamicImage, ImageDecoder, ImageFormat, ImageReader, Limits};

/// Rejects decompression bombs (tiny files with huge dimensions) before decoding.
pub(crate) const MAX_INPUT_DIMENSION: u32 = 8192;

/// Decodes the image (format sniffed from its bytes, not trusted from the file name
/// or mimetype), downscales it to fit `max_side` and encodes it as PNG. Re-encoding
/// drops all metadata (EXIF/GPS, camera info, embedded thumbnails), so the
/// orientation is applied to the pixels first. Animated images become a still.
pub(crate) fn reencode_png(data: &[u8], max_side: u32) -> Result<Vec<u8>, String> {
    let mut decoder = reader(data)?.into_decoder().map_err(|e| e.to_string())?;
    let orientation = decoder.orientation().map_err(|e| e.to_string())?;
    let mut image = DynamicImage::from_decoder(decoder).map_err(|e| e.to_string())?;
    image.apply_orientation(orientation);

    if image.width() > max_side || image.height() > max_side {
        image = image.resize(max_side, max_side, FilterType::Lanczos3);
    }

    let mut png = Vec::new();
    image
        .write_to(Cursor::new(&mut png), ImageFormat::Png)
        .map_err(|e| e.to_string())?;
    Ok(png)
}

/// Reads only the header: errors if the bytes aren't a supported image or would
/// decode to more than `max_pixels` (the decoded size is what costs memory, not
/// the file size).
pub(crate) fn check_dimensions(data: &[u8], max_pixels: u64) -> Result<(), String> {
    let (width, height) = reader(data)?.into_dimensions().map_err(|e| e.to_string())?;
    if u64::from(width) * u64::from(height) > max_pixels {
        return Err(format!("Image is too large to display ({width}x{height})"));
    }
    Ok(())
}

fn reader(data: &[u8]) -> Result<ImageReader<Cursor<&[u8]>>, String> {
    let mut reader = ImageReader::new(Cursor::new(data))
        .with_guessed_format()
        .map_err(|e| e.to_string())?;
    let mut limits = Limits::default();
    limits.max_image_width = Some(MAX_INPUT_DIMENSION);
    limits.max_image_height = Some(MAX_INPUT_DIMENSION);
    reader.limits(limits);
    Ok(reader)
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

        let output = reencode_png(&jpeg, 512).unwrap();

        assert_eq!(image::guess_format(&output).unwrap(), ImageFormat::Png);
        let decoded = image::load_from_memory(&output).unwrap();
        assert_eq!((decoded.width(), decoded.height()), (512, 256));
    }

    #[test]
    fn reencode_keeps_small_images_as_is() {
        let png = encode(&DynamicImage::new_rgba8(64, 64), ImageFormat::Png);

        let decoded = image::load_from_memory(&reencode_png(&png, 512).unwrap()).unwrap();

        assert_eq!((decoded.width(), decoded.height()), (64, 64));
    }

    #[test]
    fn reencode_rejects_non_images() {
        assert!(reencode_png(b"%PDF-1.7 definitely not an image", 512).is_err());
    }

    #[test]
    fn reencode_rejects_oversized_dimensions() {
        let png = encode(&DynamicImage::new_luma8(MAX_INPUT_DIMENSION + 1, 1), ImageFormat::Png);

        assert!(reencode_png(&png, 512).is_err());
    }

    #[test]
    fn check_dimensions_uses_pixel_count() {
        let png = encode(&DynamicImage::new_luma8(100, 100), ImageFormat::Png);

        assert!(check_dimensions(&png, 10_000).is_ok());
        assert!(check_dimensions(&png, 9_999).is_err());
        assert!(check_dimensions(b"not an image", 10_000).is_err());
    }
}
