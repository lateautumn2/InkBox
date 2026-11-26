use image::{GenericImageView, ImageFormat, ImageReader};
use serde::{Deserialize, Serialize};
use std::io::Cursor;
use thiserror::Error;

#[derive(Debug, Error)]
pub enum ImageProcError {
    #[error("Image decode error: {0}")]
    Decode(#[from] image::ImageError),
    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq)]
pub struct CropRect {
    /// Normalized margins in [0.0, 1.0].
    pub left: f32,
    pub top: f32,
    pub right: f32,
    pub bottom: f32,
}

impl Default for CropRect {
    fn default() -> Self {
        Self {
            left: 0.0,
            top: 0.0,
            right: 1.0,
            bottom: 1.0,
        }
    }
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub struct ImageDimensions {
    pub width: u32,
    pub height: u32,
    /// True when aspect ratio indicates a two-page landscape manga spread.
    pub is_wide_spread: bool,
}

/// Fast header-only dimension probe (<0.2ms, does not decode full bitmap).
pub fn inspect_image_dimensions(bytes: &[u8]) -> Result<ImageDimensions, ImageProcError> {
    let reader = ImageReader::new(Cursor::new(bytes)).with_guessed_format()?;
    let (width, height) = reader.into_dimensions()?;
    let is_wide_spread = height > 0 && (width as f32 / height as f32) > 1.15;
    Ok(ImageDimensions {
        width,
        height,
        is_wide_spread,
    })
}

/// Detects uniform white OR dark scan margins around a manga page and returns
/// normalized crop bounds, guarding against over-cropping sparse/blank pages.
pub fn detect_smart_crop_rect(bytes: &[u8]) -> Result<CropRect, ImageProcError> {
    let img = ImageReader::new(Cursor::new(bytes))
        .with_guessed_format()?
        .decode()?;

    // Downsample to max 320px wide for sub-5ms border detection.
    let small = if img.width() > 320 {
        let new_h = ((img.height() as f32) * (320.0 / img.width() as f32))
            .round()
            .max(1.0) as u32;
        img.thumbnail(320, new_h)
    } else {
        img
    };

    let (w, h) = small.dimensions();
    if w < 16 || h < 16 {
        return Ok(CropRect::default());
    }
    let luma = small.to_luma8();

    // Sample corner luminance to detect whether margins are light (white scan) or dark.
    let corners = [
        luma.get_pixel(0, 0)[0] as i32,
        luma.get_pixel(w - 1, 0)[0] as i32,
        luma.get_pixel(0, h - 1)[0] as i32,
        luma.get_pixel(w - 1, h - 1)[0] as i32,
    ];
    let bg_luma = (corners.iter().sum::<i32>() / 4) as u8;
    let is_border_pixel = |v: u8| -> bool {
        let diff = (v as i32 - bg_luma as i32).abs();
        diff <= 18
    };

    // Row/column is considered empty margin if >= 98.5% of pixels match background.
    let row_is_margin = |y: u32| -> bool {
        let mut non_bg = 0u32;
        let max_non_bg = ((w as f32) * 0.015).ceil() as u32;
        for x in 0..w {
            if !is_border_pixel(luma.get_pixel(x, y)[0]) {
                non_bg += 1;
                if non_bg > max_non_bg {
                    return false;
                }
            }
        }
        true
    };

    let col_is_margin = |x: u32, top_y: u32, bot_y: u32| -> bool {
        let mut non_bg = 0u32;
        let span = bot_y.saturating_sub(top_y).max(1);
        let max_non_bg = ((span as f32) * 0.015).ceil() as u32;
        for y in top_y..bot_y {
            if !is_border_pixel(luma.get_pixel(x, y)[0]) {
                non_bg += 1;
                if non_bg > max_non_bg {
                    return false;
                }
            }
        }
        true
    };

    let mut top = 0u32;
    while top < h / 3 && row_is_margin(top) {
        top += 1;
    }
    let mut bottom = h;
    while bottom > (h * 2) / 3 && bottom > top + 1 && row_is_margin(bottom - 1) {
        bottom -= 1;
    }

    let mut left = 0u32;
    while left < w / 3 && col_is_margin(left, top, bottom) {
        left += 1;
    }
    let mut right = w;
    while right > (w * 2) / 3 && right > left + 1 && col_is_margin(right - 1, top, bottom) {
        right -= 1;
    }

    // Add 1% breathing padding so panel borders are never clipped.
    let pad_x = ((w as f32) * 0.01).ceil() as u32;
    let pad_y = ((h as f32) * 0.01).ceil() as u32;
    let l = left.saturating_sub(pad_x) as f32 / w as f32;
    let t = top.saturating_sub(pad_y) as f32 / h as f32;
    let r = (right + pad_x).min(w) as f32 / w as f32;
    let b = (bottom + pad_y).min(h) as f32 / h as f32;

    if (r - l) < 0.45 || (b - t) < 0.45 {
        return Ok(CropRect::default());
    }

    Ok(CropRect {
        left: l,
        top: t,
        right: r,
        bottom: b,
    })
}

/// Generates a crisp downsampled JPEG thumbnail for Bookshelf / Manga Shelf covers.
pub fn make_cover_thumbnail(bytes: &[u8], max_width: u32) -> Result<Vec<u8>, ImageProcError> {
    let img = ImageReader::new(Cursor::new(bytes))
        .with_guessed_format()?
        .decode()?;
    let target_w = max_width.clamp(120, 720);
    let resized = if img.width() > target_w {
        let target_h = ((img.height() as f32) * (target_w as f32 / img.width() as f32))
            .round()
            .max(1.0) as u32;
        img.thumbnail(target_w, target_h)
    } else {
        img
    };
    let mut out = Cursor::new(Vec::new());
    resized.to_rgb8().write_to(&mut out, ImageFormat::Jpeg)?;
    Ok(out.into_inner())
}

#[cfg(test)]
mod tests {
    use super::*;
    use image::{ImageBuffer, Rgb};

    #[test]
    fn smart_crop_detects_white_border_around_manga_panel() {
        // 200x300 white canvas with a black manga panel inside [30..170, 45..255]
        let mut buf: ImageBuffer<Rgb<u8>, Vec<u8>> =
            ImageBuffer::from_pixel(200, 300, Rgb([255, 255, 255]));
        for y in 45..255 {
            for x in 30..170 {
                buf.put_pixel(x, y, Rgb([25, 25, 25]));
            }
        }
        let mut png = Cursor::new(Vec::new());
        buf.write_to(&mut png, ImageFormat::Png).unwrap();
        let bytes = png.into_inner();

        let dims = inspect_image_dimensions(&bytes).unwrap();
        assert_eq!(dims.width, 200);
        assert_eq!(dims.height, 300);
        assert!(!dims.is_wide_spread);

        let rect = detect_smart_crop_rect(&bytes).unwrap();
        assert!(rect.left > 0.10 && rect.left < 0.20, "left={}", rect.left);
        assert!(rect.right > 0.80 && rect.right < 0.90, "right={}", rect.right);
        assert!(rect.top > 0.10 && rect.top < 0.20, "top={}", rect.top);
        assert!(rect.bottom > 0.80 && rect.bottom < 0.90, "bottom={}", rect.bottom);
    }
}
