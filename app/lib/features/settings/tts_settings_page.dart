import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/icons/ink_icons.dart';
import '../../core/theme/inkbox_theme.dart';
import '../../core/widgets/floating_surface.dart';
import '../../core/widgets/ink_controls.dart';
import '../../data/platform/platform_bridge.dart';
import '../../data/providers/app_providers.dart';
import '../book_reader/book_reader_settings.dart';

const Map<String, String> kTtsLanguageLabels = {
  'zh-CN': '中文（普通话）',
  'zh-TW': '中文（台湾国语）',
  'zh-HK': '中文（粤语）',
  'en-US': 'English (US)',
  'ja-JP': '日本語',
  'system': '跟随系统语言',
};

const List<int> kTtsSleepTimerOptions = [0, 15, 30, 45, 60];

class TtsSettingsPage extends ConsumerStatefulWidget {
  const TtsSettingsPage({super.key});

  @override
  ConsumerState<TtsSettingsPage> createState() => _TtsSettingsPageState();
}

class _TtsSettingsPageState extends ConsumerState<TtsSettingsPage> {
  List<TtsEngineOption> _engines = const [];
  bool _previewing = false;
  StreamSubscription<PlatformEvent>? _eventSub;
  late final PlatformBridge _platform;

  @override
  void initState() {
    super.initState();
    _platform = ref.read(platformBridgeProvider);
    _loadEngines();
    _eventSub = _platform.events.listen((ev) {
      if (!mounted) return;
      if (ev.type == 'tts_done' || ev.type == 'tts_error') {
        setState(() => _previewing = false);
      }
    });
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    if (_previewing) {
      _platform.stopTts();
    }
    super.dispose();
  }

  Future<void> _loadEngines() async {
    final list = await _platform.getTtsEngines();
    if (mounted) setState(() => _engines = list);
  }

