use super::chinese_convert::convert_chinese;
use super::types::{
    apply_replace_rules, blocks_to_plain_text, BookBlock, BookChapterContent, BookChapterMeta,
    ChineseConversionMode, TextReplaceRule,
};
use base64::Engine;
use pulldown_cmark::{Event, HeadingLevel, Parser, Tag, TagEnd};
use roxmltree::Document;
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::Path;
use thiserror::Error;

#[derive(Debug, Error)]
pub enum StructuredBookError {
    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),
    #[error("XML error: {0}")]
    Xml(#[from] roxmltree::Error),
    #[error("Chapter out of range: {0}")]
    ChapterOutOfRange(usize),
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StructuredBookSummary {
    pub title: String,
    pub author: String,
    pub chapters: Vec<BookChapterMeta>,
}

fn parse_fb2_sections(xml: &str, fallback_title: &str) -> Result<(String, String, Vec<(String, Vec<BookBlock>)>), StructuredBookError> {
    let doc = Document::parse(xml)?;

    let title = doc
        .descendants()
        .find(|n| n.tag_name().name() == "book-title")
        .and_then(|n| n.text())
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
        .unwrap_or_else(|| fallback_title.to_string());

    let author = doc
        .descendants()
        .find(|n| n.tag_name().name() == "author")
        .map(|a| {
            let first = a
                .children()
                .find(|c| c.tag_name().name() == "first-name")
                .and_then(|c| c.text())
                .unwrap_or("")
                .trim();
            let last = a
                .children()
                .find(|c| c.tag_name().name() == "last-name")
                .and_then(|c| c.text())
                .unwrap_or("")
                .trim();
            format!("{first} {last}").trim().to_string()
        })
        .filter(|s| !s.is_empty())
        .unwrap_or_else(|| "未知作者".to_string());

    let mut chapters = Vec::new();
    if let Some(body) = doc.descendants().find(|n| n.tag_name().name() == "body") {
        for (idx, sec) in body
            .children()
            .filter(|c| c.tag_name().name() == "section")
            .enumerate()
        {
            let mut ch_title = format!("第 {} 章", idx + 1);
            let mut blocks = Vec::new();
            for child in sec.children() {
                match child.tag_name().name() {
                    "title" => {
                        let t: String = child
                            .descendants()
                            .filter_map(|d| d.text())
                            .collect::<Vec<_>>()
                            .join(" ")
                            .trim()
                            .to_string();
                        if !t.is_empty() {
                            ch_title = t.clone();
                            blocks.push(BookBlock::Heading { level: 1, text: t });
                        }
                    }
                    "p" | "v" => {
                        let t: String = child
                            .descendants()
                            .filter_map(|d| d.text())
                            .collect::<Vec<_>>()
                            .join("")
                            .trim()
                            .to_string();
                        if !t.is_empty() {
                            blocks.push(BookBlock::Paragraph { text: t });
                        }
                    }
                    _ => {}
                }
            }
            if !blocks.is_empty() {
                chapters.push((ch_title, blocks));
            }
        }
    }

    if chapters.is_empty() {
        chapters.push((
            "正文".to_string(),
            vec![BookBlock::Paragraph {
                text: "（FB2 正文为空）".to_string(),
            }],
        ));
    }

    Ok((title, author, chapters))
}

pub fn parse_fb2_summary(path: &Path) -> Result<StructuredBookSummary, StructuredBookError> {
    let xml = fs::read_to_string(path)?;
    let fallback = path
        .file_stem()
        .and_then(|s| s.to_str())
        .unwrap_or("未命名 FB2");
    let (title, author, chs) = parse_fb2_sections(&xml, fallback)?;
    let chapters = chs
        .into_iter()
        .enumerate()
        .map(|(i, (t, _))| BookChapterMeta {
            index: i,
            title: t,
            href: i.to_string(),
        })
        .collect();
    Ok(StructuredBookSummary {
        title,
        author,
        chapters,
    })
}

pub fn read_fb2_chapter(
    path: &Path,
    chapter_index: usize,
    rules: &[TextReplaceRule],
    cn_mode: ChineseConversionMode,
) -> Result<BookChapterContent, StructuredBookError> {
    let xml = fs::read_to_string(path)?;
    let fallback = path
        .file_stem()
        .and_then(|s| s.to_str())
        .unwrap_or("未命名 FB2");
    let (_, _, chs) = parse_fb2_sections(&xml, fallback)?;
    let (title, raw_blocks) = chs
        .get(chapter_index)
        .ok_or(StructuredBookError::ChapterOutOfRange(chapter_index))?;
    let blocks: Vec<BookBlock> = raw_blocks
        .iter()
        .map(|b| match b {
            BookBlock::Paragraph { text } => BookBlock::Paragraph {
                text: convert_chinese(&apply_replace_rules(text, rules), cn_mode),
            },
            BookBlock::Heading { level, text } => BookBlock::Heading {
                level: *level,
                text: convert_chinese(&apply_replace_rules(text, rules), cn_mode),
            },
            other => other.clone(),
        })
        .collect();
    let plain_text = blocks_to_plain_text(&blocks);
    Ok(BookChapterContent {
        index: chapter_index,
        title: convert_chinese(title, cn_mode),
        blocks,
        plain_text,
    })
}

pub fn extract_fb2_cover_bytes(path: &Path) -> Result<Option<Vec<u8>>, StructuredBookError> {
    let xml = fs::read_to_string(path)?;
    let doc = Document::parse(&xml)?;
    if let Some(bin) = doc.descendants().find(|n| n.tag_name().name() == "binary") {
        if let Some(b64) = bin.text() {
            let cleaned: String = b64.chars().filter(|c| !c.is_whitespace()).collect();
            if let Ok(decoded) = base64::engine::general_purpose::STANDARD.decode(cleaned) {
                return Ok(Some(decoded));
            }
        }
    }
    Ok(None)
}

fn parse_markdown_sections(md: &str, fallback_title: &str) -> (String, Vec<(String, Vec<BookBlock>)>) {
    let parser = Parser::new(md);
    let mut doc_title = fallback_title.to_string();
    let mut chapters: Vec<(String, Vec<BookBlock>)> = Vec::new();
    let mut cur_title = "正文".to_string();
    let mut cur_blocks: Vec<BookBlock> = Vec::new();

    let mut in_heading: Option<u8> = None;
    let mut buf = String::new();

    for event in parser {
        match event {
            Event::Start(Tag::Heading { level, .. }) => {
                let lvl = match level {
                    HeadingLevel::H1 => 1,
                    HeadingLevel::H2 => 2,
                    HeadingLevel::H3 => 3,
                    _ => 4,
                };
                in_heading = Some(lvl);
                buf.clear();
            }
            Event::End(TagEnd::Heading(_)) => {
                let text = buf.trim().to_string();
                let lvl = in_heading.take().unwrap_or(1);
                if !text.is_empty() {
                    if lvl == 1 && doc_title == fallback_title {
                        doc_title = text.clone();
                    }
                    if lvl <= 2 {
                        if !cur_blocks.is_empty() {
                            chapters.push((cur_title.clone(), std::mem::take(&mut cur_blocks)));
                        }
                        cur_title = text.clone();
                    }
                    cur_blocks.push(BookBlock::Heading { level: lvl, text });
                }
                buf.clear();
            }
            Event::Start(Tag::Paragraph) => {
                buf.clear();
            }
            Event::End(TagEnd::Paragraph) => {
                let text = buf.trim().to_string();
                if !text.is_empty() {
                    cur_blocks.push(BookBlock::Paragraph { text });
                }
                buf.clear();
            }
            Event::Text(t) | Event::Code(t) => buf.push_str(&t),
            Event::SoftBreak | Event::HardBreak => buf.push(' '),
            _ => {}
        }
    }

    if !cur_blocks.is_empty() {
        chapters.push((cur_title, cur_blocks));
    }
    if chapters.is_empty() {
        chapters.push((
            "正文".to_string(),
            vec![BookBlock::Paragraph {
                text: md.trim().to_string(),
            }],
        ));
    }

    (doc_title, chapters)
}

pub fn parse_markdown_summary(path: &Path) -> Result<StructuredBookSummary, StructuredBookError> {
    let md = fs::read_to_string(path)?;
    let fallback = path
        .file_stem()
        .and_then(|s| s.to_str())
        .unwrap_or("未命名文档");
    let (title, chs) = parse_markdown_sections(&md, fallback);
    let chapters = chs
        .into_iter()
        .enumerate()
        .map(|(i, (t, _))| BookChapterMeta {
            index: i,
            title: t,
            href: i.to_string(),
        })
        .collect();
    Ok(StructuredBookSummary {
        title,
        author: "本地 Markdown".to_string(),
        chapters,
    })
}

pub fn read_markdown_chapter(
    path: &Path,
    chapter_index: usize,
    rules: &[TextReplaceRule],
    cn_mode: ChineseConversionMode,
) -> Result<BookChapterContent, StructuredBookError> {
    let md = fs::read_to_string(path)?;
    let fallback = path
        .file_stem()
        .and_then(|s| s.to_str())
        .unwrap_or("未命名文档");
    let (_, chs) = parse_markdown_sections(&md, fallback);
    let (title, raw_blocks) = chs
        .get(chapter_index)
        .ok_or(StructuredBookError::ChapterOutOfRange(chapter_index))?;
    let blocks: Vec<BookBlock> = raw_blocks
        .iter()
        .map(|b| match b {
            BookBlock::Paragraph { text } => BookBlock::Paragraph {
                text: convert_chinese(&apply_replace_rules(text, rules), cn_mode),
            },
            BookBlock::Heading { level, text } => BookBlock::Heading {
                level: *level,
                text: convert_chinese(&apply_replace_rules(text, rules), cn_mode),
            },
            other => other.clone(),
        })
        .collect();
    let plain_text = blocks_to_plain_text(&blocks);
    Ok(BookChapterContent {
        index: chapter_index,
        title: convert_chinese(title, cn_mode),
        blocks,
        plain_text,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_markdown_headings_into_chapters() {
        let md = "# 墨匣手册\n\n导语段落。\n\n## 第一章 启程\n\n正文内容。";
        let (title, chs) = parse_markdown_sections(md, "fallback");
        assert_eq!(title, "墨匣手册");
        assert_eq!(chs.len(), 2);
        assert_eq!(chs[1].0, "第一章 启程");
    }

    #[test]
    fn parses_fb2_xml_structure() {
        let xml = r#"<FictionBook><description><title-info><book-title>星际旅人</book-title><author><first-name>艾萨克</first-name><last-name>阿西莫夫</last-name></author></title-info></description><body><section><title><p>序章</p></title><p>银河帝国兴起。</p></section></body></FictionBook>"#;
        let (title, author, chs) = parse_fb2_sections(xml, "fallback").unwrap();
        assert_eq!(title, "星际旅人");
        assert_eq!(author, "艾萨克 阿西莫夫");
        assert_eq!(chs.len(), 1);
    }
}
