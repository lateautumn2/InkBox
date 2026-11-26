use image::{ImageBuffer, ImageFormat, Rgb};
use inkbox_core::book::epub::{extract_epub_cover_bytes, parse_epub_metadata, read_epub_chapter};
use inkbox_core::book::types::{ChineseConversionMode, TextReplaceRule};
use inkbox_core::comic::cbz::{inspect_cbz_archive, read_cbz_page_bytes};
use inkbox_core::comic::image_proc::{detect_smart_crop_rect, make_cover_thumbnail};
use inkbox_core::importer::compute_fast_fingerprint;
use inkbox_core::webdav::{pack_backup_snapshot_zip, unpack_backup_snapshot_zip};
use std::collections::HashMap;
use std::fs::File;
use std::io::{Cursor, Write};
use zip::write::SimpleFileOptions;
use zip::{CompressionMethod, ZipWriter};

fn make_sample_png(width: u32, height: u32) -> Vec<u8> {
    let mut img: ImageBuffer<Rgb<u8>, Vec<u8>> =
        ImageBuffer::from_pixel(width, height, Rgb([250, 250, 250]));
    for y in (height / 5)..(height * 4 / 5) {
        for x in (width / 5)..(width * 4 / 5) {
            img.put_pixel(x, y, Rgb([30, 30, 30]));
        }
    }
    let mut c = Cursor::new(Vec::new());
    img.write_to(&mut c, ImageFormat::Png).unwrap();
    c.into_inner()
}

#[test]
fn end_to_end_epub_metadata_cover_and_chapter_reading() {
    let tmp = std::env::temp_dir().join("inkbox_test_sample.epub");
    let cover_png = make_sample_png(120, 180);

    {
        let f = File::create(&tmp).unwrap();
        let mut z = ZipWriter::new(f);
        let opts = SimpleFileOptions::default().compression_method(CompressionMethod::Deflated);
        z.start_file("META-INF/container.xml", opts).unwrap();
        z.write_all(
            br#"<?xml version="1.0"?><container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles></container>"#,
        )
        .unwrap();

        z.start_file("OEBPS/content.opf", opts).unwrap();
        z.write_all(
            r#"<?xml version="1.0"?><package xmlns="http://www.idpf.org/2007/opf" version="3.0"><metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>墨匣测试书</dc:title><dc:creator>测试作者</dc:creator><dc:language>zh-CN</dc:language></metadata><manifest><item id="cover" href="images/cover.png" media-type="image/png" properties="cover-image"/><item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/><item id="ch1" href="text/ch1.xhtml" media-type="application/xhtml+xml"/></manifest><spine toc="ncx"><itemref idref="ch1"/></spine></package>"#.as_bytes(),
        )
        .unwrap();

        z.start_file("OEBPS/toc.ncx", opts).unwrap();
        z.write_all(
            r#"<?xml version="1.0"?><ncx><navMap><navPoint id="n1"><navLabel><text>第一章 · 序幕</text></navLabel><content src="text/ch1.xhtml"/></navPoint></navMap></ncx>"#.as_bytes(),
        )
        .unwrap();

        z.start_file("OEBPS/images/cover.png", opts).unwrap();
        z.write_all(&cover_png).unwrap();

        z.start_file("OEBPS/text/ch1.xhtml", opts).unwrap();
        z.write_all(
            r#"<html><body><h1>第一章 · 序幕</h1><p>这是一段包含广告字样AD_REMOVE的正文。</p><aside>脚注说明文字</aside></body></html>"#.as_bytes(),
        )
        .unwrap();
        z.finish().unwrap();
    }

    let meta = parse_epub_metadata(&tmp).unwrap();
    assert_eq!(meta.title, "墨匣测试书");
    assert_eq!(meta.author, "测试作者");
    assert_eq!(meta.chapters.len(), 1);
    assert_eq!(meta.chapters[0].title, "第一章 · 序幕");

    let cover = extract_epub_cover_bytes(&tmp).unwrap().unwrap();
    let thumb = make_cover_thumbnail(&cover, 200).unwrap();
    assert!(!thumb.is_empty());

    let rules = vec![TextReplaceRule {
        pattern: "AD_REMOVE".to_string(),
        replacement: "".to_string(),
        is_regex: false,
        enabled: true,
    }];
    let ch = read_epub_chapter(
        &tmp,
        0,
        &meta.chapters[0].href,
        &meta.chapters[0].title,
        &rules,
        ChineseConversionMode::ToTraditional,
    )
    .unwrap();
    assert!(!ch.plain_text.contains("AD_REMOVE"));
    assert!(ch.plain_text.contains("這是一段"));

    let fp = compute_fast_fingerprint(&tmp).unwrap();
    assert_eq!(fp.len(), 64);

    let _ = std::fs::remove_file(&tmp);
}

#[test]
fn end_to_end_cbz_streaming_and_smart_crop() {
    let tmp = std::env::temp_dir().join("inkbox_test_manga.cbz");
    let p1 = make_sample_png(200, 300);
    let p2 = make_sample_png(420, 300); // Wide spread!

    {
        let f = File::create(&tmp).unwrap();
        let mut z = ZipWriter::new(f);
        let opts = SimpleFileOptions::default().compression_method(CompressionMethod::Stored);
        z.start_file("ComicInfo.xml", opts).unwrap();
        z.write_all("<ComicInfo><Series>测试漫画</Series><Writer>测试画师</Writer><Manga>YesAndRightToLeft</Manga></ComicInfo>".as_bytes()).unwrap();
        z.start_file("10.png", opts).unwrap();
        z.write_all(&p2).unwrap();
        z.start_file("2.png", opts).unwrap();
        z.write_all(&p1).unwrap();
        z.finish().unwrap();
    }

    let summary = inspect_cbz_archive(&tmp).unwrap();
    assert_eq!(summary.page_count, 2);
    assert_eq!(summary.pages[0].entry_name, "2.png");
    assert_eq!(summary.pages[1].entry_name, "10.png");
    assert_eq!(
        summary.comic_info.as_ref().unwrap().series.as_deref(),
        Some("测试漫画")
    );

    let bytes = read_cbz_page_bytes(&tmp, "2.png").unwrap();
    let crop = detect_smart_crop_rect(&bytes).unwrap();
    assert!(crop.left > 0.12 && crop.right < 0.88);

    let _ = std::fs::remove_file(&tmp);
}

#[test]
fn end_to_end_webdav_backup_snapshot_roundtrip() {
    let tmp = std::env::temp_dir().join("inkbox_test_backup.zip");
    let mut files = HashMap::new();
    files.insert("sync/progress_index.json".into(), r#"{"version":1}"#.into());
    files.insert("sync/preferences.json".into(), r#"{"uiStyle":"floatingCard"}"#.into());

    let count = pack_backup_snapshot_zip(&files, &tmp).unwrap();
    assert_eq!(count, 2);

    let restored = unpack_backup_snapshot_zip(&tmp).unwrap();
    assert_eq!(restored.get("sync/progress_index.json").unwrap(), r#"{"version":1}"#);
    assert_eq!(
        restored.get("sync/preferences.json").unwrap(),
        r#"{"uiStyle":"floatingCard"}"#
    );

    let _ = std::fs::remove_file(&tmp);
}
