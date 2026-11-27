import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:inkbox/data/db/app_database.dart';
import 'package:inkbox/features/settings/local_backup_service.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory temp;
  late AppDatabase source;
  late AppDatabase destination;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('inkbox_backup_test_');
    source = AppDatabase.inMemory();
    destination = AppDatabase.inMemory();
  });

  tearDown(() async {
    await source.close();
    await destination.close();
    await temp.delete(recursive: true);
  });

  test(
    'round trips library files, archived items, chapters, and notes',
    () async {
      final shelf = (await source.createShelf('历史', 'book'))!;
      final ruleId = await source.saveTocRule(name: '自定义', rule: r'^卷\d+$');
      final bookFile = File(p.join(temp.path, '书籍.txt'))
        ..writeAsStringSync('故事');
      final comicFolder = Directory(p.join(temp.path, '漫画'))..createSync();
      final chapterFolder = Directory(p.join(comicFolder.path, '第一话'))
        ..createSync();
      File(p.join(chapterFolder.path, '001.png')).writeAsBytesSync([1, 2, 3]);
      final cover = File(p.join(temp.path, '封面.png'))
        ..writeAsBytesSync([4, 5, 6]);
      await source.upsertBook(
        BooksCompanion.insert(
          contentHash: 'bookhash',
          title: '书籍',
          format: 'TXT',
          filePath: bookFile.path,
          coverPath: Value(cover.path),
          shelfId: Value(shelf.id),
          tocRuleId: Value(ruleId),
          isArchived: const Value(true),
          progressRatio: const Value(0.4),
          currentCharOffset: const Value(240),
          addedAtMs: 1,
          lastReadAtMs: 2,
        ),
      );
      final mangaId = await source.upsertManga(
        MangasCompanion.insert(
          contentHash: 'mangahash',
          title: '漫画',
          format: 'FOLDER',
          rootPath: comicFolder.path,
          addedAtMs: 1,
          lastReadAtMs: 2,
        ),
      );
      await source
          .into(source.mangaChapters)
          .insert(
            MangaChaptersCompanion.insert(
              mangaId: mangaId,
              title: '第一话',
              chapterIndex: 0,
              sourcePath: chapterFolder.path,
              lastReadPage: const Value(1),
              updatedAtMs: 2,
            ),
          );
      await source.upsertAnnotation(
        AnnotationsCompanion.insert(
          uuid: 'note',
          contentHash: 'bookhash',
          mediaKind: 'book',
          kind: 'note',
          locator: '240',
          noteText: const Value('笔记'),
          updatedAtMs: 2,
        ),
      );

      final backup = File(p.join(temp.path, 'backup.zip'));
      await LocalBackupService(source).exportTo(backup);
      final library = Directory(p.join(temp.path, 'restored'));
      final restore = LocalBackupService(destination);
      expect(await restore.importFrom(backup, libraryDirectory: library), (
        books: 1,
        comics: 1,
        skipped: 0,
      ));
      final book = (await destination.findBookByHash('bookhash'))!;
      final manga = (await destination.findMangaByHash('mangahash'))!;
      final chapter = (await destination.chaptersForManga(manga.id)).single;
      expect(book.isArchived, isTrue);
      expect(book.currentCharOffset, 240);
      expect(book.progressRatio, 0.4);
      expect(book.tocRuleId, isNotNull);
      expect((await destination.findTocRuleById(book.tocRuleId!))?.name, '自定义');
      expect(
        (await destination.getShelves('book'))
            .singleWhere((s) => s.id == book.shelfId)
            .name,
        '历史',
      );
      expect(await File(book.filePath).readAsString(), '故事');
      expect(await File(book.coverPath!).readAsBytes(), [4, 5, 6]);
      expect(p.isWithin(library.path, book.filePath), isTrue);
      expect(p.isWithin(manga.rootPath, chapter.sourcePath), isTrue);
      expect(chapter.lastReadPage, 1);
      expect(await File(p.join(chapter.sourcePath, '001.png')).readAsBytes(), [
        1,
        2,
        3,
      ]);
      expect((await destination.getAllAnnotations()).single.noteText, '笔记');
      expect(await restore.importFrom(backup, libraryDirectory: library), (
        books: 0,
        comics: 0,
        skipped: 2,
      ));
      expect(await library.list().length, 1);
    },
  );

  test('invalid media rolls back library changes', () async {
    final sourceFile = File(p.join(temp.path, 'Book.txt'))
      ..writeAsStringSync('text');
    await source.upsertBook(
      BooksCompanion.insert(
        contentHash: 'bookhash',
        title: 'Book',
        format: 'TXT',
        filePath: sourceFile.path,
        addedAtMs: 1,
        lastReadAtMs: 1,
      ),
    );
    final original = File(p.join(temp.path, 'original.zip'));
    await LocalBackupService(source).exportTo(original);
    final manifest = ZipDecoder()
        .decodeBytes(original.readAsBytesSync())
        .find('inkbox-library.json')!;
    final incomplete = File(p.join(temp.path, 'incomplete.zip'));
    final encoder = ZipFileEncoder()..create(incomplete.path);
    encoder.addArchiveFile(manifest);
    encoder.closeSync();

    final library = Directory(p.join(temp.path, 'restored'));
    await expectLater(
      LocalBackupService(destination)
          .importFrom(incomplete, libraryDirectory: library),
      throwsFormatException,
    );
    expect(await destination.findBookByHash('bookhash'), isNull);
    expect(await library.list().isEmpty, isTrue);
  });
}
