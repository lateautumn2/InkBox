use super::chinese_convert::convert_chinese;
use super::types::{
    apply_replace_rules, blocks_to_plain_text, BookBlock, BookChapterContent, BookChapterMeta,
    ChineseConversionMode, TextReplaceRule,
};
use regex::Regex;
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::Path;
use thiserror::Error;

#[derive(Debug, Error)]
pub enum MobiError {
    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),
    #[error("Invalid MOBI/AZW3 header: {0}")]
    InvalidFormat(String),
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MobiMetadata {
    pub title: String,
    pub author: String,
    pub chapter_count: usize,
    pub chapters: Vec<BookChapterMeta>,
}

fn read_be_u16(bytes: &[u8], off: usize) -> Option<u16> {
    let slice = bytes.get(off..off + 2)?;
    Some(u16::from_be_bytes([slice[0], slice[1]]))
}

fn read_be_u32(bytes: &[u8], off: usize) -> Option<u32> {
    let slice = bytes.get(off..off + 4)?;
    Some(u32::from_be_bytes([slice[0], slice[1], slice[2], slice[3]]))
}

/// Decompresses a PalmDOC LZ77 compressed record.
fn palmdoc_decompress(data: &[u8]) -> Vec<u8> {
    let mut out = Vec::with_capacity(data.len() * 2);
    let mut i = 0;
    while i < data.len() {
        let b = data[i];
        i += 1;
        if b == 0x00 || (0x09..=0x7F).contains(&b) {
            out.push(b);
        } else if (0x01..=0x08).contains(&b) {
            let count = (b as usize).min(data.len().saturating_sub(i));
            out.extend_from_slice(&data[i..i + count]);
            i += count;
        } else if (0x80..=0xBF).contains(&b) {
            if i >= data.len() {
                break;
            }
            let next = data[i];
            i += 1;
            let pair = (((b as u16) << 8) | (next as u16)) & 0x3FFF;
            let dist = (pair >> 3) as usize;
            let len = ((pair & 0x07) + 3) as usize;
            if dist > 0 && dist <= out.len() {
                for _ in 0..len {
                    let idx = out.len() - dist;
                    let byte = out[idx];
                    out.push(byte);
                }
            }
        } else {
            // 0xC0..=0xFF: space + (b ^ 0x80)
            out.push(b' ');
            out.push(b ^ 0x80);
        }
    }
    out
}

struct ParsedMobi {
    title: String,
    author: String,
    text_html: String,
}

