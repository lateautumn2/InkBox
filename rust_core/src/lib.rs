pub mod book;
pub mod comic;
pub mod ffi;
pub mod importer;
pub mod webdav;

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CoreHealth {
    pub engine_name: String,
    pub version: String,
    pub supported_book_formats: Vec<String>,
    pub supported_comic_formats: Vec<String>,
}

pub fn health_check() -> CoreHealth {
    CoreHealth {
        engine_name: "inkbox_core".to_string(),
        version: env!("CARGO_PKG_VERSION").to_string(),
        supported_book_formats: vec![
            "epub", "txt", "pdf", "mobi", "azw3", "fb2", "md",
        ]
        .into_iter()
        .map(String::from)
        .collect(),
        supported_comic_formats: vec![
            "cbz", "zip", "cbr", "rar", "cb7", "7z", "pdf", "folder",
        ]
        .into_iter()
        .map(String::from)
        .collect(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn health_reports_expected_formats() {
        let h = health_check();
        assert_eq!(h.engine_name, "inkbox_core");
        assert!(h.supported_book_formats.contains(&"epub".to_string()));
        assert!(h.supported_comic_formats.contains(&"cbz".to_string()));
    }
}
