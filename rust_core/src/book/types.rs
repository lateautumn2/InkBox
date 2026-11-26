use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BookChapterMeta {
    pub index: usize,
    pub title: String,
    /// Format-specific locator (e.g., EPUB href, TXT "start:end", MOBI/FB2/MD section index).
    pub href: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(tag = "kind")]
pub enum BookBlock {
    Heading { level: u8, text: String },
    Paragraph { text: String },
    Image { href: String, caption: Option<String> },
    Footnote { id: String, text: String },
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BookChapterContent {
    pub index: usize,
    pub title: String,
    pub blocks: Vec<BookBlock>,
    /// Flattened readable plain text (for pagination, TTS, and search).
    pub plain_text: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TextReplaceRule {
    pub pattern: String,
    pub replacement: String,
    pub is_regex: bool,
    pub enabled: bool,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
pub enum ChineseConversionMode {
    None,
    ToSimplified,
    ToTraditional,
}

pub fn blocks_to_plain_text(blocks: &[BookBlock]) -> String {
    let mut out = String::new();
    for b in blocks {
        match b {
            BookBlock::Heading { text, .. } | BookBlock::Paragraph { text } => {
                let t = text.trim();
                if !t.is_empty() {
                    if !out.is_empty() {
                        out.push_str("\n\n");
                    }
                    out.push_str(t);
                }
            }
            BookBlock::Image { caption, .. } => {
                if let Some(c) = caption {
                    if !c.trim().is_empty() {
                        if !out.is_empty() {
                            out.push_str("\n\n");
                        }
                        out.push_str("[插图: ");
                        out.push_str(c.trim());
                        out.push(']');
                    }
                }
            }
            BookBlock::Footnote { .. } => {}
        }
    }
    out
}

/// Applies Legado-style text purification / replacement rules to raw text.
pub fn apply_replace_rules(input: &str, rules: &[TextReplaceRule]) -> String {
    let mut current = input.to_string();
    for rule in rules {
        if !rule.enabled || rule.pattern.is_empty() {
            continue;
        }
        if rule.is_regex {
            if let Ok(re) = regex::Regex::new(&rule.pattern) {
                current = re.replace_all(&current, rule.replacement.as_str()).into_owned();
            }
        } else {
            current = current.replace(&rule.pattern, &rule.replacement);
        }
    }
    current
}
