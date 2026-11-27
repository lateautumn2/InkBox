import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/icons/ink_icons.dart';
import '../../core/l10n/l10n_helpers.dart';
import '../../core/layout/responsive_layout.dart';
import '../../core/theme/inkbox_theme.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/widgets/floating_surface.dart';
import '../../core/widgets/ink_controls.dart';
import '../../data/platform/platform_bridge.dart';
import '../../data/providers/app_providers.dart';
import '../book_reader/book_reader_settings.dart';
import '../tts/online_tts_client.dart';
import '../tts/tts_audio_cache.dart';
import '../tts/tts_models.dart';

class TtsSettingsPage extends ConsumerStatefulWidget {
  const TtsSettingsPage({super.key});

  @override
  ConsumerState<TtsSettingsPage> createState() => _TtsSettingsPageState();
}

class _TtsSettingsPageState extends ConsumerState<TtsSettingsPage> {
  static const _langCodes = [
    'system',
    'zh-CN',
    'zh-TW',
    'zh-HK',
    'en-US',
    'ja-JP',
  ];

  static const _timerPresets = [0, 15, 30, 60];

  final OnlineTtsClient _onlineClient = OnlineTtsClient();
  final TtsAudioCache _cache = TtsAudioCache();

  List<TtsEngineOption> _engines = const [];
  List<TtsVoiceOption> _localVoices = const [];
  bool _loadingEngines = true;
  bool _previewPlaying = false;
  bool _testingConnection = false;
  OnlineTtsTestResult? _lastTestResult;
  int _cacheBytes = 0;

  String? _activePreviewUtteranceId;
  String? _activePreviewPlaybackId;
  StreamSubscription<PlatformEvent>? _eventSub;
  late final PlatformBridge _platform;

  String? _loadedProfileId;
  bool _syncedAfterHydrate = false;
  late final TextEditingController _nameCtrl = TextEditingController();
  late final TextEditingController _endpointCtrl = TextEditingController();
  late final TextEditingController _azureRegionCtrl = TextEditingController();
  late final TextEditingController _apiKeyCtrl = TextEditingController();
  late final TextEditingController _modelCtrl = TextEditingController();
  late final TextEditingController _voiceCtrl = TextEditingController();
  late final TextEditingController _headersCtrl = TextEditingController();
  late final TextEditingController _bodyCtrl = TextEditingController();

  bool _edgeUseGateway = false;
  bool _edgeGatewayUseSsml = false;
  String _selectedFormat = 'mp3';
  String _selectedMethod = 'POST';
  OnlineTtsProviderKind _selectedKind = OnlineTtsProviderKind.edgeTts;

