import 'dart:ui';

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
import '../../features/settings/tts_settings_page.dart';
import '../../features/toc_rules/toc_rules_page.dart';
import '../../features/webdav_sync/webdav_sync_page.dart';
import '../icons/ink_icons.dart';
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

const _navItems = [
  _NavItemSpec('书架', InkIcon.bookshelf),
  _NavItemSpec('漫画', InkIcon.manga),
  _NavItemSpec('导入', InkIcon.importTray),
  _NavItemSpec('我的', InkIcon.user),
];

/// Root 4-tab scaffold supporting both FloatingCard Frosted Pill Dock
/// and Classic flush MD3 bottom navigation bar.
class AppShellScaffold extends StatelessWidget {
  const AppShellScaffold({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  void _onSelectTab(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = InkBoxTokens.of(context);

    if (tokens.isFloatingCard) {
      return Scaffold(
        backgroundColor: tokens.canvasBg,
        extendBody: true,
        body: navigationShell,
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: _FloatingBottomPillDock(
              currentIndex: navigationShell.currentIndex,
              onSelect: _onSelectTab,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: tokens.canvasBg,
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: tokens.cardSurface,
          border: Border(top: BorderSide(color: tokens.subtleBorder)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 66,
            child: Row(
              children: List.generate(_navItems.length, (i) {
                final item = _navItems[i];
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
                            horizontal: 16,
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
                            size: 20,
                            color: active
                                ? tokens.accentPrimary
                                : tokens.inkMuted,
                          ),
                        ),
                        const SizedBox(height: 3),
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

class _FloatingBottomPillDock extends StatelessWidget {
  const _FloatingBottomPillDock({
    required this.currentIndex,
    required this.onSelect,
  });

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
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: tokens.glassSurface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: tokens.subtleBorder, width: 1),
            ),
            child: Row(
              children: List.generate(_navItems.length, (i) {
                final item = _navItems[i];
                final active = currentIndex == i;
                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onSelect(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: active ? tokens.accentSoft : Colors.transparent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkIconWidget(
                            item.icon,
                            size: 20,
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
      ),
    );
  }
}
