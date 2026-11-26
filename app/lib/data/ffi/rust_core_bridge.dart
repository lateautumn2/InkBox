import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

typedef _FreeStringNative = Void Function(Pointer<Utf8>);
typedef _FreeStringDart = void Function(Pointer<Utf8>);

typedef _NoArgJsonNative = Pointer<Utf8> Function();
typedef _NoArgJsonDart = Pointer<Utf8> Function();

typedef _OneStrJsonNative = Pointer<Utf8> Function(Pointer<Utf8>);
typedef _OneStrJsonDart = Pointer<Utf8> Function(Pointer<Utf8>);

typedef _TwoStrJsonNative = Pointer<Utf8> Function(
    Pointer<Utf8>, Pointer<Utf8>);
typedef _TwoStrJsonDart = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);

typedef _ThreeStrJsonNative = Pointer<Utf8> Function(
    Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>);
typedef _ThreeStrJsonDart = Pointer<Utf8> Function(
    Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>);

typedef _ComicPageNative = Pointer<Utf8> Function(
    Pointer<Utf8>, Pointer<Utf8>, Uint8);
typedef _ComicPageDart = Pointer<Utf8> Function(
    Pointer<Utf8>, Pointer<Utf8>, int);

class CoreHealthInfo {
  const CoreHealthInfo({
    required this.engineName,
    required this.version,
    required this.supportedBookFormats,
    required this.supportedComicFormats,
    this.isNativeLoaded = true,
  });

  final String engineName;
  final String version;
  final List<String> supportedBookFormats;
  final List<String> supportedComicFormats;
  final bool isNativeLoaded;

  factory CoreHealthInfo.fromJson(Map<String, dynamic> json) {
    return CoreHealthInfo(
      engineName: json['engine_name'] as String? ?? 'inkbox_core',
      version: json['version'] as String? ?? '1.0.0',
      supportedBookFormats: (json['supported_book_formats'] as List<dynamic>? ??
              const [])
          .cast<String>(),
      supportedComicFormats:
          (json['supported_comic_formats'] as List<dynamic>? ?? const [])
              .cast<String>(),
      isNativeLoaded: true,
    );
  }
}

class BookChapterRef {
  const BookChapterRef({
    required this.index,
    required this.title,
    this.href = '',
    this.startByte = 0,
    this.endByte = 0,
  });

  final int index;
  final String title;
  final String href;
  final int startByte;
  final int endByte;
}

class SmartCropRect {
  const SmartCropRect({
    this.left = 0.0,
    this.top = 0.0,
    this.right = 1.0,
    this.bottom = 1.0,
  });

  final double left;
  final double top;
  final double right;
  final double bottom;

  factory SmartCropRect.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const SmartCropRect();
    return SmartCropRect(
      left: (json['left'] as num?)?.toDouble() ?? 0.0,
      top: (json['top'] as num?)?.toDouble() ?? 0.0,
      right: (json['right'] as num?)?.toDouble() ?? 1.0,
      bottom: (json['bottom'] as num?)?.toDouble() ?? 1.0,
    );
  }
}

class ComicPageResult {
  const ComicPageResult({
    required this.imageBytes,
    required this.width,
    required this.height,
    required this.isWideSpread,
    required this.cropRect,
  });

  final Uint8List imageBytes;
  final int width;
  final int height;
  final bool isWideSpread;
  final SmartCropRect cropRect;
}

