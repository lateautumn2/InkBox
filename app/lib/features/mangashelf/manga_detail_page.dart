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
import '../manga_reader/manga_reader_settings.dart';

class MangaDetailPage extends ConsumerStatefulWidget {
  const MangaDetailPage({super.key, required this.mangaId});

  final int mangaId;

  @override
  ConsumerState<MangaDetailPage> createState() => _MangaDetailPageState();
}

class _MangaDetailPageState extends ConsumerState<MangaDetailPage> {
  bool _descending = false;
  bool _unreadOnly = false;

  Future<void> _showChangeShelfDialog(
    BuildContext context,
    AppDatabase db,
    Manga manga,
    List<Shelf> shelves,
  ) async {
    final currentId =
        AppDatabase.resolveEffectiveShelfId(manga.shelfId, shelves);
    final targetId = await showMoveToShelfDialog(
      context: context,
      db: db,
      mediaKind: 'comic',
      shelves: shelves,
      currentShelfId: currentId,
      itemTitle: manga.title,
    );
    if (targetId == null) return;
    await db.updateMangaMeta(manga.id, shelfId: targetId);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = InkBoxTokens.of(context);
    final l10n = context.l10n;
    final mangasAsync = ref.watch(mangaHistoryStreamProvider);
    final shelves =
        ref.watch(mangaShelvesStreamProvider).valueOrNull ?? const <Shelf>[];
    final db = ref.watch(appDatabaseProvider);

    return Scaffold(
      backgroundColor: tokens.canvasBg,
      body: mangasAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (mangas) {
          final manga =
              mangas.where((m) => m.id == widget.mangaId).firstOrNull;
          if (manga == null) {
            return Center(child: Text(l10n.notFoundManga));
          }

          final chaptersAsync =
              ref.watch(mangaChaptersStreamProvider(manga.id));
          final hasCover =
              manga.coverPath != null && File(manga.coverPath!).existsSync();
          final matchedShelf = shelves
              .where((s) =>
                  s.id ==
                  AppDatabase.resolveEffectiveShelfId(manga.shelfId, shelves))
              .firstOrNull;
          final shelfLabel =
              localizedShelfName(l10n, matchedShelf, isComic: true);

          return chaptersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (rawChapters) {
              var chapters =
                  rawChapters.where((c) => !_unreadOnly || !c.isRead).toList();
              if (_descending) chapters = chapters.reversed.toList();
              final resumeChapter =
                  rawChapters.where((c) => !c.isRead).firstOrNull ??
                      rawChapters.firstOrNull;

              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Container(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        MediaQuery.of(context).padding.top + 10,
                        16,
                        22,
                      ),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF181D26), Color(0xFF2D3849)],
                        ),
                      ),
                      child: ResponsiveConstrainedBody(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                InkCircleButton(
                                  icon: const InkIconWidget(
                                    InkIcon.back,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                                  onPressed: () => context.pop(),
                                ),
                                GestureDetector(
                                  onTap: () async {
                                    final action =
                                        await showInkOptionSheet<String>(
                                      context: context,
                                      title: manga.title,
                                      options: [
                                        InkOptionItem(
                                          value: 'shelf',
                                          label: l10n.moveMangaShelfMenu,
                                          icon: InkIcon.manga,
                                        ),
                                        InkOptionItem(
                                          value: 'read_all',
                                          label: l10n.markAllReadMenu,
                                          icon: InkIcon.check,
                                        ),
                                        InkOptionItem(
                                          value: 'unread_all',
                                          label: l10n.resetUnreadMenu,
                                          icon: InkIcon.refresh,
                                        ),
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
                                    if (action == 'shelf' && context.mounted) {
                                      await _showChangeShelfDialog(
                                        context,
                                        db,
                                        manga,
                                        shelves,
                                      );
                                    } else if (action == 'read_all') {
                                      await db.updateMangaMeta(
                                        manga.id,
                                        shelfGroup: '已读完',
                                      );
                                      await db.markAllChaptersRead(
                                          manga.id, true);
                                    } else if (action == 'unread_all') {
                                      await db.updateMangaMeta(
                                        manga.id,
                                        shelfGroup: '在读',
                                      );
                                      await db.markAllChaptersRead(
                                          manga.id, false);
                                    } else if (action == 'archive') {
                                      await db.archiveMangasByIds([manga.id]);
                                      if (context.mounted) context.pop();
                                    } else if (action == 'permanent') {
                                      await ref
                                          .read(importServiceProvider)
                                          .permanentlyDeleteMangas([manga.id]);
                                      if (context.mounted) context.pop();
                                    }
                                  },
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: const BoxDecoration(
                                      color: Colors.black26,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Center(
                                      child: InkIconWidget(
                                        InkIcon.more,
                                        size: 18,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: SizedBox(
                                    width: 90,
                                    height: 124,
                                    child: hasCover
                                        ? Image.file(
                                            File(manga.coverPath!),
                                            fit: BoxFit.cover,
                                          )
                                        : Container(
                                            color: Colors.black38,
                                            padding: const EdgeInsets.all(10),
                                            child: Align(
                                              alignment: Alignment.bottomLeft,
                                              child: Text(
                                                manga.title,
                                                maxLines: 3,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        manga.title,
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${localizedAuthor(l10n, manga.author)} · $shelfLabel · ${manga.format}',
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.all(14),
                    sliver: SliverToBoxAdapter(
                      child: ResponsiveConstrainedBody(
                        child: Column(
                          children: [
                            FloatingCard(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton.icon(
                                      style: FilledButton.styleFrom(
                                        backgroundColor: tokens.accentPrimary,
                                        shape: const StadiumBorder(),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                      ),
                                      onPressed: () {
                                        final chParam = resumeChapter != null
                                            ? '?chapterId=${resumeChapter.id}'
                                            : '';
                                        context.push(
                                          '/reader/manga/${manga.id}$chParam',
                                        );
                                      },
                                      icon: InkIconWidget(
                                        InkIcon.play,
                                        size: 16,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onPrimary,
                                      ),
                                      label: Text(
                                        resumeChapter != null
                                            ? '${l10n.continueReading} · ${resumeChapter.title}'
                                            : l10n.startReading,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    l10n.mangaDefaultModeLabel,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: tokens.inkMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: MangaReadingMode.values.map((m) {
                                      final active =
                                          manga.preferredReadingMode == m.code;
                                      return InkPillChip(
                                        label: m.labelOf(l10n),
                                        selected: active,
                                        onTap: () => db.updateMangaMeta(
                                          manga.id,
                                          preferredReadingMode: m.code,
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        l10n.smartCropLabel,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          color: tokens.inkPrimary,
                                        ),
                                      ),
                                      InkSwitch(
                                        value: manga.autoCrop,
                                        onChanged: (v) => db.updateMangaMeta(
                                          manga.id,
                                          autoCrop: v,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        l10n.splitWidePagesLabel,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          color: tokens.inkPrimary,
                                        ),
                                      ),
                                      InkSwitch(
                                        value: manga.splitWidePages,
                                        onChanged: (v) => db.updateMangaMeta(
                                          manga.id,
                                          splitWidePages: v,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            FloatingCard(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          l10n.chaptersVolumeList(
                                              chapters.length),
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w700,
                                            color: tokens.inkPrimary,
                                          ),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () => setState(
                                          () => _unreadOnly = !_unreadOnly,
                                        ),
                                        child: Text(
                                          _unreadOnly
                                              ? l10n.unreadOnlyActive
                                              : l10n.unreadOnly,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: tokens.accentPrimary,
                                          ),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () => setState(
                                          () => _descending = !_descending,
                                        ),
                                        child: Text(
                                          _descending
                                              ? l10n.descendingOrder
                                              : l10n.ascendingOrder,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: tokens.accentPrimary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  if (chapters.isEmpty)
                                    Text(
                                      l10n.noChaptersMatchHint,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: tokens.inkMuted,
                                      ),
                                    )
                                  else
                                    ...chapters.map((ch) {
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 8),
                                        child: InkWell(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          onTap: () => context.push(
                                            '/reader/manga/${manga.id}?chapterId=${ch.id}',
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 11,
                                            ),
                                            decoration: BoxDecoration(
                                              color: ch.isRead
                                                  ? tokens.surfaceVariant
                                                  : tokens.accentSoft,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    ch.title,
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: tokens.inkPrimary,
                                                    ),
                                                  ),
                                                ),
                                                Text(
                                                  ch.isRead
                                                      ? l10n.readLabel
                                                      : l10n.pageOfTotalUnknown(
                                                          ch.lastReadPage + 1,
                                                          ch.pageCount > 0
                                                              ? '${ch.pageCount}'
                                                              : '?',
                                                        ),
                                                  style: TextStyle(
                                                    fontSize: 11.5,
                                                    color: ch.isRead
                                                        ? tokens.inkMuted
                                                        : tokens.accentPrimary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    }),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
