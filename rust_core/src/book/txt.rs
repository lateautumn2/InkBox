use super::chinese_convert::convert_chinese;
use super::types::{
    apply_replace_rules, blocks_to_plain_text, BookBlock, BookChapterContent,
    ChineseConversionMode, TextReplaceRule,
};
use chardetng::EncodingDetector;
use fancy_regex::Regex as FancyRegex;
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::Path;
use thiserror::Error;

#[derive(Debug, Error)]
pub enum TxtError {
    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),
    #[error("Invalid chapter regex: {0}")]
    Regex(String),
    #[error("Invalid chapter byte range")]
    InvalidRange,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct TxtChapter {
    pub index: usize,
    pub title: String,
    pub start_byte: usize,
    pub end_byte: usize,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct TxtTocRule {
    pub id: i64,
    pub name: String,
    pub rule: String,
    #[serde(default)]
    pub example: String,
    #[serde(default = "default_true")]
    pub enable: bool,
    #[serde(default)]
    pub serial_number: i32,
}

fn default_true() -> bool {
    true
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TxtIndexResult {
    pub encoding: String,
    pub total_chars: usize,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub matched_rule_id: Option<i64>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub matched_rule_name: Option<String>,
    pub chapters: Vec<TxtChapter>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TocRuleTestResult {
    pub valid: bool,
    pub match_count: usize,
    pub preview_titles: Vec<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<String>,
}

/// Default Legado-inspired Chinese & English chapter heading regex (single-rule fallback).
pub const DEFAULT_CHAPTER_REGEX: &str = r"^[ \t\u{3000}]{0,8}(?:(?:序章|楔子|引子|前言|终章|后记|尾声|番外|外传|大结局|完本感言|上架感言)(?:$|[\s\u{3000}:：、.\-—·(（\[【].{0,35}$)|第[\s\u{3000}]{0,4}[\d０-９〇零一二两三四五六七八九十百千万壹贰叁肆伍陆柒捌玖拾佰仟]+?[\s\u{3000}]{0,4}(?:章|节(?!课)|卷|集(?![合和])|部(?![分赛游])|篇(?!张)|回|话|話|幕).{0,40}$)";

/// Built-in GitHub Legado-compatible TXT TOC rules (`txtTocRule.json` standard set).
pub fn default_toc_rules() -> Vec<TxtTocRule> {
    vec![
        TxtTocRule {
            id: -1,
            name: "目录(去空白 · 标准中文章节)".to_string(),
            rule: r"^[ \t\u{3000}]{0,8}(?:(?:序章|楔子|引子|前言|终章|后记|尾声|番外|外传|大结局|完本感言|上架感言)(?:$|[\s\u{3000}:：、.\-—·(（\[【].{0,35}$)|第[\s\u{3000}]{0,4}[\d０-９〇零一二两三四五六七八九十百千万壹贰叁肆伍陆柒捌玖拾佰仟]+?[\s\u{3000}]{0,4}(?:章|节(?!课)|卷|集(?![合和])|部(?![分赛游])|篇(?!张)|回).{0,40}$)".to_string(),
            example: "第一章 黑暗森林 / 第 一 节 启程 / 楔子 / 番外".to_string(),
            enable: true,
            serial_number: 1,
        },
        TxtTocRule {
            id: -2,
            name: "卷 + 章复合标题".to_string(),
            rule: r"^[ \t\u{3000}]{0,8}(?:第[\d〇零一二两三四五六七八九十百千万]+(?:卷|部|集|篇)|卷[\d〇零一二两三四五六七八九十百千]+|正文)[\s\u{3000}·:：\-]{1,4}.{0,20}?第[\s\u{3000}]{0,3}[\d０-９〇零一二两三四五六七八九十百千万]+[\s\u{3000}]{0,3}(?:章|节|回).{0,35}$".to_string(),
            example: "第一卷 崛起 第一章 初出茅庐".to_string(),
            enable: true,
            serial_number: 2,
        },
        TxtTocRule {
            id: -3,
            name: "无「第」字章节(卷/章/节/回)".to_string(),
            rule: r"^[ \t\u{3000}]{0,8}(?:卷|章|节|回|集|部|篇)[\s\u{3000}]{0,2}[\d０-９〇零一二两三四五六七八九十百千万]+(?:[\s\u{3000}.、:：\-].{0,35})?$".to_string(),
            example: "卷一 尘封往事 / 章十二 暗夜".to_string(),
            enable: true,
            serial_number: 3,
        },
        TxtTocRule {
            id: -4,
            name: "中文数字序号标题".to_string(),
            rule: r"^[ \t\u{3000}]{0,8}[〇零一二两三四五六七八九十百千万]{1,7}[、.．:：\s\u{3000}]+[^\s。，；！？?!]{1,30}$".to_string(),
            example: "一、初入江湖 / 十二、夜访".to_string(),
            enable: true,
            serial_number: 4,
        },
        TxtTocRule {
            id: -5,
            name: "阿拉伯数字分隔符标题".to_string(),
            rule: r"^[ \t\u{3000}]{0,8}\d{1,5}[、.．:：\-—\s\u{3000}]+[^\d\s。，；]{1,35}$".to_string(),
            example: "1、序幕 / 001. 黎明之前 / 12 - 归途".to_string(),
            enable: true,
            serial_number: 5,
        },
        TxtTocRule {
            id: -6,
            name: "纯数字章节号".to_string(),
            rule: r"^[ \t\u{3000}]{0,8}\d{1,5}[ \t\u{3000}]{0,4}$".to_string(),
            example: "1 / 002 / 128".to_string(),
            enable: true,
            serial_number: 6,
        },
        TxtTocRule {
            id: -7,
            name: "英文 Chapter / Part / Section".to_string(),
            rule: r"(?i)^[ \t\u{3000}]{0,8}(?:chapter|part|section|volume|vol\.?|book|act|prologue|epilogue)(?:[\s\u{3000}\-:#.]+[0-9ivxlcdm]+)?(?:[\s\u{3000}:.\-—].{0,45})?$".to_string(),
            example: "Chapter 1 The Beginning / PART II / Prologue".to_string(),
            enable: true,
            serial_number: 7,
        },
        TxtTocRule {
            id: -8,
            name: "括号序号标题".to_string(),
            rule: r"^[ \t\u{3000}]{0,8}[(（\[【][ \t]{0,2}(?:第?[\d〇零一二两三四五六七八九十百千万]+[章节回卷话]?|序章|楔子|番外|尾声)[ \t]{0,2}[)）\]】].{0,35}$".to_string(),
            example: "（一）夜雨 / 【第一章】破晓 / [01] 启程".to_string(),
            enable: true,
            serial_number: 8,
        },
        TxtTocRule {
            id: -9,
            name: "书名括号序号".to_string(),
            rule: r"^[ \t\u{3000}]{0,8}[^\s。，；]{1,16}[(（][0-9〇零一二两三四五六七八九十百千万]{1,6}[)）][ \t\u{3000}]{0,4}$".to_string(),
            example: "凡人修仙传(12) / 雪中悍刀行（三）".to_string(),
            enable: true,
            serial_number: 9,
        },
        TxtTocRule {
            id: -10,
            name: "特殊符号标记标题(晋江/论坛体)".to_string(),
            rule: r"^[ \t\u{3000}]{0,8}(?:[☆★✦✧◆◇●○■□※§]+[ \t、.．\-]{0,3}.{1,35}|={2,}[ \t]*.{1,30}[ \t]*={2,}|-{3,}[ \t]*.{1,30}[ \t]*-{3,})$".to_string(),
            example: "☆、第1章 初遇 / ✦ 序幕 / === 第一章 ===".to_string(),
            enable: true,
            serial_number: 10,
        },
        TxtTocRule {
            id: -11,
            name: "轻小说 / 话 / 幕 / 日系章节".to_string(),
            rule: r"^[ \t\u{3000}]{0,8}(?:第[\s\u{3000}]{0,3}[\d０-９〇零一二两三四五六七八九十百千万]+[\s\u{3000}]{0,3}(?:话|話|幕|场|場|折|讲|講)|プロローグ|エピローグ|間章|幕間).{0,35}$".to_string(),
            example: "第一话 异世界 / 第03話 / 幕间".to_string(),
            enable: true,
            serial_number: 11,
        },
        TxtTocRule {
            id: -12,
            name: "正文前缀序号".to_string(),
            rule: r"^[ \t\u{3000}]{0,8}正文[\s\u{3000}:：\-·]+(?:[\d〇零一二两三四五六七八九十百千万]+|第[\d〇零一二两三四五六七八九十百千万]+[章节回]).{0,35}$".to_string(),
            example: "正文 001 重生 / 正文 第十章 风云".to_string(),
            enable: true,
            serial_number: 12,
        },
        TxtTocRule {
            id: -13,
            name: "Markdown 井号标题".to_string(),
            rule: r"^[ \t]{0,3}#{1,4}[ \t]+.{1,50}$".to_string(),
            example: "# 第一章 / ## 02 暗涌".to_string(),
            enable: true,
            serial_number: 13,
        },
        TxtTocRule {
            id: -14,
            name: "宽松数字+标题(无分隔符)".to_string(),
            rule: r"^[ \t\u{3000}]{0,8}\d{1,4}[\u{4e00}-\u{9fa5}][^\r\n。；]{0,26}$".to_string(),
            example: "001开端 / 12风起云涌".to_string(),
            enable: false,
            serial_number: 14,
        },
    ]
}

/// Converts Java/Legado regex syntax (unbraced `\uXXXX`, `\p{IsHan}`, literal `\r\n`
/// outside character classes, and leading variable-length lookbehinds like `(?<=^[\s ]{0,4})`)
/// into Rust `fancy-regex` compatible syntax.
pub fn normalize_java_regex(pattern: &str) -> String {
    let chars: Vec<char> = pattern.chars().collect();
    let mut out = String::with_capacity(pattern.len() + 24);
    let mut i = 0;
    let mut in_class = false;

    while i < chars.len() {
        let ch = chars[i];
        if ch == '\\' && i + 1 < chars.len() {
            let next = chars[i + 1];
            if next == '\\' {
                out.push('\\');
                out.push('\\');
                i += 2;
                continue;
            }
            if next == 'u'
                && i + 5 < chars.len()
                && chars[i + 2] != '{'
                && chars[i + 2..i + 6].iter().all(|c| c.is_ascii_hexdigit())
            {
                out.push_str(r"\u{");
                for c in &chars[i + 2..i + 6] {
                    out.push(*c);
                }
                out.push('}');
                i += 6;
                continue;
            }
            // Outside `[...]`, convert literal `\r\n` (not `\r?\n`) to `\n` because text is LF-normalized.
            if !in_class
                && next == 'r'
                && i + 3 < chars.len()
                && chars[i + 2] == '\\'
                && chars[i + 3] == 'n'
            {
                out.push_str(r"\n");
                i += 4;
                continue;
            }
            out.push('\\');
            out.push(next);
            i += 2;
            continue;
        }
        if ch == '[' && !in_class {
            in_class = true;
            out.push(ch);
            // A `]` immediately after `[` or `[^` is literal inside a character class.
            if i + 1 < chars.len() && chars[i + 1] == '^' {
                out.push('^');
                i += 2;
                if i < chars.len() && chars[i] == ']' {
                    out.push(']');
                    i += 1;
                }
                continue;
            } else if i + 1 < chars.len() && chars[i + 1] == ']' {
                out.push(']');
                i += 2;
                continue;
            }
            i += 1;
            continue;
        }
        if ch == ']' && in_class {
            in_class = false;
        }
        out.push(ch);
        i += 1;
    }

    let out = out.replace(r"\p{IsHan}", r"\p{Han}");
    rewrite_leading_variable_lookbehind(&out)
}

/// Rewrites leading Java variable-length positive lookbehinds (e.g. `(?<=^[\s\u{3000}]{0,4})`,
/// `(?<=[\s ]{0,4})`, `(?<=^|\n)`, `(?<=[ \s]|^)`) into equivalent non-capturing prefixes
/// `(?:...)` so GitHub Legado `txtTocRule.json` rules compile cleanly in `fancy-regex`.
fn rewrite_leading_variable_lookbehind(pattern: &str) -> String {
    let bytes = pattern.as_bytes();
    let mut prefix_end = 0usize;

    // Preserve leading inline flags such as `(?m)`, `(?i)`, `(?im)`.
    while prefix_end + 3 < bytes.len() && &bytes[prefix_end..prefix_end + 2] == b"(?" {
        let rest = &pattern[prefix_end + 2..];
        if let Some(close_rel) = rest.find(')') {
            let flags = &rest[..close_rel];
            if !flags.is_empty()
                && flags
                    .bytes()
                    .all(|b| matches!(b, b'i' | b'm' | b's' | b'x' | b'u' | b'-'))
            {
                prefix_end += 2 + close_rel + 1;
                continue;
            }
        }
        break;
    }

    if !pattern[prefix_end..].starts_with("(?<=") {
        return pattern.to_string();
    }

    let lb_start = prefix_end;
    let chars: Vec<(usize, char)> = pattern[lb_start..].char_indices().collect();
    let mut depth = 0usize;
    let mut in_class = false;
    let mut idx = 0usize;
    let mut close_byte: Option<usize> = None;

    while idx < chars.len() {
        let (bpos, c) = chars[idx];
        if c == '\\' {
            idx += 2;
            continue;
        }
        if in_class {
            if c == ']' {
                in_class = false;
            }
            idx += 1;
            continue;
        }
        match c {
            '[' => {
                in_class = true;
                if idx + 1 < chars.len() && chars[idx + 1].1 == '^' {
                    idx += 1;
                }
                if idx + 1 < chars.len() && chars[idx + 1].1 == ']' {
                    idx += 1;
                }
            }
            '(' => depth += 1,
            ')' => {
                depth = depth.saturating_sub(1);
                if depth == 0 {
                    close_byte = Some(lb_start + bpos);
                    break;
                }
            }
            _ => {}
        }
        idx += 1;
    }

    let Some(end_pos) = close_byte else {
        return pattern.to_string();
    };
    let inner = &pattern[lb_start + 4..end_pos];
    let has_var_len = inner.contains('*')
        || inner.contains('+')
        || inner.contains('?')
        || inner.contains('{')
        || inner.contains('|')
        || inner.contains('^');
    if !has_var_len {
        return pattern.to_string();
    }

    format!(
        "{}(?:{}){}",
        &pattern[..lb_start],
        inner,
        &pattern[end_pos + 1..]
    )
}

/// Checks if a regex pattern explicitly matches newline characters (`\n` or `\r`)
/// OUTSIDE negated character classes like `[^\r\n]` or `[^\r\n。；]`.
fn pattern_uses_explicit_newline(pattern: &str) -> bool {
    let chars: Vec<char> = pattern.chars().collect();
    let mut i = 0;
    let mut in_class = false;
    let mut class_negated = false;

    while i < chars.len() {
        let ch = chars[i];
        if ch == '\\' && i + 1 < chars.len() {
            let next = chars[i + 1];
            if (next == 'n' || next == 'r') && !(in_class && class_negated) {
                return true;
            }
            i += 2;
            continue;
        }
        if ch == '[' && !in_class {
            in_class = true;
            class_negated = i + 1 < chars.len() && chars[i + 1] == '^';
            if class_negated {
                i += 2;
            } else {
                i += 1;
            }
            if i < chars.len() && chars[i] == ']' {
                i += 1;
            }
            continue;
        }
        if ch == ']' && in_class {
            in_class = false;
            class_negated = false;
        }
        i += 1;
    }
    false
}

fn is_line_anchored(normalized: &str) -> bool {
    let mut s = normalized;
    while let Some(rest) = s.strip_prefix("(?") {
        if let Some(close) = rest.find(')') {
            let flags = &rest[..close];
            if !flags.is_empty()
                && flags
                    .bytes()
                    .all(|b| matches!(b, b'i' | b'm' | b's' | b'x' | b'u' | b'-'))
            {
                s = &rest[close + 1..];
                continue;
            }
        }
        break;
    }
    (s.starts_with('^') || s.starts_with("(?:^")) && s.ends_with('$')
}

fn compile_toc_regex(pattern: &str, multiline: bool) -> Result<FancyRegex, TxtError> {
    let trimmed = pattern.trim_matches(|c| c == '\r' || c == '\n');
    if trimmed.trim().is_empty() {
        return Err(TxtError::Regex("Empty regex pattern".to_string()));
    }
    let normalized = normalize_java_regex(trimmed);
    let final_pat = if multiline && !normalized.contains("(?m") && !normalized.contains("(?im") {
        format!("(?m){normalized}")
    } else {
        normalized
    };
    FancyRegex::new(&final_pat).map_err(|e| TxtError::Regex(e.to_string()))
}

fn normalize_newlines_and_bom(raw: String) -> String {
    let stripped = raw.strip_prefix('\u{feff}').unwrap_or(&raw);
    if !stripped.contains('\r') {
        return if stripped.len() == raw.len() {
            raw
        } else {
            stripped.to_string()
        };
    }
    // `\r` (0x0D) and `\n` (0x0A) are ASCII bytes that never appear inside multi-byte UTF-8.
    let bytes = stripped.as_bytes();
    let mut out = Vec::with_capacity(bytes.len());
    let mut i = 0;
    while i < bytes.len() {
        if bytes[i] == b'\r' {
            if i + 1 < bytes.len() && bytes[i + 1] == b'\n' {
                i += 1;
            }
            out.push(b'\n');
        } else {
            out.push(bytes[i]);
        }
        i += 1;
    }
    // Safety: replacing ASCII `\r`/`\r\n` with ASCII `\n` preserves valid UTF-8.
    String::from_utf8(out).expect("LF normalization preserves valid UTF-8")
}

/// Auto-detects encoding (UTF-8 / GB18030 / UTF-16, etc.) and decodes raw bytes to normalized LF UTF-8.
pub fn decode_txt_bytes(bytes: &[u8]) -> (String, String) {
    if let Some((enc, bom_len)) = encoding_rs::Encoding::for_bom(bytes) {
        let (cow, _, _) = enc.decode(&bytes[bom_len..]);
        return (
            normalize_newlines_and_bom(cow.into_owned()),
            enc.name().to_string(),
        );
    }
    match std::str::from_utf8(bytes) {
        Ok(s) => {
            return (
                normalize_newlines_and_bom(s.to_string()),
                "UTF-8".to_string(),
            );
        }
        Err(err) => {
            // Feed chardetng starting around the first non-UTF-8 byte so files with
            // long (>64KB) ASCII prefaces before GB18030/Big5 text are still detected accurately.
            let start = err.valid_up_to().saturating_sub(4 * 1024);
            let end = (start + 128 * 1024).min(bytes.len());
            let mut detector = EncodingDetector::new();
            detector.feed(&bytes[start..end], end >= bytes.len());
            let enc = detector.guess(None, true);
            let (cow, actual_enc, _) = enc.decode(bytes);
            (
                normalize_newlines_and_bom(cow.into_owned()),
                actual_enc.name().to_string(),
            )
        }
    }
}

pub fn decode_txt_with_encoding(bytes: &[u8], encoding_name: Option<&str>) -> (String, String) {
    if let Some(name) = encoding_name {
        let trimmed = name.trim();
        if !trimmed.is_empty() && !trimmed.eq_ignore_ascii_case("auto") {
            if let Some(enc) = encoding_rs::Encoding::for_label(trimmed.as_bytes()) {
                let (cow, actual, _) = enc.decode(bytes);
                return (
                    normalize_newlines_and_bom(cow.into_owned()),
                    actual.name().to_string(),
                );
            }
        }
    }
    decode_txt_bytes(bytes)
}

fn clean_heading_title(raw: &str) -> String {
    let replaced = raw.replace('\u{3000}', " ");
    let collapsed = replaced.split_whitespace().collect::<Vec<_>>().join(" ");
    let trimmed = collapsed.trim();
    if trimmed.chars().count() > 80 {
        trimmed.chars().take(80).collect()
    } else {
        trimmed.to_string()
    }
}

/// Matches a single TOC regex pattern against `text`, returning `(byte_offset, cleaned_title)`.
/// Uses fast CRLF-safe line scanning for single-line patterns and multiline `fancy-regex` otherwise.
pub fn find_toc_matches(text: &str, pattern: &str) -> Result<Vec<(usize, String)>, TxtError> {
    let trimmed_pat = pattern.trim_matches(|c| c == '\r' || c == '\n');
    let normalized_pat = normalize_java_regex(trimmed_pat);
    let uses_explicit_newline = pattern_uses_explicit_newline(&normalized_pat);
    let anchored = is_line_anchored(&normalized_pat);

    if !uses_explicit_newline {
        let re = compile_toc_regex(trimmed_pat, false)?;
        let mut matches = Vec::new();
        let mut offset = 0usize;
        for raw_line in text.split_inclusive('\n') {
            let line = raw_line.trim_end_matches(['\r', '\n']);
            let trimmed = line.trim();
            // For line-anchored heading rules (`^...$`), skip long narrative paragraphs so
            // 10MB+ novel indexing stays near-instant. Unanchored custom rules still scan full lines.
            if !trimmed.is_empty() && (!anchored || trimmed.chars().count() <= 180) {
                if anchored {
                    if let Ok(Some(m)) = re.find(line) {
                        let title = clean_heading_title(m.as_str());
                        if !title.is_empty() {
                            matches.push((offset, title));
                        }
                    }
                } else {
                    for item in re.find_iter(line) {
                        if let Ok(m) = item {
                            let title = clean_heading_title(m.as_str());
                            if !title.is_empty() {
                                let leading_ws = m.as_str().len() - m.as_str().trim_start().len();
                                let start_pos = if m.start() == 0 {
                                    offset
                                } else {
                                    offset + m.start() + leading_ws
                                };
                                matches.push((start_pos, title));
                            }
                        }
                    }
                }
            }
            offset += raw_line.len();
        }
        return Ok(matches);
    }

    let re = compile_toc_regex(trimmed_pat, true)?;
    let mut matches = Vec::new();
    for item in re.find_iter(text) {
        if let Ok(m) = item {
            let raw_match = m.as_str();
            let title = clean_heading_title(raw_match);
            if !title.is_empty() {
                // If a Legado rule matched a leading `\n` (e.g. `(?:\n|^)第1章`), advance
                // start_byte past the leading newline so the chapter starts on the heading line.
                let leading_nl = raw_match.len() - raw_match.trim_start_matches(['\r', '\n']).len();
                matches.push((m.start() + leading_nl, title));
            }
        }
    }
    Ok(matches)
}

fn sample_prefix(text: &str, max_bytes: usize) -> &str {
    if text.len() <= max_bytes {
        return text;
    }
    let mut end = max_bytes;
    while end > 0 && !text.is_char_boundary(end) {
        end -= 1;
    }
    if let Some(nl) = text[..end].rfind('\n') {
        if nl > max_bytes / 2 {
            return &text[..nl + 1];
        }
    }
    &text[..end]
}

/// Scores candidate rule matches on a sample slice to pick the cleanest chapter rule automatically.
fn score_candidate_matches(
    matches: &[(usize, String)],
    sample_chars: usize,
    is_full_text: bool,
    serial_number: i32,
) -> f64 {
    let count = matches.len();
    if count == 0 {
        return -1.0;
    }
    if count == 1 && (!is_full_text || sample_chars > 25_000) {
        return 1.0;
    }

    let avg_chars = sample_chars as f64 / count as f64;
    // Ideal chapter length for Chinese/English novels is ~400 .. 25,000 chars.
    let density_score = if (600.0..=18_000.0).contains(&avg_chars) {
        100.0
    } else if (250.0..600.0).contains(&avg_chars) || (18_000.0..=45_000.0).contains(&avg_chars) {
        70.0
    } else if (80.0..250.0).contains(&avg_chars) && is_full_text && sample_chars < 6_000 {
        // Short test novels / sample chapters naturally have fewer chars per chapter.
        85.0
    } else if avg_chars < 80.0 {
        // Too dense: likely matching ordinary prose lines or numbered lists.
        if is_full_text && sample_chars < 2_000 {
            65.0
        } else {
            5.0
        }
    } else {
        35.0
    };

    // Check title cleanliness (real chapter titles rarely contain Chinese sentence periods mid-line).
    let noisy_titles = matches
        .iter()
        .filter(|(_, t)| {
            let char_len = t.chars().count();
            char_len > 48 || (t.contains('。') && char_len > 16)
        })
        .count();
    let noise_ratio = noisy_titles as f64 / count as f64;
    let cleanliness = (1.0 - noise_ratio * 1.4).max(0.05);

    // Count bonus (diminishing returns) + subtle priority tiebreaker for higher-priority rules.
    let count_bonus = ((count as f64).min(200.0) + 1.0).ln() * 14.0;
    let priority_tiebreak = (20 - serial_number.clamp(0, 20)) as f64 * 0.6;

    density_score * cleanliness + count_bonus + priority_tiebreak
}

fn build_chapters_from_matches(text: &str, matches: &[(usize, String)]) -> Vec<TxtChapter> {
    if matches.is_empty() {
        // Fallback: split long un-chaptered TXT into ~12KB readable chunks.
        if text.len() <= 24 * 1024 {
            return vec![TxtChapter {
                index: 0,
                title: "正文".to_string(),
                start_byte: 0,
                end_byte: text.len(),
            }];
        }
        let mut chunks = Vec::new();
        let mut start = 0usize;
        while start < text.len() {
            let mut target = (start + 12 * 1024).min(text.len());
            while target < text.len() && !text.is_char_boundary(target) {
                target += 1;
            }
            if target < text.len() {
                if let Some(nl) = text[target..].find('\n') {
                    target += nl + 1;
                }
            }
            chunks.push(TxtChapter {
                index: chunks.len(),
                title: format!("第 {} 节", chunks.len() + 1),
                start_byte: start,
                end_byte: target,
            });
            start = target;
        }
        return chunks;
    }

    let mut chapters = Vec::with_capacity(matches.len() + 1);
    if matches[0].0 > 0 && !text[..matches[0].0].trim().is_empty() {
        chapters.push(TxtChapter {
            index: 0,
            title: "前言".to_string(),
            start_byte: 0,
            end_byte: matches[0].0,
        });
    }

    for (i, (start, title)) in matches.iter().enumerate() {
        let end = if i + 1 < matches.len() {
            matches[i + 1].0
        } else {
            text.len()
        };
        if end <= *start {
            continue;
        }
        chapters.push(TxtChapter {
            index: chapters.len(),
            title: title.clone(),
            start_byte: *start,
            end_byte: end,
        });
    }

    chapters
}

/// Splits decoded UTF-8 text using either a forced rule or smart auto-scoring across enabled rules.
pub fn split_txt_chapters_with_rules(
    text: &str,
    rules: &[TxtTocRule],
    forced_rule: Option<&TxtTocRule>,
) -> Result<(Vec<TxtChapter>, Option<i64>, Option<String>), TxtError> {
    if let Some(rule) = forced_rule {
        let matches = find_toc_matches(text, &rule.rule)?;
        let chapters = build_chapters_from_matches(text, &matches);
        let matched = !matches.is_empty();
        return Ok((
            chapters,
            if matched { Some(rule.id) } else { None },
            if matched { Some(rule.name.clone()) } else { None },
        ));
    }

    let enabled_rules: Vec<&TxtTocRule> = rules.iter().filter(|r| r.enable && !r.rule.trim().is_empty()).collect();
    let sample = sample_prefix(text, 512 * 1024);
    let is_full = sample.len() == text.len();
    let sample_chars = sample.chars().count();

    let mut best_rule: Option<&TxtTocRule> = None;
    let mut best_score: f64 = 0.0;
    let mut best_sample_matches: Vec<(usize, String)> = Vec::new();

    for rule in enabled_rules {
        if let Ok(matches) = find_toc_matches(sample, &rule.rule) {
            let score = score_candidate_matches(&matches, sample_chars, is_full, rule.serial_number);
            if score > best_score {
                best_score = score;
                best_rule = Some(rule);
                best_sample_matches = matches;
            }
        }
    }

    if let Some(winner) = best_rule {
        let full_matches = if is_full {
            best_sample_matches
        } else {
            find_toc_matches(text, &winner.rule)?
        };
        let chapters = build_chapters_from_matches(text, &full_matches);
        return Ok((chapters, Some(winner.id), Some(winner.name.clone())));
    }

    Ok((build_chapters_from_matches(text, &[]), None, None))
}

/// Splits decoded UTF-8 text into chapter slices using a custom regex or smart built-in Legado rules.
pub fn split_txt_chapters(
    text: &str,
    custom_regex: Option<&str>,
) -> Result<Vec<TxtChapter>, TxtError> {
    if let Some(pat) = custom_regex {
        let forced = TxtTocRule {
            id: 0,
            name: "自定义规则".to_string(),
            rule: pat.to_string(),
            example: String::new(),
            enable: true,
            serial_number: 0,
        };
        let (chapters, _, _) = split_txt_chapters_with_rules(text, &[], Some(&forced))?;
        return Ok(chapters);
    }
    let defaults = default_toc_rules();
    let (chapters, _, _) = split_txt_chapters_with_rules(text, &defaults, None)?;
    Ok(chapters)
}

pub fn index_txt_file(
    path: &Path,
    custom_regex: Option<&str>,
    forced_encoding: Option<&str>,
) -> Result<TxtIndexResult, TxtError> {
    let raw = fs::read(path)?;
    let (decoded, encoding) = decode_txt_with_encoding(&raw, forced_encoding);
    if let Some(pat) = custom_regex {
        let forced = TxtTocRule {
            id: 0,
            name: "自定义规则".to_string(),
            rule: pat.to_string(),
            example: String::new(),
            enable: true,
            serial_number: 0,
        };
        let (chapters, matched_rule_id, matched_rule_name) =
            split_txt_chapters_with_rules(&decoded, &[], Some(&forced))?;
        return Ok(TxtIndexResult {
            encoding,
            total_chars: decoded.chars().count(),
            matched_rule_id,
            matched_rule_name,
            chapters,
        });
    }
    let defaults = default_toc_rules();
    let (chapters, matched_rule_id, matched_rule_name) =
        split_txt_chapters_with_rules(&decoded, &defaults, None)?;
    Ok(TxtIndexResult {
        encoding,
        total_chars: decoded.chars().count(),
        matched_rule_id,
        matched_rule_name,
        chapters,
    })
}

pub fn index_txt_file_with_rules(
    path: &Path,
    rules: &[TxtTocRule],
    forced_rule: Option<&TxtTocRule>,
    forced_encoding: Option<&str>,
) -> Result<TxtIndexResult, TxtError> {
    let raw = fs::read(path)?;
    let (decoded, encoding) = decode_txt_with_encoding(&raw, forced_encoding);
    let effective_rules: Vec<TxtTocRule> = if rules.is_empty() {
        default_toc_rules()
    } else {
        rules.to_vec()
    };
    let (chapters, matched_rule_id, matched_rule_name) =
        split_txt_chapters_with_rules(&decoded, &effective_rules, forced_rule)?;
    Ok(TxtIndexResult {
        encoding,
        total_chars: decoded.chars().count(),
        matched_rule_id,
        matched_rule_name,
        chapters,
    })
}

/// Tests a regex rule against sample text (or file preview) for live rule editing & validation.
pub fn test_toc_rule(
    pattern: &str,
    sample_text: &str,
    max_preview: usize,
) -> TocRuleTestResult {
    let normalized_sample = normalize_newlines_and_bom(sample_text.to_string());
    match find_toc_matches(&normalized_sample, pattern) {
        Ok(matches) => TocRuleTestResult {
            valid: true,
            match_count: matches.len(),
            preview_titles: matches
                .into_iter()
                .take(max_preview)
                .map(|(_, t)| t)
                .collect(),
            error: None,
        },
        Err(e) => TocRuleTestResult {
            valid: false,
            match_count: 0,
            preview_titles: Vec::new(),
            error: Some(e.to_string()),
        },
    }
}

/// Reads a single TXT chapter slice, applies Legado-style purification rules & Chinese conversion.
pub fn read_txt_chapter(
    path: &Path,
    chapter_index: usize,
    start_byte: usize,
    end_byte: usize,
    title: &str,
    forced_encoding: Option<&str>,
    rules: &[TextReplaceRule],
    cn_mode: ChineseConversionMode,
) -> Result<BookChapterContent, TxtError> {
    let raw = fs::read(path)?;
    let (decoded, _) = decode_txt_with_encoding(&raw, forced_encoding);
    if start_byte > decoded.len()
        || end_byte > decoded.len()
        || start_byte > end_byte
        || !decoded.is_char_boundary(start_byte)
        || !decoded.is_char_boundary(end_byte)
    {
        return Err(TxtError::InvalidRange);
    }
    let slice = &decoded[start_byte..end_byte];
    let purified = convert_chinese(&apply_replace_rules(slice, rules), cn_mode);

    let mut blocks = Vec::new();
    let mut skipped_title = false;
    for line in purified.lines() {
        let trimmed = line.trim();
        if trimmed.is_empty() {
            continue;
        }
        if !skipped_title && clean_heading_title(trimmed) == clean_heading_title(title) {
            skipped_title = true;
            blocks.push(BookBlock::Heading {
                level: 1,
                text: trimmed.to_string(),
            });
            continue;
        }
        blocks.push(BookBlock::Paragraph {
            text: trimmed.to_string(),
        });
    }
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
    fn all_default_toc_rules_compile_cleanly() {
        for r in default_toc_rules() {
            let res = test_toc_rule(&r.rule, "第一章 测试\n正文", 5);
            assert!(
                res.valid,
                "Rule {} ({}) failed to compile: {:?}",
                r.id, r.name, res.error
            );
        }
    }

    #[test]
    fn decodes_gb18030_and_splits_chapters_including_crlf() {
        let sample = "楔子 雪夜\r\n漫天大雪。\r\n第一章 黑暗森林\r\n宇宙是一座黑暗森林。\r\n第二章 面壁者\r\n计划开始。";
        let (gbk_bytes, _, _) = encoding_rs::GB18030.encode(sample);
        let (decoded, enc) = decode_txt_bytes(&gbk_bytes);
        assert_ne!(enc, "UTF-8");
        assert!(decoded.contains("黑暗森林"));
        assert!(!decoded.contains('\r'));

        let chapters = split_txt_chapters(&decoded, None).unwrap();
        assert_eq!(chapters.len(), 3);
        assert_eq!(chapters[0].title, "楔子 雪夜");
        assert_eq!(chapters[1].title, "第一章 黑暗森林");
        assert_eq!(chapters[2].title, "第二章 面壁者");
    }

    #[test]
    fn detects_gb18030_after_long_ascii_header() {
        let mut raw = vec![b'A'; 70 * 1024];
        raw.push(b'\n');
        let (gbk, _, _) = encoding_rs::GB18030.encode("第一章 远方\r\n中文正文内容测试。\r\n");
        raw.extend_from_slice(&gbk);
        let (decoded, enc) = decode_txt_bytes(&raw);
        assert_ne!(enc, "UTF-8");
        assert!(decoded.contains("第一章 远方"));
        assert!(decoded.contains("中文正文内容测试"));
    }

    #[test]
    fn respects_negative_lookahead_and_rejects_prose_false_positives() {
        let text = "\u{3000}\u{3000}第 一 章 初见\r\n第一节课开始了，老师走上讲台。\r\n前言不搭后语，令他哭笑不得。\r\n正文部分还没写完，请耐心等待。\r\n正文完\r\n      第 2 章 风起\r\n番外 旧梦\r\n故事继续。";
        let chapters = split_txt_chapters(text, None).unwrap();
        let titles: Vec<&str> = chapters.iter().map(|c| c.title.as_str()).collect();
        assert_eq!(titles, vec!["第 一 章 初见", "第 2 章 风起", "番外 旧梦"]);
    }

    #[test]
    fn auto_detects_numeric_english_symbol_and_zhengwen_prefix_formats() {
        let num_text = "1、序幕\n这是一段比较长的测试正文内容用于模拟真实小说段落。\n2、相遇\n故事在雨夜中缓缓拉开帷幕，一切都显得如此神秘。\n3、启程\n主人公背起行囊走向远方。";
        let (chs, rule_id, _) =
            split_txt_chapters_with_rules(num_text, &default_toc_rules(), None).unwrap();
        assert_eq!(chs.len(), 3);
        assert_eq!(rule_id, Some(-5));

        let en_text = "Prologue\nOnce upon a time in a quiet valley.\nChapter 1 Awakening\nThe sun rose over the misty ridge.\nChapter 2 The Journey\nFootsteps echoed on stone.";
        let (en_chs, en_rule, _) =
            split_txt_chapters_with_rules(en_text, &default_toc_rules(), None).unwrap();
        assert_eq!(en_chs.len(), 3);
        assert_eq!(en_rule, Some(-7));

        let sym_text = "☆、初遇\n那是一个微风轻拂的午后。\n☆、再会\n花瓣落在石阶上。\n☆、终章\n夕阳西下。";
        let (sym_chs, sym_rule, _) =
            split_txt_chapters_with_rules(sym_text, &default_toc_rules(), None).unwrap();
        assert_eq!(sym_chs.len(), 3);
        assert_eq!(sym_rule, Some(-10));

        let zw_text = "正文 001 重生\n第一段故事开始了，雨水敲打着窗棂。\n正文 002 觉醒\n第二段故事展开，远方传来钟声。\n正文 003 破晓\n黎明到来。";
        let (zw_chs, zw_rule, _) =
            split_txt_chapters_with_rules(zw_text, &default_toc_rules(), None).unwrap();
        assert_eq!(zw_chs.len(), 3);
        assert_eq!(zw_rule, Some(-12));
    }

    #[test]
    fn supports_official_github_legado_variable_lookbehind_and_java_syntax() {
        // Real Legado `txtTocRule.json` rules featuring variable-length lookbehind, `\uXXXX`, `\p{IsHan}`
        let legado_symbol_rule = r"(?<=[\s ]{0,4})(?:[✦✧].{1,30}|前言|序章|楔子|番外)[ ]{0,4}$";
        let sample1 = "  ✦ 序幕\r\n正文内容。\r\n楔子\r\n雪夜故事。\r\n  ✧ 终章\r\n完结。";
        let r1 = test_toc_rule(legado_symbol_rule, sample1, 10);
        assert!(r1.valid, "err={:?}", r1.error);
        assert_eq!(r1.match_count, 3);
        assert_eq!(r1.preview_titles, vec!["✦ 序幕", "楔子", "✧ 终章"]);

        let legado_lb_alt = r"(?<=^|\n)[ \t]*第\d+章[^\r\n]{0,20}$";
        let sample2 = "第1章 拂晓\r\n内容一。\r\n第2章 暮色\r\n内容二。";
        let r2 = test_toc_rule(legado_lb_alt, sample2, 10);
        assert!(r2.valid, "err={:?}", r2.error);
        assert_eq!(r2.match_count, 2);
        assert_eq!(r2.preview_titles, vec!["第1章 拂晓", "第2章 暮色"]);
        let matches2 = find_toc_matches(&normalize_newlines_and_bom(sample2.to_string()), legado_lb_alt).unwrap();
        // Second chapter must start ON '第2章', not on the preceding '\n'
        assert!(normalize_newlines_and_bom(sample2.to_string())[matches2[1].0..].starts_with("第2章"));

        let java_rule = r"^[\u3000\s]*\p{IsHan}{1,6}：\d+[^\r\n。；]{0,15}$";
        assert!(!pattern_uses_explicit_newline(&normalize_java_regex(java_rule)));
        let sample3 = "　章节：1 序\r\n内容一\r\n章节：2 终\r\n内容二";
        let r3 = test_toc_rule(java_rule, sample3, 10);
        assert!(r3.valid, "err={:?}", r3.error);
        assert_eq!(r3.match_count, 2);
        assert_eq!(r3.preview_titles, vec!["章节：1 序", "章节：2 终"]);
    }

    #[test]
    fn read_txt_chapter_rejects_non_char_boundary_without_panicking() {
        let tmp = std::env::temp_dir().join("inkbox_txt_boundary_test");
        let _ = std::fs::create_dir_all(&tmp);
        let file = tmp.join("utf8.txt");
        std::fs::write(&file, "第一章 测试\n正文内容。").unwrap();
        // Byte offset 1 is inside the 3-byte UTF-8 character '第'
        let res = read_txt_chapter(&file, 0, 1, 5, "第一章", None, &[], ChineseConversionMode::None);
        assert!(matches!(res, Err(TxtError::InvalidRange)));
        let _ = std::fs::remove_dir_all(&tmp);
    }
}
