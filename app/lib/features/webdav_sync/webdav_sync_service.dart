import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/db/app_database.dart';
import '../../data/ffi/rust_core_bridge.dart';
import '../../data/platform/library_storage.dart';
import 'webdav_client.dart';

class WebDavConfig {
  const WebDavConfig({
    this.serverUrl = '',
    this.username = '',
    this.password = '',
    this.remoteRoot = '/InkBox',
    this.presetName = '坚果云',
    this.syncProgress = true,
    this.syncMeta = true,
    this.syncPrefs = true,
    this.syncFiles = true,
    this.maxFileMb = 200,
    this.deviceId = 'android_inkbox_primary',
    this.deviceName = 'Android 本机',
  });

  final String serverUrl;
  final String username;
  final String password;
  final String remoteRoot;
  final String presetName;
  final bool syncProgress;
  final bool syncMeta;
  final bool syncPrefs;
  final bool syncFiles;
  final int maxFileMb;
  final String deviceId;
  final String deviceName;

  bool get isConfigured =>
      serverUrl.trim().isNotEmpty && username.trim().isNotEmpty;

  WebDavConfig copyWith({
    String? serverUrl,
    String? username,
    String? password,
    String? remoteRoot,
    String? presetName,
    bool? syncProgress,
    bool? syncMeta,
    bool? syncPrefs,
    bool? syncFiles,
    int? maxFileMb,
    String? deviceId,
    String? deviceName,
  }) {
    return WebDavConfig(
      serverUrl: serverUrl ?? this.serverUrl,
      username: username ?? this.username,
      password: password ?? this.password,
      remoteRoot: remoteRoot ?? this.remoteRoot,
      presetName: presetName ?? this.presetName,
      syncProgress: syncProgress ?? this.syncProgress,
      syncMeta: syncMeta ?? this.syncMeta,
      syncPrefs: syncPrefs ?? this.syncPrefs,
      syncFiles: syncFiles ?? this.syncFiles,
      maxFileMb: maxFileMb ?? this.maxFileMb,
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
    );
  }

  Map<String, dynamic> toJson() => {
        'serverUrl': serverUrl,
        'username': username,
        'password': password,
        'remoteRoot': remoteRoot,
        'presetName': presetName,
        'syncProgress': syncProgress,
        'syncMeta': syncMeta,
        'syncPrefs': syncPrefs,
        'syncFiles': syncFiles,
        'maxFileMb': maxFileMb,
        'deviceId': deviceId,
        'deviceName': deviceName,
      };

  factory WebDavConfig.fromJson(Map<String, dynamic> j) => WebDavConfig(
        serverUrl: j['serverUrl'] as String? ?? '',
        username: j['username'] as String? ?? '',
        password: j['password'] as String? ?? '',
        remoteRoot: j['remoteRoot'] as String? ?? '/InkBox',
        presetName: j['presetName'] as String? ?? '坚果云',
        syncProgress: j['syncProgress'] as bool? ?? true,
        syncMeta: j['syncMeta'] as bool? ?? true,
        syncPrefs: j['syncPrefs'] as bool? ?? true,
        syncFiles: j['syncFiles'] as bool? ?? true,
        maxFileMb: (j['maxFileMb'] as num?)?.toInt() ?? 200,
        deviceId: j['deviceId'] as String? ?? 'android_inkbox_primary',
        deviceName: j['deviceName'] as String? ?? 'Android 本机',
      );
}

class ProgressConflict {
  const ProgressConflict({
    required this.contentHash,
    required this.title,
    required this.mediaKind,
    required this.localLocator,
    required this.localProgress,
    required this.localUpdatedMs,
    required this.localDeviceName,
    required this.remoteLocator,
    required this.remoteProgress,
    required this.remoteUpdatedMs,
    required this.remoteDeviceName,
  });

  final String contentHash;
  final String title;
  final String mediaKind;
  final String localLocator;
  final double localProgress;
  final int localUpdatedMs;
  final String localDeviceName;
  final String remoteLocator;
  final double remoteProgress;
  final int remoteUpdatedMs;
  final String remoteDeviceName;
}

class WebDavSyncReport {
  const WebDavSyncReport({
    required this.progressAdopted,
    required this.progressUploaded,
    required this.annotationsMerged,
    required this.filesUploaded,
    required this.conflicts,
  });

