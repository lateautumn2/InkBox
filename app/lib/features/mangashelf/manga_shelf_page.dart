import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/icons/ink_icons.dart';
import '../../core/theme/inkbox_theme.dart';
import '../../core/widgets/floating_surface.dart';
import '../../core/widgets/ink_controls.dart';
import '../../data/db/app_database.dart';
import '../../data/providers/app_providers.dart';
import '../bookshelf/shelf_sheets.dart';

class MangaShelfPage extends ConsumerStatefulWidget {
  const MangaShelfPage({super.key});

  @override
  ConsumerState<MangaShelfPage> createState() => _MangaShelfPageState();
}

class _MangaShelfPageState extends ConsumerState<MangaShelfPage> {
  String _selectedGroup = '所有';
  bool _unreadOnly = false;
  final Set<int> _selectedIds = {};

  static const _palettes = [
    [Color(0xFF23252B), Color(0xFF454954)],
    [Color(0xFF6A2C2C), Color(0xFF9E4242)],
    [Color(0xFF365745), Color(0xFF548269)],
    [Color(0xFF2A3359), Color(0xFF4A5996)],
    [Color(0xFF3D352E), Color(0xFF6B5D52)],
  ];

  void _toggleSelect(int id) {
    setState(() {
      if (!_selectedIds.remove(id)) _selectedIds.add(id);
    });
  }

  bool _isFinished(Manga m) =>
      (m.totalChapters > 0 && m.unreadCount == 0) || m.shelfGroup == '已读完';

  bool _matchesGroup(Manga m, String group) {
    if (group == '所有') return true;
    if (group == '已读完') return _isFinished(m);
    return !_isFinished(m);
  }

