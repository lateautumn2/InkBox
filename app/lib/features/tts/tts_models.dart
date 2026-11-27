import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/providers/app_providers.dart';

enum TtsEngineMode {
  local,
  online,
}

enum OnlineTtsProviderKind {
  edgeTts,
  openAiCompatible,
  customHttp,
}

class EdgeVoicePreset {
  const EdgeVoicePreset({
    required this.id,
    required this.label,
    required this.locale,
  });

  final String id;
  final String label;
  final String locale;
}

const List<EdgeVoicePreset> kBuiltinEdgeVoices = [
  EdgeVoicePreset(
    id: 'zh-CN-XiaoxiaoNeural',
    label: '晓晓 (女 · 温柔自然)',
    locale: 'zh-CN',
  ),
  EdgeVoicePreset(
    id: 'zh-CN-YunxiNeural',
    label: '云希 (男 · 阳光清朗)',
    locale: 'zh-CN',
  ),
  EdgeVoicePreset(
    id: 'zh-CN-XiaoyiNeural',
    label: '晓伊 (女 · 活泼清晰)',
    locale: 'zh-CN',
  ),
  EdgeVoicePreset(
    id: 'zh-CN-YunjianNeural',
    label: '云健 (男 · 沉稳旁白)',
    locale: 'zh-CN',
  ),
  EdgeVoicePreset(
    id: 'zh-TW-HsiaoChenNeural',
    label: '曉臻 (女 · 台灣國語)',
    locale: 'zh-TW',
  ),
  EdgeVoicePreset(
    id: 'zh-HK-HiuGaaiNeural',
    label: '曉佳 (女 · 粵語)',
    locale: 'zh-HK',
  ),
  EdgeVoicePreset(
    id: 'en-US-AriaNeural',
    label: 'Aria (Female · US)',
    locale: 'en-US',
  ),
  EdgeVoicePreset(
    id: 'en-US-GuyNeural',
    label: 'Guy (Male · US)',
    locale: 'en-US',
  ),
  EdgeVoicePreset(
    id: 'ja-JP-NanamiNeural',
    label: 'Nanami (女性 · 日本語)',
    locale: 'ja-JP',
  ),
  EdgeVoicePreset(
    id: 'ja-JP-KeitaNeural',
    label: 'Keita (男性 · 日本語)',
    locale: 'ja-JP',
  ),
];

const List<String> kOpenAiVoices = [
  'alloy',
  'ash',
  'coral',
  'echo',
  'fable',
  'nova',
  'onyx',
  'sage',
  'shimmer',
];

const List<String> kOnlineAudioFormats = ['mp3', 'opus', 'aac', 'wav'];

@immutable
class OnlineTtsProfile {
  const OnlineTtsProfile({
    required this.id,
    required this.name,
    required this.kind,
    this.endpointUrl = '',
    this.edgeUseGateway = false,
    this.model = 'tts-1',
    this.voice = 'zh-CN-XiaoxiaoNeural',
    this.format = 'mp3',
    this.httpMethod = 'POST',
    this.headersJson = '{}',
    this.bodyTemplate = '',
  });

  final String id;
  final String name;
  final OnlineTtsProviderKind kind;
  final String endpointUrl;
  final bool edgeUseGateway;
  final String model;
  final String voice;
  final String format;
  final String httpMethod; // GET | POST
  final String headersJson;
  final String bodyTemplate;

