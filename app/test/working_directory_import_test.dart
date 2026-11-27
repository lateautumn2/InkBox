import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkbox/data/db/app_database.dart';
import 'package:inkbox/data/platform/library_storage.dart';
import 'package:inkbox/data/platform/platform_bridge.dart';
import 'package:inkbox/features/importer/import_service.dart';
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
}
