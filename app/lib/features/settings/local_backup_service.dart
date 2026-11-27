import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../data/db/app_database.dart';
import '../../data/platform/library_storage.dart';

const _manifestName = 'inkbox-library.json';
const _backupVersion = 1;
const _manifestLimit = 32 * 1024 * 1024;

class LocalBackupService {
  LocalBackupService(this.db, {LibraryStorage? storage})
    : storage = storage ?? LibraryStorage();

  final AppDatabase db;
  final LibraryStorage storage;

  Future<void> exportTo(File destination) async {
    final snapshot = await db.transaction(() async {
      return <String, dynamic>{
        'version': _backupVersion,
        'books': (await db.select(db.books).get())
            .map((b) => b.toJson())
            .toList(),
        'mangas': (await db.select(db.mangas).get())
            .map((m) => m.toJson())
            .toList(),
        'chapters': (await db.select(db.mangaChapters).get())
            .map((c) => c.toJson())
            .toList(),
        'shelves': (await db.select(db.shelves).get())
            .map((s) => s.toJson())
            .toList(),
        'tocRules': (await db.getTocRules()).map((r) => r.toJson()).toList(),
        'annotations': (await db.getAllAnnotations())
            .map((a) => a.toJson())
            .toList(),
        'progress': (await db.getAllSyncStates())
            .map((s) => s.toJson())
            .toList(),
      };
    });
    final opened = <ReadableMedia>[];
    final localPaths = <String, String>{};
    try {
      for (final (table, field) in [
        ('mangas', 'rootPath'),
        ('chapters', 'sourcePath'),
        ('books', 'filePath'),
      ]) {
        for (final row
            in (snapshot[table] as List).cast<Map<String, dynamic>>()) {
          final reference = row[field] as String;
          if (!LibraryStorage.isDocument(reference)) continue;
          if (!localPaths.containsKey(reference) &&
              await storage.exists(reference)) {
            final format = row['format'] as String?;
            final media = await storage.open(
              reference,
              extension: format == 'FOLDER' ? null : format,
            );
            opened.add(media);
            localPaths.addAll(media.paths);
          }
          row[field] = localPaths[reference] ?? '';
        }
      }
      await compute(_writeBackup, (path: destination.path, snapshot: snapshot));
    } finally {
      for (final media in opened) {
        await media.close();
      }
    }
  }