  OnlineTtsProfile copyWith({
    String? id,
    String? name,
    OnlineTtsProviderKind? kind,
    String? endpointUrl,
    bool? edgeUseGateway,
    String? model,
    String? voice,
    String? format,
    String? httpMethod,
    String? headersJson,
    String? bodyTemplate,
  }) {
    return OnlineTtsProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      endpointUrl: endpointUrl ?? this.endpointUrl,
      edgeUseGateway: edgeUseGateway ?? this.edgeUseGateway,
      model: model ?? this.model,
      voice: voice ?? this.voice,
      format: format ?? this.format,
      httpMethod: httpMethod ?? this.httpMethod,
      headersJson: headersJson ?? this.headersJson,
      bodyTemplate: bodyTemplate ?? this.bodyTemplate,
    );
  }

  /// Never serializes API keys / secrets into JSON (stored encrypted via PlatformBridge).
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'kind': kind.name,
        'endpointUrl': endpointUrl,
        'edgeUseGateway': edgeUseGateway,
        'model': model,
        'voice': voice,
        'format': format,
        'httpMethod': httpMethod,
        'headersJson': headersJson,
        'bodyTemplate': bodyTemplate,
      };

  factory OnlineTtsProfile.fromJson(Map<String, dynamic> json) {
    final kindStr = json['kind'] as String? ?? 'edgeTts';
    final kind = OnlineTtsProviderKind.values.firstWhere(
      (k) => k.name == kindStr,
      orElse: () => OnlineTtsProviderKind.edgeTts,
    );
    return OnlineTtsProfile(
      id: json['id'] as String? ?? 'edge_default',
      name: json['name'] as String? ?? 'Edge TTS',
      kind: kind,
      endpointUrl: json['endpointUrl'] as String? ?? '',
      edgeUseGateway: json['edgeUseGateway'] as bool? ?? false,
      model: json['model'] as String? ?? 'tts-1',
      voice: json['voice'] as String? ?? 'zh-CN-XiaoxiaoNeural',
      format: json['format'] as String? ?? 'mp3',
      httpMethod: (json['httpMethod'] as String? ?? 'POST').toUpperCase(),
      headersJson: json['headersJson'] as String? ?? '{}',
      bodyTemplate: json['bodyTemplate'] as String? ?? '',
    );
  }

  static List<OnlineTtsProfile> defaultPresets() => const [
        OnlineTtsProfile(
          id: 'edge_default',
          name: 'Edge TTS',
          kind: OnlineTtsProviderKind.edgeTts,
          endpointUrl: 'http://127.0.0.1:3000/api/tts',
          edgeUseGateway: false,
          voice: 'zh-CN-XiaoxiaoNeural',
          format: 'mp3',
        ),
        OnlineTtsProfile(
          id: 'openai_default',
          name: 'OpenAI TTS',
          kind: OnlineTtsProviderKind.openAiCompatible,
          endpointUrl: 'https://api.openai.com/v1/audio/speech',
          model: 'tts-1',
          voice: 'alloy',
          format: 'mp3',
        ),
      ];

  static OnlineTtsProfile newTemplate(
    OnlineTtsProviderKind kind, {
    required String id,
    String? name,
  }) {
    switch (kind) {
      case OnlineTtsProviderKind.edgeTts:
        return OnlineTtsProfile(
          id: id,
          name: name ?? 'Edge TTS',
          kind: kind,
          endpointUrl: 'http://127.0.0.1:3000/api/tts',
          edgeUseGateway: false,
          voice: 'zh-CN-XiaoxiaoNeural',
          format: 'mp3',
        );
      case OnlineTtsProviderKind.openAiCompatible:
        return OnlineTtsProfile(
          id: id,
          name: name ?? 'OpenAI TTS',
          kind: kind,
          endpointUrl: 'https://api.openai.com/v1/audio/speech',
          model: 'tts-1',
          voice: 'nova',
          format: 'mp3',
        );
      case OnlineTtsProviderKind.customHttp:
        return OnlineTtsProfile(
          id: id,
          name: name ?? 'Custom HTTP TTS',
          kind: kind,
          endpointUrl:
              'https://example.com/tts?text={{textEncoded}}&voice={{voice}}&rate={{rate}}',
          httpMethod: 'GET',
          headersJson: '{}',
          bodyTemplate:
              '{"text":"{{text}}","voice":"{{voice}}","rate":{{rate}}}',
          voice: 'default',
          format: 'mp3',
        );
    }
  }
}

