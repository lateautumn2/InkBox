import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:inkbox/data/db/app_database.dart';
import 'package:inkbox/data/ffi/rust_core_bridge.dart';
import 'package:inkbox/data/platform/platform_bridge.dart';
import 'package:inkbox/features/book_reader/book_paginator.dart';
import 'package:inkbox/features/book_reader/book_reader_settings.dart';
import 'package:inkbox/features/importer/import_service.dart';
import 'package:inkbox/features/manga_reader/manga_page_source.dart';
import 'package:inkbox/features/manga_reader/manga_reader_settings.dart';
import 'package:inkbox/features/toc_rules/toc_rules_parser.dart';
import 'package:inkbox/features/webdav_sync/webdav_sync_service.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

class _FakePlatformBridge implements PlatformBridge {
  @override
  Stream<PlatformEvent> get events => const Stream.empty();
  @override
  Future<List<String>> pickDocuments() async => const [];
  @override
  Future<PickedDocumentsResult> pickDocumentsDetailed() async =>
      const PickedDocumentsResult();
  @override
  Future<PickedDirectory?> pickPersistentDirectory() async => null;
  @override
  Future<List<ScannedTreeFile>> scanPersistentDirectory(String treeUri) async =>
      const [];
  @override
  Future<void> setKeepScreenOn(bool enabled) async {}
  @override
  Future<void> setScreenBrightness(double? brightness) async {}
  @override
  Future<void> setVolumeKeyPaging(bool enabled) async {}
  @override
  Future<String?> speakText(
    String text, {
    double rate = 1.0,
    double pitch = 1.0,
    String? language,
    String? engine,
    String? voiceName,
  }) async =>
      'u1';
  @override
  Future<String?> stageDocumentUri(String uri, {String? fileName}) async =>
      null;
  @override
  Future<void> stopTts() async {}
  @override
  Future<List<TtsEngineOption>> getTtsEngines() async => const [];
  @override
  Future<List<TtsVoiceOption>> getTtsVoices({
    String? engine,
    String? language,
  }) async =>
      const [];
  @override
  Future<void> openSystemTtsSettings() async {}
  @override
  Future<bool> playAudioFile(
    String path, {
    double speed = 1.0,
    String? playbackId,
  }) async =>
      true;
  @override
  Future<void> pauseAudio() async {}
  @override
  Future<void> resumeAudio() async {}
  @override
  Future<void> stopAudio() async {}
  @override
  Future<void> setAudioSpeed(double speed) async {}
  @override
  Future<void> saveSecret(String key, String value) async {}
  @override
  Future<String?> readSecret(String key) async => null;
  @override
  Future<void> deleteSecret(String key) async {}
  @override
  Future<int> getPdfPageCount(String path) async => 0;
  @override
  Future<Uint8List?> renderPdfPage(String path, int pageIndex,
          {double scale = 2.0}) async =>
      null;
}

RustCoreBridge _openTestRustCore() {
  final dllPath = p.normalize(
    p.join(
      Directory.current.path,
      '..',
      'rust_core',
      'target',
      'debug',
      Platform.isWindows ? 'inkbox_core.dll' : 'libinkbox_core.so',
    ),
  );
  final bridge = RustCoreBridge.tryOpen(explicitLibraryPath: dllPath);
  expect(bridge, isNotNull, reason: 'Native Rust core must exist at $dllPath');
  return bridge!;
}