/// Panic-safe C-ABI FFI bridge into the shared cross-platform Rust Core library.
class RustCoreBridge {
  RustCoreBridge._(this._lib) {
    _freeString = _lib
        .lookup<NativeFunction<_FreeStringNative>>('inkbox_free_string')
        .asFunction();
    _healthJson = _lib
        .lookup<NativeFunction<_NoArgJsonNative>>('inkbox_health_json')
        .asFunction();
    _classifyPathJson = _lib
        .lookup<NativeFunction<_OneStrJsonNative>>('inkbox_classify_path_json')
        .asFunction();
    _fastFingerprintJson = _lib
        .lookup<NativeFunction<_OneStrJsonNative>>(
            'inkbox_fast_fingerprint_json')
        .asFunction();
    _indexTxtJson = _lib
        .lookup<NativeFunction<_TwoStrJsonNative>>('inkbox_index_txt_json')
        .asFunction();
    _indexTxtWithRulesJson = _lib
        .lookup<NativeFunction<_OneStrJsonNative>>(
            'inkbox_index_txt_with_rules_json')
        .asFunction();
    _testTocRuleJson = _lib
        .lookup<NativeFunction<_OneStrJsonNative>>('inkbox_test_toc_rule_json')
        .asFunction();
    _defaultTocRulesJson = _lib
        .lookup<NativeFunction<_NoArgJsonNative>>(
            'inkbox_default_toc_rules_json')
        .asFunction();
    _readBookChapterJson = _lib
        .lookup<NativeFunction<_OneStrJsonNative>>(
            'inkbox_read_book_chapter_json')
        .asFunction();
    _parseEpubJson = _lib
        .lookup<NativeFunction<_OneStrJsonNative>>('inkbox_parse_epub_json')
        .asFunction();
    _parseMobiJson = _lib
        .lookup<NativeFunction<_OneStrJsonNative>>('inkbox_parse_mobi_json')
        .asFunction();
    _parsePdfJson = _lib
        .lookup<NativeFunction<_OneStrJsonNative>>('inkbox_parse_pdf_json')
        .asFunction();
    _parseStructuredBookJson = _lib
        .lookup<NativeFunction<_TwoStrJsonNative>>(
            'inkbox_parse_structured_book_json')
        .asFunction();
    _extractCoverThumbnailJson = _lib
        .lookup<NativeFunction<_ThreeStrJsonNative>>(
            'inkbox_extract_cover_thumbnail_json')
        .asFunction();
    _inspectCbzJson = _lib
        .lookup<NativeFunction<_OneStrJsonNative>>('inkbox_inspect_cbz_json')
        .asFunction();
    _discoverComicChaptersJson = _lib
        .lookup<NativeFunction<_OneStrJsonNative>>(
            'inkbox_discover_comic_chapters_json')
        .asFunction();
    _readComicPageJson = _lib
        .lookup<NativeFunction<_ComicPageNative>>('inkbox_read_comic_page_json')
        .asFunction();
    _readEpubResourceBase64Json = _lib
        .lookup<NativeFunction<_TwoStrJsonNative>>(
            'inkbox_read_epub_resource_base64_json')
        .asFunction();
    _evaluateProgressMergeJson = _lib
        .lookup<NativeFunction<_OneStrJsonNative>>(
            'inkbox_evaluate_progress_merge_json')
        .asFunction();
    _mergeAnnotationsJson = _lib
        .lookup<NativeFunction<_OneStrJsonNative>>(
            'inkbox_merge_annotations_json')
        .asFunction();
    _packSnapshotZipJson = _lib
        .lookup<NativeFunction<_OneStrJsonNative>>(
            'inkbox_pack_snapshot_zip_json')
        .asFunction();
    _unpackSnapshotZipJson = _lib
        .lookup<NativeFunction<_OneStrJsonNative>>(
            'inkbox_unpack_snapshot_zip_json')
        .asFunction();
  }

  final DynamicLibrary _lib;
  late final _FreeStringDart _freeString;
  late final _NoArgJsonDart _healthJson;
  late final _OneStrJsonDart _classifyPathJson;
  late final _OneStrJsonDart _fastFingerprintJson;
  late final _TwoStrJsonDart _indexTxtJson;
  late final _OneStrJsonDart _indexTxtWithRulesJson;
  late final _OneStrJsonDart _testTocRuleJson;
  late final _NoArgJsonDart _defaultTocRulesJson;
  late final _OneStrJsonDart _readBookChapterJson;
  late final _OneStrJsonDart _parseEpubJson;
  late final _OneStrJsonDart _parseMobiJson;
  late final _OneStrJsonDart _parsePdfJson;
  late final _TwoStrJsonDart _parseStructuredBookJson;
  late final _ThreeStrJsonDart _extractCoverThumbnailJson;
  late final _OneStrJsonDart _inspectCbzJson;
  late final _OneStrJsonDart _discoverComicChaptersJson;
  late final _ComicPageDart _readComicPageJson;
  late final _TwoStrJsonDart _readEpubResourceBase64Json;
  late final _OneStrJsonDart _evaluateProgressMergeJson;
  late final _OneStrJsonDart _mergeAnnotationsJson;
  late final _OneStrJsonDart _packSnapshotZipJson;
  late final _OneStrJsonDart _unpackSnapshotZipJson;

  static RustCoreBridge? _instance;

  static RustCoreBridge? tryOpen({String? explicitLibraryPath}) {
    if (_instance != null && explicitLibraryPath == null) return _instance;
    try {
      final DynamicLibrary lib;
      if (explicitLibraryPath != null) {
        lib = DynamicLibrary.open(explicitLibraryPath);
      } else if (Platform.isAndroid || Platform.isLinux) {
        lib = DynamicLibrary.open('libinkbox_core.so');
      } else if (Platform.isWindows) {
        lib = DynamicLibrary.open('inkbox_core.dll');
      } else if (Platform.isMacOS) {
        lib = DynamicLibrary.open('libinkbox_core.dylib');
      } else if (Platform.isIOS) {
        lib = DynamicLibrary.process();
      } else {
        return null;
      }
      final created = RustCoreBridge._(lib);
      if (explicitLibraryPath == null) _instance = created;
      return created;
    } catch (_) {
      return null;
    }
  }