  Future<void> _togglePreview(BookReaderSettings settings) async {
    if (_previewing) {
      await _platform.stopTts();
      if (mounted) setState(() => _previewing = false);
      return;
    }
    setState(() => _previewing = true);
    final uid = await _platform.speakText(
      '墨匣本地阅读器，正在为您试听当前语音朗读语速与音调配置。',
      rate: settings.ttsRate,
      pitch: settings.ttsPitch,
      language: settings.ttsLanguage,
      engine: settings.ttsEngine.isEmpty ? null : settings.ttsEngine,
    );
    if (!mounted) return;
    if (uid == null) {
      setState(() => _previewing = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('当前环境暂无可用系统 TTS 引擎，请在系统 TTS 设置中检查语音包'),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = InkBoxTokens.of(context);
    final settings = ref.watch(bookReaderSettingsProvider);
    final ctrl = ref.read(bookReaderSettingsProvider.notifier);

    final activeEngineLabel = settings.ttsEngine.isEmpty
        ? '系统默认引擎'
        : (_engines
                .where((e) => e.name == settings.ttsEngine)
                .firstOrNull
                ?.label ??
            settings.ttsEngine);
    final activeLangLabel =
        kTtsLanguageLabels[settings.ttsLanguage] ?? settings.ttsLanguage;

    return Scaffold(
      backgroundColor: tokens.canvasBg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 28),
          children: [
            FloatingCard(
              radius: 22,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                      'TTS 语音朗读设置',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: tokens.inkPrimary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      await ctrl.update(
                        (s) => s.copyWith(
                          ttsRate: 1.0,
                          ttsPitch: 1.0,
                          ttsLanguage: 'zh-CN',
                          ttsEngine: '',
                          ttsAutoTurnPage: true,
                          ttsSleepTimerMinutes: 0,
                        ),
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已恢复默认 TTS 配置')),
                        );
                      }
                    },
                    child: Text(
                      '重置',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: tokens.accentPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // --- Speech Rate & Pitch Card ---
            FloatingCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '朗读语速',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: tokens.inkPrimary,
                        ),
                      ),
                      Text(
                        '${settings.ttsRate.toStringAsFixed(1)}x',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: tokens.accentPrimary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    min: 0.5,
                    max: 2.5,
                    divisions: 20,
                    value: settings.ttsRate.clamp(0.5, 2.5),
                    onChanged: (v) => ctrl.update(
                      (s) => s.copyWith(
                        ttsRate: double.parse(v.toStringAsFixed(1)),
                      ),
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: const [0.8, 1.0, 1.2, 1.5, 2.0].map((rate) {
                      final active = (settings.ttsRate - rate).abs() < 0.05;
                      return InkPillChip(
                        label: '${rate.toStringAsFixed(1)}x',
                        selected: active,
                        onTap: () =>
                            ctrl.update((s) => s.copyWith(ttsRate: rate)),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '声音音调',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: tokens.inkPrimary,
                        ),
                      ),
                      Text(
                        settings.ttsPitch.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: tokens.accentPrimary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    min: 0.5,
                    max: 2.0,
                    divisions: 15,
                    value: settings.ttsPitch.clamp(0.5, 2.0),
                    onChanged: (v) => ctrl.update(
                      (s) => s.copyWith(
                        ttsPitch: double.parse(v.toStringAsFixed(1)),
                      ),
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: const [
                      (0.8, '低沉 0.8'),
                      (1.0, '标准 1.0'),
                      (1.2, '清亮 1.2'),
                    ].map((item) {
                      final active = (settings.ttsPitch - item.$1).abs() < 0.05;
                      return InkPillChip(
                        label: item.$2,
                        selected: active,
                        onTap: () =>
                            ctrl.update((s) => s.copyWith(ttsPitch: item.$1)),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: _previewing
                            ? tokens.accentWarm
                            : tokens.accentPrimary,
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => _togglePreview(settings),
                      icon: InkIconWidget(
                        _previewing ? InkIcon.close : InkIcon.tts,
                        size: 16,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                      label: Text(_previewing ? '停止试听' : '试听当前语音效果'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // --- Language & Engine Card ---
            FloatingCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '语音引擎与语言',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: tokens.inkPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SettingSelectRow(
                    title: '朗读语言 / 口音',
                    valueLabel: activeLangLabel,
                    onTap: () async {
                      final picked = await showInkOptionSheet<String>(
                        context: context,
                        title: '选择朗读语言',
                        selectedValue: settings.ttsLanguage,
                        options: kTtsLanguageLabels.entries
                            .map(
                              (e) => InkOptionItem(
                                value: e.key,
                                label: e.value,
                              ),
                            )
                            .toList(),
                      );
                      if (picked != null) {
                        await ctrl.update(
                          (s) => s.copyWith(ttsLanguage: picked),
                        );
                      }
                    },
                  ),
                  Divider(height: 20, color: tokens.subtleBorder),
                  _SettingSelectRow(
                    title: 'TTS 语音引擎',
                    valueLabel: activeEngineLabel,
                    subtitle: '支持切换系统内置或第三方引擎（如 MultiTTS / 微软语音）',
                    onTap: () async {
                      await _loadEngines();
                      if (!context.mounted) return;
                      final picked = await showInkOptionSheet<String>(
                        context: context,
                        title: '选择 TTS 语音引擎',
                        subtitle: '列表展示本机已安装的 Android TTS 服务',
                        selectedValue: settings.ttsEngine,
                        options: [
                          const InkOptionItem(
                            value: '',
                            label: '系统默认引擎',
                            subtitle: '跟随系统首选文字转语音引擎',
                          ),
                          ..._engines.map(
                            (e) => InkOptionItem(
                              value: e.name,
                              label: e.label,
                              subtitle: e.name,
                            ),
                          ),
                        ],
                      );
                      if (picked != null) {
                        await ctrl.update(
                          (s) => s.copyWith(ttsEngine: picked),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        shape: const StadiumBorder(),
                        side: BorderSide(color: tokens.subtleBorder),
                      ),
                      onPressed: () => _platform.openSystemTtsSettings(),
                      icon: InkIconWidget(
                        InkIcon.gear,
                        size: 15,
                        color: tokens.inkPrimary,
                      ),
                      label: Text(
                        '打开系统 TTS 设置（下载离线语音包 / 配置引擎）',
                        style: TextStyle(
                          fontSize: 12,
                          color: tokens.inkPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // --- Auto-Advance & Sleep Timer Card ---
            FloatingCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '听书行为与定时',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: tokens.inkPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '读完本页自动翻页续读',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: tokens.inkPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '当前页朗读完毕后自动翻到下一页继续朗读',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: tokens.inkMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      InkSwitch(
                        value: settings.ttsAutoTurnPage,
                        onChanged: (v) =>
                            ctrl.update((s) => s.copyWith(ttsAutoTurnPage: v)),
                      ),
                    ],
                  ),
                  Divider(height: 22, color: tokens.subtleBorder),
                  Text(
                    '定时关闭',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: tokens.inkPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '开启听书后按设定时长自动停止朗读',
                    style: TextStyle(fontSize: 11.5, color: tokens.inkMuted),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: kTtsSleepTimerOptions.map((mins) {
                      final active = settings.ttsSleepTimerMinutes == mins;
                      return InkPillChip(
                        label: mins == 0 ? '不限时长' : '$mins 分钟',
                        selected: active,
                        onTap: () => ctrl.update(
                          (s) => s.copyWith(ttsSleepTimerMinutes: mins),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingSelectRow extends StatelessWidget {
  const _SettingSelectRow({
    required this.title,
    required this.valueLabel,
    required this.onTap,
    this.subtitle,
  });

  final String title;
  final String valueLabel;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = InkBoxTokens.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: tokens.inkPrimary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(fontSize: 11, color: tokens.inkMuted),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              valueLabel,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: tokens.accentPrimary,
              ),
            ),
            const SizedBox(width: 4),
            InkIconWidget(
              InkIcon.chevronRight,
              size: 15,
              color: tokens.inkMuted,
            ),
          ],
        ),
      ),
    );
  }
}
