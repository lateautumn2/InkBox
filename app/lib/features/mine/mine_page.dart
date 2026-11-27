import 'dart:io';

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
import '../../data/db/app_database.dart';
import '../../data/providers/app_providers.dart';
import '../book_reader/book_reader_settings.dart';
import '../settings/appearance_sheet.dart';
import '../tts/tts_models.dart';
import '../webdav_sync/webdav_sync_service.dart';

/// App settings and reading statistics.
class MinePage extends ConsumerStatefulWidget {
  const MinePage({super.key});

  @override
  ConsumerState<MinePage> createState() => _MinePageState();
}

class _MinePageState extends ConsumerState<MinePage> {
  WebDavConfig _webdavCfg = const WebDavConfig();

  @override
  void initState() {
    super.initState();
    _loadWebDavSummary();
  }

  Future<void> _loadWebDavSummary() async {
    try {
      final svc = WebDavSyncService(
        db: ref.read(appDatabaseProvider),
        rustCore: ref.read(rustCoreProvider),
      );
      final cfg = await svc.loadConfig();
      if (mounted) setState(() => _webdavCfg = cfg);
    } catch (_) {}
  }

  String _languageDisplay(String code, BuildContext context) {
    final l10n = context.l10n;
    return switch (code) {
      'zh' => l10n.languageZh,
      'en' => l10n.languageEn,
      'ja' => l10n.languageJa,
      _ => l10n.languageSystem,
    };
  }

  String _themeSummary(AppearanceState appearance, BuildContext context) {
    final l10n = context.l10n;
    final style = appearance.uiStyle == InkBoxUiStyle.floatingCard
        ? l10n.uiStyleFloating
        : l10n.uiStyleClassic;
    final color = switch (appearance.themePreference) {
      InkBoxThemePreference.crispLight => l10n.themeCrispLight,
      InkBoxThemePreference.darkTheater => l10n.themeDarkTheater,
      InkBoxThemePreference.oledBlack => l10n.themeOledBlack,
      InkBoxThemePreference.inkWash => l10n.themeInkWash,
      InkBoxThemePreference.system => l10n.themeFollowSystem,
    };
    return '$color · $style';
  }

