use super::cbz::{is_supported_image_name, parse_comic_info_xml, ComicArchiveSummary, ComicError, ComicPageEntry};
use std::fs::File;
use std::path::Path;

/// Pure-Rust CB7 / 7Z archive inspector using `sevenz-rust`.
pub fn inspect_cb7_archive(path: &Path) -> Result<ComicArchiveSummary, ComicError> {
    let mut file = File::open(path)?;
    let len = file.metadata()?.len();
    let archive = sevenz_rust::Archive::read(&mut file, len, &[])
        .map_err(|e| ComicError::Archive(format!("7Z header read failed: {e}")))?;

    let mut image_entries: Vec<(String, u64)> = Vec::new();
    let mut has_comic_info_xml = false;

    for entry in &archive.files {
        if entry.is_directory {
            continue;
        }
        let name = entry.name.clone();
        if name.eq_ignore_ascii_case("ComicInfo.xml")
            || name.to_ascii_lowercase().ends_with("/comicinfo.xml")
        {
            has_comic_info_xml = true;
            continue;
        }
        if is_supported_image_name(&name) {
            image_entries.push((name, entry.size));
        }
    }

    image_entries.sort_by(|a, b| natord::compare_ignore_case(&a.0, &b.0));

    let pages: Vec<ComicPageEntry> = image_entries
        .into_iter()
        .enumerate()
        .map(|(index, (entry_name, uncompressed_size))| ComicPageEntry {
            index,
            entry_name,
            uncompressed_size,
        })
        .collect();

    let cover_entry = pages.first().map(|p| p.entry_name.clone());
    let comic_info = if has_comic_info_xml {
        read_cb7_entry_bytes(path, "ComicInfo.xml")
            .ok()
            .and_then(|b| String::from_utf8(b).ok())
            .and_then(|xml| parse_comic_info_xml(&xml))
    } else {
        None
    };

    Ok(ComicArchiveSummary {
        page_count: pages.len(),
        has_comic_info_xml,
        comic_info,
        cover_entry,
        pages,
    })
}

/// Extracts a single named entry's raw bytes from a CB7/7Z archive into memory.
pub fn read_cb7_entry_bytes(path: &Path, target_name: &str) -> Result<Vec<u8>, ComicError> {
    let mut file = File::open(path)?;
    let len = file.metadata()?.len();
    let mut reader = sevenz_rust::SevenZReader::new(&mut file, len, sevenz_rust::Password::empty())
        .map_err(|e| ComicError::Archive(format!("7Z open failed: {e}")))?;

    let mut found: Option<Vec<u8>> = None;
    let target_lower = target_name.to_ascii_lowercase();

    reader
        .for_each_entries(|entry, data_reader| {
            let matches = entry.name == target_name
                || entry.name.to_ascii_lowercase() == target_lower
                || entry
                    .name
                    .to_ascii_lowercase()
                    .ends_with(&format!("/{target_lower}"));
            if matches {
                let mut buf = Vec::with_capacity(entry.size as usize);
                data_reader.read_to_end(&mut buf)?;
                found = Some(buf);
                return Ok(false); // Stop scanning once extracted
            }
            Ok(true)
        })
        .map_err(|e| ComicError::Archive(format!("7Z read failed: {e}")))?;

    found.ok_or_else(|| ComicError::Archive(format!("Entry not found in 7Z: {target_name}")))
}