fn parse_mobi_raw(bytes: &[u8]) -> Result<ParsedMobi, MobiError> {
    if bytes.len() < 86 {
        return Err(MobiError::InvalidFormat("File too short for PalmDB".into()));
    }

    let raw_name = &bytes[0..32];
    let fallback_title = String::from_utf8_lossy(
        raw_name.split(|&b| b == 0).next().unwrap_or(raw_name),
    )
    .trim()
    .to_string();

    let num_records = read_be_u16(bytes, 76).unwrap_or(0) as usize;
    if num_records == 0 || bytes.len() < 78 + num_records * 8 {
        return Err(MobiError::InvalidFormat("Invalid PalmDB record table".into()));
    }

    let mut offsets = Vec::with_capacity(num_records);
    for idx in 0..num_records {
        let off = read_be_u32(bytes, 78 + idx * 8).unwrap_or(0) as usize;
        offsets.push(off);
    }

    let rec0_start = offsets[0];
    let rec0_end = if num_records > 1 {
        offsets[1].min(bytes.len())
    } else {
        bytes.len()
    };
    if rec0_start >= rec0_end || rec0_end - rec0_start < 16 {
        return Err(MobiError::InvalidFormat("Invalid record 0".into()));
    }
    let rec0 = &bytes[rec0_start..rec0_end];

    let compression = read_be_u16(rec0, 0).unwrap_or(1);
    let text_record_count = read_be_u16(rec0, 8).unwrap_or(0) as usize;
    let encryption = read_be_u16(rec0, 12).unwrap_or(0);
    if encryption != 0 {
        return Err(MobiError::InvalidFormat(
            "DRM-encrypted MOBI/AZW3 files are not supported".into(),
        ));
    }

    let mut title = fallback_title;
    let mut author = "未知作者".to_string();
    let mut encoding_id: u32 = 65001; // UTF-8 default
    let mut extra_flags: u16 = 0;

    // Parse MOBI header if present at offset 16.
    if rec0.len() >= 132 && &rec0[16..20] == b"MOBI" {
        let mobi_hdr_len = read_be_u32(rec0, 20).unwrap_or(0) as usize;
        encoding_id = read_be_u32(rec0, 28).unwrap_or(65001);
        let full_name_off = read_be_u32(rec0, 84).unwrap_or(0) as usize;
        let full_name_len = read_be_u32(rec0, 88).unwrap_or(0) as usize;
        if full_name_off > 0
            && full_name_len > 0
            && full_name_off + full_name_len <= rec0.len()
        {
            let candidate =
                String::from_utf8_lossy(&rec0[full_name_off..full_name_off + full_name_len])
                    .trim()
                    .to_string();
            if !candidate.is_empty() {
                title = candidate;
            }
        }
        if mobi_hdr_len >= 228 && rec0.len() >= 244 {
            extra_flags = read_be_u16(rec0, 242).unwrap_or(0);
        }

        // Parse EXTH metadata for Author (record type 100) / Updated Title (503).
        let exth_flags = read_be_u32(rec0, 128).unwrap_or(0);
        let exth_start = 16 + mobi_hdr_len;
        if (exth_flags & 0x40) != 0
            && exth_start + 12 <= rec0.len()
            && &rec0[exth_start..exth_start + 4] == b"EXTH"
        {
            let exth_count = read_be_u32(rec0, exth_start + 8).unwrap_or(0) as usize;
            let mut cursor = exth_start + 12;
            for _ in 0..exth_count {
                if cursor + 8 > rec0.len() {
                    break;
                }
                let rec_type = read_be_u32(rec0, cursor).unwrap_or(0);
                let rec_len = read_be_u32(rec0, cursor + 4).unwrap_or(0) as usize;
                if rec_len < 8 || cursor + rec_len > rec0.len() {
                    break;
                }
                let val_bytes = &rec0[cursor + 8..cursor + rec_len];
                let val = String::from_utf8_lossy(val_bytes).trim().to_string();
                if rec_type == 100 && !val.is_empty() {
                    author = val;
                } else if rec_type == 503 && !val.is_empty() {
                    title = val;
                }
                cursor += rec_len;
            }
        }
    }

    let mut raw_text = Vec::new();
    let last_text_rec = text_record_count.min(num_records.saturating_sub(1));
    for r in 1..=last_text_rec {
        let start = offsets[r];
        let end = if r + 1 < num_records {
            offsets[r + 1].min(bytes.len())
        } else {
            bytes.len()
        };
        if start >= end {
            continue;
        }
        let mut slice = &bytes[start..end];
        // Strip trailing multibyte overlap bytes if extra_flags bit 0 is set.
        if (extra_flags & 1) != 0 && !slice.is_empty() {
            let trail = ((slice[slice.len() - 1] & 0x03) + 1) as usize;
            if trail < slice.len() {
                slice = &slice[..slice.len() - trail];
            }
        }
        match compression {
            1 => raw_text.extend_from_slice(slice),
            2 => raw_text.extend_from_slice(&palmdoc_decompress(slice)),
            _ => {
                return Err(MobiError::InvalidFormat(format!(
                    "Unsupported MOBI compression code {compression}"
                )));
            }
        }
    }

    let text_html = if encoding_id == 1252 {
        encoding_rs::WINDOWS_1252.decode(&raw_text).0.into_owned()
    } else {
        String::from_utf8_lossy(&raw_text).into_owned()
    };

    if title.is_empty() {
        title = "未命名电子书".to_string();
    }

    Ok(ParsedMobi {
        title,
        author,
        text_html,
    })
}

