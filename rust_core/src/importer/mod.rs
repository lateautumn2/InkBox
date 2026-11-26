use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::fs::File;
use std::io::{Read, Seek, SeekFrom};
use std::path::Path;

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
pub enum MediaKind {
    Book,
    Comic,
    Unknown,
}

/// Smart auto-classification by extension (PDF defaults to Book until inspected).
pub fn classify_by_extension(path: &Path) -> MediaKind {
    if path.is_dir() {
        return MediaKind::Comic;
    }
    let ext = path
        .extension()
        .and_then(|e| e.to_str())
        .map(|s| s.to_ascii_lowercase())
        .unwrap_or_default();

    match ext.as_str() {
        "epub" | "txt" | "mobi" | "azw3" | "fb2" | "md" | "pdf" => MediaKind::Book,
        "cbz" | "zip" | "cbr" | "rar" | "cb7" | "7z" => MediaKind::Comic,
        _ => MediaKind::Unknown,
    }
}

fn read_up_to(file: &mut File, max_bytes: usize) -> std::io::Result<Vec<u8>> {
    let mut out = vec![0u8; max_bytes];
    let mut filled = 0usize;
    while filled < max_bytes {
        let n = file.read(&mut out[filled..])?;
        if n == 0 {
            break;
        }
        filled += n;
    }
    out.truncate(filled);
    Ok(out)
}

/// Computes a fast dedup fingerprint using exact file size + head 64KB + middle 64KB + tail 64KB.
/// Rejects empty (0-byte) files so failed SAF copies can never collide on an empty-file hash.
pub fn compute_fast_fingerprint(path: &Path) -> std::io::Result<String> {
    const CHUNK: usize = 64 * 1024;
    let mut file = File::open(path)?;
    let len = file.metadata()?.len();
    if len == 0 {
        return Err(std::io::Error::new(
            std::io::ErrorKind::InvalidData,
            "文件内容为空 (0 字节)，无法计算指纹",
        ));
    }

    let mut hasher = Sha256::new();
    hasher.update(len.to_le_bytes());

    let head = read_up_to(&mut file, CHUNK)?;
    hasher.update(&head);

    if len > (CHUNK as u64) * 2 {
        let mid_start = (len / 2).saturating_sub((CHUNK / 2) as u64);
        file.seek(SeekFrom::Start(mid_start))?;
        let mid = read_up_to(&mut file, CHUNK)?;
        hasher.update(&mid);
    }

    if len > CHUNK as u64 {
        let tail_start = len.saturating_sub(CHUNK as u64);
        file.seek(SeekFrom::Start(tail_start))?;
        let tail = read_up_to(&mut file, CHUNK)?;
        hasher.update(&tail);
    }

    Ok(hex::encode(hasher.finalize()))
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Write;

    #[test]
    fn classifies_common_formats() {
        assert_eq!(classify_by_extension(Path::new("dune.epub")), MediaKind::Book);
        assert_eq!(classify_by_extension(Path::new("novel.TXT")), MediaKind::Book);
        assert_eq!(classify_by_extension(Path::new("vagabond.cbz")), MediaKind::Comic);
        assert_eq!(classify_by_extension(Path::new("berserk.CBR")), MediaKind::Comic);
        assert_eq!(classify_by_extension(Path::new("notes.exe")), MediaKind::Unknown);
    }

    #[test]
    fn rejects_empty_file_and_distinguishes_middle_bytes() {
        let tmp = std::env::temp_dir().join("inkbox_fp_test");
        let _ = std::fs::create_dir_all(&tmp);
        let empty = tmp.join("empty.txt");
        std::fs::write(&empty, b"").unwrap();
        assert!(compute_fast_fingerprint(&empty).is_err());

        // Same size (200KB), identical first 64KB & last 64KB, different middle bytes
        let f1 = tmp.join("same_edges_1.txt");
        let f2 = tmp.join("same_edges_2.txt");
        let mut d1 = vec![b'A'; 200 * 1024];
        let mut d2 = vec![b'A'; 200 * 1024];
        d1[100 * 1024] = b'1';
        d2[100 * 1024] = b'2';
        File::create(&f1).unwrap().write_all(&d1).unwrap();
        File::create(&f2).unwrap().write_all(&d2).unwrap();

        let h1 = compute_fast_fingerprint(&f1).unwrap();
        let h2 = compute_fast_fingerprint(&f2).unwrap();
        assert_ne!(h1, h2);
        let _ = std::fs::remove_dir_all(&tmp);
    }
}
