import 'dart:collection';
import 'dart:io';

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
  final List<int> bytes;
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

  final LinkedHashMap<int, DecodedMangaPage> _cache = LinkedHashMap();
  final _pdfReads = <Future<List<int>?>>{};
  List<MangaPageDescriptor> _pages = const [];
  ReadableMedia? _media;
  bool _closed = false;

  String get _path => _media?.path ?? sourcePath;

  List<MangaPageDescriptor> get pages => _pages;
  int get pageCount => _pages.length;

  Future<void> open() async {
    if (LibraryStorage.isDocument(sourcePath)) {
      try {
        _media = await storage.open(
          sourcePath,
          extension: format == 'FOLDER' ? null : format,
        );
      } catch (_) {
        return;
      }
    }
    final isDir = FileSystemEntity.isDirectorySync(_path);
    final isFile = FileSystemEntity.isFileSync(_path);

    if (!isDir && !isFile) {
      _pages = const [];
      return;
    }

    final ext = p.extension(_path).replaceFirst('.', '').toLowerCase();
    if (!isDir && ext == 'pdf') {
      var count = 0;
      if (platform != null) {
        count = await platform!.getPdfPageCount(_path);
      }
      if (count == 0 && rustCore != null) {
        try {
          final meta = rustCore!.parsePdfMetadata(_path);
          count = (meta['page_count'] as num?)?.toInt() ?? 0;
        } catch (_) {}
      }
      _pages = List.generate(
        count,
        (i) => MangaPageDescriptor(
          index: i,
          entryName: 'pdf_page_$i',
          isPdf: true,
        ),
      );
      return;
    }

    if (rustCore != null) {
      final summary = rustCore!.inspectComicArchive(_path);
      final raw = summary['pages'] as List<dynamic>? ?? const [];
      _pages = raw.map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        return MangaPageDescriptor(
          index: (m['index'] as num).toInt(),
          entryName: m['entry_name'] as String,
        );
      }).toList();
      return;
    }

    if (isDir) {
      final files = Directory(_path)
          .listSync()
          .whereType<File>()
          .where((f) {
            final e = p.extension(f.path).toLowerCase();
            return const {'.jpg', '.jpeg', '.png', '.webp', '.gif', '.bmp'}
                .contains(e);
          })
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
      _pages = List.generate(
        files.length,
        (i) => MangaPageDescriptor(index: i, entryName: files[i].path),
      );
    }
  }

  Future<DecodedMangaPage?> loadPage(
    int index, {
    required bool computeCrop,
  }) async {
    if (_closed || index < 0 || index >= _pages.length) return null;
    if (_cache.containsKey(index)) {
      final hit = _cache.remove(index)!;
      _cache[index] = hit;
      return hit;
    }

    final desc = _pages[index];

    DecodedMangaPage? decoded;
    if (desc.isPdf && platform != null) {
      final read = platform!.renderPdfPage(_path, index, scale: 2.0);
      _pdfReads.add(read);
      final List<int>? bytes;
      try {
        bytes = await read;
      } finally {
        _pdfReads.remove(read);
      }
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

    if (decoded != null && !_closed) {
      _cache[index] = decoded;
      while (_cache.length > maxCachedPages) {
        _cache.remove(_cache.keys.first);
      }
    }
    return decoded;
  }

  void preloadAround(int centerIndex, {required bool computeCrop}) {
    for (final offset in const [1, 2, -1, 3]) {
      final target = centerIndex + offset;
      if (target >= 0 && target < _pages.length && !_cache.containsKey(target)) {
        loadPage(target, computeCrop: computeCrop);
      }
    }
  }

  Future<void> dispose() async {
    if (_closed) return;
    _closed = true;
    _cache.clear();
    await Future.wait(_pdfReads.toList().map((read) => read.catchError((_) => null)));
    await _media?.close();
  }
}
