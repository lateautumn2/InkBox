import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../data/backup/backup_zip.dart';
import '../../data/db/app_database.dart';
import '../../data/platform/library_storage.dart';

const _manifestName = 'inkbox-library.json';
const _backupVersion = 1;
const _manifestLimit = 32 * 1024 * 1024;
const _archiveEntryLimit = 50000;
const _mediaEntryLimit = 4 * 1024 * 1024 * 1024;
const _mediaTotalLimit = 16 * 1024 * 1024 * 1024;

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
    await _writeBackup(destination.path, snapshot, storage);
  }

  Future<({int books, int comics, int skipped})> importFrom(
    File source, {
    Directory? libraryDirectory,
  }) async {
    while (true) {
      try {
        return await _importFrom(source, libraryDirectory: libraryDirectory);
      } on _LibraryChangedDuringRestore {
        // Another import won the race. Build a fresh plan for the remaining items.
      }
    }
  }

  Future<({int books, int comics, int skipped})> _importFrom(
    File source, {
    Directory? libraryDirectory,
  }) async {
    final inWorkingDirectory = storage.requiresWorkingDirectory;
    if (inWorkingDirectory && await storage.workingDirectory() == null) {
      throw StateError('ERR_WORK_DIRECTORY');
    }
    final sourcePath = source.path;
    final snapshot = await compute(_readBackup, sourcePath);
    List<T> readRows<T>(String key, T Function(Map<String, dynamic>) parse) {
      final rows = snapshot[key];
      if (rows is! List || rows.any((row) => row is! Map<String, dynamic>)) {
        throw const FormatException('Invalid InkBox backup metadata');
      }
      try {
        return rows.cast<Map<String, dynamic>>().map(parse).toList();
      } on TypeError {
        throw const FormatException('Invalid InkBox backup metadata');
      }
    }

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
    Map<String, String>? extractedNames;
    Directory? coverDirectory;
    var keepExtracted = false;

    String extractedPath(String entry) {
      if (!_isMediaEntry(entry) || entry.endsWith('/')) {
        throw const FormatException('Invalid backup media reference');
      }
      final name = extractedNames?[entry] ?? entry;
      return p.joinAll([restoredPath, ...name.split('/')]);
    }

    String restorePath(String entry) => entry.isEmpty
        ? ''
        : storedPaths[extractedPath(entry)] ?? extractedPath(entry);

    String? restoreCover(String? entry) {
      if (entry == null || entry.isEmpty) return null;
      final directory = coverDirectory;
      final name = extractedNames?[entry] ?? entry;
      return directory == null
          ? extractedPath(entry)
          : p.joinAll([directory.path, ...name.split('/')]);
    }

    final ({int books, int comics, int skipped}) result;
    try {
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
        extractedNames = await compute(_extractMedia, (
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
      result = await db.transaction(() async {
        for (final book in incomingBooks) {
          if (await db.findBookByHash(book.contentHash) != null) {
            throw const _LibraryChangedDuringRestore();
          }
        }
        for (final manga in incomingMangas) {
          if (await db.findMangaByHash(manga.contentHash) != null) {
            throw const _LibraryChangedDuringRestore();
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
        final snapshotProgress = {
          for (final record in progress) record.contentHash: record,
        };
        final originalChapterIndices = {
          for (final chapter in incomingChapters)
            chapter.id: (mangaId: chapter.mangaId, index: chapter.chapterIndex),
        };
        final originalMangaIds = {
          for (final manga in incomingMangas) manga.contentHash: manga.id,
        };
        for (final hash in restoredHashes) {
          final existing = await db.getSyncState(hash);
          final incoming = snapshotProgress[hash];
          final useExisting =
              existing != null &&
              (incoming == null ||
                  existing.updatedAtMs >= incoming.updatedAtMs);
          final record = useExisting ? existing : incoming;
          if (record == null) continue;
          var locator = record.locator;
          if (record.mediaKind == 'comic' && !useExisting) {
            final match = RegExp(r'^ch:(\d+);page:(\d+)$').firstMatch(locator);
            final chapter =
                originalChapterIndices[int.tryParse(match?[1] ?? '')];
            if (chapter != null && chapter.mangaId == originalMangaIds[hash]) {
              locator = 'idx:${chapter.index};page:${match![2]}';
            }
          }
          await db.applySyncedProgress(
            contentHash: hash,
            mediaKind: record.mediaKind,
            locator: locator,
            progressRatio: record.progressRatio,
            updatedAtMs: record.updatedAtMs,
            lastSyncedAtMs: record.lastSyncedAtMs,
            deviceId: record.deviceId,
            deviceName: record.deviceName,
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
        try {
          await storage.delete(path);
        } catch (_) {
          // Continue cleaning up and preserve the restore failure.
        }
      }
      await _deleteStaging(coverDirectory);
      rethrow;
    } finally {
      if (!keepExtracted) await _deleteStaging(restored);
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
      final name = shelf.name.trim();
      final match = existing
          .where((s) => s.mediaKind == kind && s.name.trim() == name)
          .firstOrNull;
      final target = match ?? await db.createShelf(name, kind);
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

class _LibraryChangedDuringRestore implements Exception {
  const _LibraryChangedDuringRestore();
}

Future<void> _deleteStaging(Directory? directory) async {
  try {
    await directory?.delete(recursive: true);
  } on FileSystemException {
    // Cache cleanup can reclaim staging data after a filesystem failure.
  }
}

Future<void> _writeBackup(
  String path,
  Map<String, dynamic> snapshot,
  LibraryStorage storage,
) async {
  final writer = await _BackupExportWriter.start(path);
  final mediaPaths = <String, String>{};
  final documentPaths = <String, String>{};
  var assetIndex = 0;
  var entryCount = 0;
  var totalBytes = 0;

  void reserveEntry(int size) {
    if (++entryCount > _archiveEntryLimit ||
        size > _mediaEntryLimit ||
        size > _mediaTotalLimit - totalBytes) {
      throw const FormatException('Backup archive exceeds the size limit');
    }
    totalBytes += size;
  }

  Future<void> writeFile(File file, String name) async {
    reserveEntry(await file.length());
    await writer.write('file', name, file.path);
  }

  Future<void> writeDirectory(String name) async {
    reserveEntry(0);
    await writer.write('directory', name);
  }

  Future<String?> addMedia(String path) async {
    if (path.isEmpty || !p.isAbsolute(path)) return null;
    final source = p.normalize(path);
    final existing = mediaPaths[source];
    if (existing != null) return existing;
    final type = await FileSystemEntity.type(source, followLinks: false);
    if (type != FileSystemEntityType.file &&
        type != FileSystemEntityType.directory) {
      return null;
    }
    final entry = 'media/${++assetIndex}/${_portableName(p.basename(source))}';
    if (type == FileSystemEntityType.file) {
      await writeFile(File(source), entry);
      mediaPaths[source] = entry;
      return entry;
    }

    await writeDirectory(entry);
    Future<void> addChildren(Directory directory, String prefix) async {
      final usedNames = <String>{};
      final children = await directory.list(followLinks: false).toList()
        ..sort((a, b) => a.path.compareTo(b.path));
      for (final child in children) {
        if (child is Link) continue;
        final name = _uniquePortableName(p.basename(child.path), usedNames);
        final entryName = '$prefix/$name';
        mediaPaths[p.normalize(child.path)] = entryName;
        if (child is File) {
          await writeFile(child, entryName);
        } else if (child is Directory) {
          await writeDirectory(entryName);
          await addChildren(child, entryName);
        }
      }
    }

    mediaPaths[source] = entry;
    await addChildren(Directory(source), entry);
    return entry;
  }

  Future<String?> addReference(String? reference, {String? format}) async {
    if (reference == null) return null;
    if (!LibraryStorage.isDocument(reference)) return addMedia(reference);
    final existing = documentPaths[reference];
    if (existing != null) return existing;
    if (!await storage.exists(reference)) return null;
    final media = await storage.open(
      reference,
      extension: format == 'FOLDER' ? null : format,
    );
    try {
      final entry = await addMedia(media.path);
      for (final child in media.paths.entries) {
        final archived = mediaPaths.remove(p.normalize(child.value));
        if (archived != null) documentPaths[child.key] = archived;
      }
      return entry;
    } finally {
      await media.close();
    }
  }

  try {
    for (final manga in snapshot['mangas'] as List) {
      manga['rootPath'] =
          await addReference(
            manga['rootPath'] as String,
            format: manga['format'] as String?,
          ) ??
          '';
      manga['coverPath'] = await addReference(manga['coverPath'] as String?);
    }
    for (final chapter in snapshot['chapters'] as List) {
      chapter['sourcePath'] =
          await addReference(chapter['sourcePath'] as String) ?? '';
    }
    for (final book in snapshot['books'] as List) {
      book['filePath'] =
          await addReference(
            book['filePath'] as String,
            format: book['format'] as String?,
          ) ??
          '';
      book['coverPath'] = await addReference(book['coverPath'] as String?);
    }
    final manifest = jsonEncode(snapshot);
    final size = utf8.encode(manifest).length;
    if (size > _manifestLimit) {
      throw const FormatException('Backup library metadata is too large');
    }
    reserveEntry(size);
    await writer.write('manifest', _manifestName, manifest);
    await writer.write('finish', '');
  } catch (_) {
    try {
      await writer.write('abort', '');
    } catch (_) {
      // Preserve the export failure if closing the incomplete file also fails.
    }
    rethrow;
  } finally {
    writer.dispose();
  }
}

typedef _ExportCommand = (SendPort, String, String, String?);
typedef _ExportResponse = (SendPort?, String?);

class _BackupExportWriter {
  _BackupExportWriter(this._isolate, this._commands);

  final Isolate _isolate;
  final SendPort _commands;

  static Future<_BackupExportWriter> start(String path) async {
    final response = ReceivePort();
    final isolate = await Isolate.spawn(_runBackupExport, (
      path,
      response.sendPort,
    ), onExit: response.sendPort);
    try {
      final event = await response.first as _ExportResponse?;
      final commands = event?.$1;
      if (commands == null) {
        isolate.kill();
        throw FileSystemException(event?.$2 ?? 'Could not create backup', path);
      }
      return _BackupExportWriter(isolate, commands);
    } finally {
      response.close();
    }
  }

  Future<void> write(String operation, String name, [String? data]) async {
    final response = ReceivePort();
    try {
      _commands.send((response.sendPort, operation, name, data));
      final event = await response.first as _ExportResponse;
      final error = event.$2;
      if (error != null) throw FileSystemException(error, name);
    } finally {
      response.close();
    }
  }

  void dispose() => _isolate.kill();
}

void _runBackupExport((String, SendPort) start) {
  final (path, ready) = start;
  final OutputFileStream output;
  final ZipFileEncoder encoder;
  try {
    output = OutputFileStream(path);
    encoder = ZipFileEncoder()
      ..createWithStream(output, level: ZipFileEncoder.store);
  } catch (error) {
    ready.send((null, error.toString()));
    return;
  }
  final commands = ReceivePort();
  ready.send((commands.sendPort, null));
  commands.listen((message) {
    final (response, operation, name, data) = message as _ExportCommand;
    try {
      switch (operation) {
        case 'file':
          encoder.addFileSync(File(data!), name);
        case 'directory':
          encoder.addArchiveFile(ArchiveFile.directory('$name/'));
        case 'manifest':
          encoder.addArchiveFile(ArchiveFile.string(name, data!));
        case 'finish':
          encoder.closeSync();
          commands.close();
        case 'abort':
          output.closeSync();
          commands.close();
      }
      response.send((null, null));
    } catch (error) {
      response.send((null, error.toString()));
    }
  });
}

Map<String, dynamic> _readBackup(String path) {
  final input = InputFileStream(path);
  try {
    final archive = _readLocalArchive(input);
    final manifest = archive[_manifestName];
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
  } on ArchiveException {
    throw const FormatException('Invalid InkBox backup');
  } finally {
    input.closeSync();
  }
}

final _invalidMediaCharacter = RegExp(r'[\\/:<>"|?*\x00-\x1f\x7f]');
final _invalidArchiveCharacter = RegExp(r'[\\:\x00-\x1f]');
final _assetIndex = RegExp(r'^[1-9][0-9]*$');
final _windowsReservedName = RegExp(
  r'^(CON|PRN|AUX|NUL|COM[0-9]|LPT[0-9])(\.|$)',
  caseSensitive: false,
);

String _portableName(String value) {
  var name = value
      .replaceAll(_invalidMediaCharacter, '_')
      .replaceFirst(RegExp(r'[. ]+$'), '');
  if (name.isEmpty) name = '_';
  return _windowsReservedName.hasMatch(name) ? '_$name' : name;
}

String _uniquePortableName(String value, Set<String> usedNames) {
  var name = _portableName(value);
  final extension = p.extension(name);
  final base = name.substring(0, name.length - extension.length);
  for (var suffix = 2; !usedNames.add(name.toLowerCase()); suffix++) {
    name = '${base}_$suffix$extension';
  }
  return name;
}

bool _isMediaEntry(String name) {
  if (name.length > 4096) return false;
  final parts = name.replaceFirst(RegExp(r'/$'), '').split('/');
  return parts.length >= 3 &&
      parts.length <= 128 &&
      parts.first == 'media' &&
      _assetIndex.hasMatch(parts[1]) &&
      parts
          .skip(2)
          .every(
            (part) =>
                part.isNotEmpty &&
                part != '.' &&
                part != '..' &&
                !_invalidArchiveCharacter.hasMatch(part),
          );
}

Map<String, ArchiveFile> _readLocalArchive(InputFileStream input) =>
    readBackupZip(
      input,
      maxEntries: _archiveEntryLimit,
      maxEntryBytes: _mediaEntryLimit,
      maxTotalBytes: _mediaTotalLimit,
    );

class _BackupMediaOutput extends OutputFileStream {
  _BackupMediaOutput(String path, this.limit)
    : super.withFileHandle(FileHandle(path, mode: FileAccess.write));

  final int limit;

  void _check(int count) {
    if (count > limit - length) {
      throw const FormatException('Backup media exceeds the declared size');
    }
  }

  @override
  void writeByte(int value) {
    _check(1);
    super.writeByte(value);
  }

  @override
  void writeBytes(List<int> bytes, {int? length}) {
    _check(length ?? bytes.length);
    super.writeBytes(bytes, length: length);
  }

  @override
  void writeRange(Uint8List bytes, int start, int end) {
    _check(end - start);
    super.writeRange(bytes, start, end);
  }
}

Map<String, String> _extractMedia(
  ({String zipPath, String destination, Set<String> references}) args,
) {
  final (:zipPath, :destination, :references) = args;
  final input = InputFileStream(zipPath);
  try {
    final archive = _readLocalArchive(input);
    final directories = <String>{};
    for (final ref in references) {
      if (archive[ref]?.isFile == true) continue;
      if (archive['$ref/']?.isDirectory != true) {
        throw const FormatException('Backup media is missing');
      }
      directories.add('$ref/');
    }
    final paths = <String>{};
    final outputNames = <String, String>{};
    final siblingNames = <String, Set<String>>{};

    String portablePath(String input) {
      if (input.split('/').length <= 2) return input;
      final existing = outputNames[input];
      if (existing != null) return existing;
      final parent = portablePath(p.posix.dirname(input));
      final names = siblingNames.putIfAbsent(parent, () => <String>{});
      final name = _uniquePortableName(p.posix.basename(input), names);
      return outputNames[input] = '$parent/$name';
    }

    for (final entry in archive.values) {
      final name = entry.name;
      if (name == _manifestName) continue;
      if (!_isMediaEntry(name) || entry.isSymbolicLink) {
        throw const FormatException('Invalid backup archive entry');
      }
      final logicalName = name.replaceFirst(RegExp(r'/$'), '');
      if (!paths.add(logicalName)) {
        throw const FormatException('Conflicting backup media names');
      }
      if (!references.contains(name) && !directories.any(name.startsWith)) {
        continue;
      }
      final parts = portablePath(logicalName).split('/');
      final path = p.joinAll([destination, ...parts]);
      if (entry.isDirectory) {
        Directory(path).createSync(recursive: true);
        continue;
      }
      final file = File(path);
      file.parent.createSync(recursive: true);
      final output = _BackupMediaOutput(path, entry.size);
      try {
        entry.writeContent(output);
      } finally {
        output.closeSync();
      }
      if (file.lengthSync() != entry.size) {
        throw const FormatException('Incomplete backup media');
      }
    }
    return outputNames;
  } on ArchiveException {
    throw const FormatException('Invalid backup archive');
  } finally {
    input.closeSync();
  }
}
