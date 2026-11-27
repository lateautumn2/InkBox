import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/icons/ink_icons.dart';
import '../../core/l10n/l10n_helpers.dart';
import '../../core/layout/responsive_layout.dart';
import '../../core/theme/inkbox_theme.dart';
import '../../core/widgets/floating_surface.dart';
import '../../core/widgets/ink_controls.dart';
import '../../data/db/app_database.dart';
import '../../data/providers/app_providers.dart';

Future<int?> showShelfSwitcherSheet({
  required BuildContext context,
  required String mediaKind,
}) {
  return showModalBottomSheet<int>(
    context: context,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _ShelfSwitcherSheet(mediaKind: mediaKind),
  );
}

Future<int?> showMoveToShelfDialog({
  required BuildContext context,
  required AppDatabase db,
  required String mediaKind,
  required List<Shelf> shelves,
  required int currentShelfId,
  String? itemTitle,
}) async {
  final isComic = mediaKind == 'comic';
  final l10n = context.l10n;
  final newShelfCtrl = TextEditingController();
  int selectedId = currentShelfId;

  final result = await showInkModal<({int shelfId, String newName})>(
    context: context,
    title: isComic ? l10n.moveToShelfTitleManga : l10n.moveToShelfTitleBook,
    subtitle: itemTitle,
    disposables: [newShelfCtrl],
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModalState) {
        final ctxL10n = ctx.l10n;
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
                  label: localizedShelfName(ctxL10n, s, isComic: isComic),
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
              label: isComic
                  ? ctxL10n.orCreateAndMoveManga
                  : ctxL10n.orCreateAndMoveBook,
              hintText:
                  isComic ? ctxL10n.shelfExampleManga : ctxL10n.shelfExampleBook,
              onChanged: (_) => setModalState(() {}),
            ),
          ],
        );
      },
    ),
    actionsBuilder: (ctx) => [
      TextButton(
        onPressed: () => Navigator.of(ctx).pop(),
        child: Text(ctx.l10n.cancel),
      ),
      FilledButton(
        onPressed: () => Navigator.of(ctx).pop((
          shelfId: selectedId,
          newName: newShelfCtrl.text.trim(),
        )),
        child: Text(ctx.l10n.confirm),
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
  const _ShelfSwitcherSheet({required this.mediaKind});

  final String mediaKind;

  @override
  ConsumerState<_ShelfSwitcherSheet> createState() =>
      _ShelfSwitcherSheetState();
}

class _ShelfSwitcherSheetState extends ConsumerState<_ShelfSwitcherSheet> {
  String get _mediaKind => widget.mediaKind;

  Future<T?> _editShelfName<T extends Object>({
    required String title,
    required String label,
    required String action,
    required String conflict,
    required Future<T?> Function(String name) submit,
    String initialName = '',
    String? hint,
  }) {
    final controller = TextEditingController(text: initialName);
    final error = ValueNotifier<String?>(null);
    var saving = false;
    Future<void> save(BuildContext context) async {
      final name = controller.text.trim();
      if (saving || name.isEmpty) return;
      saving = true;
      final route = ModalRoute.of(context);
      try {
        final saved = await submit(name);
        if (!context.mounted || route?.isCurrent != true) return;
        if (saved == null) {
          error.value = conflict;
          return;
        }
        Navigator.of(context).pop(saved);
      } catch (failure) {
        if (context.mounted && route?.isCurrent == true) {
          error.value = localizeError(context.l10n, failure);
        }
      } finally {
        saving = false;
      }
    }

    return showInkModal<T>(
      context: context,
      title: title,
      disposables: [controller, error],
      builder: (ctx) => ValueListenableBuilder(
        valueListenable: error,
        builder: (_, validation, _) => InkTextField(
          controller: controller,
          autofocus: true,
          label: label,
          hintText: hint,
          helperText: validation,
          onSubmitted: (_) => save(ctx),
          onChanged: (_) => error.value = null,
        ),
      ),
      actionsBuilder: (ctx) => [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(ctx.l10n.cancel),
        ),
        FilledButton(onPressed: () => save(ctx), child: Text(action)),
      ],
    );
  }

  Future<void> _promptCreateShelf() async {
    final isComic = _mediaKind == 'comic';
    final l10n = context.l10n;
    final db = ref.read(appDatabaseProvider);
    final created = await _editShelfName<Shelf>(
      title: isComic ? l10n.createMangaShelfTitle : l10n.createShelfTitle,
      label: l10n.shelfNameLabel,
      hint: isComic ? l10n.shelfExampleManga : l10n.shelfExampleBook,
      action: l10n.create,
      conflict: l10n.shelfNameExists,
      submit: (name) => db.createShelf(name, _mediaKind),
    );
    if (created == null || !mounted) return;
    if (isComic) {
      ref.read(activeMangaShelfIdProvider.notifier).state = created.id;
    } else {
      ref.read(activeBookShelfIdProvider.notifier).state = created.id;
    }
    Navigator.of(context).pop(created.id);
  }

  Future<void> _promptRenameShelf(Shelf shelf) async {
    final isComic = _mediaKind == 'comic';
    final l10n = context.l10n;
    final db = ref.read(appDatabaseProvider);
    final displayedName = localizedShelfName(l10n, shelf, isComic: isComic);
    await _editShelfName<bool>(
      title: isComic ? l10n.renameMangaShelfTitle : l10n.renameShelfTitle,
      label: l10n.newNameLabel,
      initialName: displayedName,
      action: l10n.save,
      conflict: l10n.shelfRenameConflict,
      submit: (name) async {
        if (name == displayedName || name == shelf.name) return true;
        return await db.renameShelf(shelf.id, name, _mediaKind) ? true : null;
      },
    );
  }

  Future<void> _promptDeleteShelf(Shelf shelf, Shelf defaultShelf) async {
    final isComic = _mediaKind == 'comic';
    final l10n = context.l10n;
    final shelfDisplay = localizedShelfName(l10n, shelf, isComic: isComic);
    final fallbackDisplay =
        localizedShelfName(l10n, defaultShelf, isComic: isComic);
    final ok = await showInkModal<bool>(
      context: context,
      title: l10n.deleteShelfTitle(shelfDisplay),
      subtitle: l10n.deleteShelfConfirm(fallbackDisplay),
      builder: (_) => const SizedBox.shrink(),
      actionsBuilder: (ctx) => [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(ctx.l10n.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: InkBoxTokens.of(ctx).accentWarm,
          ),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(ctx.l10n.confirmDelete),
        ),
      ],
    );
    if (ok != true || !mounted) return;
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
    final l10n = context.l10n;
    final isComic = _mediaKind == 'comic';
    final wide = isWideLayout(context);
    final systemBottom = MediaQuery.paddingOf(context).bottom;

    final shelves = (isComic
            ? ref.watch(mangaShelvesStreamProvider).valueOrNull
            : ref.watch(bookShelvesStreamProvider).valueOrNull) ??
        const <Shelf>[];
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
      bottom: false,
      child: Center(
        heightFactor: 1.0,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: wide ? kMaxModalWidth : double.infinity,
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              tokens.isFloatingCard ? 14 : 0,
              0,
              tokens.isFloatingCard ? 14 : 0,
              tokens.isFloatingCard ? systemBottom + 14 : 0,
            ),
            child: FloatingCard(
              frosted: tokens.isFloatingCard,
              radius: 22,
              borderRadius: tokens.isFloatingCard
                  ? null
                  : const BorderRadius.vertical(top: Radius.circular(22)),
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                16 + (tokens.isFloatingCard ? 0 : systemBottom),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.72,
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
                            isComic
                                ? l10n.switchMangaShelfTitle
                                : l10n.switchBookshelfTitle,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: tokens.inkPrimary,
                                ),
                          ),
                        ),
                        InkPillChip(
                          label: isComic
                              ? l10n.createMangaShelfTitle
                              : l10n.createShelfTitle,
                          leadingIcon: InkIcon.plus,
                          selected: true,
                          onTap: _promptCreateShelf,
                        ),
                      ],
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
                          return Material(
                            color: selected
                                ? tokens.accentSoft
                                : tokens.surfaceVariant.withValues(alpha: 0.58),
                            borderRadius: BorderRadius.circular(14),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () {
                                if (isComic) {
                                  ref
                                      .read(activeMangaShelfIdProvider.notifier)
                                      .state = s.id;
                                } else {
                                  ref
                                      .read(activeBookShelfIdProvider.notifier)
                                      .state = s.id;
                                }
                                Navigator.of(context).pop(s.id);
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 11,
                                ),
                                child: Row(
                                  children: [
                                    InkIconWidget(
                                      isComic
                                          ? InkIcon.manga
                                          : InkIcon.bookshelf,
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
                                                  localizedShelfName(
                                                    l10n,
                                                    s,
                                                    isComic: isComic,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
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
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 6,
                                                    vertical: 1.5,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: tokens.cardSurface
                                                        .withValues(
                                                            alpha: 0.75),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            6),
                                                  ),
                                                  child: Text(
                                                    l10n.defaultShelfBadge,
                                                    style: TextStyle(
                                                      fontSize: 9.5,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: tokens.inkMuted,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          if (selected) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              l10n.inUseLabel,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: tokens.inkMuted,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      tooltip: l10n.rename,
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
                                        tooltip: l10n.delete,
                                        onPressed: () => _promptDeleteShelf(
                                          s,
                                          defaultShelf,
                                        ),
                                        icon: InkIconWidget(
                                          InkIcon.trash,
                                          size: 16,
                                          color: tokens.accentWarm,
                                        ),
                                      )
                                    else if (selected)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          left: 4,
                                          right: 6,
                                        ),
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
        ),
      ),
    );
  }
}
