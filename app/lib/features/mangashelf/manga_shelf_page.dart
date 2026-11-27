import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/icons/ink_icons.dart';
import '../../core/l10n/l10n_helpers.dart';
import '../../core/layout/responsive_layout.dart';
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
  ShelfFilterGroup _selectedGroup = ShelfFilterGroup.all;
  bool _unreadOnly = false;
  bool _showSearch = false;
  String _query = '';
  final Set<int> _selectedIds = {};

  static const _palettes = [
    [Color(0xFF1F2733), Color(0xFF3E4E63)],
    [Color(0xFF6B2D2D), Color(0xFF9C4747)],
    [Color(0xFF2B4C40), Color(0xFF477867)],
    [Color(0xFF283454), Color(0xFF465A8E)],
    [Color(0xFF3A3546), Color(0xFF5D5670)],
  ];

  void _toggleSelect(int id) {
    setState(() {
      if (!_selectedIds.remove(id)) _selectedIds.add(id);
    });
  }

  bool _matchesGroup(Manga m, ShelfFilterGroup group) {
    return switch (group) {
      ShelfFilterGroup.all => true,
      ShelfFilterGroup.finished => isMangaFinished(m),
      ShelfFilterGroup.reading => !isMangaFinished(m),
    };
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
    final targetShelf =
        updatedShelves.where((s) => s.id == targetShelfId).firstOrNull;
    if (!mounted) return;
    final l10n = context.l10n;
    final targetName = localizedShelfName(l10n, targetShelf, isComic: true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.moveMangaSuccess(count, targetName))),
    );
  }

  Future<void> _batchRemoveMangas() async {
    final l10n = context.l10n;
    final count = _selectedIds.length;
    final choice = await showInkOptionSheet<String>(
      context: context,
      title: l10n.removeMangaTitle(count),
      options: [
        InkOptionItem(
          value: 'archive',
          label: l10n.removeArchiveMangaOption,
          icon: InkIcon.history,
        ),
        InkOptionItem(
          value: 'permanent',
          label: l10n.removePermanentOption,
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
    final l10n = context.l10n;
    final mangasAsync = ref.watch(mangasStreamProvider);
    final shelves =
        ref.watch(mangaShelvesStreamProvider).valueOrNull ?? const <Shelf>[];
    final rawActiveShelfId = ref.watch(activeMangaShelfIdProvider);
    final activeShelfId =
        AppDatabase.resolveEffectiveShelfId(rawActiveShelfId, shelves);
    final activeShelf = shelves.where((s) => s.id == activeShelfId).firstOrNull;
    final headerTitle = localizedShelfName(l10n, activeShelf, isComic: true);
    final selecting = _selectedIds.isNotEmpty;
    final navBottomInset = MediaQuery.paddingOf(context).bottom;
    final wide = isWideLayout(context);

    final shelf = SafeArea(
      bottom: false,
      child: Stack(
        children: [
          Column(
            children: [
              FloatingHeaderBar(
                title: selecting
                    ? l10n.selectedCountManga(_selectedIds.length)
                    : headerTitle,
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
                        child: InkIconWidget(
                          InkIcon.chevronDown,
                          size: 13,
                          color: tokens.accentPrimary,
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
                            l10n.cancel,
                            style: TextStyle(color: tokens.accentPrimary),
                          ),
                        ),
                      ]
                    : [
                        InkCircleButton(
                          icon: InkIconWidget(
                            InkIcon.search,
                            size: 18,
                            color: tokens.inkPrimary,
                          ),
                          highlighted: _showSearch,
                          tooltip: l10n.searchManga,
                          onPressed: () => setState(() {
                            _showSearch = !_showSearch;
                            if (!_showSearch) _query = '';
                          }),
                        ),
                        const SizedBox(width: 8),
                        InkCircleButton(
                          icon: InkIconWidget(
                            InkIcon.filter,
                            size: 18,
                            color: _unreadOnly
                                ? tokens.accentPrimary
                                : tokens.inkPrimary,
                          ),
                          highlighted: _unreadOnly,
                          tooltip: l10n.unreadOnly,
                          onPressed: () =>
                              setState(() => _unreadOnly = !_unreadOnly),
                        ),
                      ],
              ),
              if (_showSearch)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                  child: InkTextField(
                    autofocus: true,
                    prefixIcon: InkIcon.search,
                    hintText: l10n.searchMangaHint,
                    onChanged: (v) => setState(() => _query = v.trim()),
                  ),
                ),
              Expanded(
                child: mangasAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) =>
                      Center(child: Text(l10n.mangaShelfLoadError('$e'))),
                  data: (list) {
                    final shelfMangas = shelves.isEmpty
                        ? list
                        : list
                            .where((m) =>
                                AppDatabase.resolveEffectiveShelfId(
                                    m.shelfId, shelves) ==
                                activeShelfId)
                            .toList();
                    final filtered = shelfMangas.where((m) {
                      final groupOk = _matchesGroup(m, _selectedGroup);
                      final unreadOk = !_unreadOnly || m.unreadCount > 0;
                      final qMatch = _query.isEmpty ||
                          m.title
                              .toLowerCase()
                              .contains(_query.toLowerCase()) ||
                          m.author.toLowerCase().contains(_query.toLowerCase());
                      return groupOk && unreadOk && qMatch;
                    }).toList();
                    final bottomPad = wide
                        ? 88.0
                        : (tokens.isFloatingCard ? navBottomInset + 116.0 : 80.0);

                    return Column(
                      children: [
                        SizedBox(
                          height: 38,
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            scrollDirection: Axis.horizontal,
                            itemCount: ShelfFilterGroup.values.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, i) {
                              final grp = ShelfFilterGroup.values[i];
                              final active = _selectedGroup == grp;
                              return InkPillChip(
                                label: grp.labelOf(l10n),
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
                                      left: 24,
                                      right: 24,
                                      bottom: (!wide && tokens.isFloatingCard)
                                          ? 64
                                          : 16,
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
                                              ? l10n.emptyLibraryManga
                                              : (shelfMangas.isEmpty
                                                  ? l10n.emptyShelfManga(
                                                      headerTitle)
                                                  : l10n.emptyGroupManga),
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: tokens.inkMuted,
                                          ),
                                        ),
                                        if (shelfMangas.isEmpty) ...[
                                          const SizedBox(height: 14),
                                          Wrap(
                                            spacing: 10,
                                            runSpacing: 8,
                                            alignment: WrapAlignment.center,
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
                                                label:
                                                    Text(l10n.importLocalManga),
                                              ),
                                              if (shelves.length > 1)
                                                OutlinedButton(
                                                  style:
                                                      OutlinedButton.styleFrom(
                                                    shape:
                                                        const StadiumBorder(),
                                                    side: BorderSide(
                                                      color:
                                                          tokens.subtleBorder,
                                                    ),
                                                  ),
                                                  onPressed: () =>
                                                      showShelfSwitcherSheet(
                                                    context: context,
                                                    mediaKind: 'comic',
                                                  ),
                                                  child: Text(
                                                    l10n.switchOtherShelf,
                                                    style: TextStyle(
                                                      color: tokens.inkPrimary,
                                                    ),
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
                                  gridDelegate: adaptiveShelfGridDelegate(
                                    context,
                                    childAspectRatio: 0.68,
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
                    selectedMangas.every(isMangaFinished);
                return Positioned(
                  left: 14,
                  right: 14,
                  bottom: (!wide && tokens.isFloatingCard)
                      ? navBottomInset + 84
                      : 14,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: wide ? 460 : double.infinity,
                      ),
                      child: FloatingCard(
                        frosted: true,
                        radius: 22,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            TextButton(
                              onPressed: () =>
                                  _batchMoveShelf(shelves, activeShelfId),
                              child: Text(
                                l10n.moveShelf,
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
                                if (mounted) {
                                  setState(() => _selectedIds.clear());
                                }
                              },
                              child: Text(
                                allFinished
                                    ? l10n.resetUnread
                                    : l10n.markAllRead,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: tokens.accentPrimary,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: _batchRemoveMangas,
                              child: Text(
                                l10n.removeManga,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: tokens.accentWarm,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            )
          else
            Positioned(
              right: 18,
              bottom: (!wide && tokens.isFloatingCard)
                  ? navBottomInset + 84
                  : 18,
              child: FloatingActionButton.small(
                heroTag: 'manga_import_fab',
                backgroundColor: tokens.accentPrimary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
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
    return KeyboardInsetPadding(enabled: _showSearch, child: shelf);
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
          if (selected || manga.unreadCount > 0)
            Positioned(
              top: 6,
              left: 6,
              child: selected
                  ? Container(
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
                  : Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5.5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: tokens.accentPrimary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${manga.unreadCount}',
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
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
        radius: 13,
        padding: const EdgeInsets.all(5),
        child: cover,
      );
    }

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: cover,
    );
  }
}
