import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../data/db/app_database.dart';
import '../../data/ffi/rust_core_bridge.dart';
import '../../data/platform/library_storage.dart';
import '../../data/platform/platform_bridge.dart';

class ImportCandidate {
  ImportCandidate({
    required this.uriOrPath,
    required this.name,
    required this.ext,
    required this.sizeBytes,
    required this.targetKind, // 'book' | 'comic'
    this.isSafUri = false,
    this.selected = true,
  });

  final String uriOrPath;
  final String name;
  final String ext;
  final int sizeBytes;
  String targetKind;
  final bool isSafUri;
  bool selected;

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class ImportFileOutcome {
  const ImportFileOutcome({
    required this.status, // 'book' | 'manga' | 'duplicate'
    required this.kind, // 'book' | 'comic'
    required this.title,
    required this.localPath,
    this.id,
    this.shelfGroup = '在读',
    this.repaired = false,
  });

  final String status;
  final String kind;
  final String title;
  final String localPath;
  final int? id;
  final String shelfGroup;
  final bool repaired;
}

class ImportBatchResult {
  const ImportBatchResult({
    required this.booksImported,
    required this.mangasImported,
    required this.skippedDuplicates,
    required this.errors,
    this.importedItems = const [],
    this.duplicateItems = const [],
  });

  final int booksImported;
  final int mangasImported;
  final int skippedDuplicates;
  final List<String> errors;
  final List<ImportFileOutcome> importedItems;
  final List<ImportFileOutcome> duplicateItems;

  static const empty = ImportBatchResult(
    booksImported: 0,
    mangasImported: 0,
    skippedDuplicates: 0,
    errors: [],
  );

  bool get isEmpty =>
      booksImported == 0 &&
      mangasImported == 0 &&
      skippedDuplicates == 0 &&
      errors.isEmpty;
}

class ImportService {
  ImportService({
    required this.db,
    required this.platform,
    LibraryStorage? storage,
    this.rustCore,
    this.coversDirOverride,
  }) : storage = storage ?? LibraryStorage();

  final AppDatabase db;
  final PlatformBridge platform;
  final LibraryStorage storage;
  final RustCoreBridge? rustCore;
  final String? coversDirOverride;

  static const bookExtensions = {'epub', 'txt', 'pdf', 'mobi', 'azw3', 'fb2', 'md'};
  static const comicExtensions = {'cbz', 'zip', 'cbr', 'rar', 'cb7', '7z'};

  String classifyExtension(String pathOrName, {bool isDirectory = false}) {
    if (isDirectory) return 'comic';
    if (rustCore != null) {
      try {
        final kind = rustCore!.classifyPath(pathOrName);
        if (kind == 'Book') return 'book';
        if (kind == 'Comic') return 'comic';
      } catch (_) {}
    }
    final ext = p.extension(pathOrName).replaceFirst('.', '').toLowerCase();
    if (comicExtensions.contains(ext)) return 'comic';
    if (bookExtensions.contains(ext)) return 'book';
    return 'unknown';
  }

  Future<String> _computeFingerprint(String localPath) async {
    final entity = FileSystemEntity.typeSync(localPath);
    if (entity == FileSystemEntityType.notFound) {
      throw FileSystemException('ERR_FILE_NOT_FOUND', localPath);
    }
    if (entity == FileSystemEntityType.directory) {
      final children = Directory(localPath)
          .listSync()
          .map((e) => p.basename(e.path))
          .toList()
        ..sort();
      return sha256
          .convert(utf8.encode('dir:${p.basename(localPath)}:${children.join('|')}'))
          .toString();
    }

    final file = File(localPath);
    final stat = await file.stat();
    if (stat.size <= 0) {
      throw StateError('ERR_FILE_EMPTY');
    }

    if (rustCore != null) {
      try {
        return rustCore!.computeFastFingerprint(localPath);
      } catch (_) {}
    }

    // Pure-Dart fallback matching rust_core::importer::compute_fast_fingerprint byte-for-byte.
    const chunk = 64 * 1024;
    final lenBytes = ByteData(8)
      ..setUint32(0, stat.size & 0xFFFFFFFF, Endian.little)
      ..setUint32(4, (stat.size >> 32) & 0xFFFFFFFF, Endian.little);
    final builder = BytesBuilder(copy: false)..add(lenBytes.buffer.asUint8List());

    final raf = await file.open();
    try {
      builder.add(await raf.read(chunk));
      if (stat.size > chunk * 2) {
        final midStart = (stat.size ~/ 2) - (chunk ~/ 2);
        await raf.setPosition(midStart > 0 ? midStart : 0);
        builder.add(await raf.read(chunk));
      }
      if (stat.size > chunk) {
        final tailOffset = stat.size - chunk;
        await raf.setPosition(tailOffset > 0 ? tailOffset : 0);
        builder.add(await raf.read(chunk));
      }
      return sha256.convert(builder.takeBytes()).toString();
    } finally {
      await raf.close();
    }
  }

