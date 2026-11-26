import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/icons/ink_icons.dart';
import '../../core/theme/inkbox_theme.dart';
import '../../core/widgets/floating_surface.dart';
import '../../data/db/app_database.dart';
import '../../data/providers/app_providers.dart';
import '../book_reader/book_reader_settings.dart';
import '../bookshelf/shelf_sheets.dart';
import '../settings/appearance_sheet.dart';
import '../settings/tts_settings_page.dart';
import '../webdav_sync/webdav_sync_service.dart';

/// "我的" (Mine) Hub tab — extensible personal & settings hub hosting
/// Multi-Bookshelf/MangaShelf management, TTS Voice Settings, TXT TOC Rules,
/// WebDAV Sync, and Theme Presets.
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

  @override
  Widget build(BuildContext context) {
    final tokens = InkBoxTokens.of(context);
    final books = ref.watch(booksStreamProvider).valueOrNull ?? const <Book>[];
    final historyBooks =
        ref.watch(bookHistoryStreamProvider).valueOrNull ?? const <Book>[];
    final tocRules =
        ref.watch(tocRulesStreamProvider).valueOrNull ?? const <TocRule>[];
    final bookShelves =
        ref.watch(bookShelvesStreamProvider).valueOrNull ?? const <Shelf>[];
    final mangaShelves =
        ref.watch(mangaShelvesStreamProvider).valueOrNull ?? const <Shelf>[];
    final readerSettings = ref.watch(bookReaderSettingsProvider);

    final enabledRulesCount = tocRules.where((r) => r.enabled).length;
    final finishedCount = books
        .where((b) => b.progressRatio >= 0.99 || b.shelfGroup == '已读完')
        .length;
    final readingCount = books.length - finishedCount;
    final totalMinutes =
        historyBooks.fold<int>(0, (sum, b) => sum + b.readingTimeSec) ~/ 60;
    final ttsLangLabel =
        kTtsLanguageLabels[readerSettings.ttsLanguage] ?? '普通话';
    final bottomPad = tokens.isFloatingCard ? 116.0 : 28.0;

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          FloatingHeaderBar(
            title: '我的',
            actions: [
              InkCircleButton(
                icon: InkIconWidget(
                  InkIcon.floatingCard,
                  size: 18,
                  color: tokens.inkPrimary,
                ),
                tooltip: '主题预设',
                onPressed: () => showAppearanceSheet(context),
              ),
            ],
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(14, 6, 14, bottomPad),
              children: [
                FloatingCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: tokens.accentSoft,
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Center(
                              child: InkIconWidget(
                                InkIcon.bookshelf,
                                size: 22,
                                color: tokens.accentPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '墨匣 InkBox',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: tokens.inkPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '本地纯粹阅读空间',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: tokens.inkMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _StatTile(label: '书架藏书', value: '${books.length}'),
                          _StatTile(label: '在读', value: '$readingCount'),
                          _StatTile(label: '已读完', value: '$finishedCount'),
                          _StatTile(label: '累计分钟', value: '$totalMinutes'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                  child: Text(
                    '设置与功能中心',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: tokens.inkMuted,
                    ),
                  ),
                ),
                FloatingCard(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    children: [
                      _MineMenuTile(
                        icon: InkIcon.bookshelf,
                        title: '多书架与漫画架管理',
                        subtitle:
                            '书架 ${bookShelves.isEmpty ? 1 : bookShelves.length} 个 · 漫画架 ${mangaShelves.isEmpty ? 1 : mangaShelves.length} 个（支持新建与切换）',
                        onTap: () => showDualShelfManagerSheet(context),
                      ),
                      Divider(
                        height: 1,
                        indent: 54,
                        color: tokens.subtleBorder,
                      ),
                      _MineMenuTile(
                        icon: InkIcon.tts,
                        title: 'TTS 语音朗读设置',
                        subtitle:
                            '语速 ${readerSettings.ttsRate.toStringAsFixed(1)}x · 音调 ${readerSettings.ttsPitch.toStringAsFixed(1)} · $ttsLangLabel',
                        onTap: () => context.push('/mine/tts-settings'),
                      ),
                      Divider(
                        height: 1,
                        indent: 54,
                        color: tokens.subtleBorder,
                      ),
                      _MineMenuTile(
                        icon: InkIcon.toc,
                        title: 'TXT 目录识别规则',
                        subtitle:
                            '已启用 $enabledRulesCount / ${tocRules.length} 条规则 · 支持导入 Legado JSON',
                        onTap: () => context.push('/mine/toc-rules'),
                      ),
                      Divider(
                        height: 1,
                        indent: 54,
                        color: tokens.subtleBorder,
                      ),
                      _MineMenuTile(
                        icon: InkIcon.syncCloud,
                        title: 'WebDAV 多端同步',
                        subtitle: _webdavCfg.isConfigured
                            ? '${_webdavCfg.presetName} · ${_webdavCfg.remoteRoot}'
                            : '未配置服务器 · 点击设置坚果云 / Alist / NAS 同步',
                        onTap: () async {
                          await context.push('/mine/sync');
                          await _loadWebDavSummary();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
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
              fontSize: 17,
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: tokens.surfaceVariant,
                borderRadius: BorderRadius.circular(11),
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