  Future<void> _pickLanguage() async {
    final l10n = context.l10n;
    final appearance = ref.read(appearanceProvider);
    final picked = await showInkOptionSheet<String>(
      context: context,
      title: l10n.appLanguageTitle,
      selectedValue: appearance.appLocaleCode,
      options: [
        InkOptionItem(value: 'system', label: l10n.languageSystem),
        InkOptionItem(value: 'zh', label: l10n.languageZh),
        InkOptionItem(value: 'en', label: l10n.languageEn),
        InkOptionItem(value: 'ja', label: l10n.languageJa),
      ],
    );
    if (picked != null && mounted) {
      await ref.read(appearanceProvider.notifier).setAppLocaleCode(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = InkBoxTokens.of(context);
    final l10n = context.l10n;
    final books = ref.watch(booksStreamProvider).valueOrNull ?? const <Book>[];
    final historyBooks =
        ref.watch(bookHistoryStreamProvider).valueOrNull ?? const <Book>[];
    final tocRules =
        ref.watch(tocRulesStreamProvider).valueOrNull ?? const <TocRule>[];
    final readerSettings = ref.watch(bookReaderSettingsProvider);
    final ttsConfig = ref.watch(ttsConfigProvider);
    final appearance = ref.watch(appearanceProvider);

    final enabledRulesCount = tocRules.where((r) => r.enabled).length;
    final finishedCount = books.where(isBookFinished).length;
    final readingCount = books.length - finishedCount;
    final totalMinutes =
        historyBooks.fold<int>(0, (sum, b) => sum + b.readingTimeSec) ~/ 60;
    final rateStr = readerSettings.ttsRate.toStringAsFixed(1);
    final profile = ttsConfig.activeProfile;
    final profileName = profile.hasDefaultName
        ? profile.kind.labelOf(l10n)
        : profile.name;
    final ttsSubtitle = ttsConfig.mode == TtsEngineMode.online
        ? l10n.ttsMenuSummaryOnline(profileName, rateStr)
        : l10n.ttsMenuSummaryLocal(rateStr);

    final bottomPad = MediaQuery.paddingOf(context).bottom + 28;

    return SafeArea(
      bottom: false,
      child: ResponsiveConstrainedBody(
        child: Column(
          children: [
            FloatingHeaderBar(
              title: l10n.mineTitle,
              actions: [
                InkCircleButton(
                  icon: InkIconWidget(
                    Theme.of(context).brightness == Brightness.dark
                        ? InkIcon.moon
                        : InkIcon.sun,
                    size: 17,
                    color: tokens.inkPrimary,
                  ),
                  tooltip: l10n.themePresets,
                  onPressed: () => showAppearanceSheet(context),
                ),
              ],
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(14, 6, 14, bottomPad),
                children: [
                  FloatingCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 16,
                    ),
                    child: Row(
                      children: [
                        _StatTile(
                          label: l10n.statBooks,
                          value: '${books.length}',
                        ),
                        _StatTile(
                          label: l10n.statReading,
                          value: '$readingCount',
                        ),
                        _StatTile(
                          label: l10n.statFinished,
                          value: '$finishedCount',
                        ),
                        _StatTile(
                          label: l10n.statMinutes,
                          value: '$totalMinutes',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _SectionLabel(l10n.sectionAppearanceLanguage),
                  FloatingCard(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      children: [
                        _MineMenuTile(
                          icon: InkIcon.floatingCard,
                          title: l10n.appearanceSettings,
                          subtitle: _themeSummary(appearance, context),
                          onTap: () => showAppearanceSheet(context),
                        ),
                        Divider(
                          height: 1,
                          indent: 54,
                          color: tokens.subtleBorder,
                        ),
                        _MineMenuTile(
                          icon: InkIcon.language,
                          title: l10n.appLanguageTitle,
                          subtitle:
                              _languageDisplay(appearance.appLocaleCode, context),
                          onTap: _pickLanguage,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _SectionLabel(l10n.sectionReadingSync),
                  FloatingCard(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      children: [
                        _MineMenuTile(
                          icon: InkIcon.tts,
                          title: l10n.ttsMenuTitle,
                          subtitle: ttsSubtitle,
                          onTap: () => context.push('/mine/tts-settings'),
                        ),
                        Divider(
                          height: 1,
                          indent: 54,
                          color: tokens.subtleBorder,
                        ),
                        _MineMenuTile(
                          icon: InkIcon.toc,
                          title: l10n.tocRulesMenuTitle,
                          subtitle: l10n.tocRulesMenuSummary(
                            enabledRulesCount,
                            tocRules.length,
                          ),
                          onTap: () => context.push('/mine/toc-rules'),
                        ),
                        Divider(
                          height: 1,
                          indent: 54,
                          color: tokens.subtleBorder,
                        ),
                        _MineMenuTile(
                          icon: InkIcon.syncCloud,
                          title: l10n.webdavMenuTitle,
                          subtitle: _webdavCfg.isConfigured
                              ? '${_webdavCfg.presetName} · ${_webdavCfg.remoteRoot}'
                              : l10n.webdavUnconfigured,
                          onTap: () async {
                            await context.push('/mine/sync');
                            await _loadWebDavSummary();
                          },
                        ),
                        if (Platform.isAndroid) ...[
                          Divider(
                            height: 1,
                            indent: 54,
                            color: tokens.subtleBorder,
                          ),
                          _MineMenuTile(
                            icon: InkIcon.file,
                            title: l10n.localBackupTitle,
                            subtitle: l10n.localBackupSummary,
                            onTap: () => context.push('/mine/local-backup'),
                          ),
                        ],
                      ],
                    ),
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = InkBoxTokens.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: tokens.inkMuted,
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = InkBoxTokens.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: tokens.inkPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: tokens.inkMuted),
          ),
        ],
      ),
    );
  }
}

class _MineMenuTile extends StatelessWidget {
  const _MineMenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final InkIcon icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = InkBoxTokens.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: tokens.surfaceVariant,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: InkIconWidget(icon, size: 17, color: tokens.inkPrimary),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: tokens.inkPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: tokens.inkMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            InkIconWidget(
              InkIcon.chevronRight,
              size: 16,
              color: tokens.inkMuted,
            ),
          ],
        ),
      ),
    );
  }
}
