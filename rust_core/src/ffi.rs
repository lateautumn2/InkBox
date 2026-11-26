use crate::book::types::{ChineseConversionMode, TextReplaceRule};
use crate::book::{epub, fb2_md, mobi, pdf, txt};
use crate::comic::{cb7, cbz, folder, image_proc};
use crate::health_check;
use crate::importer::{classify_by_extension, compute_fast_fingerprint};
use crate::webdav::{
    evaluate_progress_merge, merge_annotations, pack_backup_snapshot_zip,
    unpack_backup_snapshot_zip, AnnotationSyncRecord, ProgressRecord,
};
use base64::Engine;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::ffi::{CStr, CString};
use std::fs;
use std::os::raw::c_char;
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::path::Path;

#[derive(Serialize)]
struct FfiEnvelope<T: Serialize> {
    ok: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    data: Option<T>,
    #[serde(skip_serializing_if = "Option::is_none")]
    error: Option<String>,
}

fn to_c_string(s: String) -> *mut c_char {
    let sanitized = if s.contains('\0') {
        s.replace('\0', "")
    } else {
        s
    };
    CString::new(sanitized)
        .expect("sanitized string contains no NUL bytes")
        .into_raw()
}

fn ok_json<T: Serialize>(data: T) -> *mut c_char {
    let env = FfiEnvelope {
        ok: true,
        data: Some(data),
        error: None,
    };
    to_c_string(serde_json::to_string(&env).unwrap_or_else(|e| {
        format!(r#"{{"ok":false,"error":"serialize error: {}"}}"#, e)
    }))
}

fn err_json(msg: impl Into<String>) -> *mut c_char {
    let env: FfiEnvelope<()> = FfiEnvelope {
        ok: false,
        data: None,
        error: Some(msg.into()),
    };
    to_c_string(serde_json::to_string(&env).unwrap_or_else(|_| {
        r#"{"ok":false,"error":"unknown error"}"#.to_string()
    }))
}

unsafe fn read_c_str(ptr: *const c_char) -> Result<String, String> {
    if ptr.is_null() {
        return Err("null string pointer".to_string());
    }
    CStr::from_ptr(ptr)
        .to_str()
        .map(|s| s.to_string())
        .map_err(|e| format!("invalid UTF-8 string: {e}"))
}

fn guarded<F: FnOnce() -> *mut c_char>(f: F) -> *mut c_char {
    match catch_unwind(AssertUnwindSafe(f)) {
        Ok(ptr) => ptr,
        Err(_) => err_json("rust core panic recovered"),
    }
}

/// Frees a UTF-8 C string returned by any `inkbox_*_json` function.
///
/// # Safety
/// `ptr` must have been allocated by `inkbox_*_json` and not previously freed.
#[no_mangle]
pub unsafe extern "C" fn inkbox_free_string(ptr: *mut c_char) {
    if !ptr.is_null() {
        let _ = CString::from_raw(ptr);
    }
}

#[no_mangle]
pub extern "C" fn inkbox_health_json() -> *mut c_char {
    guarded(|| ok_json(health_check()))
}

/// # Safety
/// `path_ptr` must be a valid NUL-terminated UTF-8 C string.
#[no_mangle]
pub unsafe extern "C" fn inkbox_classify_path_json(path_ptr: *const c_char) -> *mut c_char {
    guarded(|| match read_c_str(path_ptr) {
        Ok(p) => ok_json(classify_by_extension(Path::new(&p))),
        Err(e) => err_json(e),
    })
}

/// # Safety
/// `path_ptr` must be a valid NUL-terminated UTF-8 C string.
#[no_mangle]
pub unsafe extern "C" fn inkbox_fast_fingerprint_json(path_ptr: *const c_char) -> *mut c_char {
    guarded(|| match read_c_str(path_ptr) {
        Ok(p) => match compute_fast_fingerprint(Path::new(&p)) {
            Ok(hash) => ok_json(hash),
            Err(e) => err_json(e.to_string()),
        },
        Err(e) => err_json(e),
    })
}

/// # Safety
/// `path_ptr` must be a valid NUL-terminated UTF-8 C string; `regex_ptr` may be NULL.
#[no_mangle]
pub unsafe extern "C" fn inkbox_index_txt_json(
    path_ptr: *const c_char,
    regex_ptr: *const c_char,
) -> *mut c_char {
    guarded(|| {
        let path = match read_c_str(path_ptr) {
            Ok(p) => p,
            Err(e) => return err_json(e),
        };
        let custom_re = if regex_ptr.is_null() {
            None
        } else {
            match read_c_str(regex_ptr) {
                Ok(r) if !r.trim().is_empty() => Some(r),
                Ok(_) => None,
                Err(e) => return err_json(e),
            }
        };
        match txt::index_txt_file(Path::new(&path), custom_re.as_deref(), None) {
            Ok(res) => ok_json(res),
            Err(e) => err_json(e.to_string()),
        }
    })
}

#[derive(Deserialize)]
struct IndexTxtWithRulesReq {
    path: String,
    forced_encoding: Option<String>,
    forced_rule: Option<txt::TxtTocRule>,
    #[serde(default)]
    rules: Vec<txt::TxtTocRule>,
}

/// Indexes a TXT file using a provided rule list (Legado-compatible) and optional forced rule/encoding.
///
/// # Safety
/// `req_ptr` must be a valid NUL-terminated UTF-8 JSON string.
#[no_mangle]
pub unsafe extern "C" fn inkbox_index_txt_with_rules_json(req_ptr: *const c_char) -> *mut c_char {
    guarded(|| {
        let raw = match read_c_str(req_ptr) {
            Ok(s) => s,
            Err(e) => return err_json(e),
        };
        let req: IndexTxtWithRulesReq = match serde_json::from_str(&raw) {
            Ok(r) => r,
            Err(e) => return err_json(format!("invalid txt index request: {e}")),
        };
        match txt::index_txt_file_with_rules(
            Path::new(&req.path),
            &req.rules,
            req.forced_rule.as_ref(),
            req.forced_encoding.as_deref(),
        ) {
            Ok(res) => ok_json(res),
            Err(e) => err_json(e.to_string()),
        }
    })
}

#[derive(Deserialize)]
struct TestTocRuleReq {
    pattern: String,
    sample_text: Option<String>,
    path: Option<String>,
    forced_encoding: Option<String>,
    #[serde(default = "default_preview_limit")]
    max_preview: usize,
}

fn default_preview_limit() -> usize {
    20
}

/// Validates and tests a TXT TOC regex pattern against sample text or a local TXT file.
///
/// # Safety
/// `req_ptr` must be a valid NUL-terminated UTF-8 JSON string.
#[no_mangle]
pub unsafe extern "C" fn inkbox_test_toc_rule_json(req_ptr: *const c_char) -> *mut c_char {
    guarded(|| {
        let raw = match read_c_str(req_ptr) {
            Ok(s) => s,
            Err(e) => return err_json(e),
        };
        let req: TestTocRuleReq = match serde_json::from_str(&raw) {
            Ok(r) => r,
            Err(e) => return err_json(format!("invalid test toc rule request: {e}")),
        };
        let text = if let Some(sample) = req.sample_text {
            sample
        } else if let Some(path) = req.path {
            match fs::read(&path) {
                Ok(bytes) => {
                    let (decoded, _) =
                        txt::decode_txt_with_encoding(&bytes, req.forced_encoding.as_deref());
                    decoded
                }
                Err(e) => return err_json(e.to_string()),
            }
        } else {
            String::new()
        };
        ok_json(txt::test_toc_rule(&req.pattern, &text, req.max_preview))
    })
}

/// Returns built-in Legado-compatible default TXT TOC rules.
#[no_mangle]
pub extern "C" fn inkbox_default_toc_rules_json() -> *mut c_char {
    guarded(|| ok_json(txt::default_toc_rules()))
}

#[derive(Deserialize)]
struct ReadBookChapterReq {
    format: String,
    path: String,
    chapter_index: usize,
    href: Option<String>,
    title: Option<String>,
    start_byte: Option<usize>,
    end_byte: Option<usize>,
    forced_encoding: Option<String>,
    #[serde(default)]
    replace_rules: Vec<TextReplaceRule>,
    #[serde(default = "default_cn_mode")]
    cn_mode: ChineseConversionMode,
}

fn default_cn_mode() -> ChineseConversionMode {
    ChineseConversionMode::None
}

/// Unified chapter content reader for TXT / EPUB / MOBI / AZW3 / FB2 / MD.
///
/// # Safety
/// `req_ptr` must be a valid NUL-terminated UTF-8 JSON string.
#[no_mangle]
pub unsafe extern "C" fn inkbox_read_book_chapter_json(req_ptr: *const c_char) -> *mut c_char {
    guarded(|| {
        let raw = match read_c_str(req_ptr) {
            Ok(s) => s,
            Err(e) => return err_json(e),
        };
        let req: ReadBookChapterReq = match serde_json::from_str(&raw) {
            Ok(r) => r,
            Err(e) => return err_json(format!("invalid book chapter request: {e}")),
        };
        let fmt = req.format.to_ascii_lowercase();
        let path = Path::new(&req.path);
        let title = req.title.as_deref().unwrap_or("正文");

        match fmt.as_str() {
            "txt" => {
                let start = req.start_byte.unwrap_or(0);
                let end = req.end_byte.unwrap_or(0);
                match txt::read_txt_chapter(
                    path,
                    req.chapter_index,
                    start,
                    end,
                    title,
                    req.forced_encoding.as_deref(),
                    &req.replace_rules,
                    req.cn_mode,
                ) {
                    Ok(c) => ok_json(c),
                    Err(e) => err_json(e.to_string()),
                }
            }
            "epub" => {
                let href = req.href.as_deref().unwrap_or("");
                match epub::read_epub_chapter(
                    path,
                    req.chapter_index,
                    href,
                    title,
                    &req.replace_rules,
                    req.cn_mode,
                ) {
                    Ok(c) => ok_json(c),
                    Err(e) => err_json(e.to_string()),
                }
            }
            "mobi" | "azw3" => {
                match mobi::read_mobi_chapter(path, req.chapter_index, &req.replace_rules, req.cn_mode) {
                    Ok(c) => ok_json(c),
                    Err(e) => err_json(e.to_string()),
                }
            }
            "fb2" => match fb2_md::read_fb2_chapter(
                path,
                req.chapter_index,
                &req.replace_rules,
                req.cn_mode,
            ) {
                Ok(c) => ok_json(c),
                Err(e) => err_json(e.to_string()),
            },
            "md" | "markdown" => match fb2_md::read_markdown_chapter(
                path,
                req.chapter_index,
                &req.replace_rules,
                req.cn_mode,
            ) {
                Ok(c) => ok_json(c),
                Err(e) => err_json(e.to_string()),
            },
            "pdf" => match pdf::read_pdf_page_reflow(
                path,
                req.chapter_index,
                &req.replace_rules,
                req.cn_mode,
            ) {
                Ok(c) => ok_json(c),
                Err(e) => err_json(e.to_string()),
            },
            _ => err_json(format!("unsupported book format: {fmt}")),
        }
    })
}

/// # Safety
/// `path_ptr` must be a valid NUL-terminated UTF-8 C string.
#[no_mangle]
pub unsafe extern "C" fn inkbox_parse_epub_json(path_ptr: *const c_char) -> *mut c_char {
    guarded(|| match read_c_str(path_ptr) {
        Ok(p) => match epub::parse_epub_metadata(Path::new(&p)) {
            Ok(meta) => ok_json(meta),
            Err(e) => err_json(e.to_string()),
        },
        Err(e) => err_json(e),
    })
}

/// # Safety
/// `path_ptr` must be a valid NUL-terminated UTF-8 C string.
#[no_mangle]
pub unsafe extern "C" fn inkbox_parse_mobi_json(path_ptr: *const c_char) -> *mut c_char {
    guarded(|| match read_c_str(path_ptr) {
        Ok(p) => match mobi::parse_mobi_metadata(Path::new(&p)) {
            Ok(meta) => ok_json(meta),
            Err(e) => err_json(e.to_string()),
        },
        Err(e) => err_json(e),
    })
}

/// # Safety
/// `path_ptr` must be a valid NUL-terminated UTF-8 C string.
#[no_mangle]
pub unsafe extern "C" fn inkbox_parse_pdf_json(path_ptr: *const c_char) -> *mut c_char {
    guarded(|| match read_c_str(path_ptr) {
        Ok(p) => match pdf::parse_pdf_summary(Path::new(&p)) {
            Ok(meta) => ok_json(meta),
            Err(e) => err_json(e.to_string()),
        },
        Err(e) => err_json(e),
    })
}

/// # Safety
/// `path_ptr` & `format_ptr` must be valid NUL-terminated UTF-8 C strings.
#[no_mangle]
pub unsafe extern "C" fn inkbox_parse_structured_book_json(
    path_ptr: *const c_char,
    format_ptr: *const c_char,
) -> *mut c_char {
    guarded(|| {
        let p = match read_c_str(path_ptr) {
            Ok(s) => s,
            Err(e) => return err_json(e),
        };
        let fmt = match read_c_str(format_ptr) {
            Ok(s) => s.to_ascii_lowercase(),
            Err(e) => return err_json(e),
        };
        match fmt.as_str() {
            "fb2" => match fb2_md::parse_fb2_summary(Path::new(&p)) {
                Ok(s) => ok_json(s),
                Err(e) => err_json(e.to_string()),
            },
            "md" | "markdown" => match fb2_md::parse_markdown_summary(Path::new(&p)) {
                Ok(s) => ok_json(s),
                Err(e) => err_json(e.to_string()),
            },
            _ => err_json(format!("unsupported structured format: {fmt}")),
        }
    })
}

/// Extracts and writes a downsampled JPEG cover thumbnail for EPUB/FB2/CBZ/CB7/Folder.
///
/// # Safety
/// All string pointers must be valid NUL-terminated UTF-8 C strings.
#[no_mangle]
pub unsafe extern "C" fn inkbox_extract_cover_thumbnail_json(
    source_path_ptr: *const c_char,
    format_ptr: *const c_char,
    out_jpg_ptr: *const c_char,
) -> *mut c_char {
    guarded(|| {
        let src = match read_c_str(source_path_ptr) {
            Ok(s) => s,
            Err(e) => return err_json(e),
        };
        let fmt = match read_c_str(format_ptr) {
            Ok(s) => s.to_ascii_lowercase(),
            Err(e) => return err_json(e),
        };
        let out_jpg = match read_c_str(out_jpg_ptr) {
            Ok(s) => s,
            Err(e) => return err_json(e),
        };

        let p = Path::new(&src);
        let raw_img: Option<Vec<u8>> = match fmt.as_str() {
            "epub" => epub::extract_epub_cover_bytes(p).ok().flatten(),
            "fb2" => fb2_md::extract_fb2_cover_bytes(p).ok().flatten(),
            "cbz" | "zip" => cbz::inspect_cbz_archive(p)
                .ok()
                .and_then(|s| s.cover_entry)
                .and_then(|entry| cbz::read_cbz_page_bytes(p, &entry).ok()),
            "cb7" | "7z" => cb7::inspect_cb7_archive(p)
                .ok()
                .and_then(|s| s.cover_entry)
                .and_then(|entry| cb7::read_cb7_entry_bytes(p, &entry).ok()),
            "folder" => folder::inspect_image_folder(p)
                .ok()
                .and_then(|s| s.cover_entry)
                .and_then(|img_path| fs::read(img_path).ok()),
            _ => None,
        };

        let Some(bytes) = raw_img else {
            return ok_json(false);
        };
        match image_proc::make_cover_thumbnail(&bytes, 360) {
            Ok(thumb) => {
                if let Some(parent) = Path::new(&out_jpg).parent() {
                    let _ = fs::create_dir_all(parent);
                }
                match fs::write(&out_jpg, thumb) {
                    Ok(_) => ok_json(true),
                    Err(e) => err_json(e.to_string()),
                }
            }
            Err(e) => err_json(e.to_string()),
        }
    })
}

/// Inspects CBZ/ZIP, CB7/7Z, or image folder comics without decompressing to disk.
///
/// # Safety
/// `path_ptr` must be a valid NUL-terminated UTF-8 C string.
#[no_mangle]
pub unsafe extern "C" fn inkbox_inspect_cbz_json(path_ptr: *const c_char) -> *mut c_char {
    guarded(|| match read_c_str(path_ptr) {
        Ok(p) => {
            let path = Path::new(&p);
            if path.is_dir() {
                return match folder::inspect_image_folder(path) {
                    Ok(s) => ok_json(s),
                    Err(e) => err_json(e.to_string()),
                };
            }
            let ext = path
                .extension()
                .and_then(|e| e.to_str())
                .map(|s| s.to_ascii_lowercase())
                .unwrap_or_default();
            match ext.as_str() {
                "cb7" | "7z" => match cb7::inspect_cb7_archive(path) {
                    Ok(s) => ok_json(s),
                    Err(e) => err_json(e.to_string()),
                },
                _ => match cbz::inspect_cbz_archive(path) {
                    Ok(s) => ok_json(s),
                    Err(e) => err_json(e.to_string()),
                },
            }
        }
        Err(e) => err_json(e),
    })
}

/// Discovers nested chapters/volumes inside a comic series folder.
///
/// # Safety
/// `dir_ptr` must be a valid NUL-terminated UTF-8 C string.
#[no_mangle]
pub unsafe extern "C" fn inkbox_discover_comic_chapters_json(dir_ptr: *const c_char) -> *mut c_char {
    guarded(|| match read_c_str(dir_ptr) {
        Ok(p) => match folder::discover_series_chapters(Path::new(&p)) {
            Ok(list) => ok_json(list),
            Err(e) => err_json(e.to_string()),
        },
        Err(e) => err_json(e),
    })
}

#[derive(Serialize)]
struct ComicPagePayload {
    image_base64: String,
    width: u32,
    height: u32,
    is_wide_spread: bool,
    crop_rect: image_proc::CropRect,
}

/// Streams a single comic page (from CBZ/ZIP, CB7/7Z, or folder) along with
/// fast header dimensions, spread detection, and optional smart white-border crop rect.
///
/// # Safety
/// All pointers must be valid NUL-terminated UTF-8 C strings.
#[no_mangle]
pub unsafe extern "C" fn inkbox_read_comic_page_json(
    archive_path_ptr: *const c_char,
    entry_name_ptr: *const c_char,
    compute_crop: u8,
) -> *mut c_char {
    guarded(|| {
        let archive_path = match read_c_str(archive_path_ptr) {
            Ok(s) => s,
            Err(e) => return err_json(e),
        };
        let entry_name = match read_c_str(entry_name_ptr) {
            Ok(s) => s,
            Err(e) => return err_json(e),
        };

        let p = Path::new(&archive_path);
        let bytes_res = if p.is_dir() {
            fs::read(&entry_name).map_err(|e| e.to_string())
        } else {
            let ext = p
                .extension()
                .and_then(|e| e.to_str())
                .map(|s| s.to_ascii_lowercase())
                .unwrap_or_default();
            if ext == "cb7" || ext == "7z" {
                cb7::read_cb7_entry_bytes(p, &entry_name).map_err(|e| e.to_string())
            } else {
                cbz::read_cbz_page_bytes(p, &entry_name).map_err(|e| e.to_string())
            }
        };

        let bytes = match bytes_res {
            Ok(b) => b,
            Err(e) => return err_json(e),
        };

        let dims = image_proc::inspect_image_dimensions(&bytes).unwrap_or(image_proc::ImageDimensions {
            width: 0,
            height: 0,
            is_wide_spread: false,
        });
        let crop_rect = if compute_crop != 0 {
            image_proc::detect_smart_crop_rect(&bytes).unwrap_or_default()
        } else {
            image_proc::CropRect::default()
        };

        ok_json(ComicPagePayload {
            image_base64: base64::engine::general_purpose::STANDARD.encode(&bytes),
            width: dims.width,
            height: dims.height,
            is_wide_spread: dims.is_wide_spread,
            crop_rect,
        })
    })
}

/// Reads an embedded EPUB image/resource as base64.
///
/// # Safety
/// Both pointers must be valid NUL-terminated UTF-8 C strings.
#[no_mangle]
pub unsafe extern "C" fn inkbox_read_epub_resource_base64_json(
    epub_path_ptr: *const c_char,
    resource_href_ptr: *const c_char,
) -> *mut c_char {
    guarded(|| {
        let epub_path = match read_c_str(epub_path_ptr) {
            Ok(s) => s,
            Err(e) => return err_json(e),
        };
        let href = match read_c_str(resource_href_ptr) {
            Ok(s) => s,
            Err(e) => return err_json(e),
        };
        match epub::read_epub_resource_bytes(Path::new(&epub_path), &href) {
            Ok(bytes) => ok_json(base64::engine::general_purpose::STANDARD.encode(bytes)),
            Err(e) => err_json(e.to_string()),
        }
    })
}

#[derive(Deserialize)]
struct MergeRequest {
    local: ProgressRecord,
    remote: ProgressRecord,
    last_synced_epoch_ms: i64,
}

/// # Safety
/// `payload_ptr` must be a valid NUL-terminated UTF-8 JSON string.
#[no_mangle]
pub unsafe extern "C" fn inkbox_evaluate_progress_merge_json(
    payload_ptr: *const c_char,
) -> *mut c_char {
    guarded(|| match read_c_str(payload_ptr) {
        Ok(json_str) => match serde_json::from_str::<MergeRequest>(&json_str) {
            Ok(req) => ok_json(evaluate_progress_merge(
                &req.local,
                &req.remote,
                req.last_synced_epoch_ms,
            )),
            Err(e) => err_json(format!("invalid merge payload: {e}")),
        },
        Err(e) => err_json(e),
    })
}

#[derive(Deserialize)]
struct MergeAnnotationsReq {
    local: Vec<AnnotationSyncRecord>,
    remote: Vec<AnnotationSyncRecord>,
}

/// # Safety
/// `payload_ptr` must be a valid NUL-terminated UTF-8 JSON string.
#[no_mangle]
pub unsafe extern "C" fn inkbox_merge_annotations_json(
    payload_ptr: *const c_char,
) -> *mut c_char {
    guarded(|| match read_c_str(payload_ptr) {
        Ok(json_str) => match serde_json::from_str::<MergeAnnotationsReq>(&json_str) {
            Ok(req) => ok_json(merge_annotations(&req.local, &req.remote)),
            Err(e) => err_json(format!("invalid annotation merge payload: {e}")),
        },
        Err(e) => err_json(e),
    })
}

#[derive(Deserialize)]
struct PackSnapshotReq {
    files: HashMap<String, String>,
    output_zip_path: String,
}

/// # Safety
/// `payload_ptr` must be a valid NUL-terminated UTF-8 JSON string.
#[no_mangle]
pub unsafe extern "C" fn inkbox_pack_snapshot_zip_json(payload_ptr: *const c_char) -> *mut c_char {
    guarded(|| match read_c_str(payload_ptr) {
        Ok(json_str) => match serde_json::from_str::<PackSnapshotReq>(&json_str) {
            Ok(req) => match pack_backup_snapshot_zip(&req.files, Path::new(&req.output_zip_path)) {
                Ok(count) => ok_json(count),
                Err(e) => err_json(e.to_string()),
            },
            Err(e) => err_json(format!("invalid pack snapshot payload: {e}")),
        },
        Err(e) => err_json(e),
    })
}

/// # Safety
/// `zip_path_ptr` must be a valid NUL-terminated UTF-8 C string.
#[no_mangle]
pub unsafe extern "C" fn inkbox_unpack_snapshot_zip_json(zip_path_ptr: *const c_char) -> *mut c_char {
    guarded(|| match read_c_str(zip_path_ptr) {
        Ok(p) => match unpack_backup_snapshot_zip(Path::new(&p)) {
            Ok(map) => ok_json(map),
            Err(e) => err_json(e.to_string()),
        },
        Err(e) => err_json(e),
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn health_ffi_roundtrip_works() {
        unsafe {
            let ptr = inkbox_health_json();
            assert!(!ptr.is_null());
            let json = CStr::from_ptr(ptr).to_str().unwrap().to_string();
            inkbox_free_string(ptr);
            assert!(json.contains(r#""ok":true"#));
            assert!(json.contains("inkbox_core"));
        }
    }

    #[test]
    fn toc_rules_ffi_roundtrip_works() {
        unsafe {
            let rules_ptr = inkbox_default_toc_rules_json();
            assert!(!rules_ptr.is_null());
            let rules_json = CStr::from_ptr(rules_ptr).to_str().unwrap().to_string();
            inkbox_free_string(rules_ptr);
            assert!(rules_json.contains(r#""ok":true"#));
            assert!(rules_json.contains("目录(去空白"));

            let payload = CString::new(
                r#"{"pattern":"^第[0-9一二三]+章.{0,20}$","sample_text":"第一章 启程\r\n正文\r\n第二章 远航\r\n内容"}"#,
            )
            .unwrap();
            let test_ptr = inkbox_test_toc_rule_json(payload.as_ptr());
            let test_json = CStr::from_ptr(test_ptr).to_str().unwrap().to_string();
            inkbox_free_string(test_ptr);
            assert!(test_json.contains(r#""valid":true"#));
            assert!(test_json.contains(r#""match_count":2"#));
        }
    }
}
