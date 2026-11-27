import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Disk LRU cache for synthesized online TTS audio segments (100 MB cap).
class TtsAudioCache {
  TtsAudioCache({
    this.overrideDirPath,
    this.maxBytes = 100 * 1024 * 1024,
  });

  final String? overrideDirPath;
  final int maxBytes;
  static int _liveSeq = 0;

  Future<Directory> _cacheDir() async {
    if (overrideDirPath != null) {
      final dir = Directory(overrideDirPath!);
      await dir.create(recursive: true);
      return dir;
    }
    final tmp = await getTemporaryDirectory();
    final dir = Directory(p.join(tmp.path, 'tts_audio_cache'));
    await dir.create(recursive: true);
    return dir;
  }

  Future<Directory> _liveDir() async {
    final base = await _cacheDir();
    return Directory('${base.path}_live');
  }

  String keyFor({
    required String profileId,
    String configFingerprint = '',
    required String voice,
    required double rate,
    required double pitch,
    required String format,
    required String text,
  }) {
    final input =
        '$profileId|$configFingerprint|$voice|${rate.toStringAsFixed(2)}|${pitch.toStringAsFixed(2)}|$format|$text';
    return sha256.convert(utf8.encode(input)).toString();
  }

  Future<File?> getCachedFile(String cacheKey, String ext) async {
    try {
      final dir = await _cacheDir();
      final f = File(p.join(dir.path, '$cacheKey.$ext'));
      if (await f.exists() && await f.length() > 0) {
        try {
          await f.setLastModified(DateTime.now());
        } catch (_) {}
        return f;
      }
    } catch (_) {}
    return null;
  }

  Future<File> putBytes(
    String cacheKey,
    String ext,
    List<int> bytes, {
    int? maxBytesOverride,
  }) async {
    final dir = await _cacheDir();
    final f = File(p.join(dir.path, '$cacheKey.$ext'));
    await f.writeAsBytes(bytes, flush: true);
    await _evictIfNeeded(dir, maxBytesOverride ?? maxBytes);
    return f;
  }

  /// Writes non-cached playback bytes to a unique ephemeral file inside
  /// `<cacheDir>_live` without overwriting currently active or prefetched audio.
  Future<File> writeEphemeralFile(String ext, List<int> bytes) async {
    final liveDir = await _liveDir();
    await liveDir.create(recursive: true);
    final seq = _liveSeq++;
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final tmp = File(p.join(liveDir.path, '.tmp_${stamp}_$seq.$ext'));
    final target = File(p.join(liveDir.path, 'live_${stamp}_$seq.$ext'));
    await tmp.writeAsBytes(bytes, flush: true);
    try {
      await tmp.rename(target.path);
    } catch (_) {
      await target.writeAsBytes(bytes, flush: true);
      if (await tmp.exists()) {
        try {
          await tmp.delete();
        } catch (_) {}
      }
    }
    await _pruneOldLiveFilesIfNeeded(liveDir);
    return target;
  }

  /// Safely deletes [filePath] only if it resides in the ephemeral `_live` dir.
  Future<void> deleteEphemeralFile(String filePath) async {
    try {
      final liveDir = await _liveDir();
      final target = File(filePath);
      if (p.normalize(p.dirname(target.absolute.path)) !=
          p.normalize(liveDir.absolute.path)) {
        return;
      }
      if (await target.exists()) {
        await target.delete();
      }
    } catch (_) {}
  }

  Future<void> _pruneOldLiveFilesIfNeeded(Directory liveDir) async {
    try {
      final entries = <({File file, DateTime modified})>[];
      await for (final entity in liveDir.list()) {
        if (entity is File) {
          final st = await entity.stat();
          entries.add((file: entity, modified: st.modified));
        }
      }
      if (entries.length <= 64) return;
      entries.sort((a, b) => a.modified.compareTo(b.modified));
      final deleteCount = entries.length - 32;
      for (var i = 0; i < deleteCount; i++) {
        try {
          await entries[i].file.delete();
        } catch (_) {}
      }
    } catch (_) {}
  }

  Future<void> enforceMaxBytes(int limitBytes) async {
    try {
      final dir = await _cacheDir();
      await _evictIfNeeded(dir, limitBytes);
    } catch (_) {}
  }

  Future<void> _evictIfNeeded(Directory dir, int limitBytes) async {
    try {
      final entries = <({File file, DateTime modified, int size})>[];
      var total = 0;
      await for (final entity in dir.list()) {
        if (entity is File) {
          final st = await entity.stat();
          entries.add((file: entity, modified: st.modified, size: st.size));
          total += st.size;
        }
      }
      if (total <= limitBytes) return;
      entries.sort((a, b) => a.modified.compareTo(b.modified));
      for (final e in entries) {
        if (total <= (limitBytes * 0.8).round()) break;
        try {
          await e.file.delete();
          total -= e.size;
        } catch (_) {}
      }
    } catch (_) {}
  }

  Future<int> _dirBytes(Directory dir) async {
    if (!await dir.exists()) return 0;
    var total = 0;
    await for (final entity in dir.list()) {
      if (entity is File) {
        total += await entity.length();
      }
    }
    return total;
  }

  Future<void> _clearDir(Directory dir) async {
    if (!await dir.exists()) return;
    await for (final entity in dir.list()) {
      if (entity is File) {
        try {
          await entity.delete();
        } catch (_) {}
      }
    }
  }

  Future<int> totalSizeBytes() async {
    try {
      final dir = await _cacheDir();
      final live = await _liveDir();
      return (await _dirBytes(dir)) + (await _dirBytes(live));
    } catch (_) {
      return 0;
    }
  }

  Future<void> clear() async {
    try {
      await _clearDir(await _cacheDir());
      await _clearDir(await _liveDir());
    } catch (_) {}
  }
}