  final int progressAdopted;
  final int progressUploaded;
  final int annotationsMerged;
  final int filesUploaded;
  final List<ProgressConflict> conflicts;
}

/// Complete V1.0 Layer 1 (incremental JSON progress/annotations/shelves/prefs +
/// conflict evaluation + backup snapshots) and Layer 2 (on-demand deduplicated
/// binary book/comic file sync) orchestrator.
class WebDavSyncService {
  WebDavSyncService({
    required this.db,
    this.rustCore,
    this.tempDirOverride,
  });

  final AppDatabase db;
  final RustCoreBridge? rustCore;
  final String? tempDirOverride;

  static const _kConfigKey = 'inkbox_webdav_config_v1';

  Future<WebDavConfig> loadConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kConfigKey);
      if (raw != null && raw.isNotEmpty) {
        return WebDavConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      }
    } catch (_) {}
    return const WebDavConfig();
  }

  Future<void> saveConfig(WebDavConfig cfg) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kConfigKey, jsonEncode(cfg.toJson()));
  }

  WebDavClient _makeClient(WebDavConfig cfg) {
    return WebDavClient(
      baseUrl: cfg.serverUrl,
      username: cfg.username,
      password: cfg.password,
    );
  }

  Future<void> testConnection(WebDavConfig cfg) async {
    final client = _makeClient(cfg);
    try {
      await client.ping(cfg.remoteRoot);
      await client.ensureDirectory('${cfg.remoteRoot}/sync');
      await client.ensureDirectory('${cfg.remoteRoot}/library_files');
      await client.ensureDirectory('${cfg.remoteRoot}/backups');
    } finally {
      client.close();
    }
  }

  String _evaluateMerge(
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
    int lastSyncedMs,
  ) {
    if (rustCore != null) {
      try {
        return rustCore!.evaluateProgressMerge(
          local: local,
          remote: remote,
          lastSyncedEpochMs: lastSyncedMs,
        );
      } catch (_) {}
    }
    final localTs = (local['updated_at_epoch_ms'] as num).toInt();
    final remoteTs = (remote['updated_at_epoch_ms'] as num).toInt();
    if (local['locator'] == remote['locator']) return 'KeepLocal';
    final lDirty = localTs > lastSyncedMs;
    final rDirty = remoteTs > lastSyncedMs;
    if (!lDirty && rDirty) return 'AdoptRemote';
    if (lDirty && !rDirty) return 'KeepLocal';
    if (lDirty && rDirty && local['device_id'] != remote['device_id']) {
      return 'Conflict';
    }
    return remoteTs > localTs ? 'AdoptRemote' : 'KeepLocal';
  }

  List<Map<String, dynamic>> _mergeAnnotations(
    List<Map<String, dynamic>> local,
    List<Map<String, dynamic>> remote,
  ) {
    if (rustCore != null) {
      try {
        return rustCore!.mergeAnnotations(local: local, remote: remote);
      } catch (_) {}
    }
    final map = <String, Map<String, dynamic>>{};
    for (final r in local) {
      map[r['uuid'] as String] = r;
    }
    for (final r in remote) {
      final uuid = r['uuid'] as String;
      final prev = map[uuid];
      if (prev == null ||
          (r['updated_at_epoch_ms'] as num) >
              (prev['updated_at_epoch_ms'] as num)) {
        map[uuid] = r;
      }
    }
    return map.values.toList();
  }

  /// Runs bidirectional Layer 1 + optional Layer 2 synchronization.
  Future<WebDavSyncReport> syncAll(
    WebDavConfig cfg, {
    Map<String, dynamic>? localPreferencesSnapshot,
  }) async {
    final client = _makeClient(cfg);
    final root = cfg.remoteRoot.replaceFirst(RegExp(r'/$'), '');
    final now = DateTime.now().millisecondsSinceEpoch;

    var progressAdopted = 0;
    var progressUploaded = 0;
    var annotationsMerged = 0;
    var filesUploaded = 0;
    final conflicts = <ProgressConflict>[];

    try {
      await client.ensureDirectory('$root/sync');
      await client.ensureDirectory('$root/library_files');
      await client.ensureDirectory('$root/backups');

      final books = await db.getAllBooks();
      final mangas = await db.getAllMangas();
      final titleByHash = <String, String>{
        for (final b in books) b.contentHash: b.title,
        for (final m in mangas) m.contentHash: m.title,
      };

      // --- Layer 1A: Progress Index bidirectional merge ---
      if (cfg.syncProgress) {
        final remoteRaw = await client.getString('$root/sync/progress_index.json');
        final remoteMap = <String, Map<String, dynamic>>{};
        if (remoteRaw != null && remoteRaw.isNotEmpty) {
          final parsed = jsonDecode(remoteRaw) as Map<String, dynamic>;
          final records = parsed['records'] as Map<String, dynamic>? ?? const {};
          records.forEach((k, v) {
            remoteMap[k] = Map<String, dynamic>.from(v as Map);
          });
        }

        final localStates = await db.getAllSyncStates();
        final localMap = <String, SyncState>{
          for (final s in localStates) s.contentHash: s,
        };

        final mergedRemoteRecords = <String, Map<String, dynamic>>{...remoteMap};
        final allHashes = {...localMap.keys, ...remoteMap.keys};

        for (final hash in allHashes) {
          final localState = localMap[hash];
          final remoteRec = remoteMap[hash];

          if (localState != null && remoteRec == null) {
            mergedRemoteRecords[hash] = _syncStateToJson(localState, cfg);
            await db.markSyncStateSynced(hash, now);
            progressUploaded++;
          } else if (localState == null && remoteRec != null) {
            await _applyRemoteProgress(hash, remoteRec, now);
            progressAdopted++;
          } else if (localState != null && remoteRec != null) {
            final localJson = _syncStateToJson(localState, cfg);
            final outcome = _evaluateMerge(
              localJson,
              remoteRec,
              localState.lastSyncedAtMs,
            );
            if (outcome == 'AdoptRemote') {
              await _applyRemoteProgress(hash, remoteRec, now);
              progressAdopted++;
            } else if (outcome == 'KeepLocal') {
              mergedRemoteRecords[hash] = localJson;
              await db.markSyncStateSynced(hash, now);
              progressUploaded++;
            } else {
              conflicts.add(
                ProgressConflict(
                  contentHash: hash,
                  title: titleByHash[hash] ?? hash,
                  mediaKind: localState.mediaKind,
                  localLocator: localState.locator,
                  localProgress: localState.progressRatio,
                  localUpdatedMs: localState.updatedAtMs,
                  localDeviceName: localState.deviceName,
                  remoteLocator: remoteRec['locator'] as String? ?? '',
                  remoteProgress:
                      (remoteRec['progress_ratio'] as num?)?.toDouble() ?? 0.0,
                  remoteUpdatedMs:
                      (remoteRec['updated_at_epoch_ms'] as num?)?.toInt() ?? 0,
                  remoteDeviceName:
                      remoteRec['device_name'] as String? ?? '其他设备',
                ),
              );
            }
          }
        }

        await client.putString(
          '$root/sync/progress_index.json',
          jsonEncode({
            'schema_version': 1,
            'updated_at_ms': now,
            'records': mergedRemoteRecords,
          }),
        );
      }

      // --- Layer 1B: Annotations UUID LWW three-way merge ---
      if (cfg.syncMeta) {
        final localAnns = (await db.getAllAnnotations())
            .map((a) => {
                  'uuid': a.uuid,
                  'content_hash': a.contentHash,
                  'media_kind': a.mediaKind,
                  'kind': a.kind,
                  'chapter_index': a.chapterIndex,
                  'locator': a.locator,
                  'excerpt': a.excerpt,
                  'note_text': a.noteText,
                  'color_hex': a.colorHex,
                  'is_deleted': a.isDeleted,
                  'updated_at_epoch_ms': a.updatedAtMs,
                })
            .toList();

        final remoteAnnRaw = await client.getString('$root/sync/annotations.json');
        final remoteAnns = remoteAnnRaw != null && remoteAnnRaw.isNotEmpty
            ? ((jsonDecode(remoteAnnRaw) as Map<String, dynamic>)['items']
                    as List<dynamic>? ??
                const [])
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList()
            : <Map<String, dynamic>>[];

        final merged = _mergeAnnotations(localAnns, remoteAnns);
        for (final item in merged) {
          await db.upsertAnnotation(
            AnnotationsCompanion.insert(
              uuid: item['uuid'] as String,
              contentHash: item['content_hash'] as String,
              mediaKind: item['media_kind'] as String? ?? 'book',
              kind: item['kind'] as String? ?? 'bookmark',
              chapterIndex: Value((item['chapter_index'] as num?)?.toInt() ?? 0),
              locator: item['locator'] as String? ?? '',
              excerpt: Value(item['excerpt'] as String? ?? ''),
              noteText: Value(item['note_text'] as String? ?? ''),
              colorHex: Value(item['color_hex'] as String? ?? '#EED29A'),
              isDeleted: Value(item['is_deleted'] as bool? ?? false),
              updatedAtMs: (item['updated_at_epoch_ms'] as num?)?.toInt() ?? now,
            ),
          );
        }
        annotationsMerged = merged.length;

        await client.putString(
          '$root/sync/annotations.json',
          jsonEncode({'updated_at_ms': now, 'items': merged}),
        );

        final bookShelves = await db.getShelves('book');
        final mangaShelves = await db.getShelves('comic');
        // Library metadata manifest
        await client.putString(
          '$root/sync/library_meta.json',
          jsonEncode({
            'updated_at_ms': now,
            'shelves': [...bookShelves, ...mangaShelves]
                .map((s) => {
                      'id': s.id,
                      'name': s.name,
                      'media_kind': s.mediaKind,
                      'is_default': s.isDefault,
                    })
                .toList(),
            'books': books
                .map((b) => {
                      'content_hash': b.contentHash,
                      'title': b.title,
                      'author': b.author,
                      'format': b.format,
                      'shelf_id': b.shelfId,
                      'shelf_group': b.shelfGroup,
                      'is_pinned': b.isPinned,
                    })
                .toList(),
            'mangas': mangas
                .map((m) => {
                      'content_hash': m.contentHash,
                      'title': m.title,
                      'author': m.author,
                      'format': m.format,
                      'shelf_id': m.shelfId,
                      'shelf_group': m.shelfGroup,
                      'preferred_reading_mode': m.preferredReadingMode,
                      'is_pinned': m.isPinned,
                    })
                .toList(),
          }),
        );
      }

      // --- Layer 1C: Reader Preferences Snapshot ---
      if (cfg.syncPrefs && localPreferencesSnapshot != null) {
        await client.putString(
          '$root/sync/preferences.json',
          jsonEncode({
            'updated_at_ms': now,
            'preferences': localPreferencesSnapshot,
          }),
        );
      }

      // --- Layer 2: Deduplicated On-Demand Source File Upload ---
      if (cfg.syncFiles) {
        final maxBytes = cfg.maxFileMb * 1024 * 1024;
        final storage = LibraryStorage();
        for (final book in books) {
          if (book.cloudFileSynced) continue;
          ReadableMedia media;
          try {
            media = await storage.open(book.filePath, extension: book.format);
          } catch (_) {
            continue;
          }
          try {
            final f = File(media.path);
            if (!await f.exists() || await f.length() > maxBytes) continue;
            final ext = p.extension(media.path).replaceFirst('.', '').toLowerCase();
            final remotePath =
                '$root/library_files/${book.contentHash}.${ext.isEmpty ? "bin" : ext}';
            if (!await client.exists(remotePath)) {
              await client.putFile(remotePath, f);
              filesUploaded++;
            }
            await db.updateBookMeta(book.id, cloudFileSynced: true);
          } finally {
            await media.close();
          }
        }
      }
    } finally {
      client.close();
    }

    return WebDavSyncReport(
      progressAdopted: progressAdopted,
      progressUploaded: progressUploaded,
      annotationsMerged: annotationsMerged,
      filesUploaded: filesUploaded,
      conflicts: conflicts,
    );
  }

  /// Resolves a user-selected conflict decision and writes final state to both DB & WebDAV.
  Future<void> resolveConflict(
    WebDavConfig cfg,
    ProgressConflict conflict, {
    required bool adoptRemote,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final chosenLocator =
        adoptRemote ? conflict.remoteLocator : conflict.localLocator;
    final chosenProgress =
        adoptRemote ? conflict.remoteProgress : conflict.localProgress;
    final chosenDevice =
        adoptRemote ? conflict.remoteDeviceName : conflict.localDeviceName;

    await _applyRemoteProgress(
      conflict.contentHash,
      {
        'media_kind': conflict.mediaKind,
        'locator': chosenLocator,
        'progress_ratio': chosenProgress,
        'updated_at_epoch_ms': now,
        'device_id': cfg.deviceId,
        'device_name': chosenDevice,
      },
      now,
    );

    if (!cfg.isConfigured) return;
    final client = _makeClient(cfg);
    final root = cfg.remoteRoot.replaceFirst(RegExp(r'/$'), '');
    try {
      final raw = await client.getString('$root/sync/progress_index.json');
      final records = <String, dynamic>{};
      if (raw != null && raw.isNotEmpty) {
        final parsed = jsonDecode(raw) as Map<String, dynamic>;
        records.addAll(parsed['records'] as Map<String, dynamic>? ?? const {});
      }
      records[conflict.contentHash] = {
        'content_hash': conflict.contentHash,
        'media_kind': conflict.mediaKind,
        'locator': chosenLocator,
        'progress_ratio': chosenProgress,
        'updated_at_epoch_ms': now,
        'device_id': cfg.deviceId,
        'device_name': cfg.deviceName,
      };
      await client.putString(
        '$root/sync/progress_index.json',
        jsonEncode({'schema_version': 1, 'updated_at_ms': now, 'records': records}),
      );
    } finally {
      client.close();
    }
  }

  /// Creates a compressed `.zip` backup snapshot of all Layer 1 data and uploads it.
  Future<String> createBackupSnapshot(
    WebDavConfig cfg, {
    Map<String, dynamic>? preferences,
  }) async {
    final now = DateTime.now();
    final stamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    final fileName = 'inkbox_backup_$stamp.zip';

    final books = await db.getAllBooks();
    final mangas = await db.getAllMangas();
    final bookShelves = await db.getShelves('book');
    final mangaShelves = await db.getShelves('comic');
    final anns = await db.getAllAnnotations();
    final states = await db.getAllSyncStates();

    final files = <String, String>{
      'sync/library_meta.json': jsonEncode({
        'shelves': [...bookShelves, ...mangaShelves]
            .map((s) => s.toJson())
            .toList(),
        'books': books.map((b) => b.toJson()).toList(),
        'mangas': mangas.map((m) => m.toJson()).toList(),
      }),
      'sync/progress_index.json': jsonEncode({
        'records': {
          for (final s in states) s.contentHash: _syncStateToJson(s, cfg),
        },
      }),
      'sync/annotations.json': jsonEncode({
        'items': anns.map((a) => a.toJson()).toList(),
      }),
      if (preferences != null) 'sync/preferences.json': jsonEncode(preferences),
    };

    final tmpDir = tempDirOverride ?? (await getTemporaryDirectory()).path;
    final zipFile = File(p.join(tmpDir, fileName));

    if (rustCore != null) {
      rustCore!.packSnapshotZip(files: files, outputZipPath: zipFile.path);
    } else {
      await zipFile.writeAsString(jsonEncode(files));
    }

    final client = _makeClient(cfg);
    final root = cfg.remoteRoot.replaceFirst(RegExp(r'/$'), '');
    try {
      await client.ensureDirectory('$root/backups');
      await client.putFile('$root/backups/$fileName', zipFile);
    } finally {
      client.close();
      if (zipFile.existsSync()) zipFile.deleteSync();
    }
    return fileName;
  }

  Future<List<WebDavEntry>> listBackupSnapshots(WebDavConfig cfg) async {
    final client = _makeClient(cfg);
    final root = cfg.remoteRoot.replaceFirst(RegExp(r'/$'), '');
    try {
      final list = await client.listDirectory('$root/backups');
      return list.where((e) => !e.isDirectory && e.name.endsWith('.zip')).toList()
        ..sort((a, b) => b.name.compareTo(a.name));
    } finally {
      client.close();
    }
  }

  Future<int> restoreBackupSnapshot(WebDavConfig cfg, String fileName) async {
    final tmpDir = tempDirOverride ?? (await getTemporaryDirectory()).path;
    final zipFile = File(p.join(tmpDir, 'restore_$fileName'));
    final client = _makeClient(cfg);
    final root = cfg.remoteRoot.replaceFirst(RegExp(r'/$'), '');
    try {
      final ok = await client.downloadFile('$root/backups/$fileName', zipFile);
      if (!ok) return 0;

      final Map<String, String> unpacked;
      if (rustCore != null) {
        unpacked = rustCore!.unpackSnapshotZip(zipFile.path);
      } else {
        unpacked = Map<String, String>.from(
          jsonDecode(await zipFile.readAsString()) as Map,
        );
      }

      var restoredCount = 0;
      final now = DateTime.now().millisecondsSinceEpoch;

      final metaRaw = unpacked['sync/library_meta.json'];
      if (metaRaw != null && metaRaw.isNotEmpty) {
        final parsedMeta = jsonDecode(metaRaw) as Map<String, dynamic>;
        final rawShelves = parsedMeta['shelves'] as List<dynamic>? ?? const [];
        for (final s in rawShelves) {
          final m = Map<String, dynamic>.from(s as Map);
          final name = (m['name'] as String? ?? '').trim();
          final kind =
              (m['mediaKind'] ?? m['media_kind'] ?? 'book').toString().trim();
          final isDef = (m['isDefault'] ?? m['is_default']) == true;
          if (name.isNotEmpty && !isDef) {
            await db.createShelf(name, kind == 'comic' ? 'comic' : 'book');
          }
        }
      }

      final annRaw = unpacked['sync/annotations.json'];
      if (annRaw != null && annRaw.isNotEmpty) {
        final items = (jsonDecode(annRaw) as Map<String, dynamic>)['items']
                as List<dynamic>? ??
            const [];
        for (final raw in items) {
          final m = Map<String, dynamic>.from(raw as Map);
          final uuid = (m['uuid'] as String? ?? '').trim();
          final hash =
              (m['contentHash'] ?? m['content_hash'] ?? '').toString().trim();
          if (uuid.isEmpty || hash.isEmpty) continue;
          await db.upsertAnnotation(
            AnnotationsCompanion.insert(
              uuid: uuid,
              contentHash: hash,
              mediaKind:
                  (m['mediaKind'] ?? m['media_kind'] ?? 'book').toString(),
              kind: (m['kind'] ?? 'bookmark').toString(),
              chapterIndex: Value(
                ((m['chapterIndex'] ?? m['chapter_index']) as num?)?.toInt() ??
                    0,
              ),
              locator: (m['locator'] ?? '').toString(),
              excerpt: Value((m['excerpt'] ?? '').toString()),
              noteText: Value(
                (m['noteText'] ?? m['note_text'] ?? '').toString(),
              ),
              colorHex: Value(
                (m['colorHex'] ?? m['color_hex'] ?? '#EED29A').toString(),
              ),
              isDeleted: Value((m['isDeleted'] ?? m['is_deleted']) == true),
              updatedAtMs:
                  ((m['updatedAtMs'] ?? m['updated_at_epoch_ms']) as num?)
                          ?.toInt() ??
                      now,
            ),
          );
        }
      }

      final progRaw = unpacked['sync/progress_index.json'];
      if (progRaw != null) {
        final records =
            (jsonDecode(progRaw) as Map<String, dynamic>)['records']
                as Map<String, dynamic>? ??
                const {};
        for (final entry in records.entries) {
          await _applyRemoteProgress(
            entry.key,
            Map<String, dynamic>.from(entry.value as Map),
            now,
          );
          restoredCount++;
        }
      }
      return restoredCount;
    } finally {
      client.close();
      if (zipFile.existsSync()) zipFile.deleteSync();
    }
  }

  Map<String, dynamic> _syncStateToJson(SyncState s, WebDavConfig cfg) => {
        'content_hash': s.contentHash,
        'media_kind': s.mediaKind,
        'locator': s.locator,
        'progress_ratio': s.progressRatio,
        'updated_at_epoch_ms': s.updatedAtMs,
        'device_id': s.deviceId == 'local_device' ? cfg.deviceId : s.deviceId,
        'device_name': s.deviceName.isEmpty ? cfg.deviceName : s.deviceName,
      };

  Future<void> _applyRemoteProgress(
    String contentHash,
    Map<String, dynamic> remote,
    int syncedAtMs,
  ) async {
    final mediaKind = remote['media_kind'] as String? ?? 'book';
    final locator = remote['locator'] as String? ?? '';
    final ratio = (remote['progress_ratio'] as num?)?.toDouble() ?? 0.0;
    final updatedMs =
        (remote['updated_at_epoch_ms'] as num?)?.toInt() ?? syncedAtMs;

    await db.applySyncedBookProgress(
      contentHash: contentHash,
      mediaKind: mediaKind,
      locator: locator,
      progressRatio: ratio,
      updatedAtMs: updatedMs,
      lastSyncedAtMs: syncedAtMs,
      deviceId: remote['device_id'] as String? ?? 'remote',
      deviceName: remote['device_name'] as String? ?? '云端设备',
    );
  }
}
