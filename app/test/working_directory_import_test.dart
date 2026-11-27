import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkbox/data/db/app_database.dart';
import 'package:inkbox/data/platform/library_storage.dart';
import 'package:inkbox/data/platform/platform_bridge.dart';
import 'package:inkbox/features/importer/import_service.dart';
import 'package:inkbox/features/manga_reader/manga_page_source.dart';
import 'package:path/path.dart' as p;

class _WorkingDirectory extends LibraryStorage {
  bool authorized = false;
  final stored = <String>[];
  final released = <String>[];

  @override
  bool get requiresWorkingDirectory => true;

  @override
  Future<bool> ensureWorkingDirectory() async => authorized;

  @override
  Future<Map<String, String>> store(String localPath) async {
    final uri = 'content://test/working/${p.basename(localPath)}';
    stored.add(localPath);
    return {p.absolute(localPath): uri};
  }

  @override
  Future<void> releaseTemp(String path) async => released.add(path);
}

class _ImportPicker extends MethodChannelPlatformBridge {
  _ImportPicker(this.book, this.comic);

  final String book;
  final String comic;
  int filePicks = 0;
  final staged = <String>[];

  @override
  Future<PickedDocumentsResult> pickDocumentsDetailed() async {
    filePicks++;
    return PickedDocumentsResult(paths: [book]);
  }

  @override
  Future<String> stageDocumentUri(String uri, {String? fileName}) async {
    staged.add(uri);
    return comic;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'direct and scanned imports require a working folder and save its URI',
    () async {
      final temp = await Directory.systemTemp.createTemp('inkbox-work-test-');
      final db = AppDatabase.inMemory();
      addTearDown(() async {
        await db.close();
        await temp.delete(recursive: true);
      });
      final book = await File(p.join(temp.path, 'Novel.txt'))
          .writeAsString('A novel');
      final comic = await File(p.join(temp.path, 'Comic.cbz'))
          .writeAsString('Comic fixture');
      final picker = _ImportPicker(book.path, comic.path);
      final storage = _WorkingDirectory();
      final service = ImportService(db: db, platform: picker, storage: storage);
      final selected = [
        ImportCandidate(
          uriOrPath: 'content://test/source/Comic.cbz',
          name: 'Comic.cbz',
          ext: 'CBZ',
          sizeBytes: 13,
          targetKind: 'comic',
          isSafUri: true,
        ),
      ];

      expect(
        (await service.pickAndImportDocuments(autoClassify: true)).isEmpty,
        isTrue,
      );
      expect(
        (await service.importSelectedCandidates(
          selected,
          autoClassify: true,
        )).isEmpty,
        isTrue,
      );
      expect(picker.filePicks, 0);
      expect(picker.staged, isEmpty);
      expect(storage.stored, isEmpty);

      storage.authorized = true;
      expect(
        (await service.pickAndImportDocuments(autoClassify: true))
            .booksImported,
        1,
      );
      expect(
        (await service.importSelectedCandidates(
          selected,
          autoClassify: true,
        )).mangasImported,
        1,
      );
      expect(picker.staged, [selected.single.uriOrPath]);
      expect(storage.stored, [book.path, comic.path]);
      expect(storage.released, [book.path, comic.path]);
      expect(
        (await db.getAllBooks()).single.filePath,
        'content://test/working/Novel.txt',
      );
      final importedComic = (await db.getAllMangas()).single;
      expect(importedComic.rootPath, 'content://test/working/Comic.cbz');
      expect(
        (await db.chaptersForManga(importedComic.id)).single.sourcePath,
        importedComic.rootPath,
      );
    },
  );

  test(
    'normalizes SAF copy keys and releases a manga opened after disposal',
    () async {
      final temp = await Directory.systemTemp.createTemp('inkbox-lease-test-');
      addTearDown(() => temp.delete(recursive: true));
      final pdf = await File(p.join(temp.path, 'manga.pdf'))
          .writeAsString('PDF');
      const document = 'content://test/document/manga.pdf';
      final openStarted = Completer<void>();
      final openResult = Completer<Map<String, String>>();
      final released = <String>[];
      const channel = MethodChannel('dev.inkbox/platform');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      messenger.setMockMethodCallHandler(channel, (call) async {
        switch (call.method) {
          case 'storeLibraryPath':
            expect(call.arguments['path'], p.normalize(temp.path));
            return {temp.path: document};
          case 'openLibraryDocument':
            openStarted.complete();
            return openResult.future;
          case 'releaseMediaTemp':
            released.add(call.arguments['path'] as String);
            return null;
        }
        throw UnsupportedError(call.method);
      });
      final storage = _AndroidDocumentStorage();
      expect(
        (await storage.store('${temp.path}${p.separator}'))[temp.path],
        document,
      );
      final source = MangaPageSource(sourcePath: document, storage: storage);
      final opening = source.open();
      await openStarted.future;
      await source.dispose();
      openResult.complete({document: pdf.path});
      await opening;
      expect(source.pageCount, 0);
      expect(released, [pdf.path]);
    },
  );

  test(
    'shares one PDF decode across simultaneous manga page consumers',
    () async {
      final temp = await Directory.systemTemp.createTemp('inkbox-pdf-test-');
      addTearDown(() => temp.delete(recursive: true));
      final pdf = await File(p.join(temp.path, 'manga.pdf'))
          .writeAsString('PDF');
      final platform = _PendingPdfRenderer();
      final source = MangaPageSource(sourcePath: pdf.path, platform: platform);
      await source.open();
      addTearDown(source.dispose);
      final first = source.loadPage(0, computeCrop: true);
      final second = source.loadPage(0, computeCrop: true);
      expect(platform.renderCalls, 1);
      platform.rendered.complete(Uint8List.fromList([1, 2, 3]));
      expect(await first, same(await second));
    },
  );
}

class _AndroidDocumentStorage extends LibraryStorage {
  @override
  bool get requiresWorkingDirectory => true;
}

class _PendingPdfRenderer extends MethodChannelPlatformBridge {
  final rendered = Completer<Uint8List?>();
  int renderCalls = 0;

  @override
  Future<int> getPdfPageCount(String path) async => 1;

  @override
  Future<Uint8List?> renderPdfPage(
    String path,
    int pageIndex, {
    double scale = 2.0,
  }) {
    renderCalls++;
    return rendered.future;
  }
}