  dynamic _consumeEnvelope(Pointer<Utf8> ptr) {
    try {
      final raw = ptr.toDartString();
      final map = jsonDecode(raw) as Map<String, dynamic>;
      if (map['ok'] != true) {
        throw StateError(map['error'] as String? ?? 'Unknown Rust core error');
      }
      return map['data'];
    } finally {
      _freeString(ptr);
    }
  }

  CoreHealthInfo healthCheck() {
    final data = _consumeEnvelope(_healthJson()) as Map<String, dynamic>;
    return CoreHealthInfo.fromJson(data);
  }

  String classifyPath(String path) {
    final ptr = path.toNativeUtf8();
    try {
      return _consumeEnvelope(_classifyPathJson(ptr)) as String;
    } finally {
      calloc.free(ptr);
    }
  }

  String computeFastFingerprint(String path) {
    final ptr = path.toNativeUtf8();
    try {
      return _consumeEnvelope(_fastFingerprintJson(ptr)) as String;
    } finally {
      calloc.free(ptr);
    }
  }

  Map<String, dynamic> indexTxt(String path, {String? customRegex}) {
    final pPtr = path.toNativeUtf8();
    final rPtr = customRegex != null ? customRegex.toNativeUtf8() : nullptr;
    try {
      return _consumeEnvelope(_indexTxtJson(pPtr, rPtr))
          as Map<String, dynamic>;
    } finally {
      calloc.free(pPtr);
      if (rPtr != nullptr) calloc.free(rPtr);
    }
  }

  Map<String, dynamic> indexTxtWithRules({
    required String path,
    List<Map<String, dynamic>> rules = const [],
    Map<String, dynamic>? forcedRule,
    String? forcedEncoding,
  }) {
    final payload = jsonEncode({
      'path': path,
      'forced_encoding': forcedEncoding,
      'forced_rule': forcedRule,
      'rules': rules,
    });
    final ptr = payload.toNativeUtf8();
    try {
      return _consumeEnvelope(_indexTxtWithRulesJson(ptr))
          as Map<String, dynamic>;
    } finally {
      calloc.free(ptr);
    }
  }

  Map<String, dynamic> testTocRule({
    required String pattern,
    String? sampleText,
    String? path,
    String? forcedEncoding,
    int maxPreview = 20,
  }) {
    final payload = jsonEncode({
      'pattern': pattern,
      'sample_text': sampleText,
      'path': path,
      'forced_encoding': forcedEncoding,
      'max_preview': maxPreview,
    });
    final ptr = payload.toNativeUtf8();
    try {
      return _consumeEnvelope(_testTocRuleJson(ptr)) as Map<String, dynamic>;
    } finally {
      calloc.free(ptr);
    }
  }

