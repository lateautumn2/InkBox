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

class TtsVoiceOption {
  const TtsVoiceOption({
    required this.name,
    required this.locale,
    this.quality = 400,
    this.requiresNetwork = false,
  });

  final String name;
  final String locale;
  final int quality;
  final bool requiresNetwork;
}

/// Thin platform abstraction isolating OS-specific features so
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
    String? voiceName,
  });
  Future<void> stopTts();
  Future<List<TtsEngineOption>> getTtsEngines() async => const [];
  Future<List<TtsVoiceOption>> getTtsVoices({
    String? engine,
    String? language,
  }) async =>
      const [];
  Future<void> openSystemTtsSettings() async {}
  Future<bool> playAudioFile(
    String path, {
    double speed = 1.0,
    String? playbackId,
  }) async =>
      false;
  Future<void> pauseAudio() async {}
  Future<void> resumeAudio() async {}
  Future<void> stopAudio() async {}
  Future<void> setAudioSpeed(double speed) async {}
  Future<void> saveSecret(String key, String value) async {}
  Future<String?> readSecret(String key) async => null;
  Future<void> deleteSecret(String key) async {}
  Future<int> getPdfPageCount(String path);
  Future<Uint8List?> renderPdfPage(
    String path,
    int pageIndex, {
    double scale = 2.0,
  });
}

class MethodChannelPlatformBridge implements PlatformBridge {
  static const MethodChannel _channel = MethodChannel('dev.inkbox/platform');
  static const EventChannel _eventsChannel = EventChannel('dev.inkbox/events');

  static Future<bool> transferLocalBackup(String path, {required bool export}) async {
    return await _channel.invokeMethod<bool>(
          export ? 'exportLocalBackup' : 'importLocalBackup',
          {'path': path},
        ) ??
        false;
  }

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
        name: raw['name'] as String? ?? 'Local',
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
    } on MissingPluginException {}
  }

  @override
  Future<void> setVolumeKeyPaging(bool enabled) async {
    try {
      await _channel
          .invokeMethod<void>('setVolumeKeyPaging', {'enabled': enabled});
    } on MissingPluginException {}
  }

  @override
  Future<void> setScreenBrightness(double? brightness) async {
    try {
      await _channel.invokeMethod<void>(
        'setScreenBrightness',
        {'brightness': brightness},
      );
    } on MissingPluginException {}
  }

  @override
  Future<String?> speakText(
    String text, {
    double rate = 1.0,
    double pitch = 1.0,
    String? language,
    String? engine,
    String? voiceName,
  }) async {
    try {
      return await _channel.invokeMethod<String>('speakText', {
        'text': text,
        'rate': rate,
        'pitch': pitch,
        'language': language,
        'engine': engine,
        'voiceName': voiceName,
      });
    } on MissingPluginException {
      return null;
    } on PlatformException {
      rethrow;
    }
  }

  @override
  Future<void> stopTts() async {
    try {
      await _channel.invokeMethod<void>('stopTts');
    } on MissingPluginException {}
  }

  @override
  Future<List<TtsEngineOption>> getTtsEngines() async {
    try {
      final raw = await _channel.invokeListMethod<dynamic>('getTtsEngines');
      if (raw == null) return const [];
      return raw
          .map((e) {
            final m = Map<String, dynamic>.from(e as Map);
            return TtsEngineOption(
              name: m['name'] as String? ?? '',
              label: m['label'] as String? ?? (m['name'] as String? ?? 'TTS'),
            );
          })
          .where((e) => e.name.isNotEmpty)
          .toList();
    } on MissingPluginException {
      return const [];
    }
  }

  @override
  Future<List<TtsVoiceOption>> getTtsVoices({
    String? engine,
    String? language,
  }) async {
    try {
      final raw = await _channel.invokeListMethod<dynamic>('getTtsVoices', {
        'engine': engine,
        'language': language,
      });
      if (raw == null) return const [];
      return raw
          .map((e) {
            final m = Map<String, dynamic>.from(e as Map);
            return TtsVoiceOption(
              name: m['name'] as String? ?? '',
              locale: m['locale'] as String? ?? '',
              quality: (m['quality'] as num?)?.toInt() ?? 400,
              requiresNetwork: m['requiresNetwork'] as bool? ?? false,
            );
          })
          .where((v) => v.name.isNotEmpty)
          .toList();
    } on MissingPluginException {
      return const [];
    }
  }

  @override
  Future<void> openSystemTtsSettings() async {
    try {
      await _channel.invokeMethod<void>('openSystemTtsSettings');
    } on MissingPluginException {}
  }

  @override
  Future<bool> playAudioFile(
    String path, {
    double speed = 1.0,
    String? playbackId,
  }) async {
    try {
      final ok = await _channel.invokeMethod<bool>('playAudioFile', {
        'path': path,
        'speed': speed,
        'playbackId': playbackId,
      });
      return ok ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<void> pauseAudio() async {
    try {
      await _channel.invokeMethod<void>('pauseAudio');
    } on MissingPluginException {}
  }

  @override
  Future<void> resumeAudio() async {
    try {
      await _channel.invokeMethod<void>('resumeAudio');
    } on MissingPluginException {}
  }

  @override
  Future<void> stopAudio() async {
    try {
      await _channel.invokeMethod<void>('stopAudio');
    } on MissingPluginException {}
  }

  @override
  Future<void> setAudioSpeed(double speed) async {
    try {
      await _channel.invokeMethod<void>('setAudioSpeed', {'speed': speed});
    } on MissingPluginException {}
  }

  @override
  Future<void> saveSecret(String key, String value) async {
    try {
      await _channel.invokeMethod<void>('saveSecret', {
        'key': key,
        'value': value,
      });
    } on MissingPluginException {}
  }

  @override
  Future<String?> readSecret(String key) async {
    try {
      return await _channel.invokeMethod<String>('readSecret', {'key': key});
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<void> deleteSecret(String key) async {
    try {
      await _channel.invokeMethod<void>('deleteSecret', {'key': key});
    } on MissingPluginException {}
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
