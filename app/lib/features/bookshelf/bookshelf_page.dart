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
import 'shelf_sheets.dart';

enum _BookSortMode { lastRead, addedAt, title, progress }

class BookshelfPage extends ConsumerStatefulWidget {
  const BookshelfPage({super.key});

  @override
  ConsumerState<BookshelfPage> createState() => _BookshelfPageState();
}

class _BookshelfPageState extends ConsumerState<BookshelfPage> {
  String _selectedGroup = '所有';
  bool _isGrid = true;
  bool _showSearch = false;
  String _query = '';
  _BookSortMode _sortMode = _BookSortMode.lastRead;
  final Set<int> _selectedIds = {};

  static const _coverPalettes = [
    [Color(0xFF1E3246), Color(0xFF3B5978)],
    [Color(0xFF8C4A32), Color(0xFFB86B4B)],
    [Color(0xFF2D5A4C), Color(0xFF4A7C6A)],
    [Color(0xFF6B4E71), Color(0xFF916D98)],
    [Color(0xFF7A5C38), Color(0xFFA68255)],
    [Color(0xFF3D4B5C), Color(0xFF5E728A)],
  ];

  List<Color> _paletteFor(Book book) {
    return _coverPalettes[book.title.hashCode.abs() % _coverPalettes.length];
  }

  bool _isFinished(Book b) =>
      b.progressRatio >= 0.99 || b.shelfGroup == '已读完';