  Future<({int books, int comics, int skipped})> importFrom(
    File source, {
    Directory? libraryDirectory,
  }) async {
    final inWorkingDirectory = storage.requiresWorkingDirectory;
    if (inWorkingDirectory && await storage.workingDirectory() == null) {
      throw StateError('ERR_WORK_DIRECTORY');
    }
    final sourcePath = source.path;
    final snapshot = await compute(_readBackup, sourcePath);
    List<T> readRows<T>(String key, T Function(Map<String, dynamic>) parse) =>
        (snapshot[key] as List)
            .cast<Map<String, dynamic>>()
            .map(parse)
            .toList();
    final books = readRows('books', Book.fromJson);
    final mangas = readRows('mangas', Manga.fromJson);
    final chapters = readRows('chapters', MangaChapter.fromJson);
    final shelves = readRows('shelves', Shelf.fromJson);
    final rules = readRows('tocRules', TocRule.fromJson);
    final annotations = readRows('annotations', Annotation.fromJson);
    final progress = readRows('progress', SyncState.fromJson);

    final validHash = RegExp(r'^[a-zA-Z0-9_-]+$');
    if (books.any((b) => !validHash.hasMatch(b.contentHash)) ||
        mangas.any((m) => !validHash.hasMatch(m.contentHash))) {
      throw const FormatException('Invalid backup content fingerprint');
    }

    final library = inWorkingDirectory
        ? await getTemporaryDirectory()
        : libraryDirectory ??
              Directory(
                p.join(
                  (await getApplicationSupportDirectory()).path,
                  'library_imports',
                ),
              );
    await library.create(recursive: true);
    final restored = await library.createTemp('backup-');
    final restoredPath = restored.path;
    final storedPaths = <String, String>{};
    final storedRoots = <String>[];
    Directory? coverDirectory;
    var keepExtracted = false;

    String extractedPath(String entry) {
      if (!_isMediaEntry(entry) || entry.endsWith('/')) {
        throw const FormatException('Invalid backup media reference');
      }
      return p.joinAll([restoredPath, ...entry.split('/')]);
    }

    String restorePath(String entry) => entry.isEmpty
        ? ''
        : storedPaths[extractedPath(entry)] ?? extractedPath(entry);

    String? restoreCover(String? entry) {
      if (entry == null || entry.isEmpty) return null;
      final directory = coverDirectory;
      return directory == null
          ? extractedPath(entry)
          : p.joinAll([directory.path, ...entry.split('/')]);
    }

    final ({int books, int comics, int skipped}) result;
    try {
      result = await db.transaction(() async {
        final knownBooks = {
          for (final book in await db.getAllBooks(includeArchived: true))
            book.contentHash,
        };
        final knownMangas = {
          for (final manga in await db.getAllMangas(includeArchived: true))
            manga.contentHash,
        };
        final incomingBooks = books
            .where((b) => knownBooks.add(b.contentHash))
            .toList();
        final incomingMangas = mangas
            .where((m) => knownMangas.add(m.contentHash))
            .toList();
        final incomingMangaIds = incomingMangas.map((m) => m.id).toSet();
        final incomingChapters = chapters.where(
          (c) => incomingMangaIds.contains(c.mangaId),
        );
        final mediaEntries = {
          ...incomingBooks.map((b) => b.filePath),
          ...incomingMangas.map((m) => m.rootPath),
          ...incomingChapters.map((c) => c.sourcePath),
        }..remove('');
        final coverEntries = {
          ...incomingBooks.map((b) => b.coverPath).nonNulls,
          ...incomingMangas.map((m) => m.coverPath).nonNulls,
        }..remove('');
        final assets = {...mediaEntries, ...coverEntries};
        if (assets.isNotEmpty) {
          for (final entry in assets) {
            extractedPath(entry);
          }
          await compute(_extractMedia, (
            zipPath: sourcePath,
            destination: restoredPath,
            references: assets,
          ));
        }
        if (inWorkingDirectory) {
          final paths = mediaEntries.map(extractedPath).toList()..sort();
          for (final path in paths) {
            if (storedPaths.containsKey(path)) continue;
            final stored = await storage.store(path);
            storedRoots.add(stored[path]!);
            storedPaths.addAll(stored);
          }
          if (coverEntries.isNotEmpty) {
            final covers = Directory(
              p.join((await getApplicationDocumentsDirectory()).path, 'covers'),
            );
            await covers.create(recursive: true);
            coverDirectory = await covers.createTemp('backup-');
            for (final entry in coverEntries) {
              final destination = File(restoreCover(entry)!);
              await destination.parent.create(recursive: true);
              await File(extractedPath(entry)).copy(destination.path);
            }
          }
        }
        final shelfIds = await _mergeShelves(shelves);
        final ruleIds = await _mergeTocRules(rules);
        final restoredHashes = <String>{};
        var bookCount = 0;
        var comicCount = 0;
        for (final book in incomingBooks) {
          await db.upsertBook(
            book
                .toCompanion(false)
                .copyWith(
                  id: const Value.absent(),
                  shelfId: Value(shelfIds[book.shelfId]),
                  tocRuleId: Value(ruleIds[book.tocRuleId]),
                  filePath: Value(restorePath(book.filePath)),
                  coverPath: Value(restoreCover(book.coverPath)),
                  cloudFileSynced: const Value(false),
                ),
          );
          restoredHashes.add(book.contentHash);
          bookCount++;
        }
        final mangaIds = <int, int>{};
        for (final manga in incomingMangas) {
          mangaIds[manga.id] = await db.upsertManga(
            manga
                .toCompanion(false)
                .copyWith(
                  id: const Value.absent(),
                  rootPath: Value(restorePath(manga.rootPath)),
                  coverPath: Value(restoreCover(manga.coverPath)),
                  shelfId: Value(shelfIds[manga.shelfId]),
                  cloudFileSynced: const Value(false),
                ),
          );
          restoredHashes.add(manga.contentHash);
          comicCount++;
        }
        for (final chapter in incomingChapters) {
          final mangaId = mangaIds[chapter.mangaId];
          if (mangaId == null) continue;
          await db
              .into(db.mangaChapters)
              .insert(
                chapter
                    .toCompanion(false)
                    .copyWith(
                      id: const Value.absent(),
                      mangaId: Value(mangaId),
                      sourcePath: Value(restorePath(chapter.sourcePath)),
                    ),
              );
        }
        for (final record in progress) {
          if (!restoredHashes.contains(record.contentHash)) continue;
          final existing = await db.getSyncState(record.contentHash);
          if (existing != null && existing.updatedAtMs >= record.updatedAtMs) {
            continue;
          }
          await db.upsertSyncState(
            record.toCompanion(false).copyWith(lastSyncedAtMs: const Value(0)),
          );
        }
        final annotationsByUuid = {
          for (final annotation in await db.getAllAnnotations())
            annotation.uuid: annotation.updatedAtMs,
        };
        for (final annotation in annotations) {
          if ((annotationsByUuid[annotation.uuid] ?? -1) >=
              annotation.updatedAtMs) {
            continue;
          }
          await db.upsertAnnotation(
            annotation.toCompanion(false).copyWith(id: const Value.absent()),
          );
          annotationsByUuid[annotation.uuid] = annotation.updatedAtMs;
        }
        keepExtracted = !inWorkingDirectory && assets.isNotEmpty;
        return (
          books: bookCount,
          comics: comicCount,
          skipped: books.length + mangas.length - bookCount - comicCount,
        );
      });
    } catch (_) {
      keepExtracted = false;
      for (final path in storedRoots) {
        await storage.delete(path);
      }
      await coverDirectory?.delete(recursive: true);
      rethrow;
    } finally {
      if (!keepExtracted) await restored.delete(recursive: true);
    }
    return result;
  }

