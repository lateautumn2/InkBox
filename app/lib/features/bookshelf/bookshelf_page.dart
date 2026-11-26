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
import 'shelf_sheets.dart';

enum _BookSortMode { lastRead, addedAt, title, progress }

class BookshelfPage extends ConsumerStatefulWidget {
  const BookshelfPage({super.key});

  @override
  ConsumerState<BookshelfPage> createState() => _BookshelfPageState();
}

class _BookshelfPageState extends ConsumerState<BookshelfPage> {
  ShelfFilterGroup _selectedGroup = ShelfFilterGroup.all;
  bool _isGrid = true;
  bool _showSearch = false;
  String _query = '';
  _BookSortMode _sortMode = _BookSortMode.lastRead;
  final Set<int> _selectedIds = {};

  static const _coverPalettes = [
    [Color(0xFF1D3557), Color(0xFF3B608C)],
    [Color(0xFF264653), Color(0xFF437689)],
    [Color(0xFF3D3456), Color(0xFF64588A)],
    [Color(0xFF7D3838), Color(0xFFA85252)],
    [Color(0xFF2D4F44), Color(0xFF487A69)],
    [Color(0xFF36414E), Color(0xFF59697D)],
  ];

  List<Color> _paletteFor(Book book) {
    return _coverPalettes[book.title.hashCode.abs() % _coverPalettes.length];
  }

  bool _matchesGroup(Book b, ShelfFilterGroup group) {
    return switch (group) {
      ShelfFilterGroup.all => true,
      ShelfFilterGroup.finished => isBookFinished(b),
      ShelfFilterGroup.reading => !isBookFinished(b),
    };
  }

