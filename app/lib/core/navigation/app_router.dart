import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/book_reader/book_reader_page.dart';
import '../../features/bookshelf/book_detail_page.dart';
import '../../features/bookshelf/bookshelf_page.dart';
import '../../features/importer/import_hub_page.dart';
import '../../features/manga_reader/manga_reader_page.dart';
import '../../features/mangashelf/manga_detail_page.dart';
import '../../features/mangashelf/manga_shelf_page.dart';
import '../../features/mine/mine_page.dart';
import '../../features/settings/local_backup_page.dart';
import '../../features/settings/tts_settings_page.dart';
import '../../features/toc_rules/toc_rules_page.dart';
import '../../features/webdav_sync/webdav_sync_page.dart';
import '../icons/ink_icons.dart';
import '../l10n/l10n_helpers.dart';
import '../layout/responsive_layout.dart';
import '../theme/inkbox_theme.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/bookshelf',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return AppShellScaffold(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/bookshelf',
              builder: (context, state) => const BookshelfPage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/manga',
              builder: (context, state) => const MangaShelfPage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/import',
              builder: (context, state) => const ImportHubPage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/mine',
              builder: (context, state) => const MinePage(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/mine/local-backup',
      builder: (context, state) => const LocalBackupPage(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/mine/sync',
      builder: (context, state) => const WebDavSyncPage(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/mine/toc-rules',
      builder: (context, state) => const TocRulesPage(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/mine/tts-settings',
      builder: (context, state) => const TtsSettingsPage(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/book/:id',
      builder: (context, state) {
        final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
        final fromReader = state.uri.queryParameters['fromReader'] == '1';
        return BookDetailPage(bookId: id, fromReader: fromReader);
      },
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/manga/:id',
      builder: (context, state) {
        final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
        return MangaDetailPage(mangaId: id);
      },
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/reader/book/:id',
      builder: (context, state) {
        final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
        final chapter =
            int.tryParse(state.uri.queryParameters['chapter'] ?? '');
        final offset = int.tryParse(state.uri.queryParameters['offset'] ?? '');
        return BookReaderPage(
          bookId: id,
          initialChapterIndex: chapter,
          initialCharOffset: offset,
        );
      },
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/reader/manga/:id',
      builder: (context, state) {
        final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
        final chId = int.tryParse(state.uri.queryParameters['chapterId'] ?? '');
        return MangaReaderPage(mangaId: id, initialChapterId: chId);
      },
    ),
  ],
);

class _NavItemSpec {
  const _NavItemSpec(this.label, this.icon);
  final String label;
  final InkIcon icon;
}

/// Root 4-tab scaffold that adapts between a bottom navigation dock on phones
/// (`width < 600dp`) and a left NavigationRail on tablets/landscape.
class AppShellScaffold extends StatelessWidget {
  const AppShellScaffold({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  void _onSelectTab(int index) {
    FocusManager.instance.primaryFocus?.unfocus();
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  List<_NavItemSpec> _buildNavItems(BuildContext context) {
    final l10n = context.l10n;
    return [
      _NavItemSpec(l10n.navBooks, InkIcon.bookshelf),
      _NavItemSpec(l10n.navManga, InkIcon.manga),
      _NavItemSpec(l10n.navImport, InkIcon.importTray),
      _NavItemSpec(l10n.navMe, InkIcon.gear),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final tokens = InkBoxTokens.of(context);
    final items = _buildNavItems(context);

    if (isWideLayout(context)) {
      return Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: tokens.canvasBg,
        body: Row(
          children: [
            _AdaptiveSideRail(
              items: items,
              currentIndex: navigationShell.currentIndex,
              onSelect: _onSelectTab,
            ),
            Expanded(child: navigationShell),
          ],
        ),
      );
    }

    if (tokens.isFloatingCard) {
      return Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: tokens.canvasBg,
        extendBody: true,
        body: navigationShell,
        bottomNavigationBar: SafeArea(
          maintainBottomViewPadding: true,
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _FloatingBottomPillDock(
              items: items,
              currentIndex: navigationShell.currentIndex,
              onSelect: _onSelectTab,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: tokens.canvasBg,
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: tokens.cardSurface,
          border: Border(top: BorderSide(color: tokens.subtleBorder)),
        ),
        child: SafeArea(
          maintainBottomViewPadding: true,
          top: false,
          child: SizedBox(
            height: 60,
            child: Row(
              children: List.generate(items.length, (i) {
                final item = items[i];
                final active = navigationShell.currentIndex == i;
                return Expanded(
                  child: InkWell(
                    onTap: () => _onSelectTab(i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: active
                                ? tokens.accentSoft
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: InkIconWidget(
                            item.icon,
                            size: 19,
                            color: active
                                ? tokens.accentPrimary
                                : tokens.inkMuted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight:
                                active ? FontWeight.w600 : FontWeight.w500,
                            color: active
                                ? tokens.accentPrimary
                                : tokens.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdaptiveSideRail extends StatelessWidget {
  const _AdaptiveSideRail({
    required this.items,
    required this.currentIndex,
    required this.onSelect,
  });

  final List<_NavItemSpec> items;
  final int currentIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final tokens = InkBoxTokens.of(context);
    final railContent = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(items.length, (i) {
        final item = items[i];
        final active = i == currentIndex;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => onSelect(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 58,
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                color: active ? tokens.accentSoft : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkIconWidget(
                    item.icon,
                    size: 20,
                    color: active ? tokens.accentPrimary : tokens.inkMuted,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                      color: active ? tokens.accentPrimary : tokens.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );

    if (tokens.isFloatingCard) {
      return SafeArea(
        right: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
          child: Container(
            width: 72,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(tokens.dockRadius),
              boxShadow: tokens.dockShadows,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(tokens.dockRadius),
              child: Container(
                decoration: BoxDecoration(
                  color: tokens.cardSurface,
                  borderRadius: BorderRadius.circular(tokens.dockRadius),
                  border: Border.all(color: tokens.subtleBorder, width: 1),
                ),
                child: railContent,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      width: 76,
      decoration: BoxDecoration(
        color: tokens.cardSurface,
        border: Border(right: BorderSide(color: tokens.subtleBorder)),
      ),
      child: SafeArea(right: false, child: railContent),
    );
  }
}

class _FloatingBottomPillDock extends StatelessWidget {
  const _FloatingBottomPillDock({
    required this.items,
    required this.currentIndex,
    required this.onSelect,
  });

  final List<_NavItemSpec> items;
  final int currentIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final tokens = InkBoxTokens.of(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        boxShadow: tokens.dockShadows,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          decoration: BoxDecoration(
            color: tokens.cardSurface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: tokens.subtleBorder, width: 1),
          ),
          child: Row(
            children: List.generate(items.length, (i) {
              final item = items[i];
              final active = currentIndex == i;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onSelect(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: active ? tokens.accentSoft : Colors.transparent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        InkIconWidget(
                          item.icon,
                          size: 19,
                          color: active
                              ? tokens.accentPrimary
                              : tokens.inkMuted,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight:
                                active ? FontWeight.w600 : FontWeight.w500,
                            color: active
                                ? tokens.accentPrimary
                                : tokens.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