/// Parses Legado HTTP TTS JSON array or single object into [OnlineTtsProfile] items.
List<OnlineTtsProfile> parseLegadoHttpTtsJson(String rawJson) {
  final trimmed = rawJson.trim();
  if (trimmed.isEmpty) return const [];
  dynamic decoded;
  try {
    decoded = jsonDecode(trimmed);
  } catch (_) {
    return const [];
  }
  final List<dynamic> list = decoded is List ? decoded : [decoded];
  final result = <OnlineTtsProfile>[];
  var seq = DateTime.now().millisecondsSinceEpoch;
  for (final entry in list) {
    if (entry is! Map) continue;
    final map = Map<String, dynamic>.from(entry);
    final rawName = (map['name'] ?? '').toString().trim();
    final rawUrl = (map['url'] ?? '').toString().trim();
    if (rawUrl.isEmpty) continue;

    String endpoint = rawUrl;
    String method = 'GET';
    String headersJson = '{}';
    String bodyTemplate = '';

    // Support Legado inline options syntax: "https://host/tts,{\"method\":\"POST\",\"body\":\"...\"}"
    final commaIdx = rawUrl.indexOf(',{');
    if (commaIdx > 0) {
      endpoint = rawUrl.substring(0, commaIdx).trim();
      final optRaw = rawUrl.substring(commaIdx + 1).trim();
      try {
        final optMap = jsonDecode(optRaw);
        if (optMap is Map) {
          method = (optMap['method'] ?? 'GET').toString().toUpperCase();
          if (optMap['body'] != null) {
            bodyTemplate = optMap['body'] is String
                ? optMap['body'] as String
                : jsonEncode(optMap['body']);
          }
          if (optMap['headers'] is Map) {
            headersJson = jsonEncode(optMap['headers']);
          }
        }
      } catch (_) {}
    }
    if (map['header'] is String && (map['header'] as String).trim().isNotEmpty) {
      headersJson = (map['header'] as String).trim();
    } else if (map['header'] is Map) {
      headersJson = jsonEncode(map['header']);
    }
    // Map Legado placeholders `{{speakText}}` -> `{{text}}`
    endpoint = endpoint.replaceAll('{{speakText}}', '{{textEncoded}}');
    bodyTemplate = bodyTemplate.replaceAll('{{speakText}}', '{{text}}');

    result.add(
      OnlineTtsProfile(
        id: 'legado_${seq++}',
        name: rawName.isNotEmpty ? rawName : 'Legado TTS',
        kind: OnlineTtsProviderKind.customHttp,
        endpointUrl: endpoint,
        httpMethod: method == 'POST' ? 'POST' : 'GET',
        headersJson: headersJson,
        bodyTemplate: bodyTemplate,
        voice: 'default',
        format: 'mp3',
      ),
    );
  }
  return result;
}

@immutable
class TtsConfigState {
  const TtsConfigState({
    this.mode = TtsEngineMode.local,
    this.activeProfileId = 'edge_default',
    this.profiles = const [],
    this.secrets = const {},
    this.fallbackToLocalTts = true,
    this.sleepAtChapterEnd = false,
    this.hydrated = false,
  });

  final TtsEngineMode mode;
  final String activeProfileId;
  final List<OnlineTtsProfile> profiles;
  final Map<String, String> secrets; // Kept in memory + Keystore, never serialized
  final bool fallbackToLocalTts;
  final bool sleepAtChapterEnd;
  final bool hydrated;

  List<OnlineTtsProfile> get effectiveProfiles =>
      profiles.isEmpty ? OnlineTtsProfile.defaultPresets() : profiles;

  OnlineTtsProfile get activeProfile {
    final list = effectiveProfiles;
    return list.where((p) => p.id == activeProfileId).firstOrNull ?? list.first;
  }

  String secretFor(String profileId) => secrets[profileId] ?? '';

  TtsConfigState copyWith({
    TtsEngineMode? mode,
    String? activeProfileId,
    List<OnlineTtsProfile>? profiles,
    Map<String, String>? secrets,
    bool? fallbackToLocalTts,
    bool? sleepAtChapterEnd,
    bool? hydrated,
  }) {
    return TtsConfigState(
      mode: mode ?? this.mode,
      activeProfileId: activeProfileId ?? this.activeProfileId,
      profiles: profiles ?? this.profiles,
      secrets: secrets ?? this.secrets,
      fallbackToLocalTts: fallbackToLocalTts ?? this.fallbackToLocalTts,
      sleepAtChapterEnd: sleepAtChapterEnd ?? this.sleepAtChapterEnd,
      hydrated: hydrated ?? this.hydrated,
    );
  }

  Map<String, dynamic> toSafeJson() => {
        'mode': mode.name,
        'activeProfileId': activeProfileId,
        'profiles': effectiveProfiles.map((p) => p.toJson()).toList(),
        'fallbackToLocalTts': fallbackToLocalTts,
        'sleepAtChapterEnd': sleepAtChapterEnd,
      };
}

class TtsConfigController extends Notifier<TtsConfigState> {
  static const _kKey = 'inkbox_tts_config_v2';
  bool _userMutated = false;

  @override
  TtsConfigState build() {
    _userMutated = false;
    _hydrate();
    return TtsConfigState(profiles: OnlineTtsProfile.defaultPresets());
  }