  Future<Map<int, int>> _mergeShelves(List<Shelf> incoming) async {
    final existing = await db.select(db.shelves).get();
    final ids = <int, int>{};
    for (final shelf in incoming) {
      final kind = shelf.mediaKind;
      if (kind != 'book' && kind != 'comic') {
        throw const FormatException('Invalid backup shelf kind');
      }
      if (shelf.isDefault) {
        ids[shelf.id] = (await db.ensureDefaultShelf(kind)).id;
        continue;
      }
      final match = existing
          .where((s) => s.mediaKind == kind && s.name == shelf.name)
          .firstOrNull;
      final target = match ?? await db.createShelf(shelf.name, kind);
      if (target != null) {
        ids[shelf.id] = target.id;
        if (match == null) existing.add(target);
      }
    }
    return ids;
  }

  Future<Map<int, int>> _mergeTocRules(List<TocRule> incoming) async {
    final existing = await db.getTocRules();
    final ids = <int, int>{};
    for (final rule in incoming) {
      final match = existing.where((r) => r.rule == rule.rule).firstOrNull;
      if (match != null) {
        ids[rule.id] = match.id;
        continue;
      }
      final id = await db
          .into(db.tocRules)
          .insert(rule.toCompanion(false).copyWith(id: const Value.absent()));
      ids[rule.id] = id;
      existing.add(rule.copyWith(id: id));
    }
    return ids;
  }
}

void _writeBackup(({String path, Map<String, dynamic> snapshot}) input) {
  final (:path, :snapshot) = input;
  final encoder = ZipFileEncoder()..create(path, level: ZipFileEncoder.store);
  final mediaPaths = <String, String>{};

  String? addMedia(String? path) {
    if (path == null || path.isEmpty || !p.isAbsolute(path)) return null;
    final source = p.normalize(path);
    final existing = mediaPaths[source];
    if (existing != null) return existing;
    final type = FileSystemEntity.typeSync(source, followLinks: false);
    if (type != FileSystemEntityType.file &&
        type != FileSystemEntityType.directory) {
      return null;
    }
    final entry = 'media/${mediaPaths.length + 1}/${p.basename(source)}';
    if (!_isMediaEntry(entry)) {
      throw FormatException('Unsupported media name: ${p.basename(source)}');
    }
    if (type == FileSystemEntityType.file) {
      encoder.addFileSync(File(source), entry);
      mediaPaths[source] = entry;
      return entry;
    }

    encoder.addArchiveFile(ArchiveFile.directory('$entry/'));
    final included = <String, String>{source: entry};
    for (final child in Directory(
      source,
    ).listSync(recursive: true, followLinks: false)) {
      if (child is Link) continue;
      final relative = p.split(p.relative(child.path, from: source)).join('/');
      final name = '$entry/$relative';
      if (!_isMediaEntry(name)) {
        throw FormatException('Unsupported media name: $relative');
      }
      if (child is File) {
        encoder.addFileSync(child, name);
      } else if (child is Directory) {
        encoder.addArchiveFile(ArchiveFile.directory('$name/'));
      }
      included[p.normalize(child.path)] = name;
    }
    mediaPaths.addAll(included);
    return entry;
  }

  try {
    for (final manga in snapshot['mangas'] as List) {
      manga['rootPath'] = addMedia(manga['rootPath'] as String) ?? '';
      manga['coverPath'] = addMedia(manga['coverPath'] as String?);
    }
    for (final chapter in snapshot['chapters'] as List) {
      chapter['sourcePath'] = addMedia(chapter['sourcePath'] as String) ?? '';
    }
    for (final book in snapshot['books'] as List) {
      book['filePath'] = addMedia(book['filePath'] as String) ?? '';
      book['coverPath'] = addMedia(book['coverPath'] as String?);
    }
    final manifest = ArchiveFile.string(_manifestName, jsonEncode(snapshot));
    if (manifest.size > _manifestLimit) {
      throw const FormatException('Backup library metadata is too large');
    }
    encoder.addArchiveFile(manifest);
  } finally {
    encoder.closeSync();
  }
}

