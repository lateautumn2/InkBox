use super::cbz::{is_supported_image_name, parse_comic_info_xml, ComicArchiveSummary, ComicError, ComicPageEntry};
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::Path;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DiscoveredComicChapter {
    pub title: String,
    pub source_path: String,
    pub format: String, // "folder" | "cbz" | "zip" | "cb7" | "cbr" | "pdf"
    pub page_count: usize,
}

/// Inspects a local image folder as a comic chapter with natural sorting.
pub fn inspect_image_folder(dir: &Path) -> Result<ComicArchiveSummary, ComicError> {
    let mut entries: Vec<(String, u64)> = Vec::new();
    let mut comic_info = None;
    let mut has_comic_info_xml = false;

    for item in fs::read_dir(dir)? {
        let entry = item?;
        let meta = entry.metadata()?;
        if !meta.is_file() {
            continue;
        }
        let name = entry.file_name().to_string_lossy().to_string();
        if name.eq_ignore_ascii_case("ComicInfo.xml") {
            has_comic_info_xml = true;
            if let Ok(xml) = fs::read_to_string(entry.path()) {
                comic_info = parse_comic_info_xml(&xml);
            }
            continue;
        }
        if is_supported_image_name(&name) {
            entries.push((entry.path().to_string_lossy().to_string(), meta.len()));
        }
    }

    entries.sort_by(|a, b| natord::compare_ignore_case(&a.0, &b.0));

    let pages: Vec<ComicPageEntry> = entries
        .into_iter()
        .enumerate()
        .map(|(index, (entry_name, uncompressed_size))| ComicPageEntry {
            index,
            entry_name,
            uncompressed_size,
        })
        .collect();

    let cover_entry = pages.first().map(|p| p.entry_name.clone());

    Ok(ComicArchiveSummary {
        page_count: pages.len(),
        has_comic_info_xml,
        comic_info,
        cover_entry,
        pages,
    })
}

/// Scans a series root folder and discovers nested chapter folders or volume archives.
pub fn discover_series_chapters(root_dir: &Path) -> Result<Vec<DiscoveredComicChapter>, ComicError> {
    let mut chapters = Vec::new();
    let mut raw_items: Vec<_> = fs::read_dir(root_dir)?
        .filter_map(|e| e.ok())
        .collect();
    raw_items.sort_by(|a, b| {
        natord::compare_ignore_case(
            &a.file_name().to_string_lossy(),
            &b.file_name().to_string_lossy(),
        )
    });

    for entry in raw_items {
        let path = entry.path();
        let name = entry.file_name().to_string_lossy().to_string();
        if name.starts_with('.') {
            continue;
        }
        if path.is_dir() {
            if let Ok(summary) = inspect_image_folder(&path) {
                if summary.page_count > 0 {
                    chapters.push(DiscoveredComicChapter {
                        title: name,
                        source_path: path.to_string_lossy().to_string(),
                        format: "folder".to_string(),
                        page_count: summary.page_count,
                    });
                }
            }
        } else if path.is_file() {
            let ext = path
                .extension()
                .and_then(|e| e.to_str())
                .map(|s| s.to_ascii_lowercase())
                .unwrap_or_default();
            if matches!(ext.as_str(), "cbz" | "zip" | "cb7" | "7z" | "cbr" | "rar" | "pdf") {
                let title = path
                    .file_stem()
                    .and_then(|s| s.to_str())
                    .unwrap_or(&name)
                    .to_string();
                let page_count = if matches!(ext.as_str(), "cbz" | "zip") {
                    super::cbz::inspect_cbz_archive(&path)
                        .map(|s| s.page_count)
                        .unwrap_or(0)
                } else {
                    0
                };
                chapters.push(DiscoveredComicChapter {
                    title,
                    source_path: path.to_string_lossy().to_string(),
                    format: ext,
                    page_count,
                });
            }
        }
    }

    // If root folder itself contains images directly (single-chapter folder), return root as 1 chapter.
    if chapters.is_empty() {
        if let Ok(summary) = inspect_image_folder(root_dir) {
            if summary.page_count > 0 {
                let title = root_dir
                    .file_name()
                    .and_then(|s| s.to_str())
                    .unwrap_or("第01话")
                    .to_string();
                chapters.push(DiscoveredComicChapter {
                    title,
                    source_path: root_dir.to_string_lossy().to_string(),
                    format: "folder".to_string(),
                    page_count: summary.page_count,
                });
            }
        }
    }

    Ok(chapters)
}
