import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/importer/import_service.dart';
import '../db/app_database.dart';
import '../ffi/rust_core_bridge.dart';
import '../platform/platform_bridge.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final rustCoreProvider = Provider<RustCoreBridge?>((ref) {
  return RustCoreBridge.tryOpen();
});

final platformBridgeProvider = Provider<PlatformBridge>((ref) {
  return MethodChannelPlatformBridge();
});

final importServiceProvider = Provider<ImportService>((ref) {
  return ImportService(
    db: ref.watch(appDatabaseProvider),
    platform: ref.watch(platformBridgeProvider),
    rustCore: ref.watch(rustCoreProvider),
  );
});

final coreHealthProvider = Provider<CoreHealthInfo>((ref) {
  final bridge = ref.watch(rustCoreProvider);
  if (bridge != null) {
    try {
      return bridge.healthCheck();
    } catch (_) {}
  }
  return const CoreHealthInfo(
    engineName: 'inkbox_core (standby)',
    version: '1.0.0',
    supportedBookFormats: ['epub', 'txt', 'pdf', 'mobi', 'azw3', 'fb2', 'md'],
    supportedComicFormats: [
      'cbz',
      'zip',
      'cbr',
      'rar',
      'cb7',
      '7z',
      'pdf',
      'folder'
    ],
    isNativeLoaded: false,
  );
});

/// Active books currently on Bookshelf.
final booksStreamProvider = StreamProvider<List<Book>>((ref) {
  return ref.watch(appDatabaseProvider).watchAllBooks();
});

/// Full book import history (including items removed from Bookshelf).
final bookHistoryStreamProvider = StreamProvider<List<Book>>((ref) {
  return ref.watch(appDatabaseProvider).watchBookImportHistory();
});

/// Active mangas currently on MangaShelf.
final mangasStreamProvider = StreamProvider<List<Manga>>((ref) {
  return ref.watch(appDatabaseProvider).watchAllMangas();
});

/// Full manga import history (including items removed from MangaShelf).
final mangaHistoryStreamProvider = StreamProvider<List<Manga>>((ref) {
  return ref.watch(appDatabaseProvider).watchMangaImportHistory();
});

final bookShelvesStreamProvider = StreamProvider<List<Shelf>>((ref) {
  return ref.watch(appDatabaseProvider).watchShelves('book');
});

final mangaShelvesStreamProvider = StreamProvider<List<Shelf>>((ref) {
  return ref.watch(appDatabaseProvider).watchShelves('comic');
});

final activeBookShelfIdProvider = StateProvider<int?>((ref) => null);

final activeMangaShelfIdProvider = StateProvider<int?>((ref) => null);

final tocRulesStreamProvider = StreamProvider<List<TocRule>>((ref) {
  return ref.watch(appDatabaseProvider).watchTocRules();
});

final watchedFoldersStreamProvider = StreamProvider<List<WatchedFolder>>((ref) {
  return ref.watch(appDatabaseProvider).watchWatchedFolders();
});

final mangaChaptersStreamProvider =
    StreamProvider.family<List<MangaChapter>, int>((ref, mangaId) {
  return ref.watch(appDatabaseProvider).watchChaptersForManga(mangaId);
});

final annotationsStreamProvider =
    StreamProvider.family<List<Annotation>, String>((ref, contentHash) {
  return ref.watch(appDatabaseProvider).watchAnnotationsFor(contentHash);
});
