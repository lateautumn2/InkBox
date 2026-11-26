import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../features/toc_rules/toc_rules_parser.dart';

part 'app_database.g.dart';

/// Built-in status groups inside each shelf (custom categories are removed).
const List<String> kDefaultShelfGroups = ['所有', '在读', '已读完'];

const String kDefaultBookShelfName = '默认书架';
const String kDefaultMangaShelfName = '默认漫画架';

/// Books stored on the local bookshelf (EPUB, TXT, PDF, MOBI, AZW3, FB2, MD).
class Books extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get contentHash => text().unique()();
  TextColumn get title => text()();
  TextColumn get author => text().withDefault(const Constant('未知作者'))();
  TextColumn get format => text()(); // EPUB, TXT, PDF, MOBI, AZW3, FB2, MD
  TextColumn get filePath => text()();
  TextColumn get coverPath => text().nullable()();
  IntColumn get shelfId => integer().nullable()();
  TextColumn get shelfGroup => text().withDefault(const Constant('在读'))();
  RealColumn get progressRatio => real().withDefault(const Constant(0.0))();
  IntColumn get currentChapterIndex =>
      integer().withDefault(const Constant(0))();
  IntColumn get currentCharOffset => integer().withDefault(const Constant(0))();
  TextColumn get currentChapterTitle =>
      text().withDefault(const Constant('准备阅读'))();
  IntColumn get readingTimeSec => integer().withDefault(const Constant(0))();
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  BoolColumn get cloudFileSynced =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  IntColumn get tocRuleId => integer().nullable()();
  TextColumn get forcedEncoding => text().nullable()();
  IntColumn get addedAtMs => integer()();
  IntColumn get lastReadAtMs => integer()();
}

/// Manga / comic series stored on the manga shelf.
class Mangas extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get contentHash => text().unique()();
  TextColumn get title => text()();
  TextColumn get author => text().withDefault(const Constant('未知作者'))();
  TextColumn get format => text()(); // CBZ, CBR, CB7, ZIP, PDF, 文件夹
  TextColumn get rootPath => text()();
  TextColumn get coverPath => text().nullable()();
  IntColumn get shelfId => integer().nullable()();
  TextColumn get shelfGroup => text().withDefault(const Constant('在读'))();
  IntColumn get unreadCount => integer().withDefault(const Constant(0))();
  IntColumn get totalChapters => integer().withDefault(const Constant(1))();
  TextColumn get preferredReadingMode =>
      text().withDefault(const Constant('rtl'))(); // rtl, ltr, webtoon, dual
  BoolColumn get autoCrop => boolean().withDefault(const Constant(true))();
  BoolColumn get splitWidePages =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  BoolColumn get cloudFileSynced =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  IntColumn get addedAtMs => integer()();
  IntColumn get lastReadAtMs => integer()();
}

/// Individual chapters or volumes belonging to a manga series.
class MangaChapters extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get mangaId =>
      integer().references(Mangas, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text()();
  IntColumn get chapterIndex => integer()();
  TextColumn get sourcePath => text()();
  IntColumn get pageCount => integer().withDefault(const Constant(0))();
  IntColumn get lastReadPage => integer().withDefault(const Constant(0))();
  BoolColumn get isRead => boolean().withDefault(const Constant(false))();
  IntColumn get updatedAtMs => integer()();
}

/// Bookmarks, highlights, and reader notes synced via WebDAV Layer 1.
class Annotations extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  TextColumn get contentHash => text()();
  TextColumn get mediaKind => text()(); // book | comic
  TextColumn get kind => text()(); // bookmark | highlight | note
  IntColumn get chapterIndex => integer().withDefault(const Constant(0))();
  TextColumn get locator => text()();
  TextColumn get excerpt => text().withDefault(const Constant(''))();
  TextColumn get noteText => text().withDefault(const Constant(''))();
  TextColumn get colorHex => text().withDefault(const Constant('#EED29A'))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  IntColumn get updatedAtMs => integer()();
}

/// Persisted SAF / local directories monitored by the Smart Import Hub.
class WatchedFolders extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uriOrPath => text().unique()();
  TextColumn get displayName => text()();
  TextColumn get defaultKind =>
      text().withDefault(const Constant('auto'))(); // auto | book | comic
  IntColumn get lastScannedAtMs => integer().withDefault(const Constant(0))();
}

/// Layer 1 sync tracking state per book/manga for WebDAV conflict resolution.
class SyncStates extends Table {
  TextColumn get contentHash => text()();
  TextColumn get mediaKind => text()();
  TextColumn get locator => text()();
  RealColumn get progressRatio => real().withDefault(const Constant(0.0))();
  IntColumn get updatedAtMs => integer()();
  IntColumn get lastSyncedAtMs => integer().withDefault(const Constant(0))();
  TextColumn get deviceId => text()();
  TextColumn get deviceName => text()();

