import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:archive/archive_io.dart';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/backup/backup_zip.dart';
import '../../data/db/app_database.dart';
import '../../data/ffi/rust_core_bridge.dart';
import '../../data/platform/library_storage.dart';
import '../../data/platform/platform_bridge.dart';
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
    this.deviceId = '',
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
    deviceId: j['deviceId'] as String? ?? '',
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
    PlatformBridge? platform,
  }) : _platform = platform ?? MethodChannelPlatformBridge();

  final AppDatabase db;
  final RustCoreBridge? rustCore;
  final String? tempDirOverride;
  final PlatformBridge _platform;

  static const _kConfigKey = 'inkbox_webdav_config_v1';
  static const _kDeviceId = 'inkbox_webdav_device_id';
  static const _kPassword = 'webdav_password';
  static const _snapshotEntryLimit = 16 * 1024 * 1024;
  static const _snapshotTotalLimit = 32 * 1024 * 1024;
  static final _snapshotName = RegExp(
    r'^[a-zA-Z0-9][a-zA-Z0-9._-]{0,190}\.zip$',
  );
  static Future<String>? _creatingDeviceId;

  Future<WebDavConfig> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kConfigKey);
    var config = const WebDavConfig();
    if (raw != null && raw.isNotEmpty) {
      try {
        config = WebDavConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } on FormatException {
        // An invalid configuration has the same defaults as a fresh install.
      } on TypeError {
        // Older or malformed preferences may have incompatible field types.
      }
    }
    config = await _withDeviceIdentity(config);
    final password = await _platform.readSecret(_kPassword);
    if (password != null) {
      if (config.password.isNotEmpty) {
        await prefs.setString(_kConfigKey, jsonEncode(config.toJson()));
      }
      return config.copyWith(password: password);
    }
    if (config.password.isNotEmpty) {
      await _platform.saveSecret(_kPassword, config.password);
      if (await _platform.readSecret(_kPassword) == config.password) {
        await prefs.setString(_kConfigKey, jsonEncode(config.toJson()));
      }
    }
    return config;
  }

  Future<void> saveConfig(WebDavConfig cfg) async {
    final config = await _withDeviceIdentity(cfg);
    if (config.password.isEmpty) {
      await _platform.deleteSecret(_kPassword);
    } else {
      await _platform.saveSecret(_kPassword, config.password);
      if (await _platform.readSecret(_kPassword) != config.password) {
        throw StateError('ERR_SECURE_STORAGE');
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kConfigKey, jsonEncode(config.toJson()));
  }

  Future<WebDavConfig> _withDeviceIdentity(WebDavConfig config) async {
    if (config.deviceId.isNotEmpty &&
        config.deviceId != 'android_inkbox_primary') {
      return config;
    }
    final pending = _creatingDeviceId;
    if (pending != null) return config.copyWith(deviceId: await pending);
    final operation = _loadOrCreateDeviceId();
    _creatingDeviceId = operation;
    try {
      return config.copyWith(deviceId: await operation);
    } finally {
      _creatingDeviceId = null;
    }
  }

  Future<String> _loadOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_kDeviceId);
    if (existing != null && existing.isNotEmpty) return existing;
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final id = [
      hex.substring(0, 8),
      hex.substring(8, 12),
      hex.substring(12, 16),
      hex.substring(16, 20),
      hex.substring(20),
    ].join('-');
    await prefs.setString(_kDeviceId, id);
    return id;
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
    if (local['locator'] == remote['locator']) {
      return remoteTs > localTs ? 'AdoptRemote' : 'KeepLocal';
    }
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

  static Map<String, dynamic> _jsonObject(String raw) =>
      Map<String, dynamic>.from(jsonDecode(raw) as Map);

  static Iterable<Map<String, dynamic>> _rows(
    Map<String, dynamic> metadata,
    String key,
  ) => (metadata[key] as List? ?? const []).whereType<Map>().map(
    Map<String, dynamic>.from,
  );

  Future<Map<String, dynamic>> _libraryMetadata() async => {
    'shelves': [
      ...await db.getShelves('book'),
      ...await db.getShelves('comic'),
    ].map((shelf) => shelf.toJson()).toList(),
    'books': (await db.getAllBooks())
        .map(
          (book) => {
            'content_hash': book.contentHash,
            'title': book.title,
            'author': book.author,
            'format': book.format,
            'shelf_id': book.shelfId,
            'shelf_group': book.shelfGroup,
            'is_pinned': book.isPinned,
          },
        )
        .toList(),
    'mangas': (await db.getAllMangas())
        .map(
          (manga) => {
            'content_hash': manga.contentHash,
            'title': manga.title,
            'author': manga.author,
            'format': manga.format,
            'shelf_id': manga.shelfId,
            'shelf_group': manga.shelfGroup,
            'preferred_reading_mode': manga.preferredReadingMode,
            'is_pinned': manga.isPinned,
          },
        )
        .toList(),
  };

  Future<Map<String, dynamic>> _mergeLibraryMetadata(
    Map<String, dynamic> remote,
    Map<String, dynamic> local, {
    bool restoring = false,
  }) => db.transaction(() async {
    final shelfIds = <(String, String?), int>{};
    final localShelves = {
      for (final shelf in [
        ...await db.getShelves('book'),
        ...await db.getShelves('comic'),
      ])
        (shelf.mediaKind, shelf.isDefault ? null : shelf.name.trim()): shelf.id,
    };
    final outShelves = <Map<String, dynamic>>[];

    Map<int, (String, String?)> mergeShelves(Map<String, dynamic> meta) {
      final aliases = <int, (String, String?)>{};
      for (final row in _rows(meta, 'shelves')) {
        final kind = row['media_kind'] ?? row['mediaKind'];
        final name = (row['name'] as String? ?? '').trim();
        final id = row['id'];
        if (id is! int || (kind != 'comic' && kind != 'book') || name.isEmpty) {
          continue;
        }
        final isDefault = row['is_default'] == true || row['isDefault'] == true;
        final key = (kind as String, isDefault ? null : name);
        aliases[id] = key;
        if (shelfIds.containsKey(key)) continue;
        final outId = shelfIds.length + 1;
        shelfIds[key] = outId;
        outShelves.add({
          'id': outId,
          'name': name,
          'media_kind': kind,
          'is_default': isDefault,
        });
      }
      return aliases;
    }

    final remoteAliases = mergeShelves(remote);
    final localAliases = mergeShelves(local);
    for (final key in remoteAliases.values.toSet()) {
      final (kind, name) = key;
      if (name == null || localShelves.containsKey(key)) continue;
      final shelf = await db.createShelf(name, kind);
      if (shelf != null) localShelves[key] = shelf.id;
    }

    Future<List<Map<String, dynamic>>> mergeItems(String table) async {
      final kind = table == 'books' ? 'book' : 'comic';
      final output = <String, Map<String, dynamic>>{};
      final incoming = <String, ((String, String?)?, Map<String, dynamic>)>{};
      for (final row in _rows(remote, table)) {
        final hash = row['content_hash'] ?? row['contentHash'];
        if (hash is! String || hash.isEmpty) continue;
        final shelf = remoteAliases[row['shelf_id'] ?? row['shelfId']];
        final key = shelf?.$1 == kind ? shelf : null;
        incoming[hash] = (key, row);
        output[hash] = {
          ...row,
          'content_hash': hash,
          'shelf_id': shelfIds[key],
        };
      }
      for (final row in _rows(local, table)) {
        final hash = row['content_hash'] as String;
        final shelf = localAliases[row['shelf_id']];
        final remoteItem = incoming[hash];
        final remoteShelf = remoteItem?.$1;
        if (remoteItem != null &&
            (restoring || (shelf?.$2 == null && remoteShelf?.$2 != null))) {
          final targetId = localShelves[remoteShelf];
          final remoteRow = remoteItem.$2;
          final group = restoring
              ? (remoteRow['shelf_group'] ?? remoteRow['shelfGroup']) as String?
              : null;
          final pinned = restoring
              ? (remoteRow['is_pinned'] ?? remoteRow['isPinned']) as bool?
              : null;
          if (table == 'books') {
            final book = await db.findBookByHash(hash);
            if (book != null) {
              await db.updateBookMeta(
                book.id,
                shelfId: targetId,
                shelfGroup: group,
                isPinned: pinned,
              );
            }
          } else {
            final manga = await db.findMangaByHash(hash);
            if (manga != null) {
              await db.updateMangaMeta(
                manga.id,
                shelfId: targetId,
                shelfGroup: group,
                isPinned: pinned,
                preferredReadingMode: restoring
                    ? (remoteRow['preferred_reading_mode'] ??
                              remoteRow['preferredReadingMode'])
                          as String?
                    : null,
              );
            }
          }
          output[hash] = {...row, 'shelf_id': shelfIds[remoteShelf]};
        } else {
          output[hash] = {...row, 'shelf_id': shelfIds[shelf]};
        }
      }
      return output.values.toList();
    }

    return {
      'shelves': outShelves,
      'books': await mergeItems('books'),
      'mangas': await mergeItems('mangas'),
    };
  });

  Future<void> _syncPreferences(
    WebDavClient client,
    String path,
    WebDavConfig cfg,
    int now,
    Map<String, dynamic> local,
    Future<void> Function(Map<String, dynamic>)? applyPreferences,
  ) async {
    final encoded = jsonEncode(local);
    final remoteRaw = await client.getString(path);
    final remote = remoteRaw == null
        ? null
        : _jsonObject(remoteRaw)['preferences'] as Map<String, dynamic>?;
    SharedPreferences? prefs;
    final server = base64Url.encode(
      utf8.encode('${cfg.serverUrl}\n${cfg.username}\n$path'),
    );
    final key = 'inkbox_webdav_preferences_$server';
    if (applyPreferences != null) {
      prefs = await SharedPreferences.getInstance();
      final last = prefs.getString(key);
      if (remote != null && (last == null || encoded == last)) {
        final remoteEncoded = jsonEncode(remote);
        if (remoteEncoded != encoded) await applyPreferences(remote);
        await prefs.setString(key, remoteEncoded);
        return;
      }
    }
    if (remote == null || jsonEncode(remote) != encoded) {
      await client.putString(
        path,
        jsonEncode({'updated_at_ms': now, 'preferences': local}),
      );
    }
    await prefs?.setString(key, encoded);
  }

  /// Runs bidirectional Layer 1 + optional Layer 2 synchronization.
  Future<WebDavSyncReport> syncAll(
    WebDavConfig config, {
    Map<String, dynamic>? localPreferencesSnapshot,
    Future<void> Function(Map<String, dynamic>)? applyPreferences,
  }) async {
    final cfg = await _withDeviceIdentity(config);
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
        final remoteRaw = await client.getString(
          '$root/sync/progress_index.json',
        );
        final remoteMap = <String, Map<String, dynamic>>{};
        if (remoteRaw != null && remoteRaw.isNotEmpty) {
          final parsed = jsonDecode(remoteRaw) as Map<String, dynamic>;
          final records =
              parsed['records'] as Map<String, dynamic>? ?? const {};
          records.forEach((k, v) {
            remoteMap[k] = Map<String, dynamic>.from(v as Map);
          });
        }

        final localStates = await db.getAllSyncStates();
        final localMap = <String, SyncState>{
          for (final s in localStates) s.contentHash: s,
        };

        final mergedRemoteRecords = <String, Map<String, dynamic>>{
          ...remoteMap,
        };
        final allHashes = {...localMap.keys, ...remoteMap.keys};
        final uploadedStates = <SyncState>[];

        for (final hash in allHashes) {
          final localState = localMap[hash];
          final remoteRec = remoteMap[hash];

          if (localState != null && remoteRec == null) {
            mergedRemoteRecords[hash] = _syncStateToJson(localState, cfg);
            uploadedStates.add(localState);
            progressUploaded++;
          } else if (localState == null && remoteRec != null) {
            if (await _adoptProgress(hash, remoteRec, now, localState)) {
              progressAdopted++;
            }
          } else if (localState != null && remoteRec != null) {
            final localJson = _syncStateToJson(localState, cfg);
            final outcome = _evaluateMerge(
              localJson,
              remoteRec,
              localState.lastSyncedAtMs,
            );
            if (outcome == 'AdoptRemote') {
              if (await _adoptProgress(hash, remoteRec, now, localState)) {
                progressAdopted++;
              }
            } else if (outcome == 'KeepLocal') {
              mergedRemoteRecords[hash] = localJson;
              uploadedStates.add(localState);
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
        for (final state in uploadedStates) {
          await db.markSyncStateSynced(
            state.contentHash,
            max(now, state.updatedAtMs),
            expectedUpdatedAtMs: state.updatedAtMs,
            expectedLocator: state.locator,
          );
        }
      }

      // --- Layer 1B: Annotations UUID LWW three-way merge ---
      if (cfg.syncMeta) {
        final localAnns = (await db.getAllAnnotations())
            .map(
              (a) => {
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
              },
            )
            .toList();

        final remoteAnnRaw = await client.getString(
          '$root/sync/annotations.json',
        );
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
              chapterIndex: Value(
                (item['chapter_index'] as num?)?.toInt() ?? 0,
              ),
              locator: item['locator'] as String? ?? '',
              excerpt: Value(item['excerpt'] as String? ?? ''),
              noteText: Value(item['note_text'] as String? ?? ''),
              colorHex: Value(item['color_hex'] as String? ?? '#EED29A'),
              isDeleted: Value(item['is_deleted'] as bool? ?? false),
              updatedAtMs:
                  (item['updated_at_epoch_ms'] as num?)?.toInt() ?? now,
            ),
          );
        }
        annotationsMerged = merged.length;

        await client.putString(
          '$root/sync/annotations.json',
          jsonEncode({'updated_at_ms': now, 'items': merged}),
        );

        final metaPath = '$root/sync/library_meta.json';
        final remoteMeta = await client.getString(metaPath);
        final localMeta = await _libraryMetadata();
        final mergedMeta = await _mergeLibraryMetadata(
          remoteMeta == null ? const {} : _jsonObject(remoteMeta),
          localMeta,
        );
        await client.putString(
          metaPath,
          jsonEncode({'updated_at_ms': now, ...mergedMeta}),
        );
      }

      // --- Layer 1C: Reader Preferences Snapshot ---
      if (cfg.syncPrefs && localPreferencesSnapshot != null) {
        await _syncPreferences(
          client,
          '$root/sync/preferences.json',
          cfg,
          now,
          localPreferencesSnapshot,
          applyPreferences,
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
            final ext = p
                .extension(media.path)
                .replaceFirst('.', '')
                .toLowerCase();
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
    WebDavConfig config,
    ProgressConflict conflict, {
    required bool adoptRemote,
  }) async {
    final cfg = await _withDeviceIdentity(config);
    final now = max(
      DateTime.now().millisecondsSinceEpoch,
      max(conflict.localUpdatedMs, conflict.remoteUpdatedMs) + 1,
    );
    final chosenLocator = adoptRemote
        ? conflict.remoteLocator
        : conflict.localLocator;
    final chosenProgress = adoptRemote
        ? conflict.remoteProgress
        : conflict.localProgress;
    final chosenDevice = adoptRemote
        ? conflict.remoteDeviceName
        : conflict.localDeviceName;

    final resolvedProgress = <String, dynamic>{
      'content_hash': conflict.contentHash,
      'media_kind': conflict.mediaKind,
      'locator': chosenLocator,
      'progress_ratio': chosenProgress,
      'updated_at_epoch_ms': now,
      'device_id': cfg.deviceId,
      'device_name': chosenDevice,
    };
    final existing = await db.getSyncState(conflict.contentHash);
    await _applyRemoteProgress(
      conflict.contentHash,
      resolvedProgress,
      now,
      lastSyncedAtMs: existing?.lastSyncedAtMs ?? 0,
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
      records[conflict.contentHash] = resolvedProgress;
      await client.putString(
        '$root/sync/progress_index.json',
        jsonEncode({
          'schema_version': 1,
          'updated_at_ms': now,
          'records': records,
        }),
      );
      await db.markSyncStateSynced(
        conflict.contentHash,
        now,
        expectedUpdatedAtMs: now,
        expectedLocator: chosenLocator,
      );
    } finally {
      client.close();
    }
  }

  /// Creates a compressed `.zip` backup snapshot of all Layer 1 data and uploads it.
  Future<String> createBackupSnapshot(
    WebDavConfig config, {
    Map<String, dynamic>? preferences,
  }) async {
    final cfg = await _withDeviceIdentity(config);
    final now = DateTime.now();
    final stamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    final subSecond = (now.microsecondsSinceEpoch % 1000000).toString().padLeft(
      6,
      '0',
    );
    final fileName = 'inkbox_backup_${stamp}_$subSecond.zip';

    final files = await db.transaction(() async {
      final anns = await db.getAllAnnotations();
      final states = await db.getAllSyncStates();
      return <String, String>{
        'sync/library_meta.json': jsonEncode(await _libraryMetadata()),
        'sync/progress_index.json': jsonEncode({
          'records': {
            for (final s in states) s.contentHash: _syncStateToJson(s, cfg),
          },
        }),
        'sync/annotations.json': jsonEncode({
          'items': anns.map((a) => a.toJson()).toList(),
        }),
        if (preferences != null)
          'sync/preferences.json': jsonEncode(preferences),
      };
    });

    final tmpDir = tempDirOverride ?? (await getTemporaryDirectory()).path;
    var remaining = _snapshotTotalLimit;
    for (final value in files.values) {
      final length = utf8.encode(value).length;
      if (length > _snapshotEntryLimit || length > remaining) {
        throw const FormatException('WebDAV backup exceeds the size limit');
      }
      remaining -= length;
    }
    final staging = await Directory(tmpDir).createTemp('inkbox-backup-');
    final zipFile = File(p.join(staging.path, fileName));
    final client = _makeClient(cfg);
    final root = cfg.remoteRoot.replaceFirst(RegExp(r'/$'), '');
    try {
      if (rustCore != null) {
        rustCore!.packSnapshotZip(files: files, outputZipPath: zipFile.path);
      } else {
        final encoder = ZipFileEncoder()..create(zipFile.path);
        try {
          for (final entry in files.entries) {
            encoder.addArchiveFile(ArchiveFile.string(entry.key, entry.value));
          }
        } finally {
          await encoder.close();
        }
      }
      await client.ensureDirectory('$root/backups');
      await client.putFile('$root/backups/$fileName', zipFile);
    } finally {
      client.close();
      await _deleteTemp(staging);
    }
    return fileName;
  }

  Future<List<WebDavEntry>> listBackupSnapshots(WebDavConfig cfg) async {
    final client = _makeClient(cfg);
    final root = cfg.remoteRoot.replaceFirst(RegExp(r'/$'), '');
    try {
      final list = await client.listDirectory('$root/backups');
      return list
          .where((e) => !e.isDirectory && _snapshotName.hasMatch(e.name))
          .toList()
        ..sort((a, b) => b.name.compareTo(a.name));
    } finally {
      client.close();
    }
  }

  Future<int> restoreBackupSnapshot(
    WebDavConfig cfg,
    String fileName, {
    Future<void> Function(Map<String, dynamic>)? applyPreferences,
  }) async {
    if (p.basename(fileName) != fileName || !_snapshotName.hasMatch(fileName)) {
      throw const FormatException('Invalid WebDAV backup name');
    }
    final tmpDir = tempDirOverride ?? (await getTemporaryDirectory()).path;
    final staging = await Directory(tmpDir).createTemp('inkbox-backup-');
    final zipFile = File(p.join(staging.path, fileName));
    final client = _makeClient(cfg);
    final root = cfg.remoteRoot.replaceFirst(RegExp(r'/$'), '');
    try {
      final ok = await client.downloadFile(
        '$root/backups/$fileName',
        zipFile,
        maxBytes: 2 * _snapshotTotalLimit,
      );
      if (!ok) return 0;

      final unpacked = await _unpackSnapshot(zipFile);
      final now = DateTime.now().millisecondsSinceEpoch;
      final metaRaw = unpacked['sync/library_meta.json'];
      final annRaw = unpacked['sync/annotations.json'];
      final progRaw = unpacked['sync/progress_index.json'];
      final prefRaw = unpacked['sync/preferences.json'];
      final preferences = prefRaw == null ? null : _jsonObject(prefRaw);
      final restoredCount = await db.transaction(() async {
        if (metaRaw != null && metaRaw.isNotEmpty) {
          await _mergeLibraryMetadata(
            _jsonObject(metaRaw),
            await _libraryMetadata(),
            restoring: true,
          );
        }

        if (annRaw != null && annRaw.isNotEmpty) {
          final annotationsById = {
            for (final row in await db.getAllAnnotations())
              row.uuid: (row.updatedAtMs, row.isDeleted),
          };
          for (final m in _rows(_jsonObject(annRaw), 'items')) {
            final uuid = (m['uuid'] as String? ?? '').trim();
            final hash = (m['contentHash'] ?? m['content_hash'] ?? '')
                .toString()
                .trim();
            if (uuid.isEmpty || hash.isEmpty) continue;
            final updatedAtMs =
                ((m['updatedAtMs'] ?? m['updated_at_epoch_ms']) as num?)
                    ?.toInt() ??
                0;
            final deleted = (m['isDeleted'] ?? m['is_deleted']) == true;
            final current = annotationsById[uuid];
            if (current != null &&
                (current.$1 > updatedAtMs ||
                    (current.$1 == updatedAtMs && (current.$2 || !deleted)))) {
              continue;
            }
            await db.upsertAnnotation(
              AnnotationsCompanion.insert(
                uuid: uuid,
                contentHash: hash,
                mediaKind: (m['mediaKind'] ?? m['media_kind'] ?? 'book')
                    .toString(),
                kind: (m['kind'] ?? 'bookmark').toString(),
                chapterIndex: Value(
                  ((m['chapterIndex'] ?? m['chapter_index']) as num?)
                          ?.toInt() ??
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
                isDeleted: Value(deleted),
                updatedAtMs: updatedAtMs,
              ),
            );
            annotationsById[uuid] = (updatedAtMs, deleted);
          }
        }

        var restoredCount = 0;
        if (progRaw != null) {
          final records =
              _jsonObject(progRaw)['records'] as Map<String, dynamic>? ??
              const {};
          for (final entry in records.entries) {
            final remote = Map<String, dynamic>.from(entry.value as Map);
            final existing = await db.getSyncState(entry.key);
            final updated =
                (remote['updated_at_epoch_ms'] as num?)?.toInt() ?? 0;
            if (existing != null && existing.updatedAtMs >= updated) continue;
            await _applyRemoteProgress(entry.key, remote, now);
            restoredCount++;
          }
        }
        return restoredCount;
      });
      if (preferences != null && applyPreferences != null) {
        await applyPreferences(preferences);
      }
      return restoredCount;
    } finally {
      client.close();
      await _deleteTemp(staging);
    }
  }

  Future<Map<String, String>> _unpackSnapshot(File file) async {
    final handle = await file.open();
    final List<int> magic;
    try {
      magic = await handle.read(2);
    } finally {
      await handle.close();
    }
    if (magic.length != 2 || magic[0] != 0x50 || magic[1] != 0x4b) {
      // Earlier clients without Rust wrote a JSON envelope with a .zip suffix.
      if (await file.length() > _snapshotTotalLimit) {
        throw const FormatException('WebDAV backup exceeds the size limit');
      }
      return Map<String, String>.from(_jsonObject(await file.readAsString()));
    }
    if (rustCore != null) return rustCore!.unpackSnapshotZip(file.path);
    final input = InputFileStream(file.path);
    try {
      final archive = readBackupZip(
        input,
        maxEntries: 64,
        maxEntryBytes: _snapshotEntryLimit,
        maxTotalBytes: _snapshotTotalLimit,
      );
      return {
        for (final entry in archive.values)
          if (entry.isFile) entry.name: utf8.decode(entry.content),
      };
    } on ArchiveException {
      throw const FormatException('Invalid WebDAV backup');
    } finally {
      input.closeSync();
    }
  }

  Future<void> _deleteTemp(Directory directory) async {
    try {
      await directory.delete(recursive: true);
    } on FileSystemException {
      // Cache cleanup can reclaim staging data after a filesystem failure.
    }
  }

  Map<String, dynamic> _syncStateToJson(SyncState s, WebDavConfig cfg) => {
    'content_hash': s.contentHash,
    'media_kind': s.mediaKind,
    'locator': s.locator,
    'progress_ratio': s.progressRatio,
    'updated_at_epoch_ms': s.updatedAtMs,
    'device_id': s.deviceId == 'local_device' ? cfg.deviceId : s.deviceId,
    'device_name': s.deviceId == 'local_device' || s.deviceName.isEmpty
        ? cfg.deviceName
        : s.deviceName,
  };

  Future<bool> _adoptProgress(
    String hash,
    Map<String, dynamic> remote,
    int now,
    SyncState? expected,
  ) => db.transaction(() async {
    final current = await db.getSyncState(hash);
    if (current?.updatedAtMs != expected?.updatedAtMs ||
        current?.locator != expected?.locator) {
      return false;
    }
    await _applyRemoteProgress(hash, remote, now);
    return true;
  });

  Future<void> _applyRemoteProgress(
    String contentHash,
    Map<String, dynamic> remote,
    int syncedAtMs, {
    int? lastSyncedAtMs,
  }) async {
    final mediaKind = remote['media_kind'] as String? ?? 'book';
    final locator = remote['locator'] as String? ?? '';
    final ratio = (remote['progress_ratio'] as num?)?.toDouble() ?? 0.0;
    final updatedMs =
        (remote['updated_at_epoch_ms'] as num?)?.toInt() ?? syncedAtMs;

    await db.applySyncedProgress(
      contentHash: contentHash,
      mediaKind: mediaKind,
      locator: locator,
      progressRatio: ratio,
      updatedAtMs: updatedMs,
      lastSyncedAtMs: lastSyncedAtMs ?? max(syncedAtMs, updatedMs),
      deviceId: remote['device_id'] as String? ?? 'remote',
      deviceName: remote['device_name'] as String? ?? '云端设备',
    );
  }
}