Map<String, dynamic> _readBackup(String path) {
  final input = InputFileStream(path);
  try {
    final archive = ZipDecoder().decodeStream(input, verify: true);
    final manifest = archive.find(_manifestName);
    if (manifest == null ||
        !manifest.isFile ||
        manifest.isSymbolicLink ||
        manifest.size > _manifestLimit) {
      throw const FormatException('Invalid InkBox backup');
    }
    final snapshot = jsonDecode(utf8.decode(manifest.content));
    if (snapshot is! Map<String, dynamic> ||
        snapshot['version'] != _backupVersion) {
      throw const FormatException('Unsupported InkBox backup version');
    }
    return snapshot;
  } finally {
    input.closeSync();
  }
}

final _invalidMediaCharacter = RegExp(r'[\\:\x00-\x1f]');
final _assetIndex = RegExp(r'^[1-9][0-9]*$');
final _windowsReservedName = RegExp(
  r'^(CON|PRN|AUX|NUL|COM[0-9]|LPT[0-9])(\.|$)',
  caseSensitive: false,
);

bool _isMediaEntry(String name) {
  final parts = name.replaceFirst(RegExp(r'/$'), '').split('/');
  return parts.length >= 3 &&
      parts.first == 'media' &&
      _assetIndex.hasMatch(parts[1]) &&
      parts
          .skip(2)
          .every(
            (part) =>
                part.isNotEmpty &&
                part != '.' &&
                part != '..' &&
                !_invalidMediaCharacter.hasMatch(part) &&
                (!Platform.isWindows ||
                    (!part.endsWith('.') &&
                        !part.endsWith(' ') &&
                        !_windowsReservedName.hasMatch(part))),
          );
}

void _extractMedia(
  ({String zipPath, String destination, Set<String> references}) args,
) {
  final (:zipPath, :destination, :references) = args;
  final input = InputFileStream(zipPath);
  try {
    final archive = ZipDecoder().decodeStream(input, verify: true);
    final directories = <String>{};
    for (final ref in references) {
      if (archive.find(ref)?.isFile == true) continue;
      if (archive.find('$ref/')?.isDirectory != true) {
        throw const FormatException('Backup media is missing');
      }
      directories.add('$ref/');
    }
    for (final entry in archive) {
      final name = entry.name;
      if (name == _manifestName) continue;
      if (!_isMediaEntry(name) || entry.isSymbolicLink) {
        throw const FormatException('Invalid backup archive entry');
      }
      if (!references.contains(name) && !directories.any(name.startsWith)) {
        continue;
      }
      final parts = name.split('/').where((part) => part.isNotEmpty);
      final path = p.joinAll([destination, ...parts]);
      if (entry.isDirectory) {
        Directory(path).createSync(recursive: true);
        continue;
      }
      final file = File(path);
      file.parent.createSync(recursive: true);
      final output = OutputFileStream(path);
      try {
        entry.writeContent(output);
      } finally {
        output.closeSync();
      }
      if (file.lengthSync() != entry.size) {
        throw const FormatException('Incomplete backup media');
      }
    }
  } finally {
    input.closeSync();
  }
}