void main() {
  drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('V1.0 M2 Smart Import & Deduplication', () {
    test('imports real TXT, MD, and image-folder comic into Drift DB', () async {
      final rust = _openTestRustCore();
      final db = AppDatabase.inMemory();
      final tmp = Directory.systemTemp.createTempSync('inkbox_m2_test_');
      addTearDown(() async {
        await db.close();
        if (tmp.existsSync()) tmp.deleteSync(recursive: true);
      });

      final txtFile = File(p.join(tmp.path, 'novel.txt'))
        ..writeAsStringSync(
          '第一章 启程\n这是第一章内容，包含广告AD_TAG。\n第二章 远航\n这是第二章正文。',
        );
      final mdFile = File(p.join(tmp.path, 'guide.md'))
        ..writeAsStringSync('# 墨匣架构\n\n导言段落。\n\n## 第一节 渲染\n\n细节说明。');
      final comicDir = Directory(p.join(tmp.path, 'my_comic'))..createSync();
      // Minimal valid 1x1 PNG bytes
      final tinyPng = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+ip1sAAAAASUVORK5CYII=',
      );
      File(p.join(comicDir.path, '1.png')).writeAsBytesSync(tinyPng);
      File(p.join(comicDir.path, '2.png')).writeAsBytesSync(tinyPng);

      final svc = ImportService(
        db: db,
        platform: _FakePlatformBridge(),
        rustCore: rust,
        coversDirOverride: p.join(tmp.path, 'covers'),
      );

      expect(await svc.importLocalPath(txtFile.path), 'book');
      expect(await svc.importLocalPath(txtFile.path), 'duplicate');
      expect(await svc.importLocalPath(mdFile.path), 'book');
      expect(await svc.importLocalPath(comicDir.path), 'manga');

      final books = await db.getAllBooks();
      final mangas = await db.getAllMangas();
      expect(books.length, 2);
      expect(mangas.length, 1);
      expect(mangas.first.coverPath, isNotNull);
      expect(File(mangas.first.coverPath!).existsSync(), isTrue);

      final chapters = await db.chaptersForManga(mangas.first.id);
      expect(chapters.length, 1);
      expect(chapters.first.pageCount, 2);

      // Verify M3 Rust reading & purification + traditional Chinese conversion
      final txtBook = books.firstWhere((b) => b.format == 'TXT');
      final loader = BookContentLoader(rustCore: rust);
      final chList = await loader.loadChapterList(txtBook);
      expect(chList.length, 2);
      final ch0 = await loader.loadChapterContent(
        txtBook,
        chList.first,
        const BookReaderSettings(
          chineseConversion: 'ToTraditional',
          replaceRules: [
            ReplaceRuleConfig(
              name: 'strip_ad',
              pattern: 'AD_TAG',
              replacement: '',
            ),
          ],
        ),
      );
      expect(ch0.text.contains('AD_TAG'), isFalse);
      expect(ch0.text.contains('這'), isTrue);

      // Verify M4 MangaPageSource streams real images + smart crop rect
      final src = MangaPageSource(
        sourcePath: comicDir.path,
        rustCore: rust,
      );
      await src.open();
      expect(src.pageCount, 2);
      final p0 = await src.loadPage(0, computeCrop: true);
      expect(p0, isNotNull);
      expect(p0!.width, 1);
      await src.dispose();
    });
  });

  group('V1.0 M3 Book Paginator & 9-Grid Tap Zones', () {
    test('paginates long text and preserves char offset on font resize', () {
      final longText = List.generate(
        40,
        (i) => '这是第 ${i + 1} 段用于验证精确字符偏移分页与字号变更锚点不漂移的中文测试段落。',
      ).join('\n\n');

      final pages16 = BookPaginator.paginate(
        text: longText,
        maxWidth: 320,
        maxHeight: 460,
        style: const TextStyle(fontSize: 16, height: 1.8),
      );
      final pages22 = BookPaginator.paginate(
        text: longText,
        maxWidth: 320,
        maxHeight: 460,
        style: const TextStyle(fontSize: 22, height: 1.8),
      );

      expect(pages16.length, greaterThan(1));
      expect(pages22.length, greaterThan(pages16.length));

      final midOffset = pages16[1].startOffset;
      final anchoredPage = BookPaginator.findPageForOffset(pages22, midOffset);
      expect(anchoredPage, greaterThanOrEqualTo(1));

      // Verify O(N) windowed paginator handles a 30,000+ char chapter accurately and fast
      final hugeChapter = List.generate(
        600,
        (i) => '第 ${i + 1} 段：长篇小说大章节分页性能与边界完整性测试文本，确保窗口分页绝不丢失任何字符或产生重叠。',
      ).join('\n\n');
      final sw = Stopwatch()..start();
      final hugePages = BookPaginator.paginate(
        text: hugeChapter,
        maxWidth: 340,
        maxHeight: 560,
        style: const TextStyle(fontSize: 18, height: 1.75),
      );
      sw.stop();
      expect(hugePages.length, greaterThan(40));
      expect(hugePages.first.startOffset, 0);
      expect(
        hugePages.last.endOffset,
        BookPaginator.formatParagraphs(hugeChapter, indent: true).length,
      );
      expect(sw.elapsedMilliseconds, lessThan(4000));
    });

    test('resolves 9-grid tap zones accurately across presets', () {
      const std = BookReaderSettings(tapZonePreset: TapZonePreset.standard);
      expect(std.resolveTapAction(0.5, 0.5), TapZoneAction.toggleMenu);
      expect(std.resolveTapAction(0.1, 0.5), TapZoneAction.prevPage);
      expect(std.resolveTapAction(0.9, 0.5), TapZoneAction.nextPage);

      const left = BookReaderSettings(tapZonePreset: TapZonePreset.leftHand);
      expect(left.resolveTapAction(0.1, 0.5), TapZoneAction.nextPage);
      expect(left.resolveTapAction(0.9, 0.5), TapZoneAction.prevPage);
    });
  });

  group('V1.0 M4 Manga Tap Layouts', () {
    test('handles RTL vs LTR tap direction correctly', () {
      const s = MangaReaderSettings(tapLayout: MangaTapLayout.edge);
      // Center always toggles menu
      expect(s.resolveTapDelta(0.5, 0.5, isRtl: true), 0);
      // RTL: tapping left advances (+1), tapping right goes back (-1)
      expect(s.resolveTapDelta(0.1, 0.5, isRtl: true), 1);
      expect(s.resolveTapDelta(0.9, 0.5, isRtl: true), -1);
      // LTR: tapping right advances (+1), tapping left goes back (-1)
      expect(s.resolveTapDelta(0.9, 0.5, isRtl: false), 1);
      expect(s.resolveTapDelta(0.1, 0.5, isRtl: false), -1);
    });
  });

  group('V1.0 M5 WebDAV Layer 1 + Layer 2 + Conflict + Snapshot Roundtrip', () {
    test('syncs against real local WebDAV HTTP server end-to-end', () async {
      final rust = _openTestRustCore();
      final db = AppDatabase.inMemory();
      final tmp = Directory.systemTemp.createTempSync('inkbox_m5_dav_');

      // In-memory RFC 4918 WebDAV test server
      final storage = <String, List<int>>{};
      final dirs = <String>{'/', '/InkBox', '/InkBox/'};
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);

      server.listen((req) async {
        final path = req.uri.path;
        if (req.method == 'MKCOL') {
          dirs.add(path);
          req.response.statusCode = HttpStatus.created;
          await req.response.close();
        } else if (req.method == 'HEAD') {
          req.response.statusCode = storage.containsKey(path)
              ? HttpStatus.ok
              : HttpStatus.notFound;
          await req.response.close();
        } else if (req.method == 'PUT') {
          final bytes = <int>[];
          await for (final chunk in req) {
            bytes.addAll(chunk);
          }
          storage[path] = bytes;
          req.response.statusCode = HttpStatus.created;
          await req.response.close();
        } else if (req.method == 'GET') {
          final data = storage[path];
          if (data == null) {
            req.response.statusCode = HttpStatus.notFound;
          } else {
            req.response.statusCode = HttpStatus.ok;
            req.response.add(data);
          }
          await req.response.close();
        } else if (req.method == 'PROPFIND') {
          final depth = req.headers.value('Depth') ?? '0';
          final buf = StringBuffer()
            ..write('<?xml version="1.0" encoding="utf-8"?><d:multistatus xmlns:d="DAV:">')
            ..write('<d:response><d:href>$path</d:href><d:propstat><d:prop><d:resourcetype><d:collection/></d:resourcetype></d:prop></d:propstat></d:response>');
          if (depth == '1') {
            final prefix = path.endsWith('/') ? path : '$path/';
            for (final entry in storage.entries) {
              if (entry.key.startsWith(prefix)) {
                buf.write(
                  '<d:response><d:href>${entry.key}</d:href><d:propstat><d:prop><d:getcontentlength>${entry.value.length}</d:getcontentlength></d:prop></d:propstat></d:response>',
                );
              }
            }
          }
          buf.write('</d:multistatus>');
          req.response.statusCode = 207;
          req.response.write(buf.toString());
          await req.response.close();
        } else {
          req.response.statusCode = HttpStatus.methodNotAllowed;
          await req.response.close();
        }
      });

      addTearDown(() async {
        await server.close(force: true);
        await db.close();
        if (tmp.existsSync()) tmp.deleteSync(recursive: true);
      });

      final localBook = File(p.join(tmp.path, 'sample.txt'))
        ..writeAsStringSync('第一章\n同步测试文本');
      final now = DateTime.now().millisecondsSinceEpoch;
      final bookId = await db.upsertBook(
        BooksCompanion.insert(
          contentHash: 'hash_sync_book_1',
          title: '同步测试书',
          format: 'TXT',
          filePath: localBook.path,
          addedAtMs: now,
          lastReadAtMs: now,
        ),
      );
      await db.updateBookProgress(
        id: bookId,
        chapterIndex: 1,
        charOffset: 100,
        chapterTitle: '第一章',
        progressRatio: 0.25,
      );
      await db.upsertAnnotation(
        AnnotationsCompanion.insert(
          uuid: 'ann_u1',
          contentHash: 'hash_sync_book_1',
          mediaKind: 'book',
          kind: 'note',
          locator: 'ch:1;off:100',
          excerpt: const drift.Value('同步测试'),
          noteText: const drift.Value('本地批注'),
          updatedAtMs: now,
        ),
      );

      final cfg = WebDavConfig(
        serverUrl: 'http://127.0.0.1:${server.port}',
        username: 'user',
        password: 'secret',
        remoteRoot: '/InkBox',
        deviceId: 'phone_a',
        deviceName: 'Phone A',
      );
      final syncSvc = WebDavSyncService(
        db: db,
        rustCore: rust,
        tempDirOverride: tmp.path,
      );

      await syncSvc.testConnection(cfg);
      final report1 = await syncSvc.syncAll(
        cfg,
        localPreferencesSnapshot: {'fontSize': 18},
      );
      expect(report1.progressUploaded, 1);
      expect(report1.filesUploaded, 1);
      expect(report1.conflicts, isEmpty);
      expect(storage.containsKey('/InkBox/library_files/hash_sync_book_1.txt'), isTrue);

      // Simulate offline edits on BOTH local phone AND remote tablet -> triggers Conflict!
      final later = DateTime.now().millisecondsSinceEpoch + 5000;
      await db.updateSyncStateFields(
        'hash_sync_book_1',
        SyncStatesCompanion(
          locator: const drift.Value('ch:2;off:50'),
          progressRatio: const drift.Value(0.40),
          updatedAtMs: drift.Value(later),
          deviceId: const drift.Value('phone_a'),
        ),
      );
      storage['/InkBox/sync/progress_index.json'] = utf8.encode(
        jsonEncode({
          'schema_version': 1,
          'updated_at_ms': later + 1000,
          'records': {
            'hash_sync_book_1': {
              'content_hash': 'hash_sync_book_1',
              'media_kind': 'book',
              'locator': 'ch:3;off:300',
              'progress_ratio': 0.72,
              'updated_at_epoch_ms': later + 1000,
              'device_id': 'tablet_b',
              'device_name': 'Tablet B',
            },
          },
        }),
      );

      final report2 = await syncSvc.syncAll(cfg);
      expect(report2.conflicts.length, 1);
      expect(report2.conflicts.first.remoteDeviceName, 'Tablet B');

      // Resolve by adopting remote progress -> DB updates to 0.72!
      await syncSvc.resolveConflict(
        cfg,
        report2.conflicts.first,
        adoptRemote: true,
      );
      final updatedBook = await db.findBookByHash('hash_sync_book_1');
      expect(updatedBook!.progressRatio, closeTo(0.72, 0.001));

      // Create & list & restore compressed ZIP backup snapshot via Rust Core (including custom shelves & annotations)!
      await db.createShelf('书架1（历史）', 'book');
      final snapName = await syncSvc.createBackupSnapshot(cfg);
      final listed = await syncSvc.listBackupSnapshots(cfg);
      expect(listed.any((e) => e.name == snapName), isTrue);

      final freshDb = AppDatabase.inMemory();
      addTearDown(freshDb.close);
      final freshSyncSvc = WebDavSyncService(
        db: freshDb,
        rustCore: rust,
        tempDirOverride: tmp.path,
      );
      final restored = await freshSyncSvc.restoreBackupSnapshot(cfg, snapName);
      expect(restored, greaterThanOrEqualTo(1));
      final restoredShelves = await freshDb.getShelves('book');
      expect(
        restoredShelves.map((s) => s.name),
        containsAll(['默认书架', '书架1（历史）']),
      );
      final restoredAnns = await freshDb.getAnnotationsFor('hash_sync_book_1');
      expect(restoredAnns.length, 1);
      expect(restoredAnns.first.noteText, '本地批注');
    });
  });

  group('Bugfix Regressions: Import Pipeline & Duplicate Self-Healing', () {
    test('rejects 0-byte files, distinguishes identical-edge files, repairs missing file & supports overwrite', () async {
      final rust = _openTestRustCore();
      final db = AppDatabase.inMemory();
      final tmp = Directory.systemTemp.createTempSync('inkbox_import_fix_');
      addTearDown(() async {
        await db.close();
        if (tmp.existsSync()) tmp.deleteSync(recursive: true);
      });

      final svc = ImportService(
        db: db,
        platform: _FakePlatformBridge(),
        rustCore: rust,
        coversDirOverride: p.join(tmp.path, 'covers'),
      );

      // 1. 0-byte file must throw error instead of inserting a colliding empty hash
      final emptyTxt = File(p.join(tmp.path, 'empty.txt'))..writeAsBytesSync(const []);
      await expectLater(
        () => svc.importLocalPath(emptyTxt.path),
        throwsA(isA<StateError>()),
      );
      expect(await db.getAllBooks(), isEmpty);

      // 2. Two 200KB files with identical first/last 64KB but different middle bytes must BOTH import
      final bytesA = Uint8List(200 * 1024)..fillRange(0, 200 * 1024, 65);
      final bytesB = Uint8List.fromList(bytesA);
      bytesA[100 * 1024] = 66;
      bytesB[100 * 1024] = 67;
      final bookA = File(p.join(tmp.path, 'book_a.txt'))..writeAsBytesSync(bytesA);
      final bookB = File(p.join(tmp.path, 'book_b.txt'))..writeAsBytesSync(bytesB);

      final outA = await svc.importLocalPathDetailed(bookA.path);
      final outB = await svc.importLocalPathDetailed(bookB.path);
      expect(outA.status, 'book');
      expect(outB.status, 'book');
      expect((await db.getAllBooks()).length, 2);

      // 3. Re-importing bookA while file exists returns rich duplicate outcome
      final dupA = await svc.importLocalPathDetailed(bookA.path);
      expect(dupA.status, 'duplicate');
      expect(dupA.id, outA.id);
      expect(dupA.title, 'book_a');

      // 4. Force overwrite re-import succeeds and updates path
      final copyA = File(p.join(tmp.path, 'book_a_copy.txt'))..writeAsBytesSync(bytesA);
      final forced = await svc.importLocalPathDetailed(
        copyA.path,
        overwriteExisting: true,
      );
      expect(forced.status, 'book');
      expect(forced.repaired, isTrue);
      expect((await db.findBookById(outA.id!))!.filePath, copyA.path);

      // 5. If stored filePath is deleted from disk, re-importing auto-repairs instead of skipping
      copyA.deleteSync();
      final repaired = await svc.importLocalPathDetailed(bookA.path);
      expect(repaired.status, 'book');
      expect(repaired.repaired, isTrue);
      expect((await db.findBookById(outA.id!))!.filePath, bookA.path);
    });
  });

  group('TXT TOC Rules, Custom Categories & Import History Lifecycle', () {
    test('parses Legado JSON rules, uses imported rule on CRLF TXT, and validates regex', () async {
      final rust = _openTestRustCore();
      final db = AppDatabase.inMemory();
      final tmp = Directory.systemTemp.createTempSync('inkbox_toc_rules_');
      addTearDown(() async {
        await db.close();
        if (tmp.existsSync()) tmp.deleteSync(recursive: true);
      });

      // Rejects malformed JSON instead of turning broken lines into bogus rules
      expect(
        TocRulesCatalog.parseImportedContent('[{"name":"broken","rule":"^第'),
        isEmpty,
      );

      // Verify assets/txt_toc_rules.json, TocRulesCatalog.builtinRules, and Rust default_toc_rules stay 100% synced
      final assetRaw = File(p.join(Directory.current.path, 'assets', 'txt_toc_rules.json'))
          .readAsStringSync();
      final assetRules = TocRulesCatalog.parseImportedContent(assetRaw);
      final rustDefaults = rust.defaultTocRules();
      expect(assetRules.length, TocRulesCatalog.builtinRules.length);
      expect(rustDefaults.length, TocRulesCatalog.builtinRules.length);
      for (var i = 0; i < assetRules.length; i++) {
        expect(assetRules[i].rule, TocRulesCatalog.builtinRules[i].rule);
      }

      // Official GitHub Legado rule with variable-length lookbehind must compile & match via FFI
      final lbRes = rust.testTocRule(
        pattern: r'(?<=[\s ]{0,4})(?:[✦✧].{1,30}|楔子)[ ]{0,4}$',
        sampleText: '  ✦ 序幕\r\n正文\r\n楔子\r\n雪夜\r\n  ✧ 终章\r\n完结',
      );
      expect(lbRes['valid'], isTrue);
      expect(lbRes['match_count'], 3);

      // Import a custom Legado-format JSON rule (with Java \uXXXX unicode escape)
      const legadoJson = r'''
      [
        {
          "id": 99,
          "enable": true,
          "name": "自定义星标分章",
          "rule": "^[\\u3000\\s]*※\\s*\\d+\\s+[^\\r\\n]{1,20}$",
          "example": "※ 01 拂晓"
        }
      ]
      ''';
      final parsed = TocRulesCatalog.parseImportedContent(legadoJson);
      expect(parsed.length, 1);
      final insertedCount = await db.importTocRules(parsed);
      expect(insertedCount, 1);

      final allRules = await db.getTocRules();
      final customRule =
          allRules.firstWhere((r) => r.name == '自定义星标分章');

      // Test live validation via Rust FFI (both valid & invalid regex)
      final validTest = rust.testTocRule(
        pattern: customRule.rule,
        sampleText: '※ 01 拂晓\r\n正文第一段。\r\n※ 02 暮色\r\n正文第二段。',
      );
      expect(validTest['valid'], isTrue);
      expect(validTest['match_count'], 2);

      final invalidTest = rust.testTocRule(
        pattern: '[unclosed',
        sampleText: 'test',
      );
      expect(invalidTest['valid'], isFalse);

      // Write CRLF TXT novel matching the imported custom rule
      final txtFile = File(p.join(tmp.path, 'star_novel.txt'))
        ..writeAsStringSync(
          '※ 01 拂晓\r\n清晨的薄雾笼罩着小镇。\r\n※ 02 暮色\r\n夕阳沉入地平线。\r\n※ 03 星夜\r\n银河横贯天穹。',
        );
      final svc = ImportService(
        db: db,
        platform: _FakePlatformBridge(),
        rustCore: rust,
        coversDirOverride: p.join(tmp.path, 'covers'),
      );
      final outcome = await svc.importLocalPathDetailed(txtFile.path);
      expect(outcome.status, 'book');

      final book = (await db.findBookById(outcome.id!))!;
      final loader = BookContentLoader(rustCore: rust);
      final tocRes = await loader.loadChapterToc(
        book,
        tocRules: allRules,
        forcedRule: customRule,
      );
      expect(tocRes.chapters.length, 3);
      expect(tocRes.matchedRuleName, '自定义星标分章');
      expect(tocRes.chapters.first.title, '※ 01 拂晓');

      final ch1 = await loader.loadChapterContent(
        book,
        tocRes.chapters[1],
        const BookReaderSettings(),
      );
      expect(ch1.text, contains('夕阳沉入地平线'));
    });

    test('manages multi-shelves (book & manga) and Import History archive/restore/permanent delete', () async {
      final rust = _openTestRustCore();
      final db = AppDatabase.inMemory();
      final tmp = Directory.systemTemp.createTempSync('inkbox_hist_shelves_');
      addTearDown(() async {
        await db.close();
        if (tmp.existsSync()) tmp.deleteSync(recursive: true);
      });

      // Default shelves exist on creation and cannot be deleted
      final initialBookShelves = await db.getShelves('book');
      final initialMangaShelves = await db.getShelves('comic');
      expect(initialBookShelves.length, 1);
      expect(initialBookShelves.first.name, kDefaultBookShelfName);
      expect(initialBookShelves.first.isDefault, isTrue);
      expect(await db.deleteShelf(initialBookShelves.first.id, 'book'), isFalse);
      expect(initialMangaShelves.length, 1);
      expect(initialMangaShelves.first.name, kDefaultMangaShelfName);

      // Create multiple bookshelves & manga shelves, reject empty or duplicate names
      expect(await db.createShelf('   ', 'book'), isNull);
      final histShelf = await db.createShelf('书架1（历史）', 'book');
      final econShelf = await db.createShelf('书架2（经济）', 'book');
      expect(histShelf, isNotNull);
      expect(econShelf, isNotNull);
      expect(await db.createShelf('书架1（历史）', 'book'), isNull);

      final hotMangaShelf = await db.createShelf('漫画架1（热血）', 'comic');
      expect(hotMangaShelf, isNotNull);

      // Stage file under managed library_imports folder to test managed cleanup
      final managedDir = Directory(p.join(tmp.path, 'library_imports'))
        ..createSync(recursive: true);
      final bookFile = File(p.join(managedDir.path, 'demo_free.txt'))
        ..writeAsStringSync('第一章 开端\n内容段落。');

      final svc = ImportService(
        db: db,
        platform: _FakePlatformBridge(),
        rustCore: rust,
        coversDirOverride: p.join(tmp.path, 'covers'),
      );
      final imported = await svc.importLocalPathDetailed(
        bookFile.path,
        targetShelfId: histShelf!.id,
      );
      final bookId = imported.id!;
      expect((await db.findBookById(bookId))!.shelfId, histShelf.id);
      expect((await db.findBookById(bookId))!.shelfGroup, '在读');

      // Move book between shelves, rename shelf, delete non-default shelf -> falls back to default shelf
      await db.moveBooksToShelf([bookId], econShelf!.id);
      expect((await db.findBookById(bookId))!.shelfId, econShelf.id);
      expect(await db.renameShelf(econShelf.id, '书架2（宏观经济）', 'book'), isTrue);
      expect(await db.deleteShelf(econShelf.id, 'book'), isTrue);
      expect(
        (await db.findBookById(bookId))!.shelfId,
        initialBookShelves.first.id,
      );

      // Soft remove from bookshelf -> hidden from shelf, kept in Import History
      await db.archiveBooksByIds([bookId]);
      expect(await db.getAllBooks(), isEmpty);
      final history = await db.watchBookImportHistory().first;
      expect(history.length, 1);
      expect(history.first.isArchived, isTrue);

      // Quick restore from Import History -> back on bookshelf
      await db.restoreBookToShelf(bookId);
      expect((await db.getAllBooks()).length, 1);

      // Re-archive and re-import same file -> auto-restores instead of skipping duplicate
      await db.archiveBooksByIds([bookId]);
      final reimported = await svc.importLocalPathDetailed(bookFile.path);
      expect(reimported.status, 'book');
      expect(reimported.repaired, isTrue);
      expect((await db.getAllBooks()).length, 1);

      // Re-importing an archived book from a NEW managed copy must clean up old managed file
      await db.archiveBooksByIds([bookId]);
      final secondCopy = File(p.join(managedDir.path, 'demo_free_abc123.txt'))
        ..writeAsBytesSync(bookFile.readAsBytesSync());
      final restoredNewCopy = await svc.importLocalPathDetailed(secondCopy.path);
      expect(restoredNewCopy.status, 'book');
      expect(bookFile.existsSync(), isFalse);
      expect(secondCopy.existsSync(), isTrue);

      // Re-importing an archived manga preserves per-chapter reading progress!
      final comicDir = Directory(p.join(tmp.path, 'archive_manga'))..createSync();
      final tinyPng = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+ip1sAAAAASUVORK5CYII=',
      );
      File(p.join(comicDir.path, '01.png')).writeAsBytesSync(tinyPng);
      File(p.join(comicDir.path, '02.png')).writeAsBytesSync(tinyPng);
      final mOut = await svc.importLocalPathDetailed(comicDir.path);
      final mId = mOut.id!;
      final mCh0 = (await db.chaptersForManga(mId)).first;
      await db.updateMangaChapterProgress(
        mangaId: mId,
        chapterId: mCh0.id,
        lastReadPage: 1,
        pageCount: 2,
      );
      await db.archiveMangasByIds([mId]);
      final mRestored = await svc.importLocalPathDetailed(comicDir.path);
      expect(mRestored.status, 'manga');
      final mChAfter = (await db.chaptersForManga(mId)).first;
      expect(mChAfter.lastReadPage, 1);
      expect(mChAfter.isRead, isTrue);

      // Permanent delete removes DB record AND managed library_imports file
      await svc.permanentlyDeleteBooks([bookId]);
      expect(await db.watchBookImportHistory().first, isEmpty);
      expect(secondCopy.existsSync(), isFalse);
    });

    test('migrates V1 SQLite DB cleanly to V2, purges legacy demo entries, preserves real books, and seeds TOC rules', () async {
      final tmp = Directory.systemTemp.createTempSync('inkbox_v1_mig_');
      final dbFile = File(p.join(tmp.path, 'legacy_v1.sqlite'));
      addTearDown(() {
        if (tmp.existsSync()) tmp.deleteSync(recursive: true);
      });

      // Build an authentic V1 schema SQLite DB with legacy demo rows + a real user book
      final raw = sqlite3.sqlite3.open(dbFile.path);
      raw.execute('PRAGMA user_version = 1;');
      raw.execute('''
        CREATE TABLE books (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          content_hash TEXT NOT NULL UNIQUE,
          title TEXT NOT NULL,
          author TEXT NOT NULL DEFAULT '未知作者',
          format TEXT NOT NULL,
          file_path TEXT NOT NULL,
          cover_path TEXT NULL,
          shelf_group TEXT NOT NULL DEFAULT '在读',
          progress_ratio REAL NOT NULL DEFAULT 0.0,
          current_chapter_index INTEGER NOT NULL DEFAULT 0,
          current_char_offset INTEGER NOT NULL DEFAULT 0,
          current_chapter_title TEXT NOT NULL DEFAULT '准备阅读',
          reading_time_sec INTEGER NOT NULL DEFAULT 0,
          is_pinned INTEGER NOT NULL DEFAULT 0,
          cloud_file_synced INTEGER NOT NULL DEFAULT 0,
          added_at_ms INTEGER NOT NULL,
          last_read_at_ms INTEGER NOT NULL
        );
      ''');
      raw.execute('''
        CREATE TABLE mangas (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          content_hash TEXT NOT NULL UNIQUE,
          title TEXT NOT NULL,
          author TEXT NOT NULL DEFAULT '未知作者',
          format TEXT NOT NULL,
          root_path TEXT NOT NULL,
          cover_path TEXT NULL,
          shelf_group TEXT NOT NULL DEFAULT '追更中',
          unread_count INTEGER NOT NULL DEFAULT 0,
          total_chapters INTEGER NOT NULL DEFAULT 1,
          preferred_reading_mode TEXT NOT NULL DEFAULT 'rtl',
          auto_crop INTEGER NOT NULL DEFAULT 1,
          split_wide_pages INTEGER NOT NULL DEFAULT 1,
          is_pinned INTEGER NOT NULL DEFAULT 0,
          cloud_file_synced INTEGER NOT NULL DEFAULT 0,
          added_at_ms INTEGER NOT NULL,
          last_read_at_ms INTEGER NOT NULL
        );
      ''');
      raw.execute('''
        CREATE TABLE manga_chapters (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          manga_id INTEGER NOT NULL,
          title TEXT NOT NULL,
          chapter_index INTEGER NOT NULL,
          source_path TEXT NOT NULL,
          page_count INTEGER NOT NULL DEFAULT 0,
          last_read_page INTEGER NOT NULL DEFAULT 0,
          is_read INTEGER NOT NULL DEFAULT 0,
          updated_at_ms INTEGER NOT NULL
        );
      ''');
      raw.execute('''
        CREATE TABLE annotations (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          uuid TEXT NOT NULL UNIQUE,
          content_hash TEXT NOT NULL,
          media_kind TEXT NOT NULL,
          kind TEXT NOT NULL,
          chapter_index INTEGER NOT NULL DEFAULT 0,
          locator TEXT NOT NULL,
          excerpt TEXT NOT NULL DEFAULT '',
          note_text TEXT NOT NULL DEFAULT '',
          color_hex TEXT NOT NULL DEFAULT '#EED29A',
          is_deleted INTEGER NOT NULL DEFAULT 0,
          updated_at_ms INTEGER NOT NULL
        );
      ''');
      raw.execute('''
        CREATE TABLE sync_states (
          content_hash TEXT NOT NULL PRIMARY KEY,
          media_kind TEXT NOT NULL,
          locator TEXT NOT NULL,
          progress_ratio REAL NOT NULL DEFAULT 0.0,
          updated_at_ms INTEGER NOT NULL,
          last_synced_at_ms INTEGER NOT NULL DEFAULT 0,
          device_id TEXT NOT NULL,
          device_name TEXT NOT NULL
        );
      ''');
      raw.execute('''
        INSERT INTO books (content_hash, title, format, file_path, shelf_group, added_at_ms, last_read_at_ms)
        VALUES
          ('demo_book_threebody_2', '三体 II', 'EPUB', '/demo/threebody2.epub', '文学', 100, 100),
          ('user_real_hash_1', '用户的书', 'TXT', '/storage/user_novel.txt', '历史', 200, 200);
      ''');
      raw.execute('''
        INSERT INTO mangas (content_hash, title, format, root_path, shelf_group, added_at_ms, last_read_at_ms)
        VALUES
          ('demo_manga_vagabond', '浪客行', 'CBZ', '/demo/comics/vagabond', '追更中', 100, 100),
          ('user_manga_hash_1', '用户的漫画', 'CBZ', '/storage/user_comic.cbz', '追更中', 200, 200);
      ''');
      raw.execute('''
        INSERT INTO manga_chapters (manga_id, title, chapter_index, source_path, updated_at_ms)
        VALUES (1, '第08话', 0, '/demo/comics/vagabond/ch08.cbz', 100);
      ''');
      raw.execute('''
        INSERT INTO annotations (uuid, content_hash, media_kind, kind, locator, updated_at_ms)
        VALUES ('ann_demo_1', 'demo_book_threebody_2', 'book', 'bookmark', 'ch:0;off:0', 100);
      ''');
      raw.execute('''
        INSERT INTO sync_states (content_hash, media_kind, locator, updated_at_ms, device_id, device_name)
        VALUES ('demo_book_threebody_2', 'book', 'ch:0;off:0', 100, 'dev', 'Android');
      ''');
      raw.dispose();

      // Open with V3 AppDatabase -> triggers real onUpgrade(1 -> 3)
      final upgradedDb = AppDatabase(NativeDatabase(dbFile));
      addTearDown(upgradedDb.close);

      final books = await upgradedDb.getAllBooks(includeArchived: true);
      final mangas = await upgradedDb.getAllMangas(includeArchived: true);
      final tocRules = await upgradedDb.getTocRules();
      final bookShelves = await upgradedDb.getShelves('book');
      final anns = await upgradedDb.getAllAnnotations();
      final states = await upgradedDb.getAllSyncStates();

      expect(books.length, 1);
      expect(books.first.title, '用户的书');
      expect(books.first.isArchived, isFalse);
      expect(books.first.shelfGroup, '在读');
      final histShelf = bookShelves.firstWhere((s) => s.name == '历史');
      expect(books.first.shelfId, histShelf.id);
      expect(mangas.length, 1);
      expect(mangas.first.title, '用户的漫画');
      expect(mangas.first.shelfGroup, '在读');
      expect(anns, isEmpty);
      expect(states, isEmpty);
      expect(tocRules.length, greaterThanOrEqualTo(14));
    });

    test('migrates V2 SQLite DB with shelf_categories cleanly to V3 multi-shelves', () async {
      final tmp = Directory.systemTemp.createTempSync('inkbox_v2_mig_');
      final dbFile = File(p.join(tmp.path, 'legacy_v2.sqlite'));
      addTearDown(() {
        if (tmp.existsSync()) tmp.deleteSync(recursive: true);
      });

      final raw = sqlite3.sqlite3.open(dbFile.path);
      raw.execute('PRAGMA user_version = 2;');
      raw.execute('''
        CREATE TABLE books (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          content_hash TEXT NOT NULL UNIQUE,
          title TEXT NOT NULL,
          author TEXT NOT NULL DEFAULT '未知作者',
          format TEXT NOT NULL,
          file_path TEXT NOT NULL,
          cover_path TEXT NULL,
          shelf_group TEXT NOT NULL DEFAULT '在读',
          progress_ratio REAL NOT NULL DEFAULT 0.0,
          current_chapter_index INTEGER NOT NULL DEFAULT 0,
          current_char_offset INTEGER NOT NULL DEFAULT 0,
          current_chapter_title TEXT NOT NULL DEFAULT '准备阅读',
          reading_time_sec INTEGER NOT NULL DEFAULT 0,
          is_pinned INTEGER NOT NULL DEFAULT 0,
          cloud_file_synced INTEGER NOT NULL DEFAULT 0,
          is_archived INTEGER NOT NULL DEFAULT 0,
          toc_rule_id INTEGER NULL,
          forced_encoding TEXT NULL,
          added_at_ms INTEGER NOT NULL,
          last_read_at_ms INTEGER NOT NULL
        );
      ''');
      raw.execute('''
        CREATE TABLE mangas (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          content_hash TEXT NOT NULL UNIQUE,
          title TEXT NOT NULL,
          author TEXT NOT NULL DEFAULT '未知作者',
          format TEXT NOT NULL,
          root_path TEXT NOT NULL,
          cover_path TEXT NULL,
          shelf_group TEXT NOT NULL DEFAULT '在读',
          unread_count INTEGER NOT NULL DEFAULT 0,
          total_chapters INTEGER NOT NULL DEFAULT 1,
          preferred_reading_mode TEXT NOT NULL DEFAULT 'rtl',
          auto_crop INTEGER NOT NULL DEFAULT 1,
          split_wide_pages INTEGER NOT NULL DEFAULT 1,
          is_pinned INTEGER NOT NULL DEFAULT 0,
          cloud_file_synced INTEGER NOT NULL DEFAULT 0,
          is_archived INTEGER NOT NULL DEFAULT 0,
          added_at_ms INTEGER NOT NULL,
          last_read_at_ms INTEGER NOT NULL
        );
      ''');
      raw.execute('''
        CREATE TABLE manga_chapters (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          manga_id INTEGER NOT NULL,
          title TEXT NOT NULL,
          chapter_index INTEGER NOT NULL,
          source_path TEXT NOT NULL,
          page_count INTEGER NOT NULL DEFAULT 0,
          last_read_page INTEGER NOT NULL DEFAULT 0,
          is_read INTEGER NOT NULL DEFAULT 0,
          updated_at_ms INTEGER NOT NULL
        );
      ''');
      raw.execute('''
        CREATE TABLE annotations (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          uuid TEXT NOT NULL UNIQUE,
          content_hash TEXT NOT NULL,
          media_kind TEXT NOT NULL,
          kind TEXT NOT NULL,
          chapter_index INTEGER NOT NULL DEFAULT 0,
          locator TEXT NOT NULL,
          excerpt TEXT NOT NULL DEFAULT '',
          note_text TEXT NOT NULL DEFAULT '',
          color_hex TEXT NOT NULL DEFAULT '#EED29A',
          is_deleted INTEGER NOT NULL DEFAULT 0,
          updated_at_ms INTEGER NOT NULL
        );
      ''');
      raw.execute('''
        CREATE TABLE watched_folders (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          uri_or_path TEXT NOT NULL UNIQUE,
          display_name TEXT NOT NULL,
          default_kind TEXT NOT NULL DEFAULT 'auto',
          last_scanned_at_ms INTEGER NOT NULL DEFAULT 0
        );
      ''');
      raw.execute('''
        CREATE TABLE sync_states (
          content_hash TEXT NOT NULL PRIMARY KEY,
          media_kind TEXT NOT NULL,
          locator TEXT NOT NULL,
          progress_ratio REAL NOT NULL DEFAULT 0.0,
          updated_at_ms INTEGER NOT NULL,
          last_synced_at_ms INTEGER NOT NULL DEFAULT 0,
          device_id TEXT NOT NULL,
          device_name TEXT NOT NULL
        );
      ''');
      raw.execute('''
        CREATE TABLE shelf_categories (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          media_kind TEXT NOT NULL,
          sort_order INTEGER NOT NULL DEFAULT 0,
          created_at_ms INTEGER NOT NULL
        );
      ''');
      raw.execute('''
        CREATE TABLE toc_rules (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          rule TEXT NOT NULL,
          example TEXT NOT NULL DEFAULT '',
          enabled INTEGER NOT NULL DEFAULT 1,
          serial_number INTEGER NOT NULL DEFAULT 0,
          is_builtin INTEGER NOT NULL DEFAULT 0,
          created_at_ms INTEGER NOT NULL
        );
      ''');
      raw.execute('''
        INSERT INTO shelf_categories (name, media_kind, sort_order, created_at_ms)
        VALUES ('经济', 'book', 0, 100), ('空书架测试', 'book', 1, 101);
      ''');
      raw.execute('''
        INSERT INTO books (content_hash, title, format, file_path, shelf_group, progress_ratio, added_at_ms, last_read_at_ms)
        VALUES ('v2_book_econ', '国富论', 'EPUB', '/storage/econ.epub', '经济', 1.0, 200, 200);
      ''');
      raw.dispose();

      final upgradedDb = AppDatabase(NativeDatabase(dbFile));
      addTearDown(upgradedDb.close);

      final shelves = await upgradedDb.getShelves('book');
      expect(shelves.map((s) => s.name), containsAll(['默认书架', '经济', '空书架测试']));
      final econShelf = shelves.firstWhere((s) => s.name == '经济');
      final books = await upgradedDb.getAllBooks();
      expect(books.length, 1);
      expect(books.first.shelfId, econShelf.id);
      expect(books.first.shelfGroup, '已读完');

      final catTableLeft = await upgradedDb
          .customSelect(
            "SELECT 1 FROM sqlite_master WHERE type='table' AND name='shelf_categories'",
          )
          .get();
      expect(catTableLeft, isEmpty);
    });

    test('recovers cleanly from interrupted partial V2->V3 migration (duplicate shelf_id state)', () async {
      final tmp = Directory.systemTemp.createTempSync('inkbox_partial_mig_');
      final dbFile = File(p.join(tmp.path, 'partial_v3.sqlite'));
      addTearDown(() {
        if (tmp.existsSync()) tmp.deleteSync(recursive: true);
      });

      final raw = sqlite3.sqlite3.open(dbFile.path);
      raw.execute('PRAGMA user_version = 2;');
      raw.execute('''
        CREATE TABLE books (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          content_hash TEXT NOT NULL UNIQUE,
          title TEXT NOT NULL,
          author TEXT NOT NULL DEFAULT '未知作者',
          format TEXT NOT NULL,
          file_path TEXT NOT NULL,
          cover_path TEXT NULL,
          shelf_group TEXT NOT NULL DEFAULT '在读',
          progress_ratio REAL NOT NULL DEFAULT 0.0,
          current_chapter_index INTEGER NOT NULL DEFAULT 0,
          current_char_offset INTEGER NOT NULL DEFAULT 0,
          current_chapter_title TEXT NOT NULL DEFAULT '准备阅读',
          reading_time_sec INTEGER NOT NULL DEFAULT 0,
          is_pinned INTEGER NOT NULL DEFAULT 0,
          cloud_file_synced INTEGER NOT NULL DEFAULT 0,
          is_archived INTEGER NOT NULL DEFAULT 0,
          toc_rule_id INTEGER NULL,
          forced_encoding TEXT NULL,
          added_at_ms INTEGER NOT NULL,
          last_read_at_ms INTEGER NOT NULL,
          shelf_id INTEGER NULL
        );
      ''');
      raw.execute('''
        CREATE TABLE mangas (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          content_hash TEXT NOT NULL UNIQUE,
          title TEXT NOT NULL,
          author TEXT NOT NULL DEFAULT '未知作者',
          format TEXT NOT NULL,
          root_path TEXT NOT NULL,
          cover_path TEXT NULL,
          shelf_group TEXT NOT NULL DEFAULT '在读',
          unread_count INTEGER NOT NULL DEFAULT 0,
          total_chapters INTEGER NOT NULL DEFAULT 1,
          preferred_reading_mode TEXT NOT NULL DEFAULT 'rtl',
          auto_crop INTEGER NOT NULL DEFAULT 1,
          split_wide_pages INTEGER NOT NULL DEFAULT 1,
          is_pinned INTEGER NOT NULL DEFAULT 0,
          cloud_file_synced INTEGER NOT NULL DEFAULT 0,
          is_archived INTEGER NOT NULL DEFAULT 0,
          added_at_ms INTEGER NOT NULL,
          last_read_at_ms INTEGER NOT NULL,
          shelf_id INTEGER NULL
        );
      ''');
      raw.execute('''
        CREATE TABLE manga_chapters (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          manga_id INTEGER NOT NULL,
          title TEXT NOT NULL,
          chapter_index INTEGER NOT NULL,
          source_path TEXT NOT NULL,
          page_count INTEGER NOT NULL DEFAULT 0,
          last_read_page INTEGER NOT NULL DEFAULT 0,
          is_read INTEGER NOT NULL DEFAULT 0,
          updated_at_ms INTEGER NOT NULL
        );
      ''');
      raw.execute('''
        CREATE TABLE annotations (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          uuid TEXT NOT NULL UNIQUE,
          content_hash TEXT NOT NULL,
          media_kind TEXT NOT NULL,
          kind TEXT NOT NULL,
          chapter_index INTEGER NOT NULL DEFAULT 0,
          locator TEXT NOT NULL,
          excerpt TEXT NOT NULL DEFAULT '',
          note_text TEXT NOT NULL DEFAULT '',
          color_hex TEXT NOT NULL DEFAULT '#EED29A',
          is_deleted INTEGER NOT NULL DEFAULT 0,
          updated_at_ms INTEGER NOT NULL
        );
      ''');
      raw.execute('''
        CREATE TABLE watched_folders (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          uri_or_path TEXT NOT NULL UNIQUE,
          display_name TEXT NOT NULL,
          default_kind TEXT NOT NULL DEFAULT 'auto',
          last_scanned_at_ms INTEGER NOT NULL DEFAULT 0
        );
      ''');
      raw.execute('''
        CREATE TABLE sync_states (
          content_hash TEXT NOT NULL PRIMARY KEY,
          media_kind TEXT NOT NULL,
          locator TEXT NOT NULL,
          progress_ratio REAL NOT NULL DEFAULT 0.0,
          updated_at_ms INTEGER NOT NULL,
          last_synced_at_ms INTEGER NOT NULL DEFAULT 0,
          device_id TEXT NOT NULL,
          device_name TEXT NOT NULL
        );
      ''');
      raw.execute('''
        CREATE TABLE shelf_categories (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          media_kind TEXT NOT NULL,
          sort_order INTEGER NOT NULL DEFAULT 0,
          created_at_ms INTEGER NOT NULL,
          UNIQUE (name, media_kind)
        );
      ''');
      raw.execute('''
        CREATE TABLE toc_rules (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          rule TEXT NOT NULL,
          example TEXT NOT NULL DEFAULT '',
          enabled INTEGER NOT NULL DEFAULT 1,
          serial_number INTEGER NOT NULL DEFAULT 0,
          is_builtin INTEGER NOT NULL DEFAULT 0,
          created_at_ms INTEGER NOT NULL
        );
      ''');
      raw.execute('''
        CREATE TABLE shelves (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          media_kind TEXT NOT NULL,
          is_default INTEGER NOT NULL DEFAULT 0,
          sort_order INTEGER NOT NULL DEFAULT 0,
          created_at_ms INTEGER NOT NULL,
          UNIQUE (name, media_kind)
        );
      ''');
      raw.execute('''
        INSERT INTO shelves (id, name, media_kind, is_default, sort_order, created_at_ms)
        VALUES (1, '默认书架', 'book', 1, 0, 100);
      ''');
      raw.execute('''
        INSERT INTO books (id, content_hash, title, format, file_path, shelf_group, added_at_ms, last_read_at_ms, shelf_id)
        VALUES (6, 'hash_guanjuyipin', '官居一品', 'TXT', '/storage/guanjuyipin.txt', '在读', 200, 200, NULL);
      ''');
      raw.dispose();

      final upgradedDb = AppDatabase(NativeDatabase(dbFile));
      addTearDown(upgradedDb.close);

      final bookShelves = await upgradedDb.getShelves('book');
      final comicShelves = await upgradedDb.getShelves('comic');
      final books = await upgradedDb.getAllBooks();
      final userVersionRows =
          await upgradedDb.customSelect('PRAGMA user_version').get();
      final catTableLeft = await upgradedDb
          .customSelect(
            "SELECT 1 FROM sqlite_master WHERE type='table' AND name='shelf_categories'",
          )
          .get();

      expect(userVersionRows.single.data['user_version'], 3);
      expect(bookShelves.any((s) => s.isDefault && s.name == '默认书架'), isTrue);
      expect(comicShelves.any((s) => s.isDefault && s.name == '默认漫画架'), isTrue);
      expect(books.length, 1);
      expect(books.first.title, '官居一品');
      expect(
        books.first.shelfId,
        bookShelves.firstWhere((s) => s.isDefault).id,
      );
      expect(catTableLeft, isEmpty);
    });
  });
}
