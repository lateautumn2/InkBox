use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs::File;
use std::io::{Read, Write};
use std::path::Path;
use zip::write::SimpleFileOptions;
use zip::{CompressionMethod, ZipArchive, ZipWriter};

/// Layer 1 lightweight reading progress record synced via WebDAV JSON.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ProgressRecord {
    pub content_hash: String,
    pub media_kind: String, // "book" | "comic"
    pub locator: String,    // e.g., "chapter:14;offset:1280" or "chapter:8;page:14"
    pub progress_ratio: f64,
    pub updated_at_epoch_ms: i64,
    pub device_id: String,
    pub device_name: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub enum MergeOutcome {
    KeepLocal,
    AdoptRemote,
    Conflict,
}

/// Evaluates whether local and remote progress can be merged automatically or needs user conflict decision.
pub fn evaluate_progress_merge(
    local: &ProgressRecord,
    remote: &ProgressRecord,
    last_synced_epoch_ms: i64,
) -> MergeOutcome {
    let local_dirty = local.updated_at_epoch_ms > last_synced_epoch_ms;
    let remote_dirty = remote.updated_at_epoch_ms > last_synced_epoch_ms;

    if local.locator == remote.locator {
        return MergeOutcome::KeepLocal;
    }

    match (local_dirty, remote_dirty) {
        (false, true) => MergeOutcome::AdoptRemote,
        (true, false) => MergeOutcome::KeepLocal,
        (false, false) => {
            if remote.updated_at_epoch_ms > local.updated_at_epoch_ms {
                MergeOutcome::AdoptRemote
            } else {
                MergeOutcome::KeepLocal
            }
        }
        (true, true) => {
            if local.device_id == remote.device_id {
                if remote.updated_at_epoch_ms > local.updated_at_epoch_ms {
                    MergeOutcome::AdoptRemote
                } else {
                    MergeOutcome::KeepLocal
                }
            } else {
                MergeOutcome::Conflict
            }
        }
    }
}

/// Bookmark / Highlight / Note record merged per-UUID with tombstone support.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct AnnotationSyncRecord {
    pub uuid: String,
    pub content_hash: String,
    pub media_kind: String,
    pub kind: String,
    pub chapter_index: i32,
    pub locator: String,
    pub excerpt: String,
    pub note_text: String,
    pub color_hex: String,
    pub is_deleted: bool,
    pub updated_at_epoch_ms: i64,
}

/// UUID-keyed LWW three-way merge so offline notes across devices never clobber each other.
pub fn merge_annotations(
    local: &[AnnotationSyncRecord],
    remote: &[AnnotationSyncRecord],
) -> Vec<AnnotationSyncRecord> {
    let mut map: HashMap<String, AnnotationSyncRecord> = HashMap::new();
    for rec in local {
        map.insert(rec.uuid.clone(), rec.clone());
    }
    for rec in remote {
        match map.get(&rec.uuid) {
            Some(existing) if existing.updated_at_epoch_ms >= rec.updated_at_epoch_ms => {}
            _ => {
                map.insert(rec.uuid.clone(), rec.clone());
            }
        }
    }
    let mut merged: Vec<AnnotationSyncRecord> = map.into_values().collect();
    merged.sort_by_key(|r| (r.chapter_index, r.updated_at_epoch_ms));
    merged
}

/// Packs Layer 1 JSON files into a compressed `.zip` snapshot for `/InkBox/backups/`.
pub fn pack_backup_snapshot_zip(
    files: &HashMap<String, String>,
    output_zip_path: &Path,
) -> std::io::Result<usize> {
    if let Some(parent) = output_zip_path.parent() {
        std::fs::create_dir_all(parent)?;
    }
    let file = File::create(output_zip_path)?;
    let mut zip = ZipWriter::new(file);
    let opts = SimpleFileOptions::default().compression_method(CompressionMethod::Deflated);

    let mut keys: Vec<&String> = files.keys().collect();
    keys.sort();
    for k in keys {
        zip.start_file(k, opts)
            .map_err(|e| std::io::Error::other(e.to_string()))?;
        zip.write_all(files[k].as_bytes())?;
    }
    zip.finish()
        .map_err(|e| std::io::Error::other(e.to_string()))?;
    Ok(files.len())
}

/// Unpacks a backup snapshot `.zip` back into a map of `{ relative_path: json_string }`.
pub fn unpack_backup_snapshot_zip(zip_path: &Path) -> std::io::Result<HashMap<String, String>> {
    let file = File::open(zip_path)?;
    let mut archive =
        ZipArchive::new(file).map_err(|e| std::io::Error::other(e.to_string()))?;
    let mut out = HashMap::new();
    for i in 0..archive.len() {
        let mut entry = archive
            .by_index(i)
            .map_err(|e| std::io::Error::other(e.to_string()))?;
        if entry.is_dir() {
            continue;
        }
        let mut content = String::new();
        entry.read_to_string(&mut content)?;
        out.insert(entry.name().to_string(), content);
    }
    Ok(out)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sample(device: &str, locator: &str, ts: i64) -> ProgressRecord {
        ProgressRecord {
            content_hash: "abc123".into(),
            media_kind: "book".into(),
            locator: locator.into(),
            progress_ratio: 0.42,
            updated_at_epoch_ms: ts,
            device_id: device.into(),
            device_name: device.into(),
        }
    }

    #[test]
    fn detects_two_device_offline_conflict() {
        let local = sample("phone", "ch:14;off:200", 2000);
        let remote = sample("tablet", "ch:15;off:100", 2500);
        assert_eq!(evaluate_progress_merge(&local, &remote, 1000), MergeOutcome::Conflict);
    }

    #[test]
    fn adopts_remote_when_local_clean() {
        let local = sample("phone", "ch:14;off:200", 1000);
        let remote = sample("tablet", "ch:15;off:100", 2500);
        assert_eq!(evaluate_progress_merge(&local, &remote, 1000), MergeOutcome::AdoptRemote);
    }

    #[test]
    fn merges_annotations_from_two_devices_by_uuid_lww() {
        let a1 = AnnotationSyncRecord {
            uuid: "u1".into(),
            content_hash: "h1".into(),
            media_kind: "book".into(),
            kind: "highlight".into(),
            chapter_index: 1,
            locator: "1:10".into(),
            excerpt: "黑暗森林".into(),
            note_text: "旧笔记".into(),
            color_hex: "#EED29A".into(),
            is_deleted: false,
            updated_at_epoch_ms: 100,
        };
        let a1_newer = AnnotationSyncRecord {
            note_text: "新笔记".into(),
            updated_at_epoch_ms: 200,
            ..a1.clone()
        };
        let a2 = AnnotationSyncRecord {
            uuid: "u2".into(),
            updated_at_epoch_ms: 150,
            ..a1.clone()
        };
        let merged = merge_annotations(&[a1, a2], &[a1_newer]);
        assert_eq!(merged.len(), 2);
        let m1 = merged.iter().find(|r| r.uuid == "u1").unwrap();
        assert_eq!(m1.note_text, "新笔记");
    }
}