  List<Book> _sortBooks(List<Book> input) {
    final copy = [...input];
    copy.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      switch (_sortMode) {
        case _BookSortMode.lastRead:
          return b.lastReadAtMs.compareTo(a.lastReadAtMs);
        case _BookSortMode.addedAt:
          return b.addedAtMs.compareTo(a.addedAtMs);
        case _BookSortMode.title:
          return a.title.compareTo(b.title);
        case _BookSortMode.progress:
          return b.progressRatio.compareTo(a.progressRatio);
      }
    });
    return copy;
  }

  void _toggleSelect(int id) {
    setState(() {
      if (!_selectedIds.remove(id)) _selectedIds.add(id);
    });
  }

  Future<void> _showSortSheet() async {
    final l10n = context.l10n;
    final picked = await showInkOptionSheet<_BookSortMode>(
      context: context,
      title: l10n.sortBy,
      selectedValue: _sortMode,
      options: [
        InkOptionItem(value: _BookSortMode.lastRead, label: l10n.sortLastRead),
        InkOptionItem(value: _BookSortMode.addedAt, label: l10n.sortAddedAt),
        InkOptionItem(value: _BookSortMode.title, label: l10n.sortTitle),
        InkOptionItem(value: _BookSortMode.progress, label: l10n.sortProgress),
      ],
    );
    if (picked != null && mounted) {
      setState(() => _sortMode = picked);
    }
  }

  Future<void> _batchMoveShelf(
    List<Shelf> shelves,
    int currentShelfId,
  ) async {
    final db = ref.read(appDatabaseProvider);
    final targetShelfId = await showMoveToShelfDialog(
      context: context,
      db: db,
      mediaKind: 'book',
      shelves: shelves,
      currentShelfId: currentShelfId,
    );
    if (targetShelfId == null) return;
    final count = _selectedIds.length;
    await db.moveBooksToShelf(_selectedIds, targetShelfId);
    if (!mounted) return;
    setState(() => _selectedIds.clear());
    final updatedShelves = await db.getShelves('book');
    final targetShelf =
        updatedShelves.where((s) => s.id == targetShelfId).firstOrNull;
    if (!mounted) return;
    final l10n = context.l10n;
    final targetName = localizedShelfName(l10n, targetShelf, isComic: false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.moveBookSuccess(count, targetName))),
    );
  }

  Future<void> _batchRemoveBooks() async {
    final l10n = context.l10n;
    final count = _selectedIds.length;
    final choice = await showInkOptionSheet<String>(
      context: context,
      title: l10n.removeBooksTitle(count),
      options: [
        InkOptionItem(
          value: 'archive',
          label: l10n.removeArchiveOption,
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
      await ref.read(appDatabaseProvider).archiveBooksByIds(_selectedIds);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.archivedBooksToast(count))),
        );
      }
    } else if (choice == 'permanent') {
      await ref
          .read(importServiceProvider)
          .permanentlyDeleteBooks(_selectedIds);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.deletedBooksToast(count))),
        );
      }
    }
    setState(() => _selectedIds.clear());
  }

  @override
  Widget build(BuildContext context) {
    final tokens = InkBoxTokens.of(context);
    final l10n = context.l10n;
    final booksAsync = ref.watch(booksStreamProvider);
    final shelves =
        ref.watch(bookShelvesStreamProvider).valueOrNull ?? const <Shelf>[];
    final rawActiveShelfId = ref.watch(activeBookShelfIdProvider);
    final activeShelfId =
        AppDatabase.resolveEffectiveShelfId(rawActiveShelfId, shelves);
    final activeShelf = shelves.where((s) => s.id == activeShelfId).firstOrNull;
    final headerTitle = localizedShelfName(l10n, activeShelf, isComic: false);
    final selecting = _selectedIds.isNotEmpty;
    final navBottomInset = MediaQuery.paddingOf(context).bottom;
    final wide = isWideLayout(context);

    return SafeArea(
      bottom: false,
      child: Stack(
        children: [
          Column(
            children: [
              FloatingHeaderBar(
                title: selecting
                    ? l10n.selectedCountBooks(_selectedIds.length)
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
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (shelves.length > 1) ...[
                              Text(
                                l10n.shelvesCountBadge(shelves.length),
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
                          mediaKind: 'book',
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
                          tooltip: l10n.searchBooks,
                          onPressed: () => setState(() {
                            _showSearch = !_showSearch;
                            if (!_showSearch) _query = '';
                          }),
                        ),
                        const SizedBox(width: 8),
                        InkCircleButton(
                          icon: InkIconWidget(
                            _isGrid ? InkIcon.list : InkIcon.grid,
                            size: 18,
                            color: tokens.inkPrimary,
                          ),
                          tooltip: _isGrid ? l10n.listView : l10n.gridView,
                          onPressed: () => setState(() => _isGrid = !_isGrid),
                        ),
                        const SizedBox(width: 8),
                        InkCircleButton(
                          icon: InkIconWidget(
                            InkIcon.sort,
                            size: 17,
                            color: tokens.inkPrimary,
                          ),
                          tooltip: l10n.sortBy,
                          onPressed: _showSortSheet,
                        ),
                      ],
              ),
              if (_showSearch)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                  child: InkTextField(
                    autofocus: true,
                    prefixIcon: InkIcon.search,
                    hintText: l10n.searchBooksHint,
                    onChanged: (v) => setState(() => _query = v.trim()),
                  ),
                ),
              Expanded(
                child: booksAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) =>
                      Center(child: Text(l10n.bookshelfLoadError('$e'))),
                  data: (allBooks) {
                    final shelfBooks = shelves.isEmpty
                        ? allBooks
                        : allBooks
                            .where((b) =>
                                AppDatabase.resolveEffectiveShelfId(
                                    b.shelfId, shelves) ==
                                activeShelfId)
                            .toList();
                    final filtered = _sortBooks(
                      shelfBooks.where((b) {
                        final groupMatch = _matchesGroup(b, _selectedGroup);
                        final qMatch = _query.isEmpty ||
                            b.title
                                .toLowerCase()
                                .contains(_query.toLowerCase()) ||
                            b.author
                                .toLowerCase()
                                .contains(_query.toLowerCase());
                        return groupMatch && qMatch;
                      }).toList(),
                    );

                    final latest = shelfBooks.isEmpty
                        ? null
                        : shelfBooks.reduce(
                            (a, b) => a.lastReadAtMs >= b.lastReadAtMs ? a : b,
                          );
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
                            itemBuilder: (context, idx) {
                              final grp = ShelfFilterGroup.values[idx];
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
                                          InkIcon.bookshelf,
                                          size: 42,
                                          color: tokens.inkMuted,
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          allBooks.isEmpty
                                              ? l10n.emptyLibraryBooks
                                              : (shelfBooks.isEmpty
                                                  ? l10n.emptyShelfBooks(
                                                      headerTitle)
                                                  : l10n.emptyGroupBooks),
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: tokens.inkMuted,
                                          ),
                                        ),
                                        if (shelfBooks.isEmpty) ...[
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
                                                    Text(l10n.importLocalBooks),
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
                                                    mediaKind: 'book',
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
                              : CustomScrollView(
                                  slivers: [
                                    if (latest != null &&
                                        !selecting &&
                                        _selectedGroup ==
                                            ShelfFilterGroup.all &&
                                        _query.isEmpty)
                                      SliverPadding(
                                        padding: const EdgeInsets.fromLTRB(
                                            14, 0, 14, 12),
                                        sliver: SliverToBoxAdapter(
                                          child: _ContinueReadingCard(
                                            book: latest,
                                            palette: _paletteFor(latest),
                                            onTap: () => context.push(
                                                '/reader/book/${latest.id}'),
                                            onInfo: () => context
                                                .push('/book/${latest.id}'),
                                          ),
                                        ),
                                      ),
                                    if (_isGrid)
                                      SliverPadding(
                                        padding: EdgeInsets.fromLTRB(
                                            14, 0, 14, bottomPad),
                                        sliver: SliverGrid(
                                          gridDelegate:
                                              adaptiveShelfGridDelegate(
                                            context,
                                            childAspectRatio: 0.62,
                                          ),
                                          delegate: SliverChildBuilderDelegate(
                                            (context, i) {
                                              final book = filtered[i];
                                              final isSelected = _selectedIds
                                                  .contains(book.id);
                                              return _BookGridItem(
                                                book: book,
                                                palette: _paletteFor(book),
                                                selected: isSelected,
                                                onTap: () {
                                                  if (selecting) {
                                                    _toggleSelect(book.id);
                                                  } else {
                                                    context.push(
                                                        '/reader/book/${book.id}');
                                                  }
                                                },
                                                onLongPress: () =>
                                                    _toggleSelect(book.id),
                                              );
                                            },
                                            childCount: filtered.length,
                                          ),
                                        ),
                                      )
                                    else
                                      SliverPadding(
                                        padding: EdgeInsets.fromLTRB(
                                            14, 0, 14, bottomPad),
                                        sliver: SliverList.separated(
                                          itemCount: filtered.length,
                                          separatorBuilder: (_, _) =>
                                              const SizedBox(height: 10),
                                          itemBuilder: (context, i) {
                                            final book = filtered[i];
                                            final isSelected =
                                                _selectedIds.contains(book.id);
                                            return _BookListItem(
                                              book: book,
                                              palette: _paletteFor(book),
                                              selected: isSelected,
                                              onTap: () {
                                                if (selecting) {
                                                  _toggleSelect(book.id);
                                                } else {
                                                  context.push(
                                                      '/reader/book/${book.id}');
                                                }
                                              },
                                              onLongPress: () =>
                                                  _toggleSelect(book.id),
                                              onInfoTap: () => context
                                                  .push('/book/${book.id}'),
                                            );
                                          },
                                        ),
                                      ),
                                  ],
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
                final curBooks = booksAsync.valueOrNull ?? const <Book>[];
                final selectedBooks = curBooks
                    .where((b) => _selectedIds.contains(b.id))
                    .toList();
                final allFinished = selectedBooks.isNotEmpty &&
                    selectedBooks.every(isBookFinished);
                return Positioned(
                  left: 14,
                  right: 14,
                  bottom: (!wide && tokens.isFloatingCard)
                      ? navBottomInset + 84
                      : 14,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: wide ? 480 : double.infinity,
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
                            if (_selectedIds.length == 1)
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: _BatchActionBtn(
                                    label: l10n.details,
                                    onTap: () {
                                      final id = _selectedIds.first;
                                      setState(() => _selectedIds.clear());
                                      context.push('/book/$id');
                                    },
                                  ),
                                ),
                              ),
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: _BatchActionBtn(
                                  label: l10n.moveShelf,
                                  onTap: () =>
                                      _batchMoveShelf(shelves, activeShelfId),
                                ),
                              ),
                            ),
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: _BatchActionBtn(
                                  label: allFinished
                                      ? l10n.markReading
                                      : l10n.markFinished,
                                  onTap: () async {
                                    final db = ref.read(appDatabaseProvider);
                                    for (final b in selectedBooks) {
                                      if (allFinished) {
                                        final nextRatio = b.progressRatio >= 0.99
                                            ? ((b.currentChapterIndex == 0 &&
                                                    b.currentCharOffset == 0)
                                                ? 0.0
                                                : 0.98)
                                            : null;
                                        await db.updateBookMeta(
                                          b.id,
                                          shelfGroup: '在读',
                                          progressRatio: nextRatio,
                                        );
                                      } else {
                                        await db.updateBookMeta(
                                          b.id,
                                          shelfGroup: '已读完',
                                          progressRatio: 1.0,
                                        );
                                      }
                                    }
                                    if (mounted) {
                                      setState(() => _selectedIds.clear());
                                    }
                                  },
                                ),
                              ),
                            ),
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: _BatchActionBtn(
                                  label: l10n.removeBooks,
                                  danger: true,
                                  onTap: _batchRemoveBooks,
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
                heroTag: 'bookshelf_import_fab',
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
  }
}

class _BatchActionBtn extends StatelessWidget {
  const _BatchActionBtn({
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final tokens = InkBoxTokens.of(context);
    return TextButton(
      style: TextButton.styleFrom(
        minimumSize: Size.zero,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: onTap,
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: danger ? tokens.accentWarm : tokens.accentPrimary,
        ),
      ),
    );
  }
}

class _BookCoverArt extends StatelessWidget {
  const _BookCoverArt({
    required this.book,
    required this.palette,
    this.compact = false,
  });

  final Book book;
  final List<Color> palette;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hasCover =
        book.coverPath != null && File(book.coverPath!).existsSync();
    return ClipRRect(
      borderRadius: BorderRadius.circular(compact ? 10 : 11),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hasCover)
            Image.file(File(book.coverPath!), fit: BoxFit.cover)
          else
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: palette,
                ),
              ),
              padding: EdgeInsets.all(compact ? 6 : 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    book.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compact ? 9.5 : 11.5,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  if (!compact) ...[
                    const SizedBox(height: 2),
                    Text(
                      localizedAuthor(l10n, book.author),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 9.5,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ContinueReadingCard extends StatelessWidget {
  const _ContinueReadingCard({
    required this.book,
    required this.palette,
    required this.onTap,
    required this.onInfo,
  });

  final Book book;
  final List<Color> palette;
  final VoidCallback onTap;
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) {
    final tokens = InkBoxTokens.of(context);
    final l10n = context.l10n;
    final pct = (book.progressRatio * 100).round();
    final chTitle = localizedChapterTitle(l10n, book.currentChapterTitle);
    return FloatingCard(
      onTap: onTap,
      onLongPress: onInfo,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            height: 64,
            child: _BookCoverArt(book: book, palette: palette, compact: true),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (book.cloudFileSynced) ...[
                      InkIconWidget(
                        InkIcon.syncCloud,
                        size: 12,
                        color: tokens.accentPrimary,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      l10n.continueReading,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: tokens.accentPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  book.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: tokens.inkPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$chTitle · $pct%',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: tokens.inkMuted),
                ),
                const SizedBox(height: 7),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: book.progressRatio.clamp(0.0, 1.0),
                    minHeight: 3.5,
                    backgroundColor: tokens.surfaceVariant,
                    valueColor: AlwaysStoppedAnimation(tokens.accentPrimary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: tokens.accentSoft,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: InkIconWidget(
                InkIcon.play,
                size: 16,
                color: tokens.accentPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookGridItem extends StatelessWidget {
  const _BookGridItem({
    required this.book,
    required this.palette,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  final Book book;
  final List<Color> palette;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final tokens = InkBoxTokens.of(context);
    final pct = (book.progressRatio * 100).round();
    final cover = Stack(
      children: [
        _BookCoverArt(book: book, palette: palette),
        if (selected)
          Positioned(
            top: 6,
            left: 6,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: tokens.accentPrimary,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: InkIconWidget(
                  InkIcon.check,
                  size: 13,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );

    if (tokens.isFloatingCard) {
      return FloatingCard(
        onTap: onTap,
        onLongPress: onLongPress,
        borderColor: selected ? tokens.accentPrimary : null,
        radius: 13,
        padding: const EdgeInsets.all(6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: cover),
            const SizedBox(height: 5),
            Text(
              book.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: tokens.inkPrimary,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: book.progressRatio.clamp(0.0, 1.0),
                      minHeight: 3,
                      backgroundColor: tokens.surfaceVariant,
                      valueColor: AlwaysStoppedAnimation(
                        pct >= 99 ? tokens.statusOk : tokens.accentPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  '$pct%',
                  style: TextStyle(
                    fontSize: 9.5,
                    color: tokens.inkMuted,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: cover),
          const SizedBox(height: 5),
          Text(
            book.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: tokens.inkPrimary,
            ),
          ),
          Text(
            '$pct%',
            style: TextStyle(
              fontSize: 10,
              color: tokens.inkMuted,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _BookListItem extends StatelessWidget {
  const _BookListItem({
    required this.book,
    required this.palette,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    required this.onInfoTap,
  });

  final Book book;
  final List<Color> palette;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onInfoTap;

  @override
  Widget build(BuildContext context) {
    final tokens = InkBoxTokens.of(context);
    final l10n = context.l10n;
    final pct = (book.progressRatio * 100).round();
    final author = localizedAuthor(l10n, book.author);
    final chapter = localizedChapterTitle(l10n, book.currentChapterTitle);
    return FloatingCard(
      onTap: onTap,
      onLongPress: onLongPress,
      borderColor: selected ? tokens.accentPrimary : null,
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            height: 60,
            child: _BookCoverArt(book: book, palette: palette, compact: true),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: tokens.inkPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$author · $chapter',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: tokens.inkMuted),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: book.progressRatio.clamp(0.0, 1.0),
                          minHeight: 3.5,
                          backgroundColor: tokens.surfaceVariant,
                          valueColor:
                              AlwaysStoppedAnimation(tokens.accentPrimary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$pct%',
                      style: TextStyle(
                        fontSize: 11,
                        color: tokens.inkMuted,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: l10n.details,
            onPressed: onInfoTap,
            icon: InkIconWidget(
              InkIcon.more,
              size: 17,
              color: tokens.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}
