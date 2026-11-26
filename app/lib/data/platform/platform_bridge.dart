import 'package:flutter/services.dart';

class PickedDirectory {
  const PickedDirectory({required this.uri, required this.name});
  final String uri;
  final String name;
}

class ScannedTreeFile {
  const ScannedTreeFile({
    required this.uri,
    required this.name,
    required this.ext,
    required this.size,
  });

  final String uri;
  final String name;
  final String ext;
  final int size;
}

class PlatformEvent {
  const PlatformEvent({required this.type, required this.payload});
  final String type;
  final Map<String, dynamic> payload;
}

class PickedDocumentsResult {
  const PickedDocumentsResult({
    this.paths = const [],
    this.errors = const [],
  });

  final List<String> paths;
  final List<String> errors;
}

class TtsEngineOption {
  const TtsEngineOption({required this.name, required this.label});
  final String name;
  final String label;
}

/// Thin 5-capability platform abstraction isolating OS-specific features so
/// Android, iOS, Windows, HarmonyOS NEXT, and macOS only implement this contract.
abstract class PlatformBridge {
  Stream<PlatformEvent> get events;
  Future<List<String>> pickDocuments();
  Future<PickedDocumentsResult> pickDocumentsDetailed() async =>
      PickedDocumentsResult(paths: await pickDocuments());
  Future<PickedDirectory?> pickPersistentDirectory();
  Future<List<ScannedTreeFile>> scanPersistentDirectory(String treeUri);
  Future<String?> stageDocumentUri(String uri, {String? fileName});
  Future<void> setKeepScreenOn(bool enabled);
  Future<void> setVolumeKeyPaging(bool enabled);
  Future<void> setScreenBrightness(double? brightness);
  Future<String?> speakText(
    String text, {
    double rate = 1.0,
    double pitch = 1.0,
    String? language,
    String? engine,
  });
  Future<void> stopTts();
  Future<List<TtsEngineOption>> getTtsEngines() async => const [];
  Future<void> openSystemTtsSettings() async {}
  Future<int> getPdfPageCount(String path);
  Future<Uint8List?> renderPdfPage(String path, int pageIndex, {double scale = 2.0});
}

class MethodChannelPlatformBridge implements PlatformBridge {
  static const MethodChannel _channel = MethodChannel('dev.inkbox/platform');
  static const EventChannel _eventsChannel = EventChannel('dev.inkbox/events');

  Stream<PlatformEvent>? _cachedStream;

  @override
  Stream<PlatformEvent> get events {
    _cachedStream ??= _eventsChannel.receiveBroadcastStream().map((raw) {
      final map = Map<String, dynamic>.from(raw as Map);
      return PlatformEvent(
        type: map['type'] as String? ?? '',
        payload: Map<String, dynamic>.from(map['payload'] as Map? ?? const {}),
      );
    }).handleError((_) {});
    return _cachedStream!;
  }

  @override
  Future<List<String>> pickDocuments() async {
    try {
      final res = await _channel.invokeListMethod<String>('pickDocuments');
      return res ?? const [];
    } on MissingPluginException {
      return const [];
    }
  }

  @override
  Future<PickedDocumentsResult> pickDocumentsDetailed() async {
    try {
      final raw = await _channel
          .invokeMapMethod<String, dynamic>('pickDocumentsDetailed');
      if (raw == null) return const PickedDocumentsResult();
      final paths =
          (raw['paths'] as List<dynamic>? ?? const []).map((e) => '$e').toList();
      final errors = (raw['errors'] as List<dynamic>? ?? const [])
          .map((e) => '$e')
          .toList();
      return PickedDocumentsResult(paths: paths, errors: errors);
    } on MissingPluginException {
      return PickedDocumentsResult(paths: await pickDocuments());
    }
  }

  @override
  Future<PickedDirectory?> pickPersistentDirectory() async {
    try {
      final raw = await _channel
          .invokeMapMethod<String, dynamic>('pickPersistentDirectory');
      if (raw == null || raw['uri'] == null) return null;
      return PickedDirectory(
        uri: raw['uri'] as String,
        name: raw['name'] as String? ?? '本地目录',
      );
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<List<ScannedTreeFile>> scanPersistentDirectory(String treeUri) async {
    try {
      final raw = await _channel.invokeListMethod<dynamic>(
        'scanPersistentDirectory',
        {'treeUri': treeUri},
      );
      if (raw == null) return const [];
      return raw.map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        return ScannedTreeFile(
          uri: m['uri'] as String? ?? '',
          name: m['name'] as String? ?? '',
          ext: m['ext'] as String? ?? '',
          size: (m['size'] as num?)?.toInt() ?? 0,
        );
      }).toList();
    } on MissingPluginException {
      return const [];
    }
  }

  @override
  Future<String?> stageDocumentUri(String uri, {String? fileName}) async {
    try {
      return await _channel.invokeMethod<String>('stageDocumentUri', {
        'uri': uri,
        'fileName': fileName,
      });
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<void> setKeepScreenOn(bool enabled) async {
    try {
      await _channel.invokeMethod<void>('setKeepScreenOn', {'enabled': enabled});
    } on MissingPluginException {
      // No-op in headless tests
    }
  }

  @override
  Future<void> setVolumeKeyPaging(bool enabled) async {
    try {
      await _channel
          .invokeMethod<void>('setVolumeKeyPaging', {'enabled': enabled});
    } on MissingPluginException {
      // No-op in headless tests
    }
  }

  @override
  Future<void> setScreenBrightness(double? brightness) async {
    try {
      await _channel.invokeMethod<void>(
        'setScreenBrightness',
        {'brightness': brightness},
      );
    } on MissingPluginException {
      // No-op
    }
  }

  @override
  Future<String?> speakText(
    String text, {
    double rate = 1.0,
    double pitch = 1.0,
    String? language,
    String? engine,
  }) async {
    try {
      return await _channel.invokeMethod<String>('speakText', {
        'text': text,
        'rate': rate,
        'pitch': pitch,
        'language': language,
        'engine': engine,
      });
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<void> stopTts() async {
    try {
      await _channel.invokeMethod<void>('stopTts');
    } on MissingPluginException {
      // No-op
    }
  }

  @override
  Future<List<TtsEngineOption>> getTtsEngines() async {
    try {
      final raw = await _channel.invokeListMethod<dynamic>('getTtsEngines');
      if (raw == null) return const [];
      return raw.map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        return TtsEngineOption(
          name: m['name'] as String? ?? '',
          label: m['label'] as String? ?? (m['name'] as String? ?? 'TTS 引擎'),
        );
      }).where((e) => e.name.isNotEmpty).toList();
    } on MissingPluginException {
      return const [];
    }
  }

  @override
  Future<void> openSystemTtsSettings() async {
    try {
      await _channel.invokeMethod<void>('openSystemTtsSettings');
    } on MissingPluginException {
      // No-op
    }
  }

  @override
  Future<int> getPdfPageCount(String path) async {
    try {
      final count = await _channel.invokeMethod<int>(
        'getPdfPageCount',
        {'path': path},
      );
      return count ?? 0;
    } on MissingPluginException {
      return 0;
    }
  }

  @override
  Future<Uint8List?> renderPdfPage(
    String path,
    int pageIndex, {
    double scale = 2.0,
  }) async {
    try {
      return await _channel.invokeMethod<Uint8List>('renderPdfPage', {
        'path': path,
        'pageIndex': pageIndex,
        'scale': scale,
      });
    } on MissingPluginException {
      return null;
    }
  }
}
