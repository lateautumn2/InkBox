import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/icons/ink_icons.dart';
import '../../core/theme/inkbox_theme.dart';
import '../../core/widgets/floating_surface.dart';
import '../../core/widgets/ink_controls.dart';
import '../../data/db/app_database.dart';
import '../../data/providers/app_providers.dart';

/// Opens a frosted FloatingCard bottom sheet to switch, create, rename, or delete
/// Bookshelves (`mediaKind == 'book'`) or Manga Shelves (`mediaKind == 'comic'`).
Future<int?> showShelfSwitcherSheet({
  required BuildContext context,
  required String mediaKind,
}) {
  return showModalBottomSheet<int>(
    context: context,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _ShelfSwitcherSheet(initialMediaKind: mediaKind),
  );
}

/// Opens a frosted FloatingCard sheet allowing management of both Book & Manga shelves
/// (used from MinePage).
Future<void> showDualShelfManagerSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _ShelfSwitcherSheet(
      initialMediaKind: 'book',
      allowKindToggle: true,
    ),
  );
}

/// Modal dialog to pick or create a target shelf when moving one or more books/mangas.
Future<int?> showMoveToShelfDialog({
  required BuildContext context,
  required AppDatabase db,
  required String mediaKind,
  required List<Shelf> shelves,
  required int currentShelfId,
  String? itemTitle,
}) async {
  final isComic = mediaKind == 'comic';
  final newShelfCtrl = TextEditingController();
  int selectedId = currentShelfId;

  final result = await showInkModal<({int shelfId, String newName})>(
    context: context,
    title: isComic ? '修改漫画架' : '修改书架',
    subtitle: itemTitle != null
        ? '将《$itemTitle》移至其他${isComic ? "漫画架" : "书架"}，或直接新建'
        : '选择目标${isComic ? "漫画架" : "书架"}，或直接输入名称新建并移入',
    disposables: [newShelfCtrl],
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModalState) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: shelves.map((s) {
                final active =
                    selectedId == s.id && newShelfCtrl.text.trim().isEmpty;
                return InkPillChip(
                  label: s.name,
                  leadingIcon: isComic ? InkIcon.manga : InkIcon.bookshelf,
                  selected: active,
                  onTap: () => setModalState(() {
                    selectedId = s.id;
                    newShelfCtrl.clear();
                  }),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            InkTextField(
              controller: newShelfCtrl,
              label: isComic ? '或新建漫画架并移入' : '或新建书架并移入',
              hintText: isComic
                  ? '例如：漫画架1（热血）、漫画架2（推理）'
                  : '例如：书架1（历史）、书架2（经济）',
              onChanged: (_) => setModalState(() {}),
            ),
          ],
        );
      },
    ),
    actionsBuilder: (ctx) => [
      TextButton(
        onPressed: () => Navigator.of(ctx).pop(),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: () => Navigator.of(ctx).pop((
          shelfId: selectedId,
          newName: newShelfCtrl.text.trim(),
        )),
        child: const Text('确定'),
      ),
    ],
  );

  if (result == null) return null;
  if (result.newName.isNotEmpty) {
    final created = await db.createShelf(result.newName, mediaKind);
    if (created != null) return created.id;
    final all = await db.getShelves(mediaKind);
    final match = all.where((s) => s.name == result.newName).firstOrNull;
    if (match != null) return match.id;
  }
  return result.shelfId;
}

class _ShelfSwitcherSheet extends ConsumerStatefulWidget {
  const _ShelfSwitcherSheet({
    required this.initialMediaKind,
    this.allowKindToggle = false,
  });

  final String initialMediaKind;
  final bool allowKindToggle;

  @override
  ConsumerState<_ShelfSwitcherSheet> createState() =>
      _ShelfSwitcherSheetState();
}

class _ShelfSwitcherSheetState extends ConsumerState<_ShelfSwitcherSheet> {
  late String _mediaKind;

  @override
  void initState() {
    super.initState();
    _mediaKind = widget.initialMediaKind;
  }

