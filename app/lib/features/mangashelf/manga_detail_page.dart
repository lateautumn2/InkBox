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

class MangaDetailPage extends ConsumerStatefulWidget {
  const MangaDetailPage({super.key, required this.mangaId});

  final int mangaId;

  @override
  ConsumerState<MangaDetailPage> createState() => _MangaDetailPageState();
}

class _MangaDetailPageState extends ConsumerState<MangaDetailPage> {
  bool _descending = false;
  bool _unreadOnly = false;

  static const _modeLabels = {
    'rtl': '从右到左 (日漫)',
    'ltr': '从左到右 (美漫)',
    'webtoon': '条漫无缝滚动',
    'dual': '双页拼接',
  };

  Future<void> _showChangeShelfDialog(
    BuildContext context,
    AppDatabase db,
    Manga manga,
    List<Shelf> shelves,
  ) async {
    final currentId = AppDatabase.resolveEffectiveShelfId(manga.shelfId, shelves);
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
    final mangasAsync = ref.watch(mangaHistoryStreamProvider);
    final shelves =
        ref.watch(mangaShelvesStreamProvider).valueOrNull ?? const <Shelf>[];
    final db = ref.watch(appDatabaseProvider);

    return Scaffold(
      backgroundColor: tokens.canvasBg,
      body: mangasAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
        data: (mangas) {
          final manga =
              mangas.where((m) => m.id == widget.mangaId).firstOrNull;
          if (manga == null) {
            return const Center(child: Text('未找到漫画信息'));
          }

          final chaptersAsync =
              ref.watch(mangaChaptersStreamProvider(manga.id));
          final hasCover =
              manga.coverPath != null && File(manga.coverPath!).existsSync();

          return chaptersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('章节加载失败: $e')),
            data: (rawChapters) {
              var chapters = rawChapters.where((c) => !_unreadOnly || !c.isRead).toList();
              if (_descending) chapters = chapters.reversed.toList();
              final resumeChapter = rawChapters.where((c) => !c.isRead).firstOrNull ??
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
                          colors: [Color(0xFF1F242D), Color(0xFF3A4454)],
                        ),
                      ),
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
                                      options: const [
                                        InkOptionItem(
                                          value: 'shelf',
                                          label: '修改所属漫画架',
                                          icon: InkIcon.manga,
                                        ),
                                        InkOptionItem(
                                          value: 'read_all',
                                          label: '全部标记已读',
                                          icon: InkIcon.check,
                                        ),
                                        InkOptionItem(
                                          value: 'unread_all',
                                          label: '全部重置未读',
                                          icon: InkIcon.refresh,
                                        ),
                                        InkOptionItem(
                                          value: 'archive',
                                          label: '移出漫画架（保留导入历史）',
                                          icon: InkIcon.history,
                                        ),
                                        InkOptionItem(
                                          value: 'permanent',
                                          label: '彻底删除',
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
                                borderRadius: BorderRadius.circular(14),
                                child: SizedBox(
                                  width: 92,
                                  height: 128,
                                  child: hasCover
                                      ? Image.file(
                                          File(manga.coverPath!),
                                          fit: BoxFit.cover,
                                        )
                                      : Container(
                                          color: Colors.black38,
                                          padding: const EdgeInsets.all(10),
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Align(
                                                alignment: Alignment.topRight,
                                                child: Text(
                                                  manga.format,
                                                  style: const TextStyle(
                                                    fontSize: 9,
                                                    color: Colors.white70,
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                manga.title,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                      '${manga.author} · ${shelves.where((s) => s.id == AppDatabase.resolveEffectiveShelfId(manga.shelfId, shelves)).firstOrNull?.name ?? kDefaultMangaShelfName}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.white70,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: [
                                        _DarkChip(
                                          _modeLabels[
                                                  manga.preferredReadingMode] ??
                                              '从右到左',
                                        ),
                                        if (manga.autoCrop)
                                          const _DarkChip('智能裁边'),
                                        if (manga.splitWidePages)
                                          const _DarkChip('跨页切分'),
                                      ],
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
                  SliverPadding(
                    padding: const EdgeInsets.all(14),
                    sliver: SliverList.list(
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
                                    color:
                                        Theme.of(context).colorScheme.onPrimary,
                                  ),
                                  label: Text(
                                    resumeChapter != null
                                        ? '继续阅读 · ${resumeChapter.title}'
                                        : '开始阅读',
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '单作默认阅读模式',
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
                                children: _modeLabels.entries.map((e) {
                                  final active =
                                      manga.preferredReadingMode == e.key;
                                  return GestureDetector(
                                    onTap: () => db.updateMangaMeta(
                                      manga.id,
                                      preferredReadingMode: e.key,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: active
                                            ? tokens.accentPrimary
                                            : tokens.surfaceVariant,
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        e.value,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: active
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .onPrimary
                                              : tokens.inkPrimary,
                                        ),
                                      ),
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
                                    '智能白边裁切',
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
                                    '自动切分跨页宽图',
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
                                      '分卷 / 话列表 (${chapters.length})',
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
                                      _unreadOnly ? '仅未读 ✓' : '仅未读',
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
                                      _descending ? '倒序' : '正序',
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
                                  '当前筛选下无章节，点击上方按钮直接阅读。',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: tokens.inkMuted,
                                  ),
                                )
                              else
                                ...chapters.map((ch) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(12),
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
                                                  fontWeight: FontWeight.w600,
                                                  color: tokens.inkPrimary,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              ch.isRead
                                                  ? '已读'
                                                  : '第 ${ch.lastReadPage + 1}/${ch.pageCount > 0 ? ch.pageCount : "?"} 页',
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
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _DarkChip extends StatelessWidget {
  const _DarkChip(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 10.5, color: Colors.white),
      ),
    );
  }
}