  Future<void> _hydrate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kKey);
      List<OnlineTtsProfile> profiles = OnlineTtsProfile.defaultPresets();
      var mode = TtsEngineMode.local;
      var activeId = profiles.first.id;
      var fallback = true;
      var chapterEnd = false;

      if (raw != null && raw.isNotEmpty) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        final modeStr = map['mode'] as String? ?? 'local';
        mode = modeStr == 'online' ? TtsEngineMode.online : TtsEngineMode.local;
        final rawProfiles = map['profiles'] as List<dynamic>?;
        if (rawProfiles != null && rawProfiles.isNotEmpty) {
          profiles = rawProfiles
              .map((e) =>
                  OnlineTtsProfile.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
        }
        activeId = map['activeProfileId'] as String? ?? profiles.first.id;
        fallback = map['fallbackToLocalTts'] as bool? ?? true;
        chapterEnd = map['sleepAtChapterEnd'] as bool? ?? false;
      }

      final platform = ref.read(platformBridgeProvider);
      final secrets = <String, String>{};
      for (final p in profiles) {
        final s = await platform.readSecret('tts_secret_${p.id}');
        if (s != null && s.isNotEmpty) {
          secrets[p.id] = s;
        }
      }

      if (_userMutated) {
        state = state.copyWith(hydrated: true);
        return;
      }

      state = TtsConfigState(
        mode: mode,
        activeProfileId: activeId,
        profiles: profiles,
        secrets: secrets,
        fallbackToLocalTts: fallback,
        sleepAtChapterEnd: chapterEnd,
        hydrated: true,
      );
    } catch (_) {
      state = state.copyWith(hydrated: true);
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kKey, jsonEncode(state.toSafeJson()));
    } catch (_) {}
  }

  Future<void> setMode(TtsEngineMode mode) async {
    _userMutated = true;
    state = state.copyWith(mode: mode, hydrated: true);
    await _persist();
  }

  Future<void> setActiveProfile(String profileId) async {
    _userMutated = true;
    state = state.copyWith(activeProfileId: profileId, hydrated: true);
    await _persist();
  }

  Future<void> setFallbackToLocalTts(bool value) async {
    _userMutated = true;
    state = state.copyWith(fallbackToLocalTts: value, hydrated: true);
    await _persist();
  }

  Future<void> setSleepAtChapterEnd(bool value) async {
    _userMutated = true;
    state = state.copyWith(sleepAtChapterEnd: value, hydrated: true);
    await _persist();
  }

  Future<void> upsertProfile(
    OnlineTtsProfile profile, {
    String? apiKey,
    bool activate = true,
  }) async {
    _userMutated = true;
    final list = [...state.effectiveProfiles];
    final idx = list.indexWhere((p) => p.id == profile.id);
    if (idx >= 0) {
      list[idx] = profile;
    } else {
      list.add(profile);
    }

    final nextSecrets = Map<String, String>.from(state.secrets);
    if (apiKey != null) {
      final platform = ref.read(platformBridgeProvider);
      if (apiKey.trim().isEmpty) {
        nextSecrets.remove(profile.id);
        await platform.deleteSecret('tts_secret_${profile.id}');
      } else {
        nextSecrets[profile.id] = apiKey.trim();
        await platform.saveSecret('tts_secret_${profile.id}', apiKey.trim());
      }
    }

    state = state.copyWith(
      profiles: list,
      secrets: nextSecrets,
      activeProfileId: activate ? profile.id : state.activeProfileId,
      hydrated: true,
    );
    await _persist();
  }

  Future<void> deleteProfile(String profileId) async {
    _userMutated = true;
    final list = state.effectiveProfiles
        .where((p) => p.id != profileId)
        .toList();
    final safeList = list.isEmpty ? OnlineTtsProfile.defaultPresets() : list;
    final nextSecrets = Map<String, String>.from(state.secrets)
      ..remove(profileId);
    await ref.read(platformBridgeProvider).deleteSecret('tts_secret_$profileId');
    final nextActive = safeList.any((p) => p.id == state.activeProfileId)
        ? state.activeProfileId
        : safeList.first.id;
    state = state.copyWith(
      profiles: safeList,
      secrets: nextSecrets,
      activeProfileId: nextActive,
      hydrated: true,
    );
    await _persist();
  }

  Future<void> resetAll() async {
    _userMutated = true;
    for (final p in state.effectiveProfiles) {
      await ref.read(platformBridgeProvider).deleteSecret('tts_secret_${p.id}');
    }
    state = TtsConfigState(
      mode: TtsEngineMode.local,
      profiles: OnlineTtsProfile.defaultPresets(),
      activeProfileId: 'edge_default',
      hydrated: true,
    );
    await _persist();
  }
}

final ttsConfigProvider =
    NotifierProvider<TtsConfigController, TtsConfigState>(
  TtsConfigController.new,
);
