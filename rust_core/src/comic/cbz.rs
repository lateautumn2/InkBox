use roxmltree::Document;
use serde::{Deserialize, Serialize};
use std::fs::File;
use std::io::Read;
use std::path::Path;
use thiserror::Error;
use zip::ZipArchive;

#[derive(Debug, Error)]
pub enum ComicError {
    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),
    #[error("ZIP error: {0}")]
    Zip(#[from] zip::result::ZipError),
    #[error("Archive error: {0}")]
    Archive(String),
    #[error("Page index out of range: {0}")]
    PageOutOfRange(usize),
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct ComicInfoMeta {
    pub title: Option<String>,
    pub series: Option<String>,
    pub writer: Option<String>,
    pub number: Option<String>,
    pub volume: Option<String>,
    pub summary: Option<String>,
    /// "rtl" | "ltr" | "webtoon"
    pub recommended_reading_mode: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ComicPageEntry {
    pub index: usize,
    pub entry_name: String,
    pub uncompressed_size: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ComicArchiveSummary {
    pub page_count: usize,
    pub has_comic_info_xml: bool,
    pub comic_info: Option<ComicInfoMeta>,
    pub cover_entry: Option<String>,
    pub pages: Vec<ComicPageEntry>,
}

pub fn is_supported_image_name(name: &str) -> bool {
    let lower = name.to_ascii_lowercase();
    if lower.contains("__macosx/") || lower.rsplit('/').next().unwrap_or("").starts_with('.') {
        return false;
    }
    lower.ends_with(".jpg")
        || lower.ends_with(".jpeg")
        || lower.ends_with(".png")
        || lower.ends_with(".webp")
        || lower.ends_with(".avif")
        || lower.ends_with(".gif")
        || lower.ends_with(".bmp")
}

pub fn parse_comic_info_xml(xml: &str) -> Option<ComicInfoMeta> {
    let doc = Document::parse(xml).ok()?;
    let get_tag = |tag: &str| -> Option<String> {
        doc.descendants()
            .find(|n| n.tag_name().name().eq_ignore_ascii_case(tag))
            .and_then(|n| n.text())
            .map(|s| s.trim().to_string())
            .filter(|s| !s.is_empty())
    };
    let manga_flag = get_tag("Manga").unwrap_or_default().to_ascii_lowercase();
    let recommended_reading_mode = if manga_flag.contains("righttoleft") || manga_flag == "yes" {
        Some("rtl".to_string())
    } else if manga_flag == "no" {
        Some("ltr".to_string())
    } else {
        None
    };

    Some(ComicInfoMeta {
        title: get_tag("Title"),
        series: get_tag("Series"),
        writer: get_tag("Writer").or_else(|| get_tag("Penciller")),
        number: get_tag("Number"),
        volume: get_tag("Volume"),
        summary: get_tag("Summary"),
        recommended_reading_mode,
    })
}

/// Indexes a CBZ/ZIP comic archive without decompressing pages to disk.
pub fn inspect_cbz_archive(path: &Path) -> Result<ComicArchiveSummary, ComicError> {
    let file = File::open(path)?;
    let mut archive = ZipArchive::new(file)?;
    let mut image_entries: Vec<(String, u64)> = Vec::new();
    let mut comic_info_entry: Option<String> = None;

    for i in 0..archive.len() {
        let entry = archive.by_index(i)?;
        if entry.is_dir() {
            continue;
        }
        let name = entry.name().to_string();
        if name.eq_ignore_ascii_case("ComicInfo.xml")
            || name.to_ascii_lowercase().ends_with("/comicinfo.xml")
        {
            comic_info_entry = Some(name);
            continue;
        }
        if is_supported_image_name(&name) {
            image_entries.push((name, entry.size()));
        }
    }

    let comic_info = if let Some(ref ci_name) = comic_info_entry {
        let mut entry = archive.by_name(ci_name)?;
        let mut xml = String::new();
        entry.read_to_string(&mut xml)?;
        parse_comic_info_xml(&xml)
    } else {
        None
    };

    image_entries.sort_by(|a, b| natord::compare_ignore_case(&a.0, &b.0));

    let pages: Vec<ComicPageEntry> = image_entries
        .into_iter()
        .enumerate()
        .map(|(idx, (entry_name, uncompressed_size))| ComicPageEntry {
            index: idx,
            entry_name,
            uncompressed_size,
        })
        .collect();

    let cover_entry = pages.first().map(|p| p.entry_name.clone());

    Ok(ComicArchiveSummary {
        page_count: pages.len(),
        has_comic_info_xml: comic_info_entry.is_some(),
        comic_info,
        cover_entry,
        pages,
    })
}

/// Streams a single page's raw image bytes directly from a CBZ/ZIP archive.
pub fn read_cbz_page_bytes(path: &Path, entry_name: &str) -> Result<Vec<u8>, ComicError> {
    let file = File::open(path)?;
    let mut archive = ZipArchive::new(file)?;
    let mut entry = archive.by_name(entry_name)?;
    let mut buf = Vec::with_capacity(entry.size() as usize);
    entry.read_to_end(&mut buf)?;
    Ok(buf)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn filters_and_sorts_image_names() {
        assert!(is_supported_image_name("vol01/001.jpg"));
        assert!(is_supported_image_name("cover.WEBP"));
        assert!(!is_supported_image_name("__MACOSX/._001.jpg"));
        assert!(!is_supported_image_name("ComicInfo.xml"));

        let mut names = vec!["10.jpg", "2.jpg", "1.jpg"];
        names.sort_by(|a, b| natord::compare_ignore_case(a, b));
        assert_eq!(names, vec!["1.jpg", "2.jpg", "10.jpg"]);
    }

    #[test]
    fn parses_comic_info_xml_metadata() {
        let xml = r#"<ComicInfo><Series>浪客行</Series><Writer>井上雄彦</Writer><Volume>8</Volume><Manga>YesAndRightToLeft</Manga></ComicInfo>"#;
        let meta = parse_comic_info_xml(xml).unwrap();
        assert_eq!(meta.series.as_deref(), Some("浪客行"));
        assert_eq!(meta.writer.as_deref(), Some("井上雄彦"));
        assert_eq!(meta.recommended_reading_mode.as_deref(), Some("rtl"));
    }
}