  Future<String> _coversDirectory() async {
    if (coversDirOverride != null) {
      await Directory(coversDirOverride!).create(recursive: true);
      return coversDirOverride!;
    }
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'covers'));
    await dir.create(recursive: true);
    return dir.path;
  }

  Future<String?> _tryExtractCover(
    String localPath,
    String format,
    String hash,
  ) async {
    if (rustCore == null) return null;
    try {
      final coversDir = await _coversDirectory();
      final outPath = p.join(coversDir, '$hash.jpg');
      final ok = rustCore!.extractCoverThumbnail(
        sourcePath: localPath,
        format: format.toLowerCase(),
        outputJpgPath: outPath,
      );
      return ok && File(outPath).existsSync() ? outPath : null;
    } catch (_) {
      return null;
    }
  }

  /// Safely deletes app-managed copies (under `library_imports` or `covers`) without
  /// touching user-owned files outside InkBox's managed sandbox.
  static void cleanupManagedFileIfOwned(String? filePath) {
    if (filePath == null || filePath.trim().isEmpty) return;
    final normalized = p.normalize(filePath).replaceAll('\\', '/');
    final isManaged = normalized.contains('/library_imports/') ||
        normalized.contains('/covers/');
    if (!isManaged) return;
    try {
      final file = File(filePath);
      if (file.existsSync()) file.deleteSync();
    } catch (_) {}
  }

  Future<void> _deleteMedia(String path) async {
    if (LibraryStorage.isDocument(path)) {
      if (await db.hasMediaReference(path)) return;
      await storage.delete(path);
    } else {
      cleanupManagedFileIfOwned(path);
    }
  }

  /// Permanently removes books from DB & Import History and deletes managed cached copies.
  Future<void> permanentlyDeleteBooks(Iterable<int> ids) async {
    final deleted = await db.deleteBooksByIds(ids);
    for (final book in deleted) {
      await _deleteMedia(book.filePath);
      cleanupManagedFileIfOwned(book.coverPath);
    }
  }

  /// Permanently removes mangas from DB & Import History and deletes managed cached copies.
  Future<void> permanentlyDeleteMangas(Iterable<int> ids) async {
    final chapterPaths = <String>{};
    for (final id in ids) {
      final chs = await db.chaptersForManga(id);
      for (final c in chs) {
        chapterPaths.add(c.sourcePath);
      }
    }
    final deleted = await db.deleteMangasByIds(ids);
    for (final manga in deleted) {
      await _deleteMedia(manga.rootPath);
      chapterPaths.remove(manga.rootPath);
      cleanupManagedFileIfOwned(manga.coverPath);
    }
    for (final chPath in chapterPaths) {
      await _deleteMedia(chPath);
    }
  }

  static String _cleanDisplayStem(String rawStem) {
    final cleaned = rawStem.replaceFirst(RegExp(r'_[0-9a-f]{6}$'), '').trim();
    return cleaned.isNotEmpty ? cleaned : rawStem.trim();
  }

  static String _nonEmptyOr(dynamic candidate, String fallback) {
    if (candidate is String && candidate.trim().isNotEmpty) {
      return candidate.trim();
    }
    return fallback;
  }

  Future<List<Map<String, dynamic>>> _loadEnabledRustTocRules() async {
    final rules = await db.getTocRules();
    return rules
        .map(
          (r) => {
            'id': r.id,
            'name': r.name,
            'rule': r.rule,
            'example': r.example,
            'enable': r.enabled,
            'serial_number': r.serialNumber,
          },
        )
        .toList();
  }

  /// Imports a single local file or directory into Bookshelf or MangaShelf.
  /// Returns `'book'`, `'manga'`, or `'duplicate'`.
  Future<String> importLocalPath(
    String localPath, {
    String? forceKind,
    bool overwriteExisting = false,
    int? targetShelfId,
  }) async {
    final outcome = await importLocalPathDetailed(
      localPath,
      forceKind: forceKind,
      overwriteExisting: overwriteExisting,
      targetShelfId: targetShelfId,
    );
    return outcome.status;
  }

  /// Detailed version returning exact book/manga ID, title, and duplicate details.
  Future<ImportFileOutcome> importLocalPathDetailed(
    String localPath, {
    String? forceKind,
    bool overwriteExisting = false,
    int? targetShelfId,
  }) async {
    final isDir = FileSystemEntity.isDirectorySync(localPath);
    final kind = forceKind ?? classifyExtension(localPath, isDirectory: isDir);
    if (kind == 'unknown') {
      throw UnsupportedError('ERR_UNSUPPORTED_TYPE: ${p.basename(localPath)}');
    }
    final hash = await _computeFingerprint(localPath);
    final replacedPaths = <String>{};
    Map<String, String>? storedPaths;
    Future<String> storeMedia() async {
      final paths = await storage.store(localPath);
      storedPaths = paths;
      return paths[p.absolute(localPath)]!;
    }

    final ImportFileOutcome result;
    try {
      result = await db.transaction(() => _updateLibrary(
        localPath,
        hash: hash,
        kind: kind,
        isDir: isDir,
        overwriteExisting: overwriteExisting,
        targetShelfId: targetShelfId,
        storeMedia: storeMedia,
        storedChapterPath: (path) => storage.requiresWorkingDirectory
            ? storedPaths![p.absolute(path)]!
            : path,
        replacedPaths: replacedPaths,
      ));
    } catch (_) {
      final stored = storedPaths?[p.absolute(localPath)];
      if (stored != null && LibraryStorage.isDocument(stored)) {
        await storage.delete(stored);
      }
      rethrow;
    }
    for (final path in replacedPaths) {
      await _deleteMedia(path);
    }
    return result;
  }

  Future<ImportFileOutcome> _updateLibrary(
    String localPath, {
    required String hash,
    required String kind,
    required bool isDir,
    required bool overwriteExisting,
    required int? targetShelfId,
    required Future<String> Function() storeMedia,
    required String Function(String path) storedChapterPath,
    required Set<String> replacedPaths,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final stem = _cleanDisplayStem(p.basenameWithoutExtension(localPath));
    final rawExt = isDir
        ? 'FOLDER'
        : p.extension(localPath).replaceFirst('.', '').toUpperCase();
    final ext = rawExt.isEmpty ? 'TXT' : rawExt;

    if (kind == 'book') {
      final dup = await db.findBookByHash(hash);
      final existingBroken = dup != null && !await storage.exists(dup.filePath);
      final wasArchived = dup != null && dup.isArchived;

      if (dup != null && !overwriteExisting && !existingBroken && !wasArchived) {
        return ImportFileOutcome(
          status: 'duplicate',
          kind: 'book',
          id: dup.id,
          title: dup.title.trim().isNotEmpty ? dup.title : stem,
          shelfGroup: dup.shelfGroup,
          localPath: localPath,
        );
      }

      var title = stem.isNotEmpty ? stem : '未命名书籍';
      var author = '未知作者';
      var firstChapter = '准备阅读';

      if (rustCore != null) {
        try {
          if (ext == 'EPUB') {
            final meta = rustCore!.parseEpubMetadata(localPath);
            title = _nonEmptyOr(meta['title'], title);
            author = _nonEmptyOr(meta['author'], author);
            final chs = meta['chapters'] as List<dynamic>? ?? const [];
            if (chs.isNotEmpty) {
              firstChapter =
                  _nonEmptyOr((chs.first as Map)['title'], firstChapter);
            }
          } else if (ext == 'TXT') {
            final tocRules = await _loadEnabledRustTocRules();
            final idx = rustCore!.indexTxtWithRules(
              path: localPath,
              rules: tocRules,
            );
            final chs = idx['chapters'] as List<dynamic>? ?? const [];
            if (chs.isNotEmpty) {
              firstChapter =
                  _nonEmptyOr((chs.first as Map)['title'], firstChapter);
            }
          } else if (ext == 'PDF') {
            final meta = rustCore!.parsePdfMetadata(localPath);
            title = _nonEmptyOr(meta['title'], title);
            author = _nonEmptyOr(meta['author'], author);
            final chs = meta['chapters'] as List<dynamic>? ?? const [];
            if (chs.isNotEmpty) {
              firstChapter =
                  _nonEmptyOr((chs.first as Map)['title'], firstChapter);
            }
          } else if (ext == 'MOBI' || ext == 'AZW3') {
            final meta = rustCore!.parseMobiMetadata(localPath);
            title = _nonEmptyOr(meta['title'], title);
            author = _nonEmptyOr(meta['author'], author);
          } else if (ext == 'FB2' || ext == 'MD') {
            final meta = rustCore!.parseStructuredBook(localPath, ext.toLowerCase());
            title = _nonEmptyOr(meta['title'], title);
            author = _nonEmptyOr(meta['author'], author);
          }
        } catch (_) {
          // Graceful fallback to filename metadata if file has non-standard headers.
        }
      }

      final defaultShelf = await db.ensureDefaultShelf('book');
      final resolvedShelfId = targetShelfId ?? defaultShelf.id;
      final storedPath = await storeMedia();
      final coverPath = await _tryExtractCover(localPath, ext, hash);
      if (dup != null) {
        final effectiveTitle =
            dup.title.trim().isNotEmpty && !overwriteExisting ? dup.title : title;
        final effectiveGroup =
            (dup.shelfGroup == '已读完' || dup.progressRatio >= 0.99)
                ? '已读完'
                : '在读';
        final oldManagedPath = dup.filePath;
        await db.updateBookMeta(
          dup.id,
          title: effectiveTitle,
          author: overwriteExisting ? author : null,
          filePath: storedPath,
          coverPath: coverPath ?? dup.coverPath,
          shelfId: targetShelfId ?? dup.shelfId ?? resolvedShelfId,
          shelfGroup: effectiveGroup,
          currentChapterTitle:
              dup.currentChapterTitle.trim().isEmpty ? firstChapter : null,
          lastReadAtMs: now,
          isArchived: false,
        );
        if (oldManagedPath != storedPath &&
            (LibraryStorage.isDocument(oldManagedPath) || p.normalize(oldManagedPath) != p.normalize(storedPath))) {
          replacedPaths.add(oldManagedPath);
        }
        return ImportFileOutcome(
          status: 'book',
          kind: 'book',
          id: dup.id,
          title: effectiveTitle,
          shelfGroup: effectiveGroup,
          localPath: storedPath,
          repaired: true,
        );
      }

      await db.upsertBook(
        BooksCompanion.insert(
          contentHash: hash,
          title: title,
          author: Value(author),
          format: ext,
          filePath: storedPath,
          coverPath: Value(coverPath),
          shelfId: Value(resolvedShelfId),
          shelfGroup: const Value('在读'),
          currentChapterTitle: Value(firstChapter),
          addedAtMs: now,
          lastReadAtMs: now,
        ),
      );
      final inserted = await db.findBookByHash(hash);
      return ImportFileOutcome(
        status: 'book',
        kind: 'book',
        id: inserted?.id,
        title: title,
        shelfGroup: '在读',
        localPath: storedPath,
      );
    } else {
      final dup = await db.findMangaByHash(hash);
      final existingBroken = dup != null && !await storage.exists(dup.rootPath);
      final wasArchived = dup != null && dup.isArchived;

      if (dup != null && !overwriteExisting && !existingBroken && !wasArchived) {
        return ImportFileOutcome(
          status: 'duplicate',
          kind: 'comic',
          id: dup.id,
          title: dup.title.trim().isNotEmpty ? dup.title : stem,
          shelfGroup: dup.shelfGroup,
          localPath: localPath,
        );
      }

      var title = isDir ? p.basename(localPath) : stem;
      if (title.trim().isEmpty) title = '未命名漫画';
      var author = '未知作者';
      var readingMode = 'rtl';
      final chaptersToInsert = <MangaChaptersCompanion>[];

      if (isDir && rustCore != null) {
        final discovered = rustCore!.discoverComicChapters(localPath);
        for (var i = 0; i < discovered.length; i++) {
          final ch = discovered[i];
          chaptersToInsert.add(
            MangaChaptersCompanion.insert(
              mangaId: 0, // Replaced after manga insert
              title: _nonEmptyOr(ch['title'], '第 ${i + 1} 话'),
              chapterIndex: i,
              sourcePath: ch['source_path'] as String? ?? localPath,
              pageCount: Value((ch['page_count'] as num?)?.toInt() ?? 0),
              updatedAtMs: now,
            ),
          );
        }
      } else {
        var pageCount = 0;
        if (rustCore != null &&
            (ext == 'CBZ' || ext == 'ZIP' || ext == 'CB7' || ext == '7Z')) {
          try {
            final summary = rustCore!.inspectComicArchive(localPath);
            pageCount = (summary['page_count'] as num?)?.toInt() ?? 0;
            final ci = summary['comic_info'] as Map<String, dynamic>?;
            if (ci != null) {
              title = _nonEmptyOr(ci['series'], _nonEmptyOr(ci['title'], title));
              author = _nonEmptyOr(ci['writer'], author);
              readingMode =
                  _nonEmptyOr(ci['recommended_reading_mode'], readingMode);
            }
          } catch (_) {}
        }
        chaptersToInsert.add(
          MangaChaptersCompanion.insert(
            mangaId: 0,
            title: title,
            chapterIndex: 0,
            sourcePath: localPath,
            pageCount: Value(pageCount),
            updatedAtMs: now,
          ),
        );
      }

      final coverSource = chaptersToInsert.isNotEmpty
          ? chaptersToInsert.first.sourcePath.value
          : localPath;
      final coverFmt = FileSystemEntity.isDirectorySync(coverSource)
          ? 'folder'
          : p.extension(coverSource).replaceFirst('.', '').toLowerCase();
      final coverPath = await _tryExtractCover(coverSource, coverFmt, hash);

      final defaultShelf = await db.ensureDefaultShelf('comic');
      final resolvedShelfId = targetShelfId ?? defaultShelf.id;
      int mangaId;
      String storedRoot;
      var shouldReplaceChapters = true;
      if (dup != null) {
        mangaId = dup.id;
        final oldRootPath = dup.rootPath;
        final existingChapters = await db.chaptersForManga(mangaId);
        // When restoring an archived manga whose file & chapters are intact (and not overwriting),
        // preserve per-chapter reading progress instead of wiping MangaChapters.
        if (wasArchived &&
            !overwriteExisting &&
            !existingBroken &&
            existingChapters.isNotEmpty) {
          shouldReplaceChapters = false;
          storedRoot = oldRootPath;
          await db.updateMangaMeta(
            mangaId,
            rootPath: storedRoot,
            coverPath: coverPath ?? dup.coverPath,
            shelfId: targetShelfId ?? dup.shelfId ?? resolvedShelfId,
            lastReadAtMs: now,
            isArchived: false,
          );
        } else {
          storedRoot = await storeMedia();
          await db.updateMangaMeta(
            mangaId,
            title: overwriteExisting ? title : dup.title,
            author: overwriteExisting ? author : null,
            rootPath: storedRoot,
            coverPath: coverPath ?? dup.coverPath,
            shelfId: targetShelfId ?? dup.shelfId ?? resolvedShelfId,
            lastReadAtMs: now,
            isArchived: false,
          );
          if (oldRootPath != storedRoot &&
              (LibraryStorage.isDocument(oldRootPath) || p.normalize(oldRootPath) != p.normalize(storedRoot))) {
            replacedPaths.add(oldRootPath);
          }
        }
      } else {
        storedRoot = await storeMedia();
        await db.upsertManga(
          MangasCompanion.insert(
            contentHash: hash,
            title: title,
            author: Value(author),
            format: isDir ? '文件夹' : ext,
            rootPath: storedRoot,
            coverPath: Value(coverPath),
            shelfId: Value(resolvedShelfId),
            shelfGroup: const Value('在读'),
            unreadCount: Value(chaptersToInsert.length),
            totalChapters: Value(chaptersToInsert.length),
            preferredReadingMode: Value(readingMode),
            addedAtMs: now,
            lastReadAtMs: now,
          ),
        );
        final inserted = await db.findMangaByHash(hash);
        mangaId = inserted!.id;
      }

      if (shouldReplaceChapters) {
        await db.replaceMangaChapters(
          mangaId,
          chaptersToInsert
              .map(
                (c) => MangaChaptersCompanion.insert(
                  mangaId: mangaId,
                  title: c.title.value,
                  chapterIndex: c.chapterIndex.value,
                  sourcePath: storedChapterPath(c.sourcePath.value),
                  pageCount: c.pageCount,
                  updatedAtMs: now,
                ),
              )
              .toList(),
        );
      }
      return ImportFileOutcome(
        status: 'manga',
        kind: 'comic',
        id: mangaId,
        title: dup != null && !overwriteExisting ? dup.title : title,
        shelfGroup: dup?.shelfGroup ?? '在读',
        localPath: storedRoot,
        repaired: dup != null,
      );
    }
  }

  /// Launches Android SAF multi-file picker and imports all chosen files.
  Future<ImportBatchResult> pickAndImportDocuments({
    required bool autoClassify,
    bool overwriteExisting = false,
    int? targetBookShelfId,
    int? targetMangaShelfId,
  }) async {
    if (!await storage.ensureWorkingDirectory()) return ImportBatchResult.empty;
    final picked = await platform.pickDocumentsDetailed();
    var books = 0;
    var mangas = 0;
    var skipped = 0;
    final errors = <String>[...picked.errors];
    final importedItems = <ImportFileOutcome>[];
    final duplicateItems = <ImportFileOutcome>[];

    for (final filePath in picked.paths) {
      var keepForOverwrite = false;
      try {
        final isDir = FileSystemEntity.isDirectorySync(filePath);
        final resolvedKind = autoClassify
            ? classifyExtension(filePath, isDirectory: isDir)
            : 'book';
        final outcome = await importLocalPathDetailed(
          filePath,
          forceKind: autoClassify ? null : 'book',
          overwriteExisting: overwriteExisting,
          targetShelfId:
              resolvedKind == 'comic' ? targetMangaShelfId : targetBookShelfId,
        );
        if (outcome.status == 'book') {
          books++;
          importedItems.add(outcome);
        } else if (outcome.status == 'manga') {
          mangas++;
          importedItems.add(outcome);
        } else {
          skipped++;
          duplicateItems.add(outcome);
          keepForOverwrite = true;
        }
      } catch (e) {
        errors.add('${p.basename(filePath)}: $e');
      } finally {
        if (!keepForOverwrite) await storage.releaseTemp(filePath);
      }
    }

    return ImportBatchResult(
      booksImported: books,
      mangasImported: mangas,
      skippedDuplicates: skipped,
      errors: errors,
      importedItems: importedItems,
      duplicateItems: duplicateItems,
    );
  }

  Future<WatchedFolder?> addWatchedDirectory() async {
    final picked = await platform.pickPersistentDirectory();
    if (picked == null) return null;
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = await db.upsertWatchedFolder(
      WatchedFoldersCompanion.insert(
        uriOrPath: picked.uri,
        displayName: picked.name,
        lastScannedAtMs: Value(now),
      ),
    );
    return WatchedFolder(
      id: id,
      uriOrPath: picked.uri,
      displayName: picked.name,
      defaultKind: 'auto',
      lastScannedAtMs: now,
    );
  }

  Future<List<ImportCandidate>> scanWatchedFolders({
    void Function(WatchedFolder, Object)? onFolderError,
  }) async {
    final folders = await db.getWatchedFolders();
    final found = <ImportCandidate>[];

    for (final folder in folders) {
      if (folder.uriOrPath.startsWith('content://')) {
        final List<ScannedTreeFile> items;
        try {
          items = await platform.scanPersistentDirectory(folder.uriOrPath);
        } catch (error) {
          if (onFolderError == null) rethrow;
          onFolderError(folder, error);
          continue;
        }
        for (final item in items) {
          final kind = classifyExtension(item.name);
          if (kind == 'unknown') continue;
          found.add(
            ImportCandidate(
              uriOrPath: item.uri,
              name: item.name,
              ext: item.ext.toUpperCase(),
              sizeBytes: item.size,
              targetKind: kind,
              isSafUri: true,
            ),
          );
        }
      } else if (Directory(folder.uriOrPath).existsSync()) {
        for (final ent
            in Directory(folder.uriOrPath).listSync(recursive: true)) {
          if (ent is! File) continue;
          final name = p.basename(ent.path);
          final kind = classifyExtension(name);
          if (kind == 'unknown') continue;
          found.add(
            ImportCandidate(
              uriOrPath: ent.path,
              name: name,
              ext: p.extension(name).replaceFirst('.', '').toUpperCase(),
              sizeBytes: ent.lengthSync(),
              targetKind: kind,
              isSafUri: false,
            ),
          );
        }
      }
    }
    return found;
  }

  Future<ImportBatchResult> importSelectedCandidates(
    List<ImportCandidate> candidates, {
    required bool autoClassify,
    bool overwriteExisting = false,
    int? targetBookShelfId,
    int? targetMangaShelfId,
  }) async {
    if (!await storage.ensureWorkingDirectory()) return ImportBatchResult.empty;
    var books = 0;
    var mangas = 0;
    var skipped = 0;
    final errors = <String>[];
    final importedItems = <ImportFileOutcome>[];
    final duplicateItems = <ImportFileOutcome>[];

    for (final c in candidates.where((e) => e.selected)) {
      String? staged;
      var keepForOverwrite = false;
      try {
        String? localPath = c.uriOrPath;
        if (c.isSafUri) {
          staged = await platform.stageDocumentUri(
            c.uriOrPath,
            fileName: c.name,
          );
          localPath = staged;
        }
        if (localPath == null) {
          errors.add('${c.name}: ERR_STREAM_OPEN');
          continue;
        }
        final kind = autoClassify ? c.targetKind : 'book';
        final outcome = await importLocalPathDetailed(
          localPath,
          forceKind: kind,
          overwriteExisting: overwriteExisting,
          targetShelfId:
              kind == 'comic' ? targetMangaShelfId : targetBookShelfId,
        );
        if (outcome.status == 'book') {
          books++;
          importedItems.add(outcome);
        } else if (outcome.status == 'manga') {
          mangas++;
          importedItems.add(outcome);
        } else {
          skipped++;
          duplicateItems.add(outcome);
          keepForOverwrite = true;
        }
      } catch (e) {
        errors.add('${c.name}: $e');
      } finally {
        if (staged != null && !keepForOverwrite) {
          await storage.releaseTemp(staged);
        }
      }
    }

    return ImportBatchResult(
      booksImported: books,
      mangasImported: mangas,
      skippedDuplicates: skipped,
      errors: errors,
      importedItems: importedItems,
      duplicateItems: duplicateItems,
    );
  }
}