  Future<void> _batchMoveShelf(List<Shelf> shelves, int currentShelfId) async {
    final db = ref.read(appDatabaseProvider);
    final targetShelfId = await showMoveToShelfDialog(
      context: context,
      db: db,
      mediaKind: 'comic',
      shelves: shelves,
      currentShelfId: currentShelfId,
    );
    if (targetShelfId == null) return;
    final count = _selectedIds.length;
    await db.moveMangasToShelf(_selectedIds, targetShelfId);
    if (!mounted) return;
    setState(() => _selectedIds.clear());
    final updatedShelves = await db.getShelves('comic');
    final targetName = updatedShelves
            .where((s) => s.id == targetShelfId)
            .firstOrNull
            ?.name ??
        '目标漫画架';
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已将 $count 部漫画移至「$targetName」')),
    );
  }

  Future<void> _batchRemoveMangas() async {
    final count = _selectedIds.length;
    final choice = await showInkOptionSheet<String>(
      context: context,
      title: '移除选中的 $count 部漫画',
      subtitle: '移出漫画架会保留在「导入历史」中，随时可重新入架',
      options: const [
        InkOptionItem(
          value: 'archive',
          label: '移出漫画架（保留在导入历史）',
          icon: InkIcon.history,
        ),
        InkOptionItem(
          value: 'permanent',
          label: '彻底删除',
          subtitle: '同时清除导入历史与应用内缓存文件',
          icon: InkIcon.trash,
          danger: true,
        ),
      ],
    );
    if (choice == null || !mounted) return;
    if (choice == 'archive') {
      await ref.read(appDatabaseProvider).archiveMangasByIds(_selectedIds);
    } else if (choice == 'permanent') {
      await ref
          .read(importServiceProvider)
          .permanentlyDeleteMangas(_selectedIds);
    }
    setState(() => _selectedIds.clear());
  }

  @override
  Widget build(BuildContext context) {
    final tokens = InkBoxTokens.of(context);
    final mangasAsync = ref.watch(mangasStreamProvider);
    final shelves =
        ref.watch(mangaShelvesStreamProvider).valueOrNull ?? const <Shelf>[];
    final rawActiveShelfId = ref.watch(activeMangaShelfIdProvider);
    final activeShelfId =
        AppDatabase.resolveEffectiveShelfId(rawActiveShelfId, shelves);
    final activeShelf = shelves.where((s) => s.id == activeShelfId).firstOrNull;
    final headerTitle = activeShelf?.name ?? kDefaultMangaShelfName;
    final selecting = _selectedIds.isNotEmpty;
    final navBottomInset = MediaQuery.paddingOf(context).bottom;

    return SafeArea(
      bottom: false,
      child: Stack(
        children: [
          Column(
            children: [
              FloatingHeaderBar(
                title: selecting ? '已选 ${_selectedIds.length} 部' : headerTitle,
                titleTrailing: selecting
                    ? null
                    : Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: tokens.accentSoft,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (shelves.length > 1) ...[
                              Text(
                                '${shelves.length}架',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: tokens.accentPrimary,
                                ),
                              ),
                              const SizedBox(width: 2),
                            ],
                            InkIconWidget(
                              InkIcon.chevronDown,
                              size: 13,
                              color: tokens.accentPrimary,
                            ),
                          ],
                        ),
                      ),
                onTitleTap: selecting
                    ? null
                    : () => showShelfSwitcherSheet(
                          context: context,
                          mediaKind: 'comic',
                        ),
                actions: selecting
                    ? [
                        TextButton(
                          onPressed: () => setState(() => _selectedIds.clear()),
                          child: Text(
                            '取消',
                            style: TextStyle(color: tokens.accentPrimary),
                          ),
                        ),
                      ]
                    : [
                        InkCircleButton(
                          icon: InkIconWidget(
                            InkIcon.filter,
                            size: 18,
                            color: _unreadOnly
                                ? tokens.accentPrimary
                                : tokens.inkPrimary,
                          ),
                          highlighted: _unreadOnly,
                          tooltip: _unreadOnly ? '显示全部漫画' : '仅看未读漫画',
                          onPressed: () =>
                              setState(() => _unreadOnly = !_unreadOnly),
                        ),
                      ],
              ),
              Expanded(
                child: mangasAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('漫画架加载失败: $e')),
                  data: (list) {
                    final shelfMangas = shelves.isEmpty
                        ? list
                        : list
                            .where((m) =>
                                AppDatabase.resolveEffectiveShelfId(
                                    m.shelfId, shelves) ==
                                activeShelfId)
                            .toList();
                    final activeGroup =
                        kDefaultShelfGroups.contains(_selectedGroup)
                            ? _selectedGroup
                            : '所有';
                    final filtered = shelfMangas.where((m) {
                      final groupOk = _matchesGroup(m, activeGroup);
                      final unreadOk = !_unreadOnly || m.unreadCount > 0;
                      return groupOk && unreadOk;
                    }).toList();
                    final bottomPad =
                        tokens.isFloatingCard ? navBottomInset + 124.0 : 80.0;

                    return Column(
                      children: [
                        SizedBox(
                          height: 38,
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            scrollDirection: Axis.horizontal,
                            itemCount: kDefaultShelfGroups.length + 1,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, i) {
                              if (i == kDefaultShelfGroups.length) {
                                return InkPillChip(
                                  label: '切换漫画架',
                                  leadingIcon: InkIcon.manga,
                                  elevated: true,
                                  onTap: () => showShelfSwitcherSheet(
                                    context: context,
                                    mediaKind: 'comic',
                                  ),
                                );
                              }
                              final grp = kDefaultShelfGroups[i];
                              final active = activeGroup == grp;
                              return InkPillChip(
                                label: grp,
                                selected: active,
                                elevated: true,
                                onTap: () =>
                                    setState(() => _selectedGroup = grp),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: filtered.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: EdgeInsets.only(
                                      bottom: tokens.isFloatingCard ? 64 : 16,
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        InkIconWidget(
                                          InkIcon.manga,
                                          size: 40,
                                          color: tokens.inkMuted,
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          list.isEmpty
                                              ? '漫画架还是空的，前往导入中心添加吧'
                                              : (shelfMangas.isEmpty
                                                  ? '「$headerTitle」暂无漫画，可导入或从其他漫画架移入'
                                                  : '当前分组暂无漫画'),
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: tokens.inkMuted,
                                          ),
                                        ),
                                        if (shelfMangas.isEmpty) ...[
                                          const SizedBox(height: 14),
                                          Wrap(
                                            spacing: 10,
                                            children: [
                                              FilledButton.icon(
                                                style: FilledButton.styleFrom(
                                                  backgroundColor:
                                                      tokens.accentPrimary,
                                                  shape: const StadiumBorder(),
                                                ),
                                                onPressed: () =>
                                                    context.go('/import'),
                                                icon: InkIconWidget(
                                                  InkIcon.importTray,
                                                  size: 16,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onPrimary,
                                                ),
                                                label: const Text('导入本地漫画'),
                                              ),
                                              if (shelves.length > 1)
                                                OutlinedButton(
                                                  style:
                                                      OutlinedButton.styleFrom(
                                                    shape:
                                                        const StadiumBorder(),
                                                    side: BorderSide(
                                                        color: tokens
                                                            .subtleBorder),
                                                  ),
                                                  onPressed: () =>
                                                      showShelfSwitcherSheet(
                                                    context: context,
                                                    mediaKind: 'comic',
                                                  ),
                                                  child: Text(
                                                    '切换其他漫画架',
                                                    style: TextStyle(
                                                        color:
                                                            tokens.inkPrimary),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                )
                              : GridView.builder(
                                  padding: EdgeInsets.fromLTRB(
                                      14, 0, 14, bottomPad),
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    mainAxisSpacing: 12,
                                    crossAxisSpacing: 12,
                                    childAspectRatio: 0.66,
                                  ),
                                  itemCount: filtered.length,
                                  itemBuilder: (context, idx) {
                                    final manga = filtered[idx];
                                    final colors = _palettes[
                                        manga.title.hashCode.abs() %
                                            _palettes.length];
                                    final isSelected =
                                        _selectedIds.contains(manga.id);
                                    return _MangaGridCard(
                                      manga: manga,
                                      colors: colors,
                                      selected: isSelected,
                                      onTap: () {
                                        if (selecting) {
                                          _toggleSelect(manga.id);
                                        } else {
                                          context.push('/manga/${manga.id}');
                                        }
                                      },
                                      onLongPress: () =>
                                          _toggleSelect(manga.id),
                                    );
                                  },
                                ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
          if (selecting)
            Builder(
              builder: (context) {
                final curMangas = mangasAsync.valueOrNull ?? const <Manga>[];
                final selectedMangas = curMangas
                    .where((m) => _selectedIds.contains(m.id))
                    .toList();
                final allFinished = selectedMangas.isNotEmpty &&
                    selectedMangas.every(_isFinished);
                return Positioned(
                  left: 14,
                  right: 14,
                  bottom: tokens.isFloatingCard ? navBottomInset + 92 : 14,
                  child: FloatingCard(
                    frosted: true,
                    radius: 24,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        TextButton(
                          onPressed: () =>
                              _batchMoveShelf(shelves, activeShelfId),
                          child: Text(
                            '移动漫画架',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: tokens.accentPrimary,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            final db = ref.read(appDatabaseProvider);
                            for (final id in _selectedIds) {
                              await db.updateMangaMeta(
                                id,
                                shelfGroup: allFinished ? '在读' : '已读完',
                              );
                              await db.markAllChaptersRead(id, !allFinished);
                            }
                            if (mounted) setState(() => _selectedIds.clear());
                          },
                          child: Text(
                            allFinished ? '重置在读' : '全部标已读',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: tokens.accentPrimary,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _batchRemoveMangas,
                          child: Text(
                            '移除漫画',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: tokens.accentWarm,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            )
          else
            Positioned(
              right: 18,
              bottom: tokens.isFloatingCard ? navBottomInset + 92 : 18,
              child: FloatingActionButton.small(
                heroTag: 'manga_import_fab',
                backgroundColor: tokens.accentPrimary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                onPressed: () => context.go('/import'),
                child: InkIconWidget(
                  InkIcon.plus,
                  size: 20,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MangaGridCard extends StatelessWidget {
  const _MangaGridCard({
    required this.manga,
    required this.colors,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  final Manga manga;
  final List<Color> colors;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final tokens = InkBoxTokens.of(context);
    final hasCover =
        manga.coverPath != null && File(manga.coverPath!).existsSync();

    final cover = ClipRRect(
      borderRadius: BorderRadius.circular(11),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hasCover)
            Image.file(File(manga.coverPath!), fit: BoxFit.cover)
          else
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: colors,
                ),
              ),
            ),
          Positioned(
            top: 6,
            left: 6,
            right: 6,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (selected)
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: tokens.accentPrimary,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: InkIconWidget(
                        InkIcon.check,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  )
                else if (manga.unreadCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5.5, vertical: 2),
                    decoration: BoxDecoration(
                      color: InkBoxTheme.slateInkLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${manga.unreadCount}',
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  )
                else
                  Container(
                    width: 19,
                    height: 19,
                    decoration: BoxDecoration(
                      color: tokens.statusOk,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Center(
                      child: InkIconWidget(
                        InkIcon.check,
                        size: 11,
                        color: Colors.white,
                      ),
                    ),
                  ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    manga.format,
                    style: const TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(7, 20, 7, 7),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                ),
              ),
              child: Text(
                manga.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (tokens.isFloatingCard) {
      return FloatingCard(
        onTap: onTap,
        onLongPress: onLongPress,
        borderColor: selected ? tokens.accentPrimary : null,
        radius: 14,
        padding: const EdgeInsets.all(6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: cover),
            const SizedBox(height: 5),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      manga.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10, color: tokens.inkMuted),
                    ),
                  ),
                  Text(
                    manga.preferredReadingMode == 'webtoon'
                        ? '条漫'
                        : manga.preferredReadingMode == 'dual'
                            ? '双页'
                            : manga.preferredReadingMode == 'ltr'
                                ? '美漫'
                                : '日漫',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: tokens.accentPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: cover,
    );
  }
}