fn split_mobi_html_chapters(html: &str) -> Vec<(String, Vec<BookBlock>)> {
    let pb_re = Regex::new(r"(?i)<mbp:pagebreak\s*/?>|<div[^>]*page-break[^>]*>").unwrap();
    let tag_re = Regex::new(r"(?is)<[^>]+>").unwrap();
    let heading_re = Regex::new(r"(?is)<h[1-3][^>]*>(.*?)</h[1-3]>").unwrap();
    let para_re = Regex::new(r"(?is)<(?:p|div|li|h[1-6])[^>]*>(.*?)</(?:p|div|li|h[1-6])>").unwrap();

    let raw_sections: Vec<&str> = pb_re
        .split(html)
        .map(|s| s.trim())
        .filter(|s| !s.is_empty())
        .collect();

    let sections = if raw_sections.is_empty() {
        vec![html]
    } else {
        raw_sections
    };

    let mut chapters = Vec::new();
    for (idx, sec) in sections.iter().enumerate() {
        let mut blocks = Vec::new();
        let mut title = heading_re
            .captures(sec)
            .and_then(|c| c.get(1))
            .map(|m| decode_html_entities(&tag_re.replace_all(m.as_str(), "")))
            .map(|s| s.trim().to_string())
            .filter(|s| !s.is_empty())
            .unwrap_or_else(|| format!("第 {} 节", idx + 1));

        for cap in para_re.captures_iter(sec) {
            if let Some(m) = cap.get(1) {
                let clean = decode_html_entities(&tag_re.replace_all(m.as_str(), ""))
                    .trim()
                    .to_string();
                if !clean.is_empty() {
                    blocks.push(BookBlock::Paragraph { text: clean });
                }
            }
        }
        if blocks.is_empty() {
            let fallback = decode_html_entities(&tag_re.replace_all(sec, ""))
                .trim()
                .to_string();
            if !fallback.is_empty() {
                for line in fallback.lines() {
                    let t = line.trim();
                    if !t.is_empty() {
                        blocks.push(BookBlock::Paragraph {
                            text: t.to_string(),
                        });
                    }
                }
            }
        }
        if !blocks.is_empty() {
            if title.chars().count() > 40 {
                title = title.chars().take(40).collect();
            }
            chapters.push((title, blocks));
        }
    }

    if chapters.is_empty() {
        chapters.push((
            "正文".to_string(),
            vec![BookBlock::Paragraph {
                text: "（无可解析文本内容）".to_string(),
            }],
        ));
    }
    chapters
}

pub fn decode_html_entities(s: &str) -> String {
    s.replace("&nbsp;", " ")
        .replace("&amp;", "&")
        .replace("&lt;", "<")
        .replace("&gt;", ">")
        .replace("&quot;", "\"")
        .replace("&#39;", "'")
        .replace("&ldquo;", "“")
        .replace("&rdquo;", "”")
        .replace("&mdash;", "—")
        .replace("&hellip;", "…")
}

pub fn parse_mobi_metadata(path: &Path) -> Result<MobiMetadata, MobiError> {
    let bytes = fs::read(path)?;
    let parsed = parse_mobi_raw(&bytes)?;
    let chs = split_mobi_html_chapters(&parsed.text_html);
    let chapters = chs
        .iter()
        .enumerate()
        .map(|(i, (title, _))| BookChapterMeta {
            index: i,
            title: title.clone(),
            href: i.to_string(),
        })
        .collect::<Vec<_>>();
    Ok(MobiMetadata {
        title: parsed.title,
        author: parsed.author,
        chapter_count: chapters.len(),
        chapters,
    })
}

pub fn read_mobi_chapter(
    path: &Path,
    chapter_index: usize,
    rules: &[TextReplaceRule],
    cn_mode: ChineseConversionMode,
) -> Result<BookChapterContent, MobiError> {
    let bytes = fs::read(path)?;
    let parsed = parse_mobi_raw(&bytes)?;
    let chs = split_mobi_html_chapters(&parsed.text_html);
    let (title, raw_blocks) = chs
        .get(chapter_index)
        .ok_or_else(|| MobiError::InvalidFormat(format!("Chapter {chapter_index} out of range")))?;

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
    fn palmdoc_decompresses_literals_and_backreferences() {
        // "hello " + backreference dist=6, len=5 -> "hello hello"
        let mut data = b"hello ".to_vec();
        // dist=6 (0b110), len-3=2 (0b010) -> pair = (6 << 3) | 2 = 50 -> 0x8000 | 50 = 0x8032
        data.push(0x80);
        data.push(0x32);
        let out = palmdoc_decompress(&data);
        assert_eq!(String::from_utf8(out).unwrap(), "hello hello");
    }
}
