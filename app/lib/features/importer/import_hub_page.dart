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
import 'import_service.dart';

class ImportHubPage extends ConsumerStatefulWidget {
  const ImportHubPage({super.key});

  @override
  ConsumerState<ImportHubPage> createState() => _ImportHubPageState();
}

class _ImportHubPageState extends ConsumerState<ImportHubPage> {
  bool _autoClassify = true;
  bool _overwriteExisting = false;
  bool _busy = false;
  String _selectedFormat = '全部';
  String _historyFilter = '全部'; // '全部' | '已移出' | '在书架'
  List<ImportCandidate> _candidates = [];
  ImportBatchResult? _lastResult;

  static const _formats = ['全部', 'EPUB', 'TXT', 'PDF', 'MOBI', '漫画包'];

  Future<void> _pickLocalFiles() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final res = await ref.read(importServiceProvider).pickAndImportDocuments(
            autoClassify: _autoClassify,
            overwriteExisting: _overwriteExisting,
            targetBookShelfId: ref.read(activeBookShelfIdProvider),
            targetMangaShelfId: ref.read(activeMangaShelfIdProvider),
          );
      if (!mounted) return;
      if (!res.isEmpty) {
        setState(() => _lastResult = res);
        _showResultSnack(res);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addAndScanDirectory() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final svc = ref.read(importServiceProvider);
      await svc.addWatchedDirectory();
      final scanned = await svc.scanWatchedFolders();
      if (!mounted) return;
      setState(() => _candidates = scanned);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('目录扫描完成：发现 ${scanned.length} 个可导入文件')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rescanWatched() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final scanned =
          await ref.read(importServiceProvider).scanWatchedFolders();
      if (!mounted) return;
      setState(() => _candidates = scanned);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('扫描完成：发现 ${scanned.length} 个文件')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importSelected() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final res =
          await ref.read(importServiceProvider).importSelectedCandidates(
                _candidates,
                autoClassify: _autoClassify,
                overwriteExisting: _overwriteExisting,
                targetBookShelfId: ref.read(activeBookShelfIdProvider),
                targetMangaShelfId: ref.read(activeMangaShelfIdProvider),
              );
      if (!mounted) return;
      setState(() {
        _candidates = _candidates.where((c) => !c.selected).toList();
        _lastResult = res;
      });
      _showResultSnack(res);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forceReimportDuplicate(ImportFileOutcome dup) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final outcome =
          await ref.read(importServiceProvider).importLocalPathDetailed(
                dup.localPath,
                forceKind: dup.kind,
                overwriteExisting: true,
              );
      if (!mounted) return;
      setState(() {
        if (_lastResult != null) {
          _lastResult = ImportBatchResult(
            booksImported:
                _lastResult!.booksImported + (outcome.status == 'book' ? 1 : 0),
            mangasImported: _lastResult!.mangasImported +
                (outcome.status == 'manga' ? 1 : 0),
            skippedDuplicates:
                (_lastResult!.skippedDuplicates - 1).clamp(0, 9999),
            errors: _lastResult!.errors,
            importedItems: [..._lastResult!.importedItems, outcome],
            duplicateItems: _lastResult!.duplicateItems
                .where((d) => d.localPath != dup.localPath || d.id != dup.id)
                .toList(),
          );
        }
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('已覆盖更新《${outcome.title}》'),
            action: outcome.id != null
                ? SnackBarAction(
                    label: '立即阅读',
                    onPressed: () => _openOutcome(outcome),
                  )
                : null,
          ),
        );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('覆盖导入失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmPermanentDelete({
    required String title,
    required bool isComic,
    required int id,
  }) async {
    final confirmed = await showInkModal<bool>(
      context: context,
      title: '彻底删除确认',
      subtitle: '确定要彻底删除《$title》吗？将同时清除导入历史、阅读进度、书签笔记及应用内缓存文件，无法恢复。',
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
          child: const Text('彻底删除'),
        ),
      ],
    );
    if (confirmed != true) return;
    final svc = ref.read(importServiceProvider);
    if (isComic) {
      await svc.permanentlyDeleteMangas([id]);
    } else {
      await svc.permanentlyDeleteBooks([id]);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('已彻底删除《$title》')));
  }

  void _openOutcome(ImportFileOutcome item) {
    if (item.id == null) {
      context.go(item.kind == 'comic' ? '/manga' : '/bookshelf');
      return;
    }
    if (item.kind == 'comic') {
      context.push('/manga/${item.id}');
    } else {
      context.push('/reader/book/${item.id}');
    }
  }

  void _showResultSnack(ImportBatchResult res) {
    final msg = '导入完成：书籍 +${res.booksImported}，漫画 +${res.mangasImported}'
        '${res.skippedDuplicates > 0 ? "，已有 ${res.skippedDuplicates} 本" : ""}'
        '${res.errors.isNotEmpty ? "，失败 ${res.errors.length}" : ""}';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          duration: const Duration(seconds: 4),
          action: (res.booksImported > 0 || res.mangasImported > 0)
              ? SnackBarAction(
                  label: res.booksImported > 0 ? '查看书架' : '查看漫画',
                  onPressed: () => context.go(
                    res.booksImported > 0 ? '/bookshelf' : '/manga',
                  ),
                )
              : null,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = InkBoxTokens.of(context);
    final health = ref.watch(coreHealthProvider);
    final foldersAsync = ref.watch(watchedFoldersStreamProvider);
    final bookHistory =
        ref.watch(bookHistoryStreamProvider).valueOrNull ?? const <Book>[];
    final mangaHistory =
        ref.watch(mangaHistoryStreamProvider).valueOrNull ?? const <Manga>[];
    final bottomPad = tokens.isFloatingCard ? 168.0 : 88.0;

    final visibleCandidates = _candidates.where((c) {
      if (_selectedFormat == '全部') return true;
      if (_selectedFormat == '漫画包') return c.targetKind == 'comic';
      return c.ext == _selectedFormat;
    }).toList();

    final selectedCount = _candidates.where((c) => c.selected).length;

    final historyEntries = <_HistoryEntry>[
      ...bookHistory.map(
        (b) => _HistoryEntry(
          id: b.id,
          title: b.title,
          format: b.format,
          isComic: false,
          isArchived: b.isArchived,
          addedAtMs: b.addedAtMs,
          localPath: b.filePath,
          fileExists: File(b.filePath).existsSync(),
          subtitle:
              '${b.author} · 已读 ${(b.progressRatio * 100).round()}%',
        ),
      ),
      ...mangaHistory.map(
        (m) => _HistoryEntry(
          id: m.id,
          title: m.title,
          format: m.format,
          isComic: true,
          isArchived: m.isArchived,
          addedAtMs: m.addedAtMs,
          localPath: m.rootPath,
          fileExists:
              FileSystemEntity.typeSync(m.rootPath) != FileSystemEntityType.notFound,
          subtitle: '${m.author} · 共 ${m.totalChapters} 话',
        ),
      ),
    ]..sort((a, b) => b.addedAtMs.compareTo(a.addedAtMs));

    final filteredHistory = historyEntries.where((h) {
      if (_historyFilter == '已移出') return h.isArchived;
      if (_historyFilter == '在书架') return !h.isArchived;
      return true;
    }).toList();

    return SafeArea(
      bottom: false,
      child: Stack(
        children: [
          Column(
            children: [
              FloatingHeaderBar(
                title: '导入中心',
                actions: [
                  InkCircleButton(
                    icon: InkIconWidget(
                      InkIcon.refresh,
                      size: 17,
                      color: tokens.inkPrimary,
                    ),
                    tooltip: '重新扫描监听目录',
                    onPressed: _rescanWatched,
                  ),
                ],
              ),
              if (_busy)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: LinearProgressIndicator(
                    minHeight: 2.5,
                    color: tokens.accentPrimary,
                  ),
                ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(14, 6, 14, bottomPad),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: FloatingCard(
                            onTap: _pickLocalFiles,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                InkIconWidget(
                                  InkIcon.file,
                                  size: 24,
                                  color: tokens.inkPrimary,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  '选择本地文件',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: tokens.inkPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '多选书漫批量入库',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: tokens.inkMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FloatingCard(
                            backgroundColor: tokens.accentSoft,
                            borderColor: Colors.transparent,
                            onTap: _addAndScanDirectory,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                InkIconWidget(
                                  InkIcon.folder,
                                  size: 24,
                                  color: tokens.accentPrimary,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  '添加并扫描目录',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: tokens.accentPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '持久化监听新增书漫',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: tokens.accentPrimary
                                        .withValues(alpha: 0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    FloatingCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              InkIconWidget(
                                InkIcon.spark,
                                size: 20,
                                color: tokens.accentPrimary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '智能分拣入架',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: tokens.inkPrimary,
                                      ),
                                    ),
                                    Text(
                                      '自动区分书籍书架与漫画架',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: tokens.inkMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              InkSwitch(
                                value: _autoClassify,
                                onChanged: (v) =>
                                    setState(() => _autoClassify = v),
                              ),
                            ],
                          ),
                          Divider(height: 18, color: tokens.subtleBorder),
                          Row(
                            children: [
                              InkIconWidget(
                                InkIcon.refresh,
                                size: 18,
                                color: tokens.inkMuted,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '重复文件覆盖更新',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: tokens.inkPrimary,
                                      ),
                                    ),
                                    Text(
                                      '遇到相同文件时直接更新路径与元信息',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: tokens.inkMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              InkSwitch(
                                value: _overwriteExisting,
                                onChanged: (v) =>
                                    setState(() => _overwriteExisting = v),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Concise supported file types card (engine/feature details moved to README)
                    FloatingCard(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '支持类型',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: tokens.inkPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '书籍：${health.supportedBookFormats.map((e) => e.toUpperCase()).join(' · ')}\n'
                            '漫画：${health.supportedComicFormats.map((e) => e == 'folder' ? '图片文件夹' : e.toUpperCase()).join(' · ')}',
                            style: TextStyle(
                              fontSize: 11.5,
                              height: 1.65,
                              color: tokens.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_lastResult != null && !_lastResult!.isEmpty) ...[
                      const SizedBox(height: 12),
                      _buildLastResultCard(tokens, _lastResult!),
                    ],
                    foldersAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, _) => const SizedBox.shrink(),
                      data: (folders) {
                        if (folders.isEmpty) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: folders.map((f) {
                              return InkPillChip(
                                label: f.displayName,
                                leadingIcon: InkIcon.folder,
                                onDelete: () => ref
                                    .read(appDatabaseProvider)
                                    .deleteWatchedFolder(f.id),
                              );
                            }).toList(),
                          ),
                        );
                      },
                    ),
                    if (_candidates.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 36,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _formats.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (context, idx) {
                            final fmt = _formats[idx];
                            final active = _selectedFormat == fmt;
                            return InkPillChip(
                              label: fmt,
                              selected: active,
                              elevated: true,
                              onTap: () =>
                                  setState(() => _selectedFormat = fmt),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...visibleCandidates.map((c) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: FloatingCard(
                            onTap: () =>
                                setState(() => c.selected = !c.selected),
                            borderColor:
                                c.selected ? tokens.accentPrimary : null,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: c.selected
                                        ? tokens.accentPrimary
                                        : tokens.surfaceVariant,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: c.selected
                                      ? const Center(
                                          child: InkIconWidget(
                                            InkIcon.check,
                                            size: 13,
                                            color: Colors.white,
                                          ),
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: tokens.surfaceVariant,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    c.ext,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: tokens.inkPrimary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        c.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: tokens.inkPrimary,
                                        ),
                                      ),
                                      Text(
                                        '${c.formattedSize} · 归类为${c.targetKind == "comic" ? "漫画架" : "书架"}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: tokens.inkMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => setState(() {
                                    c.targetKind = c.targetKind == 'comic'
                                        ? 'book'
                                        : 'comic';
                                  }),
                                  child: Text(
                                    c.targetKind == 'comic' ? '改书架' : '改漫画',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: tokens.accentPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                    const SizedBox(height: 16),
                    // Import History Section (supports quick restore to shelf & permanent deletion)
                    Row(
                      children: [
                        InkIconWidget(
                          InkIcon.history,
                          size: 16,
                          color: tokens.inkPrimary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '导入历史 (${historyEntries.length})',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: tokens.inkPrimary,
                          ),
                        ),
                        const Spacer(),
                        ...const ['全部', '已移出', '在书架'].map((f) {
                          return Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: GestureDetector(
                              onTap: () => setState(() => _historyFilter = f),
                              child: Text(
                                f,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: _historyFilter == f
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: _historyFilter == f
                                      ? tokens.accentPrimary
                                      : tokens.inkMuted,
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (filteredHistory.isEmpty)
                      FloatingCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 20,
                        ),
                        child: Center(
                          child: Text(
                            historyEntries.isEmpty
                                ? '暂无导入历史，导入后的书籍与移出书架的记录都会保存在这里'
                                : '当前筛选下无历史记录',
                            style:
                                TextStyle(fontSize: 12, color: tokens.inkMuted),
                          ),
                        ),
                      )
                    else
                      ...filteredHistory.map((item) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: FloatingCard(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: item.isArchived
                                        ? tokens.surfaceVariant
                                        : tokens.accentSoft,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    item.format,
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      color: item.isArchived
                                          ? tokens.inkMuted
                                          : tokens.accentPrimary,
                                    ),
                                  ),
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
                                              item.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: tokens.inkPrimary,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            !item.fileExists
                                                ? '文件缺失'
                                                : (item.isArchived
                                                    ? '已移出'
                                                    : '在架'),
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: (!item.fileExists ||
                                                      item.isArchived)
                                                  ? tokens.accentWarm
                                                  : tokens.statusOk,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        item.subtitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: tokens.inkMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (item.isArchived)
                                  TextButton(
                                    style: TextButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    onPressed: () async {
                                      if (!item.fileExists) {
                                        ScaffoldMessenger.of(context)
                                          ..hideCurrentSnackBar()
                                          ..showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                '《${item.title}》的本地文件已不存在，请重新选择文件导入',
                                              ),
                                            ),
                                          );
                                        return;
                                      }
                                      final db = ref.read(appDatabaseProvider);
                                      if (item.isComic) {
                                        await db.restoreMangaToShelf(item.id);
                                      } else {
                                        await db.restoreBookToShelf(item.id);
                                      }
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context)
                                        ..hideCurrentSnackBar()
                                        ..showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              '已将《${item.title}》重新加入${item.isComic ? "漫画架" : "书架"}',
                                            ),
                                          ),
                                        );
                                    },
                                    child: Text(
                                      '入架',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: tokens.accentPrimary,
                                      ),
                                    ),
                                  )
                                else
                                  TextButton(
                                    style: TextButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    onPressed: () => context.push(
                                      item.isComic
                                          ? '/manga/${item.id}'
                                          : '/reader/book/${item.id}',
                                    ),
                                    child: Text(
                                      '阅读',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: tokens.accentPrimary,
                                      ),
                                    ),
                                  ),
                                IconButton(
                                  tooltip: '彻底删除',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => _confirmPermanentDelete(
                                    title: item.title,
                                    isComic: item.isComic,
                                    id: item.id,
                                  ),
                                  icon: InkIconWidget(
                                    InkIcon.trash,
                                    size: 16,
                                    color: tokens.accentWarm,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ],
          ),
          if (selectedCount > 0)
            Positioned(
              left: 14,
              right: 14,
              bottom: tokens.isFloatingCard ? 92 : 14,
              child: FloatingCard(
                frosted: true,
                radius: 22,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '已选 $selectedCount 项待入库',
                      style: TextStyle(fontSize: 12.5, color: tokens.inkMuted),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: tokens.accentPrimary,
                        shape: const StadiumBorder(),
                      ),
                      onPressed: _busy ? null : _importSelected,
                      child: Text('导入至架 ($selectedCount)'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLastResultCard(InkBoxTokens tokens, ImportBatchResult res) {
    return FloatingCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkIconWidget(
                res.errors.isNotEmpty ? InkIcon.spark : InkIcon.check,
                size: 16,
                color: res.errors.isNotEmpty
                    ? tokens.accentWarm
                    : tokens.statusOk,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '本次导入结果',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: tokens.inkPrimary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _lastResult = null),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                child: Text(
                  '收起',
                  style: TextStyle(fontSize: 11.5, color: tokens.inkMuted),
                ),
              ),
            ],
          ),
          if (res.importedItems.isNotEmpty) ...[
            const SizedBox(height: 6),
            ...res.importedItems.map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${item.repaired ? "已恢复/更新" : "已入架"}：《${item.title}》（${item.kind == "comic" ? "漫画架" : "书架"}）',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: tokens.inkPrimary,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _openOutcome(item),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                      child: Text(
                        '立即阅读',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: tokens.accentPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
          if (res.duplicateItems.isNotEmpty) ...[
            const SizedBox(height: 4),
            ...res.duplicateItems.map((dup) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '已在${dup.kind == "comic" ? "漫画架" : "书架"}：《${dup.title}》（分组：${dup.shelfGroup}）',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: tokens.inkMuted,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _openOutcome(dup),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                      child: Text(
                        '打开',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: tokens.accentPrimary,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed:
                          _busy ? null : () => _forceReimportDuplicate(dup),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                      child: Text(
                        '覆盖重导',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: tokens.accentWarm,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
          if (res.errors.isNotEmpty) ...[
            const SizedBox(height: 4),
            ...res.errors.map((err) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '失败：$err',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: tokens.accentWarm,
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _HistoryEntry {
  const _HistoryEntry({
    required this.id,
    required this.title,
    required this.format,
    required this.isComic,
    required this.isArchived,
    required this.addedAtMs,
    required this.localPath,
    required this.fileExists,
    required this.subtitle,
  });

  final int id;
  final String title;
  final String format;
  final bool isComic;
  final bool isArchived;
  final int addedAtMs;
  final String localPath;
  final bool fileExists;
  final String subtitle;
}