  @override
  void initState() {
    super.initState();
    _platform = ref.read(platformBridgeProvider);
    _loadEnginesAndVoices();
    _refreshCacheSize();
    _eventSub = _platform.events.listen((ev) {
      if (!mounted) return;
      if (ev.type == 'tts_done' || ev.type == 'tts_error') {
        final uid = (ev.payload['utteranceId'] as String? ?? '').trim();
        if (_activePreviewUtteranceId != null &&
            uid.isNotEmpty &&
            uid != _activePreviewUtteranceId) {
          return;
        }
        setState(() {
          _activePreviewUtteranceId = null;
          _previewPlaying = false;
        });
      } else if (ev.type == 'audio_done' || ev.type == 'audio_error') {
        final pid = (ev.payload['playbackId'] as String? ?? '').trim();
        if (_activePreviewPlaybackId != null &&
            pid.isNotEmpty &&
            pid != _activePreviewPlaybackId) {
          return;
        }
        setState(() {
          _activePreviewPlaybackId = null;
          _previewPlaying = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    _nameCtrl.dispose();
    _endpointCtrl.dispose();
    _azureRegionCtrl.dispose();
    _apiKeyCtrl.dispose();
    _modelCtrl.dispose();
    _voiceCtrl.dispose();
    _headersCtrl.dispose();
    _bodyCtrl.dispose();
    if (_previewPlaying) {
      _platform.stopTts();
      _platform.stopAudio();
    }
    super.dispose();
  }

  Future<void> _loadEnginesAndVoices() async {
    setState(() => _loadingEngines = true);
    final platform = ref.read(platformBridgeProvider);
    final readerSettings = ref.read(bookReaderSettingsProvider);
    final list = await platform.getTtsEngines();
    final voices = await platform.getTtsVoices(
      engine: readerSettings.ttsEngine.isEmpty ? null : readerSettings.ttsEngine,
      language: readerSettings.ttsLanguage,
    );
    if (!mounted) return;
    setState(() {
      _engines = list;
      _localVoices = voices;
      _loadingEngines = false;
    });
  }

  Future<void> _refreshLocalVoices({
    String? engine,
    String? language,
  }) async {
    final platform = ref.read(platformBridgeProvider);
    final voices = await platform.getTtsVoices(
      engine: engine == null || engine.isEmpty ? null : engine,
      language: language,
    );
    if (mounted) {
      setState(() => _localVoices = voices);
    }
  }

  Future<void> _refreshCacheSize() async {
    final bytes = await _cache.totalSizeBytes();
    if (mounted) setState(() => _cacheBytes = bytes);
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  void _syncProfileForm(TtsConfigState cfg, {bool force = false}) {
    final profile = cfg.activeProfile;
    final shouldHydrateSync = cfg.hydrated && !_syncedAfterHydrate;
    if (!force && !shouldHydrateSync && _loadedProfileId == profile.id) return;
    if (cfg.hydrated) _syncedAfterHydrate = true;
    _loadedProfileId = profile.id;
    _selectedKind = profile.kind;
    _edgeUseGateway = profile.edgeUseGateway;
    _edgeGatewayUseSsml = profile.edgeGatewayUseSsml;
    _selectedFormat = profile.format;
    _selectedMethod = profile.httpMethod;
    _nameCtrl.text = profile.name;
    _endpointCtrl.text = profile.endpointUrl;
    _azureRegionCtrl.text = profile.azureRegion;
    _apiKeyCtrl.text = cfg.secretFor(profile.id);
    _modelCtrl.text = profile.model;
    _voiceCtrl.text = profile.voice;
    _headersCtrl.text = profile.headersJson;
    _bodyCtrl.text = profile.bodyTemplate;
  }

  OnlineTtsProfile _draftProfile(OnlineTtsProfile base) {
    final region = _azureRegionCtrl.text.trim().isEmpty
        ? 'eastus'
        : _azureRegionCtrl.text.trim();
    var endpoint = _endpointCtrl.text.trim();
    if (_selectedKind == OnlineTtsProviderKind.azureSpeech && endpoint.isEmpty) {
      endpoint = 'https://$region.tts.speech.microsoft.com/cognitiveservices/v1';
    }
    return base.copyWith(
      name: _nameCtrl.text.trim().isEmpty ? base.name : _nameCtrl.text.trim(),
      kind: _selectedKind,
      endpointUrl: endpoint,
      edgeUseGateway: _edgeUseGateway,
      edgeGatewayUseSsml: _edgeGatewayUseSsml,
      azureRegion: region,
      model: _modelCtrl.text.trim().isEmpty ? 'tts-1' : _modelCtrl.text.trim(),
      voice: _voiceCtrl.text.trim().isEmpty
          ? base.voice
          : _voiceCtrl.text.trim(),
      format: _selectedFormat,
      httpMethod: _selectedMethod,
      headersJson:
          _headersCtrl.text.trim().isEmpty ? '{}' : _headersCtrl.text.trim(),
      bodyTemplate: _bodyCtrl.text,
    );
  }

  Future<void> _saveCurrentProfile() async {
    final cfg = ref.read(ttsConfigProvider);
    final updated = _draftProfile(cfg.activeProfile);
    await ref.read(ttsConfigProvider.notifier).upsertProfile(
          updated,
          apiKey: _apiKeyCtrl.text,
        );
    _loadedProfileId = updated.id;
  }

  Future<void> _stopActivePreview() async {
    _activePreviewUtteranceId = null;
    _activePreviewPlaybackId = null;
    await _platform.stopTts();
    await _platform.stopAudio();
    if (mounted && _previewPlaying) {
      setState(() => _previewPlaying = false);
    }
  }

  Future<void> _toggleLocalPreview(BookReaderSettings settings) async {
    final l10n = context.l10n;
    final platform = _platform;
    if (_previewPlaying) {
      await _stopActivePreview();
      return;
    }

    await platform.stopAudio();
    final appLocale = ref.read(appearanceProvider).appLocaleCode;
    final sample = ttsPreviewSampleText(settings.ttsLanguage, appLocale);

    setState(() => _previewPlaying = true);
    try {
      final uid = await platform.speakText(
        sample,
        rate: settings.ttsRate,
        pitch: settings.ttsPitch,
        language: settings.ttsLanguage,
        engine: settings.ttsEngine.isEmpty ? null : settings.ttsEngine,
        voiceName: settings.ttsVoice.isEmpty ? null : settings.ttsVoice,
      );
      if (!mounted) return;
      if (uid == null) {
        setState(() => _previewPlaying = false);
        _toast(l10n.errTtsUnavailable);
      } else {
        _activePreviewUtteranceId = uid;
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _previewPlaying = false);
      _toast(localizeError(l10n, e));
    }
  }

  Future<void> _testAndPreviewOnline(BookReaderSettings settings) async {
    final l10n = context.l10n;
    final platform = _platform;
    if (_previewPlaying) {
      await _stopActivePreview();
      return;
    }

    await platform.stopTts();
    await _saveCurrentProfile();
    if (!mounted) return;

    final cfg = ref.read(ttsConfigProvider);
    final profile = cfg.activeProfile;
    final apiKey = cfg.secretFor(profile.id);
    final appLocale = ref.read(appearanceProvider).appLocaleCode;
    final sample = ttsPreviewSampleText(settings.ttsLanguage, appLocale);

    setState(() {
      _testingConnection = true;
      _lastTestResult = null;
    });

    final res = await _onlineClient.testConnection(
      profile: profile,
      sampleText: sample,
      rate: settings.ttsRate,
      pitch: settings.ttsPitch,
      apiKey: apiKey,
      enableCache: cfg.cacheEnabled,
      maxCacheBytes: cfg.cacheMaxMb * 1024 * 1024,
    );
    if (!mounted) return;

    setState(() {
      _testingConnection = false;
      _lastTestResult = res;
    });
    unawaited(_refreshCacheSize());

    if (res.ok && res.audioPath != null) {
      final pid = 'preview_${DateTime.now().millisecondsSinceEpoch}';
      setState(() {
        _activePreviewPlaybackId = pid;
        _previewPlaying = true;
      });
      final started = await platform.playAudioFile(
        res.audioPath!,
        speed: settings.ttsRate,
        playbackId: pid,
      );
      if (!started && mounted) {
        setState(() {
          _activePreviewPlaybackId = null;
          _previewPlaying = false;
        });
        _toast(l10n.errTtsSpeakFailed);
      }
    } else if (!res.ok) {
      _toast(
        localizeError(l10n, res.errorCode ?? 'ERR_UNKNOWN'),
      );
    }
  }

  Future<void> _showNewProfileModal() async {
    final l10n = context.l10n;
    final nameCtrl = TextEditingController();
    var chosenKind = OnlineTtsProviderKind.edgeTts;

    final createdKind = await showInkModal<OnlineTtsProviderKind>(
      context: context,
      title: l10n.ttsNewProfile,
      disposables: [nameCtrl],
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkTextField(
              controller: nameCtrl,
              label: l10n.ttsProfileNameLabel,
              autofocus: true,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: OnlineTtsProviderKind.values.map((k) {
                return InkPillChip(
                  label: k.labelOf(l10n),
                  selected: chosenKind == k,
                  onTap: () => setModalState(() => chosenKind = k),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actionsBuilder: (ctx) => [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(chosenKind),
          child: Text(l10n.create),
        ),
      ],
    );

    if (createdKind == null || !mounted) return;
    final tpl = OnlineTtsProfile.newTemplate(
      createdKind,
      id: 'tts_${DateTime.now().millisecondsSinceEpoch}',
      name: nameCtrl.text.trim().isEmpty ? null : nameCtrl.text.trim(),
    );
    await ref.read(ttsConfigProvider.notifier).upsertProfile(tpl, activate: true);
    if (mounted) {
      _syncProfileForm(ref.read(ttsConfigProvider), force: true);
      setState(() {});
    }
  }

  Future<void> _showLegadoImportModal() async {
    final l10n = context.l10n;
    final jsonCtrl = TextEditingController();
    final raw = await showInkModal<String>(
      context: context,
      title: l10n.ttsImportLegado,
      disposables: [jsonCtrl],
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkTextField(
            controller: jsonCtrl,
            label: l10n.ruleJsonOrRegexLabel,
            maxLines: 6,
            minLines: 4,
            monospace: true,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () async {
                final data = await Clipboard.getData(Clipboard.kTextPlain);
                if (data?.text != null) {
                  jsonCtrl.text = data!.text!;
                }
              },
              child: Text(l10n.pasteFromClipboard),
            ),
          ),
        ],
      ),
      actionsBuilder: (ctx) => [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(jsonCtrl.text),
          child: Text(l10n.importRulesBtn),
        ),
      ],
    );

    if (raw == null || raw.trim().isEmpty || !mounted) return;
    final imported = parseLegadoHttpTtsJson(raw);
    if (imported.isEmpty) {
      _toast(l10n.errInvalidJson);
      return;
    }
    final ctrl = ref.read(ttsConfigProvider.notifier);
    for (final p in imported) {
      await ctrl.upsertProfile(p, activate: true);
    }
    if (mounted) {
      _syncProfileForm(ref.read(ttsConfigProvider), force: true);
      setState(() {});
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final settings = ref.watch(bookReaderSettingsProvider);
    final settingsCtrl = ref.read(bookReaderSettingsProvider.notifier);
    final ttsCfg = ref.watch(ttsConfigProvider);
    final ttsCfgCtrl = ref.read(ttsConfigProvider.notifier);
    final tokens = InkBoxTokens.of(context);
    final isOnline = ttsCfg.mode == TtsEngineMode.online;

    _syncProfileForm(ttsCfg);

    return Scaffold(
      body: SafeArea(
        child: ResponsiveConstrainedBody(
          maxWidth: kMaxContentWidth,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    InkCircleButton(
                      icon: InkIconWidget(
                        InkIcon.back,
                        size: 18,
                        color: tokens.inkPrimary,
                      ),
                      onPressed: () => context.pop(),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.ttsSettingsTitle,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: tokens.inkPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.reset,
                      onPressed: () async {
                        await settingsCtrl.update(
                          (s) => s.copyWith(
                            ttsRate: 1.0,
                            ttsPitch: 1.0,
                            ttsLanguage: 'system',
                            ttsEngine: '',
                            ttsVoice: '',
                            ttsAutoTurnPage: true,
                            ttsSleepTimerMinutes: 0,
                          ),
                        );
                        await ttsCfgCtrl.resetAll();
                        if (!mounted) return;
                        _syncProfileForm(ref.read(ttsConfigProvider), force: true);
                        _toast(l10n.ttsResetToast);
                      },
                      icon: InkIconWidget(
                        InkIcon.refresh,
                        size: 18,
                        color: tokens.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CustomScrollView(
                  slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
                sliver: SliverList.list(
                  children: [
                    // Mode Switch Card
                    FloatingCard(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children: [
                          Expanded(
                            child: _ModeTabButton(
                              label: l10n.ttsModeLocal,
                              selected: !isOnline,
                              onTap: () async {
                                if (_previewPlaying) {
                                  await _stopActivePreview();
                                }
                                await ttsCfgCtrl.setMode(TtsEngineMode.local);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _ModeTabButton(
                              label: l10n.ttsModeOnline,
                              selected: isOnline,
                              onTap: () async {
                                if (_previewPlaying) {
                                  await _stopActivePreview();
                                }
                                await ttsCfgCtrl.setMode(TtsEngineMode.online);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Shared Playback Card (Rate, Pitch, Auto-Turn, Timer)
                    FloatingCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              InkIconWidget(
                                InkIcon.tts,
                                size: 17,
                                color: tokens.accentPrimary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                l10n.ttsSpeechRate,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: tokens.inkPrimary,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${settings.ttsRate.toStringAsFixed(1)}x',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: tokens.accentPrimary,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          Slider(
                            min: 0.6,
                            max: 2.0,
                            divisions: 14,
                            value: settings.ttsRate.clamp(0.6, 2.0),
                            onChanged: (v) {
                              final rounded =
                                  double.parse(v.toStringAsFixed(1));
                              settingsCtrl
                                  .update((s) => s.copyWith(ttsRate: rounded));
                            },
                          ),
                          const Divider(height: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.ttsSpeechPitch,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: tokens.inkPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  (0.8, l10n.ttsPitchLow),
                                  (1.0, l10n.ttsPitchNormal),
                                  (1.25, l10n.ttsPitchHigh),
                                ].map((item) {
                                  final selected =
                                      (settings.ttsPitch - item.$1).abs() < 0.05;
                                  return InkPillChip(
                                    label: item.$2,
                                    selected: selected,
                                    onTap: () => settingsCtrl.update(
                                      (s) => s.copyWith(ttsPitch: item.$1),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                l10n.ttsAutoTurnPage,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: tokens.inkPrimary,
                                ),
                              ),
                              InkSwitch(
                                value: settings.ttsAutoTurnPage,
                                onChanged: (v) => settingsCtrl.update(
                                  (s) => s.copyWith(ttsAutoTurnPage: v),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 16),
                          Text(
                            l10n.ttsSleepTimer,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: tokens.inkPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ..._timerPresets.map((m) {
                                final selected = !ttsCfg.sleepAtChapterEnd &&
                                    settings.ttsSleepTimerMinutes == m;
                                return InkPillChip(
                                  label: m == 0
                                      ? l10n.ttsTimerOff
                                      : l10n.ttsTimerMinutes(m),
                                  selected: selected,
                                  onTap: () {
                                    ttsCfgCtrl.setSleepAtChapterEnd(false);
                                    settingsCtrl.update(
                                      (s) => s.copyWith(ttsSleepTimerMinutes: m),
                                    );
                                  },
                                );
                              }),
                              InkPillChip(
                                label: l10n.ttsTimerChapterEnd,
                                selected: ttsCfg.sleepAtChapterEnd,
                                onTap: () => ttsCfgCtrl.setSleepAtChapterEnd(
                                  !ttsCfg.sleepAtChapterEnd,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (!isOnline)
                      _buildLocalTtsCard(l10n, tokens, settings, settingsCtrl)
                    else
                      _buildOnlineTtsSection(
                        l10n,
                        tokens,
                        settings,
                        ttsCfg,
                        ttsCfgCtrl,
                      ),
                  ],
                ),
              ),
            ],
          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocalTtsCard(
    dynamic l10n,
    InkBoxTokens tokens,
    BookReaderSettings settings,
    BookReaderSettingsController settingsCtrl,
  ) {
    return Column(
      children: [
        FloatingCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.ttsEngineLabel,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: tokens.inkPrimary,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _loadEnginesAndVoices,
                    icon: InkIconWidget(
                      InkIcon.refresh,
                      size: 14,
                      color: tokens.accentPrimary,
                    ),
                    label: Text(
                      l10n.ttsRefreshEngines,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
              if (_loadingEngines)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    InkPillChip(
                      label: l10n.ttsSystemDefaultEngine,
                      selected: settings.ttsEngine.isEmpty,
                      onTap: () {
                        settingsCtrl.update(
                          (s) => s.copyWith(ttsEngine: '', ttsVoice: ''),
                        );
                        _refreshLocalVoices(
                          engine: '',
                          language: settings.ttsLanguage,
                        );
                      },
                    ),
                    ..._engines.map((e) {
                      return InkPillChip(
                        label: e.label,
                        selected: settings.ttsEngine == e.name,
                        onTap: () {
                          settingsCtrl.update(
                            (s) => s.copyWith(ttsEngine: e.name, ttsVoice: ''),
                          );
                          _refreshLocalVoices(
                            engine: e.name,
                            language: settings.ttsLanguage,
                          );
                        },
                      );
                    }),
                  ],
                ),
              const Divider(height: 18),
              Text(
                l10n.ttsLanguageLabel,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: tokens.inkPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _langCodes.map((code) {
                  return InkPillChip(
                    label: localizedTtsLanguage(l10n, code),
                    selected: settings.ttsLanguage == code,
                    onTap: () {
                      settingsCtrl.update(
                        (s) => s.copyWith(ttsLanguage: code),
                      );
                      _refreshLocalVoices(
                        engine: settings.ttsEngine,
                        language: code,
                      );
                    },
                  );
                }).toList(),
              ),
              const Divider(height: 18),
              Text(
                l10n.ttsVoiceLabel,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: tokens.inkPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  InkPillChip(
                    label: l10n.ttsVoiceDefault,
                    selected: settings.ttsVoice.isEmpty,
                    onTap: () =>
                        settingsCtrl.update((s) => s.copyWith(ttsVoice: '')),
                  ),
                  ..._localVoices.take(12).map((v) {
                    final tag = v.requiresNetwork
                        ? l10n.ttsVoiceNetwork
                        : l10n.ttsVoiceOffline;
                    final shortName =
                        v.name.split('-').take(4).join('-');
                    return InkPillChip(
                      label: '$shortName ($tag)',
                      selected: settings.ttsVoice == v.name,
                      onTap: () => settingsCtrl.update(
                        (s) => s.copyWith(ttsVoice: v.name),
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _toggleLocalPreview(settings),
                icon: InkIconWidget(
                  _previewPlaying ? InkIcon.close : InkIcon.tts,
                  size: 16,
                  color: Colors.white,
                ),
                label: Text(
                  _previewPlaying ? l10n.ttsStopPreviewBtn : l10n.ttsPreviewBtn,
                ),
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton(
              onPressed: () =>
                  ref.read(platformBridgeProvider).openSystemTtsSettings(),
              child: Text(l10n.ttsOpenSystemSettings),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOnlineTtsSection(
    dynamic l10n,
    InkBoxTokens tokens,
    BookReaderSettings settings,
    TtsConfigState ttsCfg,
    TtsConfigController ttsCfgCtrl,
  ) {
    final activeProfile = ttsCfg.activeProfile;
    final profiles = ttsCfg.effectiveProfiles;

    return Column(
      children: [
        FloatingCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    l10n.ttsModeOnline,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: tokens.inkPrimary,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _showLegadoImportModal,
                    child: Text(
                      l10n.ttsImportLegado,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  TextButton(
                    onPressed: _showNewProfileModal,
                    child: Text(
                      '+ ${l10n.ttsNewProfile}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: profiles.map((p) {
                  return InkPillChip(
                    label: p.name,
                    selected: p.id == activeProfile.id,
                    onTap: () {
                      ttsCfgCtrl.setActiveProfile(p.id);
                      _lastTestResult = null;
                      _syncProfileForm(
                        ttsCfg.copyWith(activeProfileId: p.id),
                        force: true,
                      );
                    },
                  );
                }).toList(),
              ),
              const Divider(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: OnlineTtsProviderKind.values.map((k) {
                  return InkPillChip(
                    label: k.labelOf(l10n),
                    selected: _selectedKind == k,
                    onTap: () => setState(() => _selectedKind = k),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              InkTextField(
                controller: _nameCtrl,
                label: l10n.ttsProfileNameLabel,
              ),
              const SizedBox(height: 10),

              if (_selectedKind == OnlineTtsProviderKind.edgeTts) ...[
                Text(
                  l10n.ttsEdgeModeLabel,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: tokens.inkMuted,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    InkPillChip(
                      label: l10n.ttsEdgeDirect,
                      selected: !_edgeUseGateway,
                      onTap: () => setState(() => _edgeUseGateway = false),
                    ),
                    InkPillChip(
                      label: l10n.ttsEdgeGateway,
                      selected: _edgeUseGateway,
                      onTap: () => setState(() => _edgeUseGateway = true),
                    ),
                  ],
                ),
                if (_edgeUseGateway) ...[
                  const SizedBox(height: 10),
                  InkTextField(
                    controller: _endpointCtrl,
                    label: l10n.ttsEndpointLabel,
                    monospace: true,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    l10n.ttsEdgeGatewayProtocolLabel,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: tokens.inkMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      InkPillChip(
                        label: l10n.ttsEdgeGatewayGet,
                        selected: !_edgeGatewayUseSsml,
                        onTap: () => setState(() => _edgeGatewayUseSsml = false),
                      ),
                      InkPillChip(
                        label: l10n.ttsEdgeGatewayRaSsml,
                        selected: _edgeGatewayUseSsml,
                        onTap: () => setState(() => _edgeGatewayUseSsml = true),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  InkTextField(
                    controller: _apiKeyCtrl,
                    label: l10n.ttsApiKeyLabel,
                    hintText: l10n.ttsApiKeyHint,
                    obscureText: true,
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  l10n.ttsVoiceIdLabel,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: tokens.inkMuted,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: kBuiltinEdgeVoices.map((v) {
                    return InkPillChip(
                      label: v.label,
                      selected: _voiceCtrl.text == v.id,
                      onTap: () => setState(() => _voiceCtrl.text = v.id),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                InkTextField(
                  controller: _voiceCtrl,
                  label: l10n.ttsVoiceIdLabel,
                  monospace: true,
                ),
              ] else if (_selectedKind ==
                  OnlineTtsProviderKind.azureSpeech) ...[
                InkTextField(
                  controller: _azureRegionCtrl,
                  label: l10n.ttsAzureRegionLabel,
                  monospace: true,
                ),
                const SizedBox(height: 10),
                InkTextField(
                  controller: _endpointCtrl,
                  label: l10n.ttsEndpointLabel,
                  monospace: true,
                ),
                const SizedBox(height: 10),
                InkTextField(
                  controller: _apiKeyCtrl,
                  label: l10n.ttsApiKeyLabel,
                  obscureText: true,
                ),
                const SizedBox(height: 10),
                Text(
                  l10n.ttsVoiceIdLabel,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: tokens.inkMuted,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: kBuiltinEdgeVoices.map((v) {
                    return InkPillChip(
                      label: v.label,
                      selected: _voiceCtrl.text == v.id,
                      onTap: () => setState(() => _voiceCtrl.text = v.id),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                InkTextField(
                  controller: _voiceCtrl,
                  label: l10n.ttsVoiceIdLabel,
                  monospace: true,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  children: kOnlineAudioFormats.map((fmt) {
                    return InkPillChip(
                      label: fmt.toUpperCase(),
                      selected: _selectedFormat == fmt,
                      onTap: () => setState(() => _selectedFormat = fmt),
                    );
                  }).toList(),
                ),
              ] else if (_selectedKind ==
                  OnlineTtsProviderKind.openAiCompatible) ...[
                InkTextField(
                  controller: _endpointCtrl,
                  label: l10n.ttsEndpointLabel,
                  monospace: true,
                ),
                const SizedBox(height: 10),
                InkTextField(
                  controller: _apiKeyCtrl,
                  label: l10n.ttsApiKeyLabel,
                  hintText: l10n.ttsApiKeyHint,
                  obscureText: true,
                ),
                const SizedBox(height: 10),
                InkTextField(
                  controller: _modelCtrl,
                  label: l10n.ttsModelLabel,
                  monospace: true,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: kOpenAiVoices.map((v) {
                    return InkPillChip(
                      label: v,
                      selected: _voiceCtrl.text == v,
                      onTap: () => setState(() => _voiceCtrl.text = v),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                InkTextField(
                  controller: _voiceCtrl,
                  label: l10n.ttsVoiceIdLabel,
                  monospace: true,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  children: kOnlineAudioFormats.map((fmt) {
                    return InkPillChip(
                      label: fmt.toUpperCase(),
                      selected: _selectedFormat == fmt,
                      onTap: () => setState(() => _selectedFormat = fmt),
                    );
                  }).toList(),
                ),
              ] else ...[
                InkTextField(
                  controller: _endpointCtrl,
                  label: l10n.ttsEndpointLabel,
                  monospace: true,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.ttsTemplateHint,
                  style: TextStyle(fontSize: 11, color: tokens.inkMuted),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: ['GET', 'POST'].map((m) {
                    return InkPillChip(
                      label: '${l10n.ttsHttpMethodLabel}: $m',
                      selected: _selectedMethod == m,
                      onTap: () => setState(() => _selectedMethod = m),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                InkTextField(
                  controller: _apiKeyCtrl,
                  label: l10n.ttsApiKeyLabel,
                  hintText: l10n.ttsApiKeyHint,
                  obscureText: true,
                ),
                const SizedBox(height: 10),
                InkTextField(
                  controller: _headersCtrl,
                  label: l10n.ttsHeadersJsonLabel,
                  monospace: true,
                  maxLines: 2,
                ),
                if (_selectedMethod == 'POST') ...[
                  const SizedBox(height: 10),
                  InkTextField(
                    controller: _bodyCtrl,
                    label: l10n.ttsBodyTemplateLabel,
                    monospace: true,
                    maxLines: 3,
                  ),
                ],
                const SizedBox(height: 10),
                InkTextField(
                  controller: _voiceCtrl,
                  label: l10n.ttsVoiceIdLabel,
                  monospace: true,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  children: kOnlineAudioFormats.map((fmt) {
                    return InkPillChip(
                      label: fmt.toUpperCase(),
                      selected: _selectedFormat == fmt,
                      onTap: () => setState(() => _selectedFormat = fmt),
                    );
                  }).toList(),
                ),
              ],

              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        await _saveCurrentProfile();
                        if (mounted) {
                          _toast(l10n.save);
                        }
                      },
                      child: Text(l10n.save),
                    ),
                  ),
                  if (profiles.length > 1) ...[
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () async {
                        await ttsCfgCtrl.deleteProfile(activeProfile.id);
                        if (mounted) {
                          _syncProfileForm(
                            ref.read(ttsConfigProvider),
                            force: true,
                          );
                          setState(() {});
                        }
                      },
                      child: Text(
                        l10n.ttsDeleteProfile,
                        style: TextStyle(color: tokens.accentWarm),
                      ),
                    ),
                  ],
                ],
              ),
              if (_lastTestResult != null) ...[
                const SizedBox(height: 10),
                Text(
                  _lastTestResult!.ok
                      ? l10n.ttsTestConnected(_lastTestResult!.latencyMs)
                      : l10n.ttsTestFailed(
                          localizeError(
                            l10n,
                            _lastTestResult!.errorCode ?? 'ERR_UNKNOWN',
                          ),
                        ),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _lastTestResult!.ok
                        ? tokens.accentPrimary
                        : tokens.accentWarm,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _testingConnection
              ? null
              : () => _testAndPreviewOnline(settings),
          icon: InkIconWidget(
            _previewPlaying ? InkIcon.close : InkIcon.tts,
            size: 16,
            color: Colors.white,
          ),
          label: Text(
            _testingConnection
                ? l10n.ttsTestingConnection
                : _previewPlaying
                    ? l10n.ttsStopPreviewBtn
                    : l10n.ttsTestAndPreview,
          ),
        ),
        const SizedBox(height: 12),
        FloatingCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.ttsCacheSettingsTitle,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: tokens.inkPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      l10n.ttsFallbackLocalLabel,
                      style: TextStyle(fontSize: 13, color: tokens.inkPrimary),
                    ),
                  ),
                  InkSwitch(
                    value: ttsCfg.fallbackToLocalTts,
                    onChanged: (v) => ttsCfgCtrl.setFallbackToLocalTts(v),
                  ),
                ],
              ),
              const Divider(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      l10n.ttsCacheEnableLabel,
                      style: TextStyle(fontSize: 13, color: tokens.inkPrimary),
                    ),
                  ),
                  InkSwitch(
                    value: ttsCfg.cacheEnabled,
                    onChanged: (v) => ttsCfgCtrl.setCacheEnabled(v),
                  ),
                ],
              ),
              if (ttsCfg.cacheEnabled) ...[
                const SizedBox(height: 10),
                Text(
                  l10n.ttsCacheMaxMbLabel,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: tokens.inkMuted,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [50, 100, 250, 500].map((mb) {
                    return InkPillChip(
                      label: '$mb MB',
                      selected: ttsCfg.cacheMaxMb == mb,
                      onTap: () async {
                        await ttsCfgCtrl.setCacheMaxMb(mb);
                        await _cache.enforceMaxBytes(mb * 1024 * 1024);
                        await _refreshCacheSize();
                      },
                    );
                  }).toList(),
                ),
              ],
              const Divider(height: 18),
              Text(
                l10n.ttsPrefetchCountLabel,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: tokens.inkMuted,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [0, 1, 2, 3].map((cnt) {
                  return InkPillChip(
                    label: cnt == 0
                        ? l10n.ttsPrefetchOff
                        : l10n.ttsPrefetchUnit(cnt),
                    selected: ttsCfg.prefetchCount == cnt,
                    onTap: () => ttsCfgCtrl.setPrefetchCount(cnt),
                  );
                }).toList(),
              ),
              const Divider(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      ttsCfg.cacheEnabled
                          ? '${l10n.ttsClearCacheLabel(_formatBytes(_cacheBytes))} / ${ttsCfg.cacheMaxMb} MB'
                          : l10n.ttsClearCacheLabel(_formatBytes(_cacheBytes)),
                      style: TextStyle(fontSize: 13, color: tokens.inkPrimary),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      await _cache.clear();
                      await _refreshCacheSize();
                      _toast(l10n.ttsCacheClearedToast);
                    },
                    child: Text(l10n.clear),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ModeTabButton extends StatelessWidget {
  const _ModeTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = InkBoxTokens.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? tokens.accentPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : tokens.inkMuted,
          ),
        ),
      ),
    );
  }
}
