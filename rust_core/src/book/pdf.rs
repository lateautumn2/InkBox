use super::chinese_convert::convert_chinese;
use super::types::{
    apply_replace_rules, blocks_to_plain_text, BookBlock, BookChapterContent, BookChapterMeta,
    ChineseConversionMode, TextReplaceRule,
};
use lopdf::Document;
use serde::{Deserialize, Serialize};
use std::path::Path;
use thiserror::Error;

#[derive(Debug, Error)]
pub enum PdfError {
    #[error("PDF parse error: {0}")]
    Lopdf(#[from] lopdf::Error),
    #[error("PDF page out of range: {0}")]
    PageOutOfRange(usize),
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PdfSummary {
    pub title: String,
    pub author: String,
    pub page_count: usize,
    pub likely_scanned_comic: bool,
    pub chapters: Vec<BookChapterMeta>,
}

fn read_info_str(doc: &Document, key: &[u8]) -> Option<String> {
    let info_ref = doc.trailer.get(b"Info").ok()?.as_reference().ok()?;
    let info_dict = doc.get_object(info_ref).ok()?.as_dict().ok()?;
    let val = info_dict.get(key).ok()?;
    match val {
        lopdf::Object::String(bytes, _) => {
            if bytes.len() >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF {
                let u16s: Vec<u16> = bytes[2..]
                    .chunks_exact(2)
                    .map(|c| u16::from_be_bytes([c[0], c[1]]))
                    .collect();
                Some(String::from_utf16_lossy(&u16s).trim().to_string())
            } else {
                Some(String::from_utf8_lossy(bytes).trim().to_string())
            }
        }
        _ => None,
    }
    .filter(|s| !s.is_empty())
}

/// Inspects a PDF file in pure Rust: extracts page count, metadata, and checks whether
/// the first 3 pages lack extractable text (indicating a scanned comic/manga PDF).
pub fn parse_pdf_summary(path: &Path) -> Result<PdfSummary, PdfError> {
    let doc = Document::load(path)?;
    let pages = doc.get_pages();
    let page_count = pages.len();

    let fallback_title = path
        .file_stem()
        .and_then(|s| s.to_str())
        .unwrap_or("未命名 PDF")
        .to_string();
    let title = read_info_str(&doc, b"Title").unwrap_or(fallback_title);
    let author = read_info_str(&doc, b"Author").unwrap_or_else(|| "未知作者".to_string());

    // Sample first 3 pages to classify text PDF vs scanned comic PDF.
    let probe_pages: Vec<u32> = (1..=(page_count.min(3) as u32)).collect();
    let sample_text = doc.extract_text(&probe_pages).unwrap_or_default();
    let likely_scanned_comic = page_count > 0 && sample_text.trim().chars().count() < 24;

    let chapters = (0..page_count)
        .map(|i| BookChapterMeta {
            index: i,
            title: format!("第 {} 页", i + 1),
            href: (i + 1).to_string(),
        })
        .collect();

    Ok(PdfSummary {
        title,
        author,
        page_count,
        likely_scanned_comic,
        chapters,
    })
}

/// Heuristically merges hard PDF line wraps into natural reflowed paragraphs.
pub fn reflow_pdf_text(raw: &str) -> String {
    let mut out = String::new();
    for line in raw.replace("\r\n", "\n").lines() {
        let t = line.trim();
        if t.is_empty() {
            if !out.ends_with("\n\n") && !out.is_empty() {
                out.push_str("\n\n");
            }
            continue;
        }
        out.push_str(t);
        if t.ends_with('。')
            || t.ends_with('！')
            || t.ends_with('？')
            || t.ends_with('.')
            || t.ends_with('!')
            || t.ends_with('?')
            || t.ends_with('：')
            || t.ends_with(':')
        {
            out.push_str("\n\n");
        } else {
            out.push(' ');
        }
    }
    out.trim().to_string()
}

/// Extracts and reflows text from a 0-based PDF page for the book reading engine.
pub fn read_pdf_page_reflow(
    path: &Path,
    page_index: usize,
    rules: &[TextReplaceRule],
    cn_mode: ChineseConversionMode,
) -> Result<BookChapterContent, PdfError> {
    let doc = Document::load(path)?;
    let page_count = doc.get_pages().len();
    if page_index >= page_count {
        return Err(PdfError::PageOutOfRange(page_index));
    }
    let page_num = (page_index + 1) as u32;
    let raw = doc.extract_text(&[page_num]).unwrap_or_default();
    let reflowed = reflow_pdf_text(&raw);
    let processed = convert_chinese(&apply_replace_rules(&reflowed, rules), cn_mode);

    let blocks: Vec<BookBlock> = if processed.is_empty() {
        vec![BookBlock::Paragraph {
            text: "（当前 PDF 页面未检测到可选文字，请点击顶栏「原版PDF」切换高清水墨原版渲染模式）"
                .to_string(),
        }]
    } else {
        processed
            .split("\n\n")
            .map(|p| p.trim())
            .filter(|p| !p.is_empty())
            .map(|p| BookBlock::Paragraph {
                text: p.to_string(),
            })
            .collect()
    };

    let plain_text = blocks_to_plain_text(&blocks);
    Ok(BookChapterContent {
        index: page_index,
        title: format!("第 {} 页", page_index + 1),
        blocks,
        plain_text,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn reflow_merges_broken_lines_into_paragraphs() {
        let raw = "第一行未结束\n第二行句末。\n新段落开始\n继续这一段！";
        let out = reflow_pdf_text(raw);
        assert!(out.contains("第一行未结束 第二行句末。"));
        assert!(out.contains("\n\n新段落开始 继续这一段！"));
    }
}