  List<Map<String, dynamic>> defaultTocRules() {
    final list = _consumeEnvelope(_defaultTocRulesJson()) as List<dynamic>;
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Map<String, dynamic> readBookChapter({
    required String format,
    required String path,
    required int chapterIndex,
    String? href,
    String? title,
    int? startByte,
    int? endByte,
    String? forcedEncoding,
    List<Map<String, dynamic>> replaceRules = const [],
    String cnMode = 'None',
  }) {
    final payload = jsonEncode({
      'format': format,
      'path': path,
      'chapter_index': chapterIndex,
      'href': href,
      'title': title,
      'start_byte': startByte,
      'end_byte': endByte,
      'forced_encoding': forcedEncoding,
      'replace_rules': replaceRules,
      'cn_mode': cnMode,
    });
    final ptr = payload.toNativeUtf8();
    try {
      return _consumeEnvelope(_readBookChapterJson(ptr))
          as Map<String, dynamic>;
    } finally {
      calloc.free(ptr);
    }
  }

  Map<String, dynamic> parseEpubMetadata(String path) {
    final ptr = path.toNativeUtf8();
    try {
      return _consumeEnvelope(_parseEpubJson(ptr)) as Map<String, dynamic>;
    } finally {
      calloc.free(ptr);
    }
  }

  Map<String, dynamic> parseMobiMetadata(String path) {
    final ptr = path.toNativeUtf8();
    try {
      return _consumeEnvelope(_parseMobiJson(ptr)) as Map<String, dynamic>;
    } finally {
      calloc.free(ptr);
    }
  }

  Map<String, dynamic> parsePdfMetadata(String path) {
    final ptr = path.toNativeUtf8();
    try {
      return _consumeEnvelope(_parsePdfJson(ptr)) as Map<String, dynamic>;
    } finally {
      calloc.free(ptr);
    }
  }

  Map<String, dynamic> parseStructuredBook(String path, String format) {
    final pPtr = path.toNativeUtf8();
    final fPtr = format.toNativeUtf8();
    try {
      return _consumeEnvelope(_parseStructuredBookJson(pPtr, fPtr))
          as Map<String, dynamic>;
    } finally {
      calloc.free(pPtr);
      calloc.free(fPtr);
    }
  }

  bool extractCoverThumbnail({
    required String sourcePath,
    required String format,
    required String outputJpgPath,
  }) {
    final sPtr = sourcePath.toNativeUtf8();
    final fPtr = format.toNativeUtf8();
    final oPtr = outputJpgPath.toNativeUtf8();
    try {
      return _consumeEnvelope(_extractCoverThumbnailJson(sPtr, fPtr, oPtr))
          as bool;
    } finally {
      calloc.free(sPtr);
      calloc.free(fPtr);
      calloc.free(oPtr);
    }
  }

  Map<String, dynamic> inspectComicArchive(String path) {
    final ptr = path.toNativeUtf8();
    try {
      return _consumeEnvelope(_inspectCbzJson(ptr)) as Map<String, dynamic>;
    } finally {
      calloc.free(ptr);
    }
  }

  // Backward-compatible alias
  Map<String, dynamic> inspectCbzArchive(String path) =>
      inspectComicArchive(path);

  List<Map<String, dynamic>> discoverComicChapters(String rootDir) {
    final ptr = rootDir.toNativeUtf8();
    try {
      final list = _consumeEnvelope(_discoverComicChaptersJson(ptr))
          as List<dynamic>;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } finally {
      calloc.free(ptr);
    }
  }

  ComicPageResult readComicPage({
    required String archivePath,
    required String entryName,
    bool computeCrop = true,
  }) {
    final aPtr = archivePath.toNativeUtf8();
    final ePtr = entryName.toNativeUtf8();
    try {
      final map = _consumeEnvelope(
        _readComicPageJson(aPtr, ePtr, computeCrop ? 1 : 0),
      ) as Map<String, dynamic>;
      return ComicPageResult(
        imageBytes: base64Decode(map['image_base64'] as String),
        width: (map['width'] as num?)?.toInt() ?? 0,
        height: (map['height'] as num?)?.toInt() ?? 0,
        isWideSpread: map['is_wide_spread'] as bool? ?? false,
        cropRect: SmartCropRect.fromJson(
          map['crop_rect'] as Map<String, dynamic>?,
        ),
      );
    } finally {
      calloc.free(aPtr);
      calloc.free(ePtr);
    }
  }

  Uint8List readEpubResourceBytes(String epubPath, String resourceHref) {
    final pPtr = epubPath.toNativeUtf8();
    final hPtr = resourceHref.toNativeUtf8();
    try {
      final b64 = _consumeEnvelope(_readEpubResourceBase64Json(pPtr, hPtr))
          as String;
      return base64Decode(b64);
    } finally {
      calloc.free(pPtr);
      calloc.free(hPtr);
    }
  }

  String evaluateProgressMerge({
    required Map<String, dynamic> local,
    required Map<String, dynamic> remote,
    required int lastSyncedEpochMs,
  }) {
    final payload = jsonEncode({
      'local': local,
      'remote': remote,
      'last_synced_epoch_ms': lastSyncedEpochMs,
    });
    final ptr = payload.toNativeUtf8();
    try {
      return _consumeEnvelope(_evaluateProgressMergeJson(ptr)) as String;
    } finally {
      calloc.free(ptr);
    }
  }

  List<Map<String, dynamic>> mergeAnnotations({
    required List<Map<String, dynamic>> local,
    required List<Map<String, dynamic>> remote,
  }) {
    final payload = jsonEncode({'local': local, 'remote': remote});
    final ptr = payload.toNativeUtf8();
    try {
      final list =
          _consumeEnvelope(_mergeAnnotationsJson(ptr)) as List<dynamic>;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } finally {
      calloc.free(ptr);
    }
  }

  int packSnapshotZip({
    required Map<String, String> files,
    required String outputZipPath,
  }) {
    final payload = jsonEncode({
      'files': files,
      'output_zip_path': outputZipPath,
    });
    final ptr = payload.toNativeUtf8();
    try {
      return (_consumeEnvelope(_packSnapshotZipJson(ptr)) as num).toInt();
    } finally {
      calloc.free(ptr);
    }
  }

  Map<String, String> unpackSnapshotZip(String zipPath) {
    final ptr = zipPath.toNativeUtf8();
    try {
      final map =
          _consumeEnvelope(_unpackSnapshotZipJson(ptr)) as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(k, v.toString()));
    } finally {
      calloc.free(ptr);
    }
  }
}
