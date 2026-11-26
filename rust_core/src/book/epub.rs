use super::chinese_convert::convert_chinese;
use super::mobi::decode_html_entities;
use super::types::{
    apply_replace_rules, blocks_to_plain_text, BookBlock, BookChapterContent, BookChapterMeta,
    ChineseConversionMode, TextReplaceRule,
};
use regex::Regex;
use roxmltree::Document;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs::File;
use std::io::Read;
use std::path::Path;
use thiserror::Error;
use zip::ZipArchive;

#[derive(Debug, Error)]
pub enum EpubError {
    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),
    #[error("ZIP error: {0}")]
    Zip(#[from] zip::result::ZipError),
    #[error("XML error: {0}")]
    Xml(#[from] roxmltree::Error),
    #[error("Invalid EPUB structure: {0}")]
    InvalidStructure(String),
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EpubMetadata {
    pub title: String,
    pub author: String,
    pub language: Option<String>,
    pub description: Option<String>,
    pub cover_href: Option<String>,
    pub spine_count: usize,
    pub chapters: Vec<BookChapterMeta>,
}

fn read_zip_text(archive: &mut ZipArchive<File>, entry_path: &str) -> Result<String, EpubError> {
    let resolved_name = if archive.by_name(entry_path).is_ok() {
        entry_path.to_string()
    } else {
        let decoded = percent_decode_href(entry_path);
        if decoded != entry_path && archive.by_name(&decoded).is_ok() {
            decoded
        } else {
            entry_path.to_string()
        }
    };
    let mut entry = archive.by_name(&resolved_name)?;
    let mut buf = String::new();
    entry.read_to_string(&mut buf)?;
    Ok(buf)
}

fn read_zip_bytes(archive: &mut ZipArchive<File>, entry_path: &str) -> Result<Vec<u8>, EpubError> {
    let resolved_name = if archive.by_name(entry_path).is_ok() {
        entry_path.to_string()
    } else {
        let decoded = percent_decode_href(entry_path);
        if decoded != entry_path && archive.by_name(&decoded).is_ok() {
            decoded
        } else {
            entry_path.to_string()
        }
    };
    let mut entry = archive.by_name(&resolved_name)?;
    let mut buf = Vec::with_capacity(entry.size() as usize);
    entry.read_to_end(&mut buf)?;
    Ok(buf)
}

fn percent_decode_href(input: &str) -> String {
    let bytes = input.as_bytes();
    let mut out = Vec::with_capacity(bytes.len());
    let mut i = 0;
    while i < bytes.len() {
        if bytes[i] == b'%' && i + 2 < bytes.len() {
            if let Ok(hex_str) = std::str::from_utf8(&bytes[i + 1..i + 3]) {
                if let Ok(val) = u8::from_str_radix(hex_str, 16) {
                    out.push(val);
                    i += 3;
                    continue;
                }
            }
        }
        out.push(bytes[i]);
        i += 1;
    }
    String::from_utf8_lossy(&out).into_owned()
}

fn resolve_relative(base_dir: &str, href: &str) -> String {
    let clean_href = href.split('#').next().unwrap_or(href);
    let combined = if base_dir.is_empty() {
        clean_href.trim_start_matches('/').to_string()
    } else {
        format!(
            "{}/{}",
            base_dir.trim_end_matches('/'),
            clean_href.trim_start_matches('/')
        )
    };
    let mut stack: Vec<&str> = Vec::new();
    for seg in combined.split('/') {
        match seg {
            "" | "." => {}
            ".." => {
                stack.pop();
            }
            other => stack.push(other),
        }
    }
    stack.join("/")
}

fn locate_opf(archive: &mut ZipArchive<File>) -> Result<(String, String), EpubError> {
    let container_xml = read_zip_text(archive, "META-INF/container.xml")?;
    let container_doc = Document::parse(&container_xml)?;
    let opf_path = container_doc
        .descendants()
        .find(|n| n.has_tag_name("rootfile"))
        .and_then(|n| n.attribute("full-path"))
        .ok_or_else(|| EpubError::InvalidStructure("Missing rootfile in container.xml".into()))?
        .to_string();
    let opf_dir = match opf_path.rfind('/') {
        Some(idx) => opf_path[..idx].to_string(),
        None => String::new(),
    };
    Ok((opf_path, opf_dir))
}

/// Parses EPUB 2/3 metadata, cover path, and complete chapter table of contents.
pub fn parse_epub_metadata(path: &Path) -> Result<EpubMetadata, EpubError> {
    let file = File::open(path)?;
    let mut archive = ZipArchive::new(file)?;
    let (opf_path, opf_dir) = locate_opf(&mut archive)?;

    let opf_xml = read_zip_text(&mut archive, &opf_path)?;
    let opf_doc = Document::parse(&opf_xml)?;

    let title = opf_doc
        .descendants()
        .find(|n| n.tag_name().name() == "title")
        .and_then(|n| n.text())
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
        .unwrap_or_else(|| {
            path.file_stem()
                .and_then(|s| s.to_str())
                .unwrap_or("未命名书籍")
                .to_string()
        });

    let author = opf_doc
        .descendants()
        .find(|n| n.tag_name().name() == "creator")
        .and_then(|n| n.text())
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
        .unwrap_or_else(|| "未知作者".to_string());

    let language = opf_doc
        .descendants()
        .find(|n| n.tag_name().name() == "language")
        .and_then(|n| n.text())
        .map(|s| s.trim().to_string());

    let description = opf_doc
        .descendants()
        .find(|n| n.tag_name().name() == "description")
        .and_then(|n| n.text())
        .map(|s| s.trim().to_string());

    let cover_id = opf_doc
        .descendants()
        .find(|n| n.tag_name().name() == "meta" && n.attribute("name") == Some("cover"))
        .and_then(|n| n.attribute("content"));

    let mut manifest: HashMap<String, String> = HashMap::new();
    let mut ncx_href: Option<String> = None;
    let mut nav_href: Option<String> = None;
    let mut cover_href: Option<String> = None;

    for item in opf_doc
        .descendants()
        .filter(|n| n.tag_name().name() == "item")
    {
        let id = item.attribute("id").unwrap_or("");
        let href = item.attribute("href").unwrap_or("");
        let media_type = item.attribute("media-type").unwrap_or("");
        let props = item.attribute("properties").unwrap_or("");

        if !id.is_empty() && !href.is_empty() {
            let resolved = resolve_relative(&opf_dir, href);
            manifest.insert(id.to_string(), resolved.clone());
            if media_type == "application/x-dtbncx+xml" || resolved.ends_with(".ncx") {
                ncx_href = Some(resolved.clone());
            }
            if props.split_whitespace().any(|tok| tok == "nav") {
                nav_href = Some(resolved.clone());
            }
            if props.split_whitespace().any(|tok| tok == "cover-image")
                || (cover_id.is_some() && Some(id) == cover_id)
            {
                cover_href = Some(resolved);
            }
        }
    }

    let spine_hrefs: Vec<String> = opf_doc
        .descendants()
        .filter(|n| n.tag_name().name() == "itemref")
        .filter_map(|n| n.attribute("idref"))
        .filter_map(|idref| manifest.get(idref).cloned())
        .collect();
    let spine_count = spine_hrefs.len();

    // Try NCX TOC first, then fall back to EPUB3 nav if NCX was missing or empty.
    let mut toc_titles: HashMap<String, String> = HashMap::new();
    if let Some(ncx) = ncx_href {
        if let Ok(ncx_xml) = read_zip_text(&mut archive, &ncx) {
            if let Ok(ncx_doc) = Document::parse(&ncx_xml) {
                let ncx_dir = match ncx.rfind('/') {
                    Some(i) => &ncx[..i],
                    None => "",
                };
                for nav_point in ncx_doc
                    .descendants()
                    .filter(|n| n.tag_name().name() == "navPoint")
                {
                    let label = nav_point
                        .descendants()
                        .find(|n| n.tag_name().name() == "text")
                        .and_then(|n| n.text())
                        .map(|s| s.trim().to_string())
                        .unwrap_or_default();
                    let src = nav_point
                        .descendants()
                        .find(|n| n.tag_name().name() == "content")
                        .and_then(|n| n.attribute("src"))
                        .map(|s| resolve_relative(ncx_dir, s))
                        .unwrap_or_default();
                    if !label.is_empty() && !src.is_empty() {
                        let decoded = percent_decode_href(&src);
                        toc_titles.entry(src).or_insert_with(|| label.clone());
                        toc_titles.entry(decoded).or_insert(label);
                    }
                }
            }
        }
    }
    if toc_titles.is_empty() {
        if let Some(nav) = nav_href {
            if let Ok(nav_xml) = read_zip_text(&mut archive, &nav) {
                let link_re =
                    Regex::new(r#"(?is)<a[^>]*href=["']([^"']+)["'][^>]*>(.*?)</a>"#).unwrap();
                let tag_re = Regex::new(r"(?is)<[^>]+>").unwrap();
                let nav_dir = match nav.rfind('/') {
                    Some(i) => &nav[..i],
                    None => "",
                };
                for cap in link_re.captures_iter(&nav_xml) {
                    if let (Some(h), Some(lbl)) = (cap.get(1), cap.get(2)) {
                        let resolved = resolve_relative(nav_dir, h.as_str());
                        let decoded = percent_decode_href(&resolved);
                        let clean_lbl =
                            decode_html_entities(&tag_re.replace_all(lbl.as_str(), ""))
                                .trim()
                                .to_string();
                        if !clean_lbl.is_empty() {
                            toc_titles
                                .entry(resolved)
                                .or_insert_with(|| clean_lbl.clone());
                            toc_titles.entry(decoded).or_insert(clean_lbl);
                        }
                    }
                }
            }
        }
    }

    let chapters = spine_hrefs
        .into_iter()
        .enumerate()
        .map(|(i, href)| {
            let decoded_href = percent_decode_href(&href);
            let ch_title = toc_titles
                .get(&href)
                .or_else(|| toc_titles.get(&decoded_href))
                .cloned()
                .unwrap_or_else(|| format!("第 {} 章", i + 1));
            BookChapterMeta {
                index: i,
                title: ch_title,
                href,
            }
        })
        .collect();

    Ok(EpubMetadata {
        title,
        author,
        language,
        description,
        cover_href,
        spine_count,
        chapters,
    })
}

/// Extracts raw cover image bytes from an EPUB archive if declared.
pub fn extract_epub_cover_bytes(path: &Path) -> Result<Option<Vec<u8>>, EpubError> {
    let meta = parse_epub_metadata(path)?;
    let Some(cover_href) = meta.cover_href else {
        return Ok(None);
    };
    let file = File::open(path)?;
    let mut archive = ZipArchive::new(file)?;
    match read_zip_bytes(&mut archive, &cover_href) {
        Ok(b) => Ok(Some(b)),
        Err(_) => Ok(None),
    }
}

/// Reads an embedded resource (e.g., inline illustration image) from inside an EPUB.
pub fn read_epub_resource_bytes(path: &Path, resource_href: &str) -> Result<Vec<u8>, EpubError> {
    let file = File::open(path)?;
    let mut archive = ZipArchive::new(file)?;
    read_zip_bytes(&mut archive, resource_href)
}

/// Parses an EPUB XHTML chapter into structured blocks (headings, paragraphs, inline images, footnotes).
pub fn read_epub_chapter(
    path: &Path,
    chapter_index: usize,
    href: &str,
    title_hint: &str,
    rules: &[TextReplaceRule],
    cn_mode: ChineseConversionMode,
) -> Result<BookChapterContent, EpubError> {
    let file = File::open(path)?;
    let mut archive = ZipArchive::new(file)?;
    let html = read_zip_text(&mut archive, href)?;
    let base_dir = match href.rfind('/') {
        Some(i) => &href[..i],
        None => "",
    };

    let body_re = Regex::new(r"(?is)<body[^>]*>(.*)</body>").unwrap();
    let body = body_re
        .captures(&html)
        .and_then(|c| c.get(1))
        .map(|m| m.as_str())
        .unwrap_or(&html);

    let script_re = Regex::new(r"(?is)<(script|style)[^>]*>.*?</(script|style)>").unwrap();
    let cleaned_body = script_re.replace_all(body, "");

    let block_re = Regex::new(
        r#"(?is)<(h[1-6]|p|li|blockquote|aside)[^>]*>(.*?)</(?:h[1-6]|p|li|blockquote|aside)>|<img[^>]*src=["']([^"']+)["'][^>]*>"#,
    )
    .unwrap();
    let tag_re = Regex::new(r"(?is)<[^>]+>").unwrap();
    let img_in_block_re = Regex::new(r#"(?is)<img[^>]*src=["']([^"']+)["'][^>]*>"#).unwrap();

    let mut blocks = Vec::new();
    for cap in block_re.captures_iter(&cleaned_body) {
        if let Some(standalone_img) = cap.get(3) {
            blocks.push(BookBlock::Image {
                href: resolve_relative(base_dir, standalone_img.as_str()),
                caption: None,
            });
            continue;
        }
        let tag = cap
            .get(1)
            .map(|m| m.as_str().to_ascii_lowercase())
            .unwrap_or_default();
        let inner = cap.get(2).map(|m| m.as_str()).unwrap_or("");

        // Capture inline images inside paragraphs too.
        for img_cap in img_in_block_re.captures_iter(inner) {
            if let Some(src) = img_cap.get(1) {
                blocks.push(BookBlock::Image {
                    href: resolve_relative(base_dir, src.as_str()),
                    caption: None,
                });
            }
        }

        let text = decode_html_entities(&tag_re.replace_all(inner, ""))
            .split_whitespace()
            .collect::<Vec<_>>()
            .join(" ");
        let text = convert_chinese(&apply_replace_rules(text.trim(), rules), cn_mode);
        if text.is_empty() {
            continue;
        }

        if tag.starts_with('h') {
            let level = tag[1..].parse::<u8>().unwrap_or(2).clamp(1, 6);
            blocks.push(BookBlock::Heading { level, text });
        } else if tag == "aside" {
            blocks.push(BookBlock::Footnote {
                id: format!("fn_{}", blocks.len()),
                text,
            });
        } else {
            blocks.push(BookBlock::Paragraph { text });
        }
    }

    if blocks.is_empty() {
        let fallback = decode_html_entities(&tag_re.replace_all(&cleaned_body, ""));
        for line in fallback.lines() {
            let t = convert_chinese(&apply_replace_rules(line.trim(), rules), cn_mode);
            if !t.is_empty() {
                blocks.push(BookBlock::Paragraph { text: t });
            }
        }
    }

    let plain_text = blocks_to_plain_text(&blocks);
    Ok(BookChapterContent {
        index: chapter_index,
        title: convert_chinese(title_hint, cn_mode),
        blocks,
        plain_text,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Write;
    use zip::write::SimpleFileOptions;

    #[test]
    fn reads_percent_encoded_chinese_epub_chapters_and_single_quoted_nav() {
        let tmp = std::env::temp_dir().join("inkbox_epub_pct_test");
        let _ = std::fs::create_dir_all(&tmp);
        let epub_path = tmp.join("encoded_cn.epub");

        let file = File::create(&epub_path).unwrap();
        let mut zw = zip::ZipWriter::new(file);
        let opts = SimpleFileOptions::default();

        zw.start_file("META-INF/container.xml", opts).unwrap();
        zw.write_all(
            br#"<?xml version="1.0"?><container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles></container>"#,
        )
        .unwrap();

        zw.start_file("OEBPS/content.opf", opts).unwrap();
        zw.write_all(
            r#"<?xml version="1.0" encoding="utf-8"?><package xmlns="http://www.idpf.org/2007/opf"><metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>测试古籍</dc:title><dc:creator>墨匣</dc:creator></metadata><manifest><item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/><item id="c1" href="Text/%E7%AC%AC1%E7%AB%A0.xhtml" media-type="application/xhtml+xml"/></manifest><spine><itemref idref="c1"/></spine></package>"#.as_bytes(),
        )
        .unwrap();

        zw.start_file("OEBPS/nav.xhtml", opts).unwrap();
        zw.write_all(
            "<?xml version=\"1.0\" encoding=\"utf-8\"?><html xmlns=\"http://www.w3.org/1999/xhtml\"><body><nav><ol><li><a href='Text/第1章.xhtml'>第一章 青山依旧</a></li></ol></nav></body></html>"
                .as_bytes(),
        )
        .unwrap();

        zw.start_file("OEBPS/Text/第1章.xhtml", opts).unwrap();
        zw.write_all(
            "<?xml version=\"1.0\" encoding=\"utf-8\"?><html xmlns=\"http://www.w3.org/1999/xhtml\"><body><h1>第一章 青山依旧</h1><p>秋风吹过山谷。</p></body></html>"
                .as_bytes(),
        )
        .unwrap();
        zw.finish().unwrap();

        let meta = parse_epub_metadata(&epub_path).unwrap();
        assert_eq!(meta.title, "测试古籍");
        assert_eq!(meta.chapters.len(), 1);
        assert_eq!(meta.chapters[0].title, "第一章 青山依旧");

        let ch = read_epub_chapter(
            &epub_path,
            0,
            &meta.chapters[0].href,
            &meta.chapters[0].title,
            &[],
            ChineseConversionMode::None,
        )
        .unwrap();
        assert!(ch.plain_text.contains("秋风吹过山谷"));

        let _ = std::fs::remove_dir_all(&tmp);
    }
}
