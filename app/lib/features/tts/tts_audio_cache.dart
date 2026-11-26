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

  String keyFor({
    required String profileId,
    required String voice,
    required double rate,
    required double pitch,
    required String format,
    required String text,
  }) {
    final input =
        '$profileId|$voice|${rate.toStringAsFixed(2)}|${pitch.toStringAsFixed(2)}|$format|$text';
    return sha256.convert(utf8.encode(input)).toString();
  }

  Future<File?> getCachedFile(String cacheKey, String ext) async {
    try {
      final dir = await _cacheDir();
      final f = File(p.join(dir.path, '$cacheKey.$ext'));
      if (await f.exists() && await f.length() > 0) {
        return f;
      }
    } catch (_) {}
    return null;
  }

  Future<File> putBytes(String cacheKey, String ext, List<int> bytes) async {
    final dir = await _cacheDir();
    final f = File(p.join(dir.path, '$cacheKey.$ext'));
    await f.writeAsBytes(bytes, flush: true);
    await _evictIfNeeded(dir);
    return f;
  }

  Future<void> _evictIfNeeded(Directory dir) async {
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
      if (total <= maxBytes) return;
      entries.sort((a, b) => a.modified.compareTo(b.modified));
      for (final e in entries) {
        if (total <= (maxBytes * 0.8).round()) break;
        try {
          await e.file.delete();
          total -= e.size;
        } catch (_) {}
      }
    } catch (_) {}
  }

  Future<int> totalSizeBytes() async {
    try {
      final dir = await _cacheDir();
      var total = 0;
      await for (final entity in dir.list()) {
        if (entity is File) {
          total += await entity.length();
        }
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  Future<void> clear() async {
    try {
      final dir = await _cacheDir();
      if (await dir.exists()) {
        await for (final entity in dir.list()) {
          if (entity is File) {
            try {
              await entity.delete();
            } catch (_) {}
          }
        }
      }
    } catch (_) {}
  }
}