  @override
  Set<Column> get primaryKey => {contentHash};
}

/// User-manageable Bookshelves and Manga Shelves (e.g. 默认书架, 书架1（历史）, 书架2（经济）).
@DataClassName('Shelf')
class Shelves extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get mediaKind => text()(); // 'book' | 'comic'
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get createdAtMs => integer()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {name, mediaKind},
      ];
}

/// TXT chapter recognition regex rules (GitHub Legado-compatible + user imported).
class TocRules extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get rule => text()();
  TextColumn get example => text().withDefault(const Constant(''))();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  IntColumn get serialNumber => integer().withDefault(const Constant(0))();
  BoolColumn get isBuiltin => boolean().withDefault(const Constant(false))();
  IntColumn get createdAtMs => integer()();
}

@DriftDatabase(
  tables: [
    Books,
    Mangas,
    MangaChapters,
    Annotations,
    WatchedFolders,
    SyncStates,
    Shelves,
    TocRules,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  factory AppDatabase.inMemory() => AppDatabase(NativeDatabase.memory());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _seedDefaultShelves();
          await _seedBuiltinTocRules();
        },
        onUpgrade: (m, from, to) async {
          await transaction(() async {
            if (from < 2) {
              await _addColumnIfMissing(m, books, books.isArchived);
              await _addColumnIfMissing(m, books, books.tocRuleId);
              await _addColumnIfMissing(m, books, books.forcedEncoding);
              await _addColumnIfMissing(m, mangas, mangas.isArchived);
              await _createTableIfMissing(m, tocRules);
              // Purge any legacy pre-seeded demo entries and orphan annotations/sync states from V1.
              for (final tbl in const ['annotations', 'sync_states']) {
                if (await _hasTable(tbl)) {
                  await customStatement(
                    "DELETE FROM $tbl WHERE content_hash LIKE 'demo_%'",
                  );
                }
              }
              await customStatement(
                "DELETE FROM books WHERE content_hash LIKE 'demo_%' OR file_path LIKE '/demo/%'",
              );
              await customStatement(
                "DELETE FROM manga_chapters WHERE manga_id IN (SELECT id FROM mangas WHERE content_hash LIKE 'demo_%' OR root_path LIKE '/demo/%')",
              );
              await customStatement(
                "DELETE FROM mangas WHERE content_hash LIKE 'demo_%' OR root_path LIKE '/demo/%'",
              );
              await _seedBuiltinTocRules();
            }
            if (from < 3) {
              await _addColumnIfMissing(m, books, books.shelfId);
              await _addColumnIfMissing(m, mangas, mangas.shelfId);
              await _createTableIfMissing(m, shelves);
              await _seedDefaultShelves();

              final defBookShelf = await ensureDefaultShelf('book');
              final defComicShelf = await ensureDefaultShelf('comic');

              // Migrate any V2 shelf_categories rows into Shelves.
              if (await _hasTable('shelf_categories')) {
                final legacyCats = await customSelect(
                  'SELECT name, media_kind FROM shelf_categories ORDER BY sort_order ASC, created_at_ms ASC',
                ).get();
                for (final row in legacyCats) {
                  final rawName = (row.data['name'] as String? ?? '').trim();
                  final kind =
                      (row.data['media_kind'] as String? ?? 'book').trim();
                  if (rawName.isNotEmpty &&
                      !kDefaultShelfGroups.contains(rawName) &&
                      rawName != '追更中') {
                    await createShelf(
                      rawName,
                      kind == 'comic' ? 'comic' : 'book',
                    );
                  }
                }
              }

              // Also migrate any custom non-status shelf_group values on preserved books & mangas into real shelves.
              final bookGroups = await customSelect(
                "SELECT DISTINCT TRIM(shelf_group) AS g FROM books WHERE TRIM(shelf_group) NOT IN ('', '所有', '在读', '已读完')",
              ).get();
              for (final row in bookGroups) {
                final g = (row.data['g'] as String? ?? '').trim();
                if (g.isEmpty) continue;
                final shelf = await createShelf(g, 'book') ??
                    (await getShelves('book'))
                        .where((s) => s.name == g)
                        .firstOrNull;
                if (shelf != null) {
                  await customStatement(
                    "UPDATE books SET shelf_id = ?, shelf_group = CASE WHEN progress_ratio >= 0.99 THEN '已读完' ELSE '在读' END WHERE TRIM(shelf_group) = ?",
                    [shelf.id, g],
                  );
                }
              }

              final mangaGroups = await customSelect(
                "SELECT DISTINCT TRIM(shelf_group) AS g FROM mangas WHERE TRIM(shelf_group) NOT IN ('', '所有', '在读', '已读完', '追更中')",
              ).get();
              for (final row in mangaGroups) {
                final g = (row.data['g'] as String? ?? '').trim();
                if (g.isEmpty) continue;
                final shelf = await createShelf(g, 'comic') ??
                    (await getShelves('comic'))
                        .where((s) => s.name == g)
                        .firstOrNull;
                if (shelf != null) {
                  await customStatement(
                    "UPDATE mangas SET shelf_id = ?, shelf_group = '在读' WHERE TRIM(shelf_group) = ?",
                    [shelf.id, g],
                  );
                }
              }

              // Backfill default shelf IDs and normalize status groups strictly to 在读 / 已读完.
              await customStatement(
                'UPDATE books SET shelf_id = ? WHERE shelf_id IS NULL',
                [defBookShelf.id],
              );
              await customStatement(
                'UPDATE mangas SET shelf_id = ? WHERE shelf_id IS NULL',
                [defComicShelf.id],
              );
              await customStatement(
                "UPDATE books SET shelf_group = CASE WHEN progress_ratio >= 0.99 OR shelf_group = '已读完' THEN '已读完' ELSE '在读' END WHERE shelf_group NOT IN ('在读', '已读完')",
              );
              await customStatement(
                "UPDATE mangas SET shelf_group = CASE WHEN shelf_group = '已读完' THEN '已读完' ELSE '在读' END WHERE shelf_group NOT IN ('在读', '已读完')",
              );
              await customStatement('DROP TABLE IF EXISTS shelf_categories');
            }
          });
        },
        beforeOpen: (details) async {
          await _seedDefaultShelves();
        },
      );

  Future<bool> _hasTable(String tableName) async {
    final rows = await customSelect(
      "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
      variables: [Variable.withString(tableName)],
    ).get();
    return rows.isNotEmpty;
  }

  Future<bool> _hasColumn(String tableName, String columnName) async {
    final rows = await customSelect('PRAGMA table_info("$tableName")').get();
    return rows.any((row) => (row.data['name'] as String?) == columnName);
  }

  Future<void> _addColumnIfMissing(
    Migrator m,
    TableInfo table,
    GeneratedColumn column,
  ) async {
    if (!await _hasColumn(table.actualTableName, column.$name)) {
      await m.addColumn(table, column);
    }
  }

  Future<void> _createTableIfMissing(Migrator m, TableInfo table) async {
    if (!await _hasTable(table.actualTableName)) {
      await m.createTable(table);
    }
  }

  Future<void> _seedDefaultShelves() async {
    await ensureDefaultShelf('book');
    await ensureDefaultShelf('comic');
  }

  Future<void> _seedBuiltinTocRules() async {
    final existing = await select(tocRules).get();
    if (existing.isNotEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await batch((b) {
      b.insertAll(
        tocRules,
        TocRulesCatalog.builtinRules
            .map(
              (r) => TocRulesCompanion.insert(
                name: r.name,
                rule: r.rule,
                example: Value(r.example),
                enabled: Value(r.enabled),
                serialNumber: Value(r.serialNumber),
                isBuiltin: const Value(true),
                createdAtMs: now,
              ),
            )
            .toList(),
      );
    });
  }

  // --- Books CRUD ---

  /// Streams active books currently displayed on the Bookshelf (excludes archived history items).
  Stream<List<Book>> watchAllBooks() {
    return (select(books)
          ..where((t) => t.isArchived.equals(false))
          ..orderBy([
            (t) => OrderingTerm.desc(t.isPinned),
            (t) => OrderingTerm.desc(t.lastReadAtMs),
          ]))
        .watch();
  }

  /// Streams ALL imported books (both on-shelf and removed/archived) for Import History.
  Stream<List<Book>> watchBookImportHistory() {
    return (select(books)
          ..orderBy([
            (t) => OrderingTerm.desc(t.addedAtMs),
          ]))
        .watch();
  }

  Future<List<Book>> getAllBooks({bool includeArchived = false}) {
    final q = select(books);
    if (!includeArchived) {
      q.where((t) => t.isArchived.equals(false));
    }
    return q.get();
  }

  Future<Book?> findBookById(int id) =>
      (select(books)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<Book?> findBookByHash(String hash) =>
      (select(books)..where((t) => t.contentHash.equals(hash)))
          .getSingleOrNull();

  Future<int> upsertBook(BooksCompanion entry) => into(books).insert(
        entry,
        onConflict: DoUpdate((_) => entry, target: [books.contentHash]),
      );

  Future<void> updateBookProgress({
    required int id,
    required int chapterIndex,
    required int charOffset,
    required String chapterTitle,
    required double progressRatio,
    int readingTimeDeltaSec = 0,
  }) async {
    final existing = await findBookById(id);
    if (existing == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await (update(books)..where((t) => t.id.equals(id))).write(
      BooksCompanion(
        currentChapterIndex: Value(chapterIndex),
        currentCharOffset: Value(charOffset),
        currentChapterTitle: Value(chapterTitle),
        progressRatio: Value(progressRatio.clamp(0.0, 1.0)),
        readingTimeSec: Value(existing.readingTimeSec + readingTimeDeltaSec),
        lastReadAtMs: Value(now),
      ),
    );
    await upsertSyncState(
      SyncStatesCompanion.insert(
        contentHash: existing.contentHash,
        mediaKind: 'book',
        locator: 'ch:$chapterIndex;off:$charOffset',
        progressRatio: Value(progressRatio.clamp(0.0, 1.0)),
        updatedAtMs: now,
        deviceId: 'local_device',
        deviceName: Platform.operatingSystem,
      ),
    );
  }

  Future<void> updateBookMeta(
    int id, {
    String? title,
    String? author,
    int? shelfId,
    String? shelfGroup,
    bool? isPinned,
    String? coverPath,
    bool? cloudFileSynced,
    double? progressRatio,
    String? filePath,
    String? currentChapterTitle,
    int? lastReadAtMs,
    bool? isArchived,
    int? tocRuleId,
    bool clearTocRuleId = false,
    String? forcedEncoding,
    bool clearForcedEncoding = false,
  }) async {
    await (update(books)..where((t) => t.id.equals(id))).write(
      BooksCompanion(
        title: title != null ? Value(title) : const Value.absent(),
        author: author != null ? Value(author) : const Value.absent(),
        shelfId: shelfId != null ? Value(shelfId) : const Value.absent(),
        shelfGroup:
            shelfGroup != null ? Value(shelfGroup) : const Value.absent(),
        isPinned: isPinned != null ? Value(isPinned) : const Value.absent(),
        coverPath: coverPath != null ? Value(coverPath) : const Value.absent(),
        cloudFileSynced: cloudFileSynced != null
            ? Value(cloudFileSynced)
            : const Value.absent(),
        progressRatio:
            progressRatio != null ? Value(progressRatio) : const Value.absent(),
        filePath: filePath != null ? Value(filePath) : const Value.absent(),
        currentChapterTitle: currentChapterTitle != null
            ? Value(currentChapterTitle)
            : const Value.absent(),
        lastReadAtMs:
            lastReadAtMs != null ? Value(lastReadAtMs) : const Value.absent(),
        isArchived:
            isArchived != null ? Value(isArchived) : const Value.absent(),
        tocRuleId: clearTocRuleId
            ? const Value(null)
            : (tocRuleId != null ? Value(tocRuleId) : const Value.absent()),
        forcedEncoding: clearForcedEncoding
            ? const Value(null)
            : (forcedEncoding != null
                ? Value(forcedEncoding)
                : const Value.absent()),
      ),
    );
  }

  /// Soft-removes books from Bookshelf while preserving them in Import History.
  Future<void> archiveBooksByIds(Iterable<int> ids) async {
    if (ids.isEmpty) return;
    await (update(books)..where((t) => t.id.isIn(ids))).write(
      const BooksCompanion(
        isArchived: Value(true),
        isPinned: Value(false),
      ),
    );
  }

  /// Restores an archived book from Import History back onto the Bookshelf.
  Future<void> restoreBookToShelf(int id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (update(books)..where((t) => t.id.equals(id))).write(
      BooksCompanion(
        isArchived: const Value(false),
        lastReadAtMs: Value(now),
      ),
    );
  }

  /// Permanently deletes books and associated annotations/sync state from SQLite.
  Future<List<Book>> deleteBooksByIds(Iterable<int> ids) async {
    if (ids.isEmpty) return const [];
    final targets = await (select(books)..where((t) => t.id.isIn(ids))).get();
    final hashes = targets.map((b) => b.contentHash).toList();
    await transaction(() async {
      if (hashes.isNotEmpty) {
        await (delete(annotations)..where((t) => t.contentHash.isIn(hashes)))
            .go();
        await (delete(syncStates)..where((t) => t.contentHash.isIn(hashes)))
            .go();
      }
      await (delete(books)..where((t) => t.id.isIn(ids))).go();
    });
    return targets;
  }

  // --- Mangas & Chapters CRUD ---

  Stream<List<Manga>> watchAllMangas() {
    return (select(mangas)
          ..where((t) => t.isArchived.equals(false))
          ..orderBy([
            (t) => OrderingTerm.desc(t.isPinned),
            (t) => OrderingTerm.desc(t.lastReadAtMs),
          ]))
        .watch();
  }

  Stream<List<Manga>> watchMangaImportHistory() {
    return (select(mangas)
          ..orderBy([
            (t) => OrderingTerm.desc(t.addedAtMs),
          ]))
        .watch();
  }

  Future<List<Manga>> getAllMangas({bool includeArchived = false}) {
    final q = select(mangas);
    if (!includeArchived) {
      q.where((t) => t.isArchived.equals(false));
    }
    return q.get();
  }

  Future<Manga?> findMangaById(int id) =>
      (select(mangas)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<Manga?> findMangaByHash(String hash) =>
      (select(mangas)..where((t) => t.contentHash.equals(hash)))
          .getSingleOrNull();

  Future<int> upsertManga(MangasCompanion entry) => into(mangas).insert(
        entry,
        onConflict: DoUpdate((_) => entry, target: [mangas.contentHash]),
      );

  Future<void> updateMangaMeta(
    int id, {
    String? title,
    String? author,
    int? shelfId,
    String? shelfGroup,
    String? preferredReadingMode,
    bool? autoCrop,
    bool? splitWidePages,
    bool? isPinned,
    int? unreadCount,
    int? totalChapters,
    String? coverPath,
    bool? cloudFileSynced,
    int? lastReadAtMs,
    String? rootPath,
    bool? isArchived,
  }) async {
    await (update(mangas)..where((t) => t.id.equals(id))).write(
      MangasCompanion(
        title: title != null ? Value(title) : const Value.absent(),
        author: author != null ? Value(author) : const Value.absent(),
        shelfId: shelfId != null ? Value(shelfId) : const Value.absent(),
        shelfGroup:
            shelfGroup != null ? Value(shelfGroup) : const Value.absent(),
        preferredReadingMode: preferredReadingMode != null
            ? Value(preferredReadingMode)
            : const Value.absent(),
        autoCrop: autoCrop != null ? Value(autoCrop) : const Value.absent(),
        splitWidePages: splitWidePages != null
            ? Value(splitWidePages)
            : const Value.absent(),
        isPinned: isPinned != null ? Value(isPinned) : const Value.absent(),
        unreadCount:
            unreadCount != null ? Value(unreadCount) : const Value.absent(),
        totalChapters:
            totalChapters != null ? Value(totalChapters) : const Value.absent(),
        coverPath: coverPath != null ? Value(coverPath) : const Value.absent(),
        cloudFileSynced: cloudFileSynced != null
            ? Value(cloudFileSynced)
            : const Value.absent(),
        lastReadAtMs:
            lastReadAtMs != null ? Value(lastReadAtMs) : const Value.absent(),
        rootPath: rootPath != null ? Value(rootPath) : const Value.absent(),
        isArchived:
            isArchived != null ? Value(isArchived) : const Value.absent(),
      ),
    );
  }

  Future<void> archiveMangasByIds(Iterable<int> ids) async {
    if (ids.isEmpty) return;
    await (update(mangas)..where((t) => t.id.isIn(ids))).write(
      const MangasCompanion(
        isArchived: Value(true),
        isPinned: Value(false),
      ),
    );
  }

  Future<void> restoreMangaToShelf(int id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (update(mangas)..where((t) => t.id.equals(id))).write(
      MangasCompanion(
        isArchived: const Value(false),
        lastReadAtMs: Value(now),
      ),
    );
  }

  Future<List<Manga>> deleteMangasByIds(Iterable<int> ids) async {
    if (ids.isEmpty) return const [];
    final targets = await (select(mangas)..where((t) => t.id.isIn(ids))).get();
    final hashes = targets.map((m) => m.contentHash).toList();
    await transaction(() async {
      if (hashes.isNotEmpty) {
        await (delete(annotations)..where((t) => t.contentHash.isIn(hashes)))
            .go();
        await (delete(syncStates)..where((t) => t.contentHash.isIn(hashes)))
            .go();
      }
      await (delete(mangaChapters)..where((t) => t.mangaId.isIn(ids))).go();
      await (delete(mangas)..where((t) => t.id.isIn(ids))).go();
    });
    return targets;
  }

  Future<List<MangaChapter>> chaptersForManga(int mangaId) {
    return (select(mangaChapters)
          ..where((t) => t.mangaId.equals(mangaId))
          ..orderBy([(t) => OrderingTerm.asc(t.chapterIndex)]))
        .get();
  }

  Stream<List<MangaChapter>> watchChaptersForManga(int mangaId) {
    return (select(mangaChapters)
          ..where((t) => t.mangaId.equals(mangaId))
          ..orderBy([(t) => OrderingTerm.asc(t.chapterIndex)]))
        .watch();
  }

  Future<void> replaceMangaChapters(
    int mangaId,
    List<MangaChaptersCompanion> entries,
  ) async {
    await transaction(() async {
      await (delete(mangaChapters)..where((t) => t.mangaId.equals(mangaId)))
          .go();
      await batch((b) => b.insertAll(mangaChapters, entries));
    });
    await _recalculateMangaUnread(mangaId);
  }

  Future<void> updateMangaChapterProgress({
    required int mangaId,
    required int chapterId,
    required int lastReadPage,
    required int pageCount,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final completed = pageCount > 0 && lastReadPage >= pageCount - 1;
    await (update(mangaChapters)..where((t) => t.id.equals(chapterId))).write(
      MangaChaptersCompanion(
        lastReadPage: Value(lastReadPage),
        pageCount: Value(pageCount),
        isRead: Value(completed),
        updatedAtMs: Value(now),
      ),
    );
    await _recalculateMangaUnread(mangaId);
    final manga = await findMangaById(mangaId);
    if (manga != null) {
      await updateMangaMeta(mangaId, lastReadAtMs: now);
      await upsertSyncState(
        SyncStatesCompanion.insert(
          contentHash: manga.contentHash,
          mediaKind: 'comic',
          locator: 'ch:$chapterId;page:$lastReadPage',
          progressRatio: Value(
            pageCount > 0 ? ((lastReadPage + 1) / pageCount).clamp(0.0, 1.0) : 0,
          ),
          updatedAtMs: now,
          deviceId: 'local_device',
          deviceName: Platform.operatingSystem,
        ),
      );
    }
  }

  Future<void> markAllChaptersRead(int mangaId, bool isRead) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (update(mangaChapters)..where((t) => t.mangaId.equals(mangaId)))
        .write(
      MangaChaptersCompanion(
        isRead: Value(isRead),
        updatedAtMs: Value(now),
      ),
    );
    await _recalculateMangaUnread(mangaId);
  }

  Future<void> _recalculateMangaUnread(int mangaId) async {
    final all = await chaptersForManga(mangaId);
    final unread = all.where((c) => !c.isRead).length;
    await updateMangaMeta(
      mangaId,
      unreadCount: unread,
      totalChapters: all.length,
    );
  }

  // --- Multi-Bookshelf & Multi-MangaShelf CRUD ---

  static int resolveEffectiveShelfId(int? rawShelfId, List<Shelf> list) {
    if (list.isEmpty) return rawShelfId ?? 0;
    if (rawShelfId != null && list.any((s) => s.id == rawShelfId)) {
      return rawShelfId;
    }
    final def = list.where((s) => s.isDefault).firstOrNull ?? list.first;
    return def.id;
  }

  Stream<List<Shelf>> watchShelves(String mediaKind) {
    return (select(shelves)
          ..where((t) => t.mediaKind.equals(mediaKind))
          ..orderBy([
            (t) => OrderingTerm.desc(t.isDefault),
            (t) => OrderingTerm.asc(t.sortOrder),
            (t) => OrderingTerm.asc(t.createdAtMs),
          ]))
        .watch();
  }

  Future<List<Shelf>> getShelves(String mediaKind) {
    return (select(shelves)
          ..where((t) => t.mediaKind.equals(mediaKind))
          ..orderBy([
            (t) => OrderingTerm.desc(t.isDefault),
            (t) => OrderingTerm.asc(t.sortOrder),
            (t) => OrderingTerm.asc(t.createdAtMs),
          ]))
        .get();
  }

  Future<Shelf> ensureDefaultShelf(String mediaKind) async {
    final existing = await getShelves(mediaKind);
    final def = existing.where((s) => s.isDefault).firstOrNull;
    if (def != null) return def;
    if (existing.isNotEmpty) {
      await (update(shelves)..where((t) => t.id.equals(existing.first.id)))
          .write(const ShelvesCompanion(isDefault: Value(true)));
      return existing.first.copyWith(isDefault: true);
    }
    final fallbackName =
        mediaKind == 'comic' ? kDefaultMangaShelfName : kDefaultBookShelfName;
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = await into(shelves).insert(
      ShelvesCompanion.insert(
        name: fallbackName,
        mediaKind: mediaKind,
        isDefault: const Value(true),
        sortOrder: const Value(0),
        createdAtMs: now,
      ),
    );
    return Shelf(
      id: id,
      name: fallbackName,
      mediaKind: mediaKind,
      isDefault: true,
      sortOrder: 0,
      createdAtMs: now,
    );
  }

  Future<Shelf?> createShelf(String rawName, String mediaKind) async {
    final name = rawName.trim();
    if (name.isEmpty) return null;
    await ensureDefaultShelf(mediaKind);
    final dup = await (select(shelves)
          ..where(
              (t) => t.name.equals(name) & t.mediaKind.equals(mediaKind)))
        .getSingleOrNull();
    if (dup != null) return null;
    final cur = await getShelves(mediaKind);
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = await into(shelves).insert(
      ShelvesCompanion.insert(
        name: name,
        mediaKind: mediaKind,
        isDefault: const Value(false),
        sortOrder: Value(cur.length),
        createdAtMs: now,
      ),
    );
    return Shelf(
      id: id,
      name: name,
      mediaKind: mediaKind,
      isDefault: false,
      sortOrder: cur.length,
      createdAtMs: now,
    );
  }

  Future<bool> renameShelf(
    int id,
    String rawNewName,
    String mediaKind,
  ) async {
    final newName = rawNewName.trim();
    if (newName.isEmpty) return false;
    final old = await (select(shelves)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (old == null || old.name == newName) return false;
    final dup = await (select(shelves)
          ..where(
              (t) => t.name.equals(newName) & t.mediaKind.equals(mediaKind)))
        .getSingleOrNull();
    if (dup != null) return false;
    await (update(shelves)..where((t) => t.id.equals(id)))
        .write(ShelvesCompanion(name: Value(newName)));
    return true;
  }

  Future<bool> deleteShelf(int id, String mediaKind) async {
    final target = await (select(shelves)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (target == null || target.isDefault) return false;
    final def = await ensureDefaultShelf(mediaKind);
    if (def.id == id) return false;

    await transaction(() async {
      if (mediaKind == 'book') {
        await (update(books)..where((t) => t.shelfId.equals(id)))
            .write(BooksCompanion(shelfId: Value(def.id)));
      } else {
        await (update(mangas)..where((t) => t.shelfId.equals(id)))
            .write(MangasCompanion(shelfId: Value(def.id)));
      }
      await (delete(shelves)..where((t) => t.id.equals(id))).go();
    });
    return true;
  }

  Future<void> moveBooksToShelf(Iterable<int> ids, int targetShelfId) async {
    if (ids.isEmpty) return;
    await (update(books)..where((t) => t.id.isIn(ids)))
        .write(BooksCompanion(shelfId: Value(targetShelfId)));
  }

  Future<void> moveMangasToShelf(Iterable<int> ids, int targetShelfId) async {
    if (ids.isEmpty) return;
    await (update(mangas)..where((t) => t.id.isIn(ids)))
        .write(MangasCompanion(shelfId: Value(targetShelfId)));
  }

  // --- TXT TOC Rules CRUD ---

  Stream<List<TocRule>> watchTocRules() {
    return (select(tocRules)
          ..orderBy([
            (t) => OrderingTerm.asc(t.serialNumber),
            (t) => OrderingTerm.asc(t.id),
          ]))
        .watch();
  }

  Future<List<TocRule>> getTocRules() {
    return (select(tocRules)
          ..orderBy([
            (t) => OrderingTerm.asc(t.serialNumber),
            (t) => OrderingTerm.asc(t.id),
          ]))
        .get();
  }

  Future<TocRule?> findTocRuleById(int id) =>
      (select(tocRules)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> saveTocRule({
    int? id,
    required String name,
    required String rule,
    String example = '',
    bool enabled = true,
    int? serialNumber,
    bool isBuiltin = false,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final cleanRule = rule.replaceAll(RegExp(r'^[\r\n]+|[\r\n]+$'), '');
    if (id != null) {
      await (update(tocRules)..where((t) => t.id.equals(id))).write(
        TocRulesCompanion(
          name: Value(name.trim()),
          rule: Value(cleanRule),
          example: Value(example.trim()),
          enabled: Value(enabled),
          serialNumber: serialNumber != null
              ? Value(serialNumber)
              : const Value.absent(),
        ),
      );
      return id;
    }
    final cur = await getTocRules();
    return into(tocRules).insert(
      TocRulesCompanion.insert(
        name: name.trim(),
        rule: cleanRule,
        example: Value(example.trim()),
        enabled: Value(enabled),
        serialNumber: Value(serialNumber ?? (cur.length + 1)),
        isBuiltin: Value(isBuiltin),
        createdAtMs: now,
      ),
    );
  }

  Future<int> importTocRules(List<ParsedTocRule> incoming) async {
    if (incoming.isEmpty) return 0;
    final existing = await getTocRules();
    final existingByRule = {for (final r in existing) r.rule: r};
    final now = DateTime.now().millisecondsSinceEpoch;
    var count = 0;

    await transaction(() async {
      var nextSerial = existing.length + 1;
      for (final item in incoming) {
        final pat = item.rule.replaceAll(RegExp(r'^[\r\n]+|[\r\n]+$'), '');
        if (pat.trim().isEmpty) continue;
        final dup = existingByRule[pat];
        if (dup != null) {
          await (update(tocRules)..where((t) => t.id.equals(dup.id))).write(
            TocRulesCompanion(
              name: Value(item.name.trim()),
              example: item.example.trim().isNotEmpty
                  ? Value(item.example.trim())
                  : const Value.absent(),
              enabled: Value(item.enabled),
            ),
          );
          count++;
        } else {
          await into(tocRules).insert(
            TocRulesCompanion.insert(
              name: item.name.trim(),
              rule: pat,
              example: Value(item.example.trim()),
              enabled: Value(item.enabled),
              serialNumber: Value(nextSerial++),
              isBuiltin: Value(item.isBuiltin),
              createdAtMs: now,
            ),
          );
          count++;
        }
      }
    });
    return count;
  }

  Future<void> toggleTocRule(int id, bool enabled) async {
    await (update(tocRules)..where((t) => t.id.equals(id)))
        .write(TocRulesCompanion(enabled: Value(enabled)));
  }

  Future<void> deleteTocRule(int id) async {
    await transaction(() async {
      await (update(books)..where((t) => t.tocRuleId.equals(id)))
          .write(const BooksCompanion(tocRuleId: Value(null)));
      await (delete(tocRules)..where((t) => t.id.equals(id))).go();
    });
  }

  Future<int> restoreDefaultTocRules() async {
    return importTocRules(TocRulesCatalog.builtinRules);
  }

  // --- Annotations (Bookmarks / Highlights / Notes) ---

  Stream<List<Annotation>> watchAnnotationsFor(String contentHash) {
    return (select(annotations)
          ..where((t) =>
              t.contentHash.equals(contentHash) & t.isDeleted.equals(false))
          ..orderBy([
            (t) => OrderingTerm.asc(t.chapterIndex),
            (t) => OrderingTerm.desc(t.updatedAtMs),
          ]))
        .watch();
  }

  Future<List<Annotation>> getAnnotationsFor(String contentHash) {
    return (select(annotations)
          ..where((t) =>
              t.contentHash.equals(contentHash) & t.isDeleted.equals(false))
          ..orderBy([
            (t) => OrderingTerm.asc(t.chapterIndex),
            (t) => OrderingTerm.desc(t.updatedAtMs),
          ]))
        .get();
  }

  Future<List<Annotation>> getAllAnnotations() => select(annotations).get();

  Future<int> upsertAnnotation(AnnotationsCompanion entry) =>
      into(annotations).insert(
        entry,
        onConflict: DoUpdate((_) => entry, target: [annotations.uuid]),
      );

  Future<void> softDeleteAnnotation(String uuid) async {
    await (update(annotations)..where((t) => t.uuid.equals(uuid))).write(
      AnnotationsCompanion(
        isDeleted: const Value(true),
        updatedAtMs: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  // --- Watched Folders ---

  Stream<List<WatchedFolder>> watchWatchedFolders() =>
      select(watchedFolders).watch();

  Future<List<WatchedFolder>> getWatchedFolders() =>
      select(watchedFolders).get();

  Future<int> upsertWatchedFolder(WatchedFoldersCompanion entry) =>
      into(watchedFolders).insert(
        entry,
        onConflict: DoUpdate((_) => entry, target: [watchedFolders.uriOrPath]),
      );

  Future<void> deleteWatchedFolder(int id) =>
      (delete(watchedFolders)..where((t) => t.id.equals(id))).go();

  // --- WebDAV Sync States ---

  Future<List<SyncState>> getAllSyncStates() => select(syncStates).get();

  Future<SyncState?> getSyncState(String contentHash) =>
      (select(syncStates)..where((t) => t.contentHash.equals(contentHash)))
          .getSingleOrNull();

  Future<void> upsertSyncState(SyncStatesCompanion entry) =>
      into(syncStates).insertOnConflictUpdate(entry);

  Future<void> markSyncStateSynced(String contentHash, int syncedAtMs) async {
    await (update(syncStates)..where((t) => t.contentHash.equals(contentHash)))
        .write(SyncStatesCompanion(lastSyncedAtMs: Value(syncedAtMs)));
  }

  Future<void> updateSyncStateFields(
    String contentHash,
    SyncStatesCompanion companion,
  ) async {
    await (update(syncStates)..where((t) => t.contentHash.equals(contentHash)))
        .write(companion);
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'inkbox_library.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