  bool _matchesGroup(Book b, String group) {
    if (group == '所有') return true;
    if (group == '已读完') return _isFinished(b);
    return !_isFinished(b);
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
    final picked = await showInkOptionSheet<_BookSortMode>(
      context: context,
      title: '排序方式',
      selectedValue: _sortMode,
      options: const [
        InkOptionItem(
          value: _BookSortMode.lastRead,
          label: '按最近阅读',
          subtitle: '优先展示刚刚读过的书籍',
        ),
        InkOptionItem(
          value: _BookSortMode.addedAt,
          label: '按添加时间',
          subtitle: '最新导入的书籍排在前面',
        ),
        InkOptionItem(
          value: _BookSortMode.title,
          label: '按书名排序',
          subtitle: '按书名首字符顺序排列',
        ),
        InkOptionItem(
          value: _BookSortMode.progress,
          label: '按阅读进度',
          subtitle: '进度更高的书籍优先显示',
        ),
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
    final targetName = updatedShelves
            .where((s) => s.id == targetShelfId)
            .firstOrNull
            ?.name ??
        '目标书架';
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已将 $count 本书移至「$targetName」')),
    );
  }

  Future<void> _batchRemoveBooks() async {
    final count = _selectedIds.length;
    final choice = await showInkOptionSheet<String>(
      context: context,
      title: '移除选中的 $count 本书籍',
      subtitle: '移出书架会保留在「导入历史」中，随时可一键重新入架',
      options: const [
        InkOptionItem(
          value: 'archive',
          label: '移出书架（保留在导入历史）',
          subtitle: '保留阅读进度与本地文件，可在「导入 -> 导入历史」快速恢复',
          icon: InkIcon.history,
        ),
        InkOptionItem(
          value: 'permanent',
          label: '彻底删除',
          subtitle: '同时清除导入历史、书签笔记与应用内文件副本，无法恢复',
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
          SnackBar(content: Text('已移出 $count 本书（可在「导入历史」中恢复）')),
        );
      }
    } else if (choice == 'permanent') {
      await ref.read(importServiceProvider).permanentlyDeleteBooks(_selectedIds);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已彻底删除 $count 本书')),
        );
      }
    }
    setState(() => _selectedIds.clear());
  }

  @override
  Widget build(BuildContext context) {
    final tokens = InkBoxTokens.of(context);
    final booksAsync = ref.watch(booksStreamProvider);
    final shelves =
        ref.watch(bookShelvesStreamProvider).valueOrNull ?? const <Shelf>[];
    final rawActiveShelfId = ref.watch(activeBookShelfIdProvider);
    final activeShelfId =
        AppDatabase.resolveEffectiveShelfId(rawActiveShelfId, shelves);
    final activeShelf = shelves.where((s) => s.id == activeShelfId).firstOrNull;
    final headerTitle = activeShelf?.name ?? kDefaultBookShelfName;
    final selecting = _selectedIds.isNotEmpty;
    final navBottomInset = MediaQuery.paddingOf(context).bottom;

    return SafeArea(
      bottom: false,
      child: Stack(
        children: [
          Column(
            children: [
              FloatingHeaderBar(
                title: selecting ? '已选 ${_selectedIds.length} 本' : headerTitle,
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
                          mediaKind: 'book',
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
                            InkIcon.search,
                            size: 18,
                            color: tokens.inkPrimary,
                          ),
                          highlighted: _showSearch,
                          tooltip: '搜索书籍',
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
                          tooltip: _isGrid ? '切换为列表视图' : '切换为网格视图',
                          onPressed: () => setState(() => _isGrid = !_isGrid),
                        ),
                        const SizedBox(width: 8),
                        InkCircleButton(
                          icon: InkIconWidget(
                            InkIcon.sort,
                            size: 17,
                            color: tokens.inkPrimary,
                          ),
                          tooltip: '排序方式',
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
                    hintText: '搜索当前书架书名或作者...',
                    onChanged: (v) => setState(() => _query = v.trim()),
                  ),
                ),
              Expanded(
                child: booksAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('书架加载失败: $e')),
                  data: (allBooks) {
                    final shelfBooks = shelves.isEmpty
                        ? allBooks
                        : allBooks
                            .where((b) =>
                                AppDatabase.resolveEffectiveShelfId(
                                    b.shelfId, shelves) ==
                                activeShelfId)
                            .toList();
                    final activeGroup =
                        kDefaultShelfGroups.contains(_selectedGroup)
                            ? _selectedGroup
                            : '所有';
                    final filtered = _sortBooks(
                      shelfBooks.where((b) {
                        final groupMatch = _matchesGroup(b, activeGroup);
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
                            itemBuilder: (context, idx) {
                              if (idx == kDefaultShelfGroups.length) {
                                return InkPillChip(
                                  label: '切换书架',
                                  leadingIcon: InkIcon.bookshelf,
                                  elevated: true,
                                  onTap: () => showShelfSwitcherSheet(
                                    context: context,
                                    mediaKind: 'book',
                                  ),
                                );
                              }
                              final grp = kDefaultShelfGroups[idx];
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
                                          InkIcon.bookshelf,
                                          size: 42,
                                          color: tokens.inkMuted,
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          allBooks.isEmpty
                                              ? '书架还是空的，导入你的第一本小说吧'
                                              : (shelfBooks.isEmpty
                                                  ? '「$headerTitle」暂无书籍，可导入或从其他书架移入'
                                                  : '当前分组暂无书籍'),
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: tokens.inkMuted,
                                          ),
                                        ),
                                        if (shelfBooks.isEmpty) ...[
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
                                                label: const Text('导入本地书籍'),
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
                                                    mediaKind: 'book',
                                                  ),
                                                  child: Text(
                                                    '切换其他书架',
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
                              : CustomScrollView(
                                  slivers: [
                                    if (latest != null &&
                                        !selecting &&
                                        activeGroup == '所有' &&
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
                                              const SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: 3,
                                            mainAxisSpacing: 12,
                                            crossAxisSpacing: 12,
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
                                                onInfoTap: () => context
                                                    .push('/book/${book.id}'),
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
                    selectedBooks.every(_isFinished);
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
                        _BatchActionBtn(
                          label: '移动书架',
                          onTap: () => _batchMoveShelf(shelves, activeShelfId),
                        ),
                        _BatchActionBtn(
                          label: allFinished ? '标为在读' : '标为读完',
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
                            if (mounted) setState(() => _selectedIds.clear());
                          },
                        ),
                        _BatchActionBtn(
                          label: '移除书籍',
                          danger: true,
                          onTap: _batchRemoveBooks,
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
                heroTag: 'bookshelf_import_fab',
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
      onPressed: onTap,
      child: Text(
        label,
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
                      book.author,
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
          Positioned(
            top: compact ? 4 : 6,
            right: compact ? 4 : 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                book.format,
                style: TextStyle(
                  fontSize: compact ? 7.5 : 8.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
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
    final pct = (book.progressRatio * 100).round();
    return FloatingCard(
      onTap: onTap,
      onLongPress: onInfo,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            height: 68,
            child: _BookCoverArt(book: book, palette: palette, compact: true),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    InkIconWidget(
                      InkIcon.syncCloud,
                      size: 13,
                      color: tokens.accentPrimary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      book.cloudFileSynced ? '继续阅读 · 云端已同步' : '继续阅读',
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
                  '${book.currentChapterTitle} · $pct%',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: tokens.inkMuted),
                ),
                const SizedBox(height: 7),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: book.progressRatio.clamp(0.0, 1.0),
                    minHeight: 4,
                    backgroundColor: tokens.surfaceVariant,
                    valueColor: AlwaysStoppedAnimation(tokens.accentPrimary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: tokens.accentSoft,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: InkIconWidget(
                InkIcon.play,
                size: 17,
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
        radius: 14,
        padding: const EdgeInsets.all(6.5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: cover),
            const SizedBox(height: 5),
            Row(
              children: [
                Expanded(
                  child: Text(
                    book.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: tokens.inkPrimary,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: onInfoTap,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 2),
                    child: InkIconWidget(
                      InkIcon.more,
                      size: 14,
                      color: tokens.inkMuted,
                    ),
                  ),
                ),
              ],
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
          Row(
            children: [
              Expanded(
                child: Text(
                  book.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: tokens.inkPrimary,
                  ),
                ),
              ),
              GestureDetector(
                onTap: onInfoTap,
                child: InkIconWidget(
                  InkIcon.more,
                  size: 14,
                  color: tokens.inkMuted,
                ),
              ),
            ],
          ),
          Text('$pct%', style: TextStyle(fontSize: 10, color: tokens.inkMuted)),
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
    final pct = (book.progressRatio * 100).round();
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
                  '${book.author} · ${book.currentChapterTitle}',
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
                      style: TextStyle(fontSize: 11, color: tokens.inkMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onInfoTap,
            icon: InkIconWidget(InkIcon.more, size: 17, color: tokens.inkMuted),
          ),
        ],
      ),
    );
  }
}