  Future<void> _promptCreateShelf() async {
    final isComic = _mediaKind == 'comic';
    final ctrl = TextEditingController();
    final name = await showInkModal<String>(
      context: context,
      title: isComic ? '新建漫画架' : '新建书架',
      subtitle: isComic
          ? '创建独立漫画架（每个漫画架均保留 所有 / 在读 / 已读完 分组）'
          : '创建独立书架（每个书架均保留 所有 / 在读 / 已读完 分组）',
      disposables: [ctrl],
      builder: (ctx) => InkTextField(
        controller: ctrl,
        autofocus: true,
        label: isComic ? '漫画架名称' : '书架名称',
        hintText: isComic
            ? '例如：漫画架1（热血）、漫画架2（完结）'
            : '例如：书架1（历史）、书架2（经济）',
        onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
      ),
      actionsBuilder: (ctx) => [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
          child: const Text('创建'),
        ),
      ],
    );
    if (name == null || name.isEmpty) return;
    final created =
        await ref.read(appDatabaseProvider).createShelf(name, _mediaKind);
    if (!mounted) return;
    if (created == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${isComic ? "漫画架" : "书架"}名称已存在'),
        ),
      );
      return;
    }
    if (isComic) {
      ref.read(activeMangaShelfIdProvider.notifier).state = created.id;
    } else {
      ref.read(activeBookShelfIdProvider.notifier).state = created.id;
    }
    if (!widget.allowKindToggle && mounted) {
      Navigator.of(context).pop(created.id);
    }
  }

  Future<void> _promptRenameShelf(Shelf shelf) async {
    final isComic = _mediaKind == 'comic';
    final ctrl = TextEditingController(text: shelf.name);
    final nextName = await showInkModal<String>(
      context: context,
      title: isComic ? '重命名漫画架' : '重命名书架',
      disposables: [ctrl],
      builder: (ctx) => InkTextField(
        controller: ctrl,
        autofocus: true,
        label: '新名称',
        onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
      ),
      actionsBuilder: (ctx) => [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
          child: const Text('保存'),
        ),
      ],
    );
    if (nextName == null || nextName.isEmpty) return;
    final ok = await ref
        .read(appDatabaseProvider)
        .renameShelf(shelf.id, nextName, _mediaKind);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('名称未变更或与已有书架重复')),
      );
    }
  }

  Future<void> _promptDeleteShelf(Shelf shelf, Shelf defaultShelf) async {
    final isComic = _mediaKind == 'comic';
    final ok = await showInkModal<bool>(
      context: context,
      title: '删除「${shelf.name}」',
      subtitle:
          '删除后该${isComic ? "漫画架" : "书架"}内的作品将自动归入「${defaultShelf.name}」，不会删除本地文件。',
      builder: (_) => const SizedBox.shrink(),
      actionsBuilder: (ctx) => [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: InkBoxTokens.of(ctx).accentWarm,
          ),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('确认删除'),
        ),
      ],
    );
    if (ok != true) return;
    await ref.read(appDatabaseProvider).deleteShelf(shelf.id, _mediaKind);
    if (!mounted) return;
    if (isComic && ref.read(activeMangaShelfIdProvider) == shelf.id) {
      ref.read(activeMangaShelfIdProvider.notifier).state = defaultShelf.id;
    } else if (!isComic && ref.read(activeBookShelfIdProvider) == shelf.id) {
      ref.read(activeBookShelfIdProvider.notifier).state = defaultShelf.id;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = InkBoxTokens.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final isComic = _mediaKind == 'comic';

    final shelves = (isComic
            ? ref.watch(mangaShelvesStreamProvider).valueOrNull
            : ref.watch(bookShelvesStreamProvider).valueOrNull) ??
        const <Shelf>[];
    final books = ref.watch(booksStreamProvider).valueOrNull ?? const <Book>[];
    final mangas =
        ref.watch(mangasStreamProvider).valueOrNull ?? const <Manga>[];

    final activeRawId = isComic
        ? ref.watch(activeMangaShelfIdProvider)
        : ref.watch(activeBookShelfIdProvider);
    final activeId = AppDatabase.resolveEffectiveShelfId(activeRawId, shelves);
    final defaultShelf = shelves.where((s) => s.isDefault).firstOrNull ??
        (shelves.isNotEmpty
            ? shelves.first
            : Shelf(
                id: 0,
                name: isComic ? kDefaultMangaShelfName : kDefaultBookShelfName,
                mediaKind: _mediaKind,
                isDefault: true,
                sortOrder: 0,
                createdAtMs: 0,
              ));

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          tokens.isFloatingCard ? 14 : 0,
          0,
          tokens.isFloatingCard ? 14 : 0,
          (tokens.isFloatingCard ? 14 : 0) + bottomInset,
        ),
        child: FloatingCard(
          frosted: true,
          radius: 26,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.74,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: tokens.inkMuted.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.allowKindToggle
                            ? '多书架与漫画架管理'
                            : (isComic ? '切换漫画架' : '切换书架'),
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: tokens.inkPrimary,
                                ),
                      ),
                    ),
                    InkPillChip(
                      label: isComic ? '新建漫画架' : '新建书架',
                      leadingIcon: InkIcon.plus,
                      selected: true,
                      onTap: _promptCreateShelf,
                    ),
                  ],
                ),
                if (widget.allowKindToggle) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      InkPillChip(
                        label: '书籍书架',
                        leadingIcon: InkIcon.bookshelf,
                        selected: !isComic,
                        onTap: () => setState(() => _mediaKind = 'book'),
                      ),
                      const SizedBox(width: 8),
                      InkPillChip(
                        label: '漫画架',
                        leadingIcon: InkIcon.manga,
                        selected: isComic,
                        onTap: () => setState(() => _mediaKind = 'comic'),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  isComic
                      ? '点击可切换当前漫画架；每个漫画架均保留「所有 / 在读 / 已读完」分组'
                      : '点击可切换当前书架；每个书架均保留「所有 / 在读 / 已读完」分组',
                  style: TextStyle(fontSize: 11.5, color: tokens.inkMuted),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: shelves.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, idx) {
                      final s = shelves[idx];
                      final selected = s.id == activeId;
                      final itemCount = isComic
                          ? mangas
                              .where((m) =>
                                  AppDatabase.resolveEffectiveShelfId(
                                      m.shelfId, shelves) ==
                                  s.id)
                              .length
                          : books
                              .where((b) =>
                                  AppDatabase.resolveEffectiveShelfId(
                                      b.shelfId, shelves) ==
                                  s.id)
                              .length;
                      return Material(
                        color: selected
                            ? tokens.accentSoft
                            : tokens.surfaceVariant.withValues(alpha: 0.58),
                        borderRadius: BorderRadius.circular(14),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () {
                            if (isComic) {
                              ref.read(activeMangaShelfIdProvider.notifier).state =
                                  s.id;
                            } else {
                              ref.read(activeBookShelfIdProvider.notifier).state =
                                  s.id;
                            }
                            if (!widget.allowKindToggle) {
                              Navigator.of(context).pop(s.id);
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 11,
                            ),
                            child: Row(
                              children: [
                                InkIconWidget(
                                  isComic ? InkIcon.manga : InkIcon.bookshelf,
                                  size: 18,
                                  color: selected
                                      ? tokens.accentPrimary
                                      : tokens.inkPrimary,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              s.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w700,
                                                color: selected
                                                    ? tokens.accentPrimary
                                                    : tokens.inkPrimary,
                                              ),
                                            ),
                                          ),
                                          if (s.isDefault) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 1.5,
                                              ),
                                              decoration: BoxDecoration(
                                                color: tokens.cardSurface
                                                    .withValues(alpha: 0.75),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                '主架',
                                                style: TextStyle(
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: tokens.inkMuted,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '$itemCount ${isComic ? "部漫画" : "本书籍"}${selected ? " · 当前使用中" : ""}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: tokens.inkMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  tooltip: '重命名',
                                  onPressed: () => _promptRenameShelf(s),
                                  icon: InkIconWidget(
                                    InkIcon.note,
                                    size: 16,
                                    color: tokens.inkMuted,
                                  ),
                                ),
                                if (!s.isDefault)
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    tooltip: '删除',
                                    onPressed: () =>
                                        _promptDeleteShelf(s, defaultShelf),
                                    icon: InkIconWidget(
                                      InkIcon.trash,
                                      size: 16,
                                      color: tokens.accentWarm,
                                    ),
                                  )
                                else if (selected)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        left: 4, right: 6),
                                    child: InkIconWidget(
                                      InkIcon.check,
                                      size: 16,
                                      color: tokens.accentPrimary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
