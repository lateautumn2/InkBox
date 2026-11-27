import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../data/ffi/rust_core_bridge.dart';
import '../../data/platform/library_storage.dart';
import '../../data/platform/platform_bridge.dart';

class MangaPageDescriptor {
  const MangaPageDescriptor({
    required this.index,
    required this.entryName,
    this.isPdf = false,
  });

  final int index;
  final String entryName;
  final bool isPdf;
}

class DecodedMangaPage {
  const DecodedMangaPage({
    required this.index,
    required this.bytes,
    required this.width,
    required this.height,
    required this.isWideSpread,
    required this.cropRect,
  });

  final int index;
  final Uint8List bytes;
  final int width;
  final int height;
  final bool isWideSpread;
  final SmartCropRect cropRect;
}

/// Streaming manga page source with bounded LRU preload window (prevents OOM on
/// 100MB+ CBZ/CB7/PDF/Folder chapters).
class MangaPageSource {
  MangaPageSource({
    required this.sourcePath,
    this.rustCore,
    this.platform,
    this.format,
    LibraryStorage? storage,
    this.maxCachedPages = 8,
  }) : storage = storage ?? LibraryStorage();

  final String sourcePath;
  final RustCoreBridge? rustCore;
  final PlatformBridge? platform;
  final String? format;
  final LibraryStorage storage;
  final int maxCachedPages;

  final LinkedHashMap<(int, bool), DecodedMangaPage> _cache = LinkedHashMap();
  final _inFlight = <(int, bool), Future<DecodedMangaPage?>>{};
  List<MangaPageDescriptor> _pages = const [];
  ReadableMedia? _media;
  Future<void>? _opening;
  bool _closed = false;

  String get _path => _media?.path ?? sourcePath;

  List<MangaPageDescriptor> get pages => _pages;
  int get pageCount => _pages.length;

  Future<void> open() => _opening ??= _open();

  Future<void> _open() async {
    if (_closed) return;
    ReadableMedia? media;
    try {
      media = await storage.open(
        sourcePath,
        extension: format == 'FOLDER' || format == '文件夹' ? null : format,
      );
      if (_closed) return;
      final pages = await _readDescriptors(media.path);
      if (_closed || pages.isEmpty) return;
      _pages = pages;
      _media = media;
      media = null;
    } finally {
      await media?.close();
    }
  }

  Future<List<MangaPageDescriptor>> _readDescriptors(String path) async {
    final isDir = FileSystemEntity.isDirectorySync(path);
    final isFile = FileSystemEntity.isFileSync(path);

    if (!isDir && !isFile) return const [];

    final ext = p.extension(path).replaceFirst('.', '').toLowerCase();
    if (!isDir && ext == 'pdf') {
      var count = 0;
      if (platform != null) {
        count = await platform!.getPdfPageCount(path);
      }
      if (_closed) return const [];
      if (count == 0 && rustCore != null) {
        try {
          final meta = rustCore!.parsePdfMetadata(path);
          count = (meta['page_count'] as num?)?.toInt() ?? 0;
        } catch (_) {}
      }
      return List.generate(
        count,
        (i) => MangaPageDescriptor(
          index: i,
          entryName: 'pdf_page_$i',
          isPdf: true,
        ),
      );
    }

    if (rustCore != null) {
      final summary = rustCore!.inspectComicArchive(path);
      final raw = summary['pages'] as List<dynamic>? ?? const [];
      return raw.map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        return MangaPageDescriptor(
          index: (m['index'] as num).toInt(),
          entryName: m['entry_name'] as String,
        );
      }).toList();
    }

    if (isDir) {
      final files =
          (await Directory(
              path,
            ).list(followLinks: false).toList()).whereType<File>().where((f) {
              final e = p.extension(f.path).toLowerCase();
              return const {
                '.jpg',
                '.jpeg',
                '.png',
                '.webp',
                '.gif',
                '.bmp',
              }.contains(e);
            }).toList()
            ..sort((a, b) => a.path.compareTo(b.path));
      return List.generate(
        files.length,
        (i) => MangaPageDescriptor(index: i, entryName: files[i].path),
      );
    }
    return const [];
  }

  Future<DecodedMangaPage?> loadPage(
    int index, {
    required bool computeCrop,
  }) async {
    if (_closed || index < 0 || index >= _pages.length) return null;
    final key = (index, computeCrop && !_pages[index].isPdf);
    final hit = _cache.remove(key);
    if (hit != null) {
      _cache[key] = hit;
      return hit;
    }
    return _inFlight.putIfAbsent(key, () async {
      try {
        final decoded = await _decodePage(index, computeCrop);
        if (_closed || decoded == null) return null;
        _cache[key] = decoded;
        while (_cache.length > maxCachedPages && _cache.isNotEmpty) {
          _cache.remove(_cache.keys.first);
        }
        return decoded;
      } catch (_) {
        return null;
      } finally {
        _inFlight.remove(key);
      }
    });
  }

  Future<DecodedMangaPage?> _decodePage(int index, bool computeCrop) async {
    final desc = _pages[index];

    DecodedMangaPage? decoded;
    if (desc.isPdf && platform != null) {
      final bytes = await platform!.renderPdfPage(_path, index, scale: 2.0);
      if (bytes != null) {
        decoded = DecodedMangaPage(
          index: index,
          bytes: bytes,
          width: 0,
          height: 0,
          isWideSpread: false,
          cropRect: const SmartCropRect(),
        );
      }
    } else if (rustCore != null) {
      final res = rustCore!.readComicPage(
        archivePath: _path,
        entryName: desc.entryName,
        computeCrop: computeCrop,
      );
      decoded = DecodedMangaPage(
        index: index,
        bytes: res.imageBytes,
        width: res.width,
        height: res.height,
        isWideSpread: res.isWideSpread,
        cropRect: res.cropRect,
      );
    } else if (File(desc.entryName).existsSync()) {
      final bytes = await File(desc.entryName).readAsBytes();
      decoded = DecodedMangaPage(
        index: index,
        bytes: bytes,
        width: 0,
        height: 0,
        isWideSpread: false,
        cropRect: const SmartCropRect(),
      );
    }

    return decoded;
  }

  void preloadAround(int centerIndex, {required bool computeCrop}) {
    for (final offset in const [1, 2, -1, 3]) {
      final target = centerIndex + offset;
      if (target >= 0 && target < _pages.length) {
        unawaited(loadPage(target, computeCrop: computeCrop));
      }
    }
  }

  Future<void> dispose() async {
    if (_closed) return;
    _closed = true;
    _cache.clear();
    _pages = const [];
    await Future.wait(_inFlight.values.toList());
    await _media?.close();
  }
}
