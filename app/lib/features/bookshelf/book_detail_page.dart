import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/icons/ink_icons.dart';
import '../../core/theme/inkbox_theme.dart';
import '../../core/widgets/floating_surface.dart';
import '../../core/widgets/ink_controls.dart';
import '../../data/db/app_database.dart';
import '../../data/ffi/rust_core_bridge.dart';
import '../../data/providers/app_providers.dart';
import '../book_reader/book_paginator.dart';
import '../book_reader/reader_highlight_canvas.dart';
import 'shelf_sheets.dart';

class BookDetailPage extends ConsumerStatefulWidget {
  const BookDetailPage({
    super.key,
    required this.bookId,
    this.fromReader = false,
  });

  final int bookId;
  final bool fromReader;

  @override
  ConsumerState<BookDetailPage> createState() => _BookDetailPageState();
}

class _BookDetailPageState extends ConsumerState<BookDetailPage> {
  List<BookChapterRef> _chapters = const [];
  String? _matchedRuleName;
  String? _detectedEncoding;
  bool _loadingToc = true;
  bool _tocReversed = false;
  String? _lastTocFingerprint;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadToc());
  }

  Future<bool> _loadToc({Book? explicitBook}) async {
    final db = ref.read(appDatabaseProvider);
    final book = explicitBook ?? await db.findBookById(widget.bookId);
    if (!mounted || book == null) {
      if (mounted) setState(() => _loadingToc = false);
      return false;
    }
    final fp =
        '${book.filePath}|${book.tocRuleId ?? -1}|${book.forcedEncoding ?? "auto"}';
    _lastTocFingerprint = fp;
    if (mounted) setState(() => _loadingToc = true);

    final tocRules = await db.getTocRules();
    final forcedRule = book.tocRuleId != null
        ? tocRules.where((r) => r.id == book.tocRuleId).firstOrNull
        : null;
    final loader = BookContentLoader(rustCore: ref.read(rustCoreProvider));
    final tocResult = await loader.loadChapterToc(
      book,
      tocRules: tocRules,
      forcedRule: forcedRule,
    );
    if (!mounted) return false;
    setState(() {
      _chapters = tocResult.chapters;
      _matchedRuleName = tocResult.matchedRuleName ??
          (forcedRule != null ? '${forcedRule.name}（未匹配）' : null);
      _detectedEncoding = tocResult.detectedEncoding;
      _loadingToc = false;
    });
    return tocResult.matchedRuleName != null;
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          duration: const Duration(milliseconds: 1600),
        ),
      );
  }

  void _openChapter(Book book, int chapterIndex, {int? charOffset}) {
    if (widget.fromReader) {
      context.pop((chapterIndex: chapterIndex, charOffset: charOffset ?? 0));
    } else {
      final offSuffix = charOffset != null ? '&offset=$charOffset' : '';
      context.push('/reader/book/${book.id}?chapter=$chapterIndex$offSuffix');
    }
  }

  Future<void> _showTocRuleSelector(Book book) async {
    final db = ref.read(appDatabaseProvider);
    final rules = await db.getTocRules();
    if (!mounted) return;
    final currentVal = book.tocRuleId ?? -1;
    final picked = await showInkOptionSheet<int>(
      context: context,
      title: '选择目录识别规则',
      subtitle: '可指定单本书专用规则，或交由引擎从已启用规则中智能自动匹配',
      selectedValue: currentVal,
      options: [
        const InkOptionItem<int>(
          value: -1,
          label: '智能自动识别（推荐）',
          subtitle: '自动对已启用的全部目录规则评分并选取最优分章结果',
          icon: InkIcon.spark,
        ),
        ...rules.map(
          (r) => InkOptionItem<int>(
            value: r.id,
            label: r.name,
            subtitle: r.example.isNotEmpty ? r.example : r.rule,
            icon: InkIcon.toc,
          ),
        ),
      ],
    );
    if (picked == null || !mounted) return;
    if (picked == -1) {
      await db.updateBookMeta(book.id, clearTocRuleId: true);
    } else {
      await db.updateBookMeta(book.id, tocRuleId: picked);
    }
    final fresh = await db.findBookById(book.id);
    final matched = await _loadToc(explicitBook: fresh);
    if (fresh != null && _chapters.isNotEmpty) {
      final safeIdx = fresh.currentChapterIndex.clamp(0, _chapters.length - 1);
      await db.updateBookMeta(
        fresh.id,
        currentChapterTitle: _chapters[safeIdx].title,
      );
    }
    _toast(
      matched
          ? '已重新解析目录（共 ${_chapters.length} 章）'
          : '该规则未匹配到章节，已按默认分段显示（${_chapters.length} 节）',
    );
  }

  Future<void> _showEncodingSelector(Book book) async {
    final db = ref.read(appDatabaseProvider);
    final current = book.forcedEncoding ?? 'auto';
    final picked = await showInkOptionSheet<String>(
      context: context,
      title: '选择文本编码',
      subtitle: '若正文或章节名出现乱码，可手动切换文件编码',
      selectedValue: current,
      options: const [
        InkOptionItem(value: 'auto', label: '自动检测（推荐）'),
        InkOptionItem(value: 'UTF-8', label: 'UTF-8'),
        InkOptionItem(value: 'GB18030', label: 'GB18030 / GBK（中文常见）'),
        InkOptionItem(value: 'Big5', label: 'Big5（繁体中文）'),
        InkOptionItem(value: 'UTF-16LE', label: 'UTF-16 LE'),
        InkOptionItem(value: 'UTF-16BE', label: 'UTF-16 BE'),
      ],
    );
    if (picked == null || !mounted) return;
    if (picked == 'auto') {
      await db.updateBookMeta(book.id, clearForcedEncoding: true);
    } else {
      await db.updateBookMeta(book.id, forcedEncoding: picked);
    }
    final fresh = await db.findBookById(book.id);
    await _loadToc(explicitBook: fresh);
    if (fresh != null && _chapters.isNotEmpty) {
      final safeIdx = fresh.currentChapterIndex.clamp(0, _chapters.length - 1);
      await db.updateBookMeta(
        fresh.id,
        currentChapterTitle: _chapters[safeIdx].title,
      );
    }
    _toast('已切换编码为 ${_detectedEncoding ?? picked}');
  }

  Future<void> _openFullTocSheet(Book book) async {
    if (_chapters.isEmpty) return;
    final pickedChapter = await showModalBottomSheet<int>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _FullBookTocSheet(
        bookTitle: book.title,
        chapters: _chapters,
        currentChapterIndex: book.currentChapterIndex,
        initialReversed: _tocReversed,
      ),
    );
    if (pickedChapter != null && mounted) {
      _openChapter(book, pickedChapter);
    }
  }

  Future<void> _removeBook(Book book) async {
    final choice = await showInkOptionSheet<String>(
      context: context,
      title: '移除《${book.title}》',
      subtitle: '移出书架后仍可在「导入 -> 导入历史」中快速重新入架',
      options: const [
        InkOptionItem(
          value: 'archive',
          label: '移出书架（保留在导入历史）',
          subtitle: '保留阅读进度与本地文件，随时可恢复',
          icon: InkIcon.history,
        ),
        InkOptionItem(
          value: 'permanent',
          label: '彻底删除',
          subtitle: '同时清除导入历史、书签笔记与应用内缓存文件',
          icon: InkIcon.trash,
          danger: true,
        ),
      ],
    );
    if (choice == null || !mounted) return;
    if (choice == 'archive') {
      await ref.read(appDatabaseProvider).archiveBooksByIds([book.id]);
    } else if (choice == 'permanent') {
      await ref.read(importServiceProvider).permanentlyDeleteBooks([book.id]);
    }
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = InkBoxTokens.of(context);
    final books =
        ref.watch(bookHistoryStreamProvider).valueOrNull ?? const <Book>[];
    final book = books.where((b) => b.id == widget.bookId).firstOrNull;
    final shelves =
        ref.watch(bookShelvesStreamProvider).valueOrNull ?? const <Shelf>[];
    final db = ref.watch(appDatabaseProvider);

    if (book == null) {
      return Scaffold(
        backgroundColor: tokens.canvasBg,
        appBar: AppBar(title: const Text('书籍详情')),
        body: const Center(child: Text('未找到该书籍')),
      );
    }

    final expectedFp =
        '${book.filePath}|${book.tocRuleId ?? -1}|${book.forcedEncoding ?? "auto"}';
    if (_lastTocFingerprint != null &&
        _lastTocFingerprint != expectedFp &&
        !_loadingToc) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadToc(explicitBook: book);
      });
    }

    final effectiveShelfId =
        AppDatabase.resolveEffectiveShelfId(book.shelfId, shelves);
    final shelfName = shelves
            .where((s) => s.id == effectiveShelfId)
            .firstOrNull
            ?.name ??
        kDefaultBookShelfName;
    final isFinished =
        book.progressRatio >= 0.99 || book.shelfGroup == '已读完';

    final annotationsAsync =
        ref.watch(annotationsStreamProvider(book.contentHash));
    final pct = (book.progressRatio * 100).toStringAsFixed(1);
    final mins = (book.readingTimeSec / 60).floor();
    final isTxt = book.format.toUpperCase() == 'TXT';

    // Build visible TOC preview window (up to 8 chapters centered near reading position, or reversed)
    final previewIndices = _buildPreviewIndices(
      total: _chapters.length,
      current: book.currentChapterIndex,
      reversed: _tocReversed,
    );

    return Scaffold(
      backgroundColor: tokens.canvasBg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 28),
          children: [
            FloatingCard(
              radius: 22,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  InkCircleButton(
                    icon: InkIconWidget(
                      InkIcon.back,
                      size: 18,
                      color: tokens.inkPrimary,
                    ),
                    onPressed: () => context.pop(),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '书籍详情',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: tokens.inkPrimary,
                      ),
                    ),
                  ),
                  InkCircleButton(
                    icon: InkIconWidget(
                      InkIcon.note,
                      size: 17,
                      color: tokens.inkPrimary,
                    ),
                    tooltip: '编辑元信息',
                    onPressed: () =>
                        _showEditMetaDialog(context, db, book, shelves),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            FloatingCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DetailCover(book: book),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              book.title,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: tokens.inkPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              book.author,
                              style: TextStyle(
                                fontSize: 13,
                                color: tokens.inkMuted,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                _InfoTag(book.format),
                                _InfoTag('书架：$shelfName'),
                                _InfoTag(isFinished ? '已读完' : '在读'),
                                _InfoTag('已读 $pct%'),
                                _InfoTag('时长 $mins 分钟'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: tokens.accentPrimary,
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        if (widget.fromReader) {
                          context.pop();
                        } else {
                          context.push('/reader/book/${book.id}');
                        }
                      },
                      icon: InkIconWidget(
                        InkIcon.play,
                        size: 16,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                      label: Text('继续阅读 · ${book.currentChapterTitle}'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            shape: const StadiumBorder(),
                            side: BorderSide(color: tokens.subtleBorder),
                          ),
                          onPressed: () async {
                            final targetId = await showMoveToShelfDialog(
                              context: context,
                              db: db,
                              mediaKind: 'book',
                              shelves: shelves,
                              currentShelfId: effectiveShelfId,
                              itemTitle: book.title,
                            );
                            if (targetId != null) {
                              await db.updateBookMeta(
                                book.id,
                                shelfId: targetId,
                              );
                              _toast('已修改所属书架');
                            }
                          },
                          child: Text(
                            '修改书架',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: tokens.inkPrimary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            shape: const StadiumBorder(),
                            side: BorderSide(color: tokens.subtleBorder),
                          ),
                          onPressed: () async {
                            await db.updateBookMeta(
                              book.id,
                              isPinned: !book.isPinned,
                            );
                          },
                          child: Text(
                            book.isPinned ? '取消置顶' : '置顶书架',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: tokens.inkPrimary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            shape: const StadiumBorder(),
                            side: BorderSide(color: tokens.accentWarm),
                          ),
                          onPressed: () => _removeBook(book),
                          child: Text(
                            '移除书籍',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: tokens.accentWarm,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // --- Table of Contents & Parsing / Encoding Configuration Card ---
            FloatingCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      InkIconWidget(
                        InkIcon.toc,
                        size: 16,
                        color: tokens.accentPrimary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '章节目录 (${_chapters.length})',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: tokens.inkPrimary,
                          ),
                        ),
                      ),
                      InkPillChip(
                        label: _tocReversed ? '倒序' : '正序',
                        onTap: () =>
                            setState(() => _tocReversed = !_tocReversed),
                      ),
                      if (_chapters.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        InkPillChip(
                          label: '全部目录',
                          selected: true,
                          onTap: () => _openFullTocSheet(book),
                        ),
                      ],
                    ],
                  ),
                  if (isTxt) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: tokens.surfaceVariant.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '分章规则：${_matchedRuleName ?? "智能自动识别"} · 编码：${book.forcedEncoding ?? _detectedEncoding ?? "自动检测"}',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: tokens.inkPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              InkPillChip(
                                label: '切换目录规则',
                                onTap: () => _showTocRuleSelector(book),
                              ),
                              InkPillChip(
                                label: '切换编码',
                                onTap: () => _showEncodingSelector(book),
                              ),
                              InkPillChip(
                                label: '管理规则库',
                                onTap: () async {
                                  await context.push('/mine/toc-rules');
                                  if (mounted) {
                                    final fresh =
                                        await db.findBookById(book.id);
                                    await _loadToc(explicitBook: fresh);
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  if (_loadingToc)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: tokens.accentPrimary,
                          ),
                        ),
                      ),
                    )
                  else if (_chapters.isEmpty)
                    Text(
                      '未解析到目录章节',
                      style: TextStyle(fontSize: 12, color: tokens.inkMuted),
                    )
                  else ...[
                    ...previewIndices.map((chIdx) {
                      final ch = _chapters[chIdx];
                      final active = chIdx == book.currentChapterIndex;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Material(
                          color: active
                              ? tokens.accentSoft
                              : tokens.surfaceVariant.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(11),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => _openChapter(book, chIdx),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      ch.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: active
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: active
                                            ? tokens.accentPrimary
                                            : tokens.inkPrimary,
                                      ),
                                    ),
                                  ),
                                  if (active)
                                    Text(
                                      '当前阅读',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        color: tokens.accentPrimary,
                                      ),
                                    )
                                  else
                                    InkIconWidget(
                                      InkIcon.chevronRight,
                                      size: 14,
                                      color: tokens.inkMuted,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                    if (_chapters.length > previewIndices.length)
                      Align(
                        alignment: Alignment.center,
                        child: TextButton(
                          onPressed: () => _openFullTocSheet(book),
                          child: Text(
                            '展开查看全部 ${_chapters.length} 章目录',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: tokens.accentPrimary,
                            ),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // --- Bookmarks, Highlights & Notes Card ---
            FloatingCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '书签与划线笔记',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: tokens.inkPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  annotationsAsync.when(
                    loading: () => const Text('加载中...'),
                    error: (e, _) => Text('读取失败: $e'),
                    data: (notes) {
                      if (notes.isEmpty) {
                        return Text(
                          '暂无书签或划线笔记。在阅读器中点亮书签或长按文字即可添加划线。',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.5,
                            color: tokens.inkMuted,
                          ),
                        );
                      }
                      return Column(
                        children: notes.map((n) {
                          final kindLabel = n.kind == 'bookmark'
                              ? '书签'
                              : (n.noteText.isNotEmpty ? '划线想法' : '划线');
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Material(
                              color: tokens.surfaceVariant,
                              borderRadius: BorderRadius.circular(12),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: () {
                                  final loc =
                                      ParsedAnnotationLocator.parse(n.locator);
                                  _openChapter(
                                    book,
                                    n.chapterIndex,
                                    charOffset: loc.startOffset,
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '$kindLabel · 第 ${n.chapterIndex + 1} 章',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: tokens.accentPrimary,
                                            ),
                                          ),
                                          GestureDetector(
                                            onTap: () =>
                                                db.softDeleteAnnotation(n.uuid),
                                            child: Text(
                                              '删除',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: tokens.inkMuted,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (n.excerpt.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          '“${n.excerpt}”',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            color: tokens.inkPrimary,
                                          ),
                                        ),
                                      ],
                                      if (n.noteText.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          n.noteText,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: tokens.inkMuted,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
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
                  Text(
                    '本地文件信息',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: tokens.inkPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '路径：${book.filePath}\n指纹：${book.contentHash}',
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.5,
                      color: tokens.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<int> _buildPreviewIndices({
    required int total,
    required int current,
    required bool reversed,
  }) {
    if (total <= 0) return const [];
    const maxPreview = 8;
    if (total <= maxPreview) {
      final all = List<int>.generate(total, (i) => i);
      return reversed ? all.reversed.toList() : all;
    }
    if (reversed) {
      return List<int>.generate(maxPreview, (i) => total - 1 - i);
    }
    final safeCur = current.clamp(0, total - 1);
    final start = (safeCur - 2).clamp(0, total - maxPreview);
    return List<int>.generate(maxPreview, (i) => start + i);
  }

  Future<void> _showEditMetaDialog(
    BuildContext context,
    AppDatabase db,
    Book book,
    List<Shelf> shelves,
  ) async {
    final titleCtrl = TextEditingController(text: book.title);
    final authorCtrl = TextEditingController(text: book.author);
    final newShelfCtrl = TextEditingController();
    int selectedShelfId =
        AppDatabase.resolveEffectiveShelfId(book.shelfId, shelves);
    String selectedStatus =
        (book.progressRatio >= 0.99 || book.shelfGroup == '已读完')
            ? '已读完'
            : '在读';

    final result = await showInkModal<
        ({
          String title,
          String author,
          int shelfId,
          String newShelfName,
          String status,
        })>(
      context: context,
      title: '编辑书籍信息',
      disposables: [titleCtrl, authorCtrl, newShelfCtrl],
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final muted = InkBoxTokens.of(ctx).inkMuted;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkTextField(controller: titleCtrl, label: '书名'),
              const SizedBox(height: 10),
              InkTextField(controller: authorCtrl, label: '作者'),
              const SizedBox(height: 10),
              Text(
                '所属书架',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: muted,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: shelves.map((s) {
                  return InkPillChip(
                    label: s.name,
                    leadingIcon: InkIcon.bookshelf,
                    selected: selectedShelfId == s.id &&
                        newShelfCtrl.text.trim().isEmpty,
                    onTap: () => setModalState(() {
                      selectedShelfId = s.id;
                      newShelfCtrl.clear();
                    }),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              InkTextField(
                controller: newShelfCtrl,
                label: '或输入新建书架',
                hintText: '例如：书架1（历史）、书架2（经济）',
                onChanged: (_) => setModalState(() {}),
              ),
              const SizedBox(height: 10),
              Text(
                '阅读状态分组',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: muted,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: ['在读', '已读完'].map((st) {
                  return InkPillChip(
                    label: st,
                    selected: selectedStatus == st,
                    onTap: () => setModalState(() => selectedStatus = st),
                  );
                }).toList(),
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
            title: titleCtrl.text.trim(),
            author: authorCtrl.text.trim(),
            shelfId: selectedShelfId,
            newShelfName: newShelfCtrl.text.trim(),
            status: selectedStatus,
          )),
          child: const Text('保存'),
        ),
      ],
    );

    if (result == null) return;
    int finalShelfId = result.shelfId;
    if (result.newShelfName.isNotEmpty) {
      final created = await db.createShelf(result.newShelfName, 'book');
      if (created != null) {
        finalShelfId = created.id;
      } else {
        final all = await db.getShelves('book');
        final match =
            all.where((s) => s.name == result.newShelfName).firstOrNull;
        if (match != null) finalShelfId = match.id;
      }
    }
    double? nextProgress;
    if (result.status == '已读完') {
      nextProgress = 1.0;
    } else if (book.progressRatio >= 0.99) {
      nextProgress =
          (book.currentChapterIndex == 0 && book.currentCharOffset == 0)
              ? 0.0
              : (_chapters.isNotEmpty
                  ? (book.currentChapterIndex / _chapters.length)
                      .clamp(0.0, 0.98)
                  : 0.0);
    }
    await db.updateBookMeta(
      book.id,
      title: result.title.isEmpty ? book.title : result.title,
      author: result.author.isEmpty ? book.author : result.author,
      shelfId: finalShelfId,
      shelfGroup: result.status,
      progressRatio: nextProgress,
    );
  }
}

class _FullBookTocSheet extends StatefulWidget {
  const _FullBookTocSheet({
    required this.bookTitle,
    required this.chapters,
    required this.currentChapterIndex,
    required this.initialReversed,
  });

  final String bookTitle;
  final List<BookChapterRef> chapters;
  final int currentChapterIndex;
  final bool initialReversed;

  @override
  State<_FullBookTocSheet> createState() => _FullBookTocSheetState();
}

class _FullBookTocSheetState extends State<_FullBookTocSheet> {
  late bool _reversed;
  String _query = '';
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _reversed = widget.initialReversed;
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToCurrent());
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _jumpToCurrent() {
    if (!mounted ||
        !_scrollCtrl.hasClients ||
        widget.chapters.isEmpty ||
        _query.isNotEmpty) {
      return;
    }
    final safeCur =
        widget.currentChapterIndex.clamp(0, widget.chapters.length - 1);
    final visualIdx =
        _reversed ? (widget.chapters.length - 1 - safeCur) : safeCur;
    const extent = 46.0;
    final target = (visualIdx * extent - extent * 2)
        .clamp(0.0, _scrollCtrl.position.maxScrollExtent);
    _scrollCtrl.jumpTo(target);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = InkBoxTokens.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final ordered = _reversed
        ? widget.chapters.reversed.toList()
        : widget.chapters;
    final filtered = _query.isEmpty
        ? ordered
        : ordered
            .where(
              (c) => c.title.toLowerCase().contains(_query.toLowerCase()),
            )
            .toList();

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
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.76,
            child: Column(
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
                        '${widget.bookTitle} · 目录 (${widget.chapters.length})',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: tokens.inkPrimary,
                        ),
                      ),
                    ),
                    InkPillChip(
                      label: _reversed ? '倒序' : '正序',
                      onTap: () {
                        setState(() => _reversed = !_reversed);
                        WidgetsBinding.instance
                            .addPostFrameCallback((_) => _jumpToCurrent());
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                InkTextField(
                  prefixIcon: InkIcon.search,
                  hintText: '搜索章节名称...',
                  onChanged: (v) => setState(() => _query = v.trim()),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Text(
                            '未找到匹配章节',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: tokens.inkMuted,
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollCtrl,
                          itemExtent: 46,
                          itemCount: filtered.length,
                          itemBuilder: (_, idx) {
                            final ch = filtered[idx];
                            final active =
                                ch.index == widget.currentChapterIndex;
                            return InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () => Navigator.of(context).pop(ch.index),
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 10),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        ch.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: active
                                              ? FontWeight.w700
                                              : FontWeight.w400,
                                          color: active
                                              ? tokens.accentPrimary
                                              : tokens.inkPrimary,
                                        ),
                                      ),
                                    ),
                                    if (active)
                                      InkIconWidget(
                                        InkIcon.check,
                                        size: 15,
                                        color: tokens.accentPrimary,
                                      ),
                                  ],
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

class _DetailCover extends StatelessWidget {
  const _DetailCover({required this.book});
  final Book book;

  @override
  Widget build(BuildContext context) {
    final hasFile =
        book.coverPath != null && File(book.coverPath!).existsSync();
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 90,
        height: 126,
        child: hasFile
            ? Image.file(File(book.coverPath!), fit: BoxFit.cover)
            : Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1E3246), Color(0xFF3B5978)],
                  ),
                ),
                padding: const EdgeInsets.all(10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: Text(
                        book.format,
                        style: const TextStyle(
                          fontSize: 9,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                    Text(
                      book.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _InfoTag extends StatelessWidget {
  const _InfoTag(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = InkBoxTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: tokens.surfaceVariant,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, color: tokens.inkPrimary),
      ),
    );
  }
}
