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
import '../../data/platform/library_storage.dart';
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
  bool _forcedRuleUnmatched = false;
  String? _forcedRuleRawName;
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
    ReadableMedia? media;
    if (LibraryStorage.isDocument(book.filePath)) {
      try {
        media = await ref.read(libraryStorageProvider).open(
          book.filePath,
          extension: book.format,
        );
      } catch (_) {
        // The TOC loader handles unavailable files.
      }
    }
    final LoadedTocResult tocResult;
    try {
      tocResult = await loader.loadChapterToc(
        media == null ? book : book.copyWith(filePath: media.path),
        tocRules: tocRules,
        forcedRule: forcedRule,
      );
    } finally {
      await media?.close();
    }
    if (!mounted) return false;
    setState(() {
      _chapters = tocResult.chapters;
      _matchedRuleName = tocResult.matchedRuleName;
      _forcedRuleUnmatched =
          tocResult.matchedRuleName == null && forcedRule != null;
      _forcedRuleRawName = forcedRule?.name;
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
    final l10n = context.l10n;
    final currentVal = book.tocRuleId ?? -1;
    final picked = await showInkOptionSheet<int>(
      context: context,
      title: l10n.selectTocRuleTitle,
      selectedValue: currentVal,
      options: [
        InkOptionItem<int>(
          value: -1,
          label: l10n.autoDetectRecommended,
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
    if (!mounted) return;
    _toast(
      matched
          ? l10n.tocReloadedCount(_chapters.length)
          : l10n.tocNoMatchFallback(_chapters.length),
    );
  }

  Future<void> _showEncodingSelector(Book book) async {
    final db = ref.read(appDatabaseProvider);
    final l10n = context.l10n;
    final current = book.forcedEncoding ?? 'auto';
    final picked = await showInkOptionSheet<String>(
      context: context,
      title: l10n.selectEncodingTitle,
      selectedValue: current,
      options: [
        InkOptionItem(value: 'auto', label: l10n.encodingAuto),
        const InkOptionItem(value: 'UTF-8', label: 'UTF-8'),
        InkOptionItem(value: 'GB18030', label: l10n.encodingGb18030),
        InkOptionItem(value: 'Big5', label: l10n.encodingBig5),
        const InkOptionItem(value: 'UTF-16LE', label: 'UTF-16 LE'),
        const InkOptionItem(value: 'UTF-16BE', label: 'UTF-16 BE'),
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
    if (!mounted) return;
    _toast(l10n.encodingSwitched(_detectedEncoding ?? picked));
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
    final l10n = context.l10n;
    final choice = await showInkOptionSheet<String>(
      context: context,
      title: l10n.removeBookTitleSingle(book.title),
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
      await ref.read(appDatabaseProvider).archiveBooksByIds([book.id]);
    } else if (choice == 'permanent') {
      await ref.read(importServiceProvider).permanentlyDeleteBooks([book.id]);
    }
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = InkBoxTokens.of(context);
    final l10n = context.l10n;
    final books =
        ref.watch(bookHistoryStreamProvider).valueOrNull ?? const <Book>[];
    final book = books.where((b) => b.id == widget.bookId).firstOrNull;
    final shelves =
        ref.watch(bookShelvesStreamProvider).valueOrNull ?? const <Shelf>[];
    final db = ref.watch(appDatabaseProvider);

    if (book == null) {
      return Scaffold(
        backgroundColor: tokens.canvasBg,
        appBar: AppBar(title: Text(l10n.bookDetailsTitle)),
        body: Center(child: Text(l10n.notFoundBook)),
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
    final matchedShelf =
        shelves.where((s) => s.id == effectiveShelfId).firstOrNull;
    final shelfName = localizedShelfName(l10n, matchedShelf, isComic: false);
    final isFinished = isBookFinished(book);

    final annotationsAsync =
        ref.watch(annotationsStreamProvider(book.contentHash));
    final pct = (book.progressRatio * 100).toStringAsFixed(1);
    final mins = (book.readingTimeSec / 60).floor();
    final isTxt = book.format.toUpperCase() == 'TXT';

    final previewIndices = _buildPreviewIndices(
      total: _chapters.length,
      current: book.currentChapterIndex,
      reversed: _tocReversed,
    );

    final ruleDisplay = _matchedRuleName ??
        (_forcedRuleUnmatched && _forcedRuleRawName != null
            ? l10n.ruleUnmatchedTag(_forcedRuleRawName!)
            : l10n.smartAutoDetect);
    final encodingDisplay =
        book.forcedEncoding ?? _detectedEncoding ?? l10n.encodingAuto;

    return Scaffold(
      backgroundColor: tokens.canvasBg,
      body: SafeArea(
        child: ResponsiveConstrainedBody(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 28),
            children: [
              FloatingCard(
                radius: 18,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                        l10n.bookDetailsTitle,
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
                      tooltip: l10n.editMetadata,
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
                                localizedAuthor(l10n, book.author),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: tokens.inkMuted,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${book.format} · $shelfName · ${isFinished ? l10n.shelfGroupFinished : l10n.shelfGroupReading} · $pct% · ${l10n.readingMinutesShort(mins)}',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  height: 1.45,
                                  color: tokens.inkMuted,
                                ),
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
                        label: Text(
                          '${l10n.continueReading} · ${localizedChapterTitle(l10n, book.currentChapterTitle)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
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
                                _toast(l10n.movedShelfSuccess);
                              }
                            },
                            child: Text(
                              l10n.moveShelf,
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
                              book.isPinned
                                  ? l10n.unpinFromShelf
                                  : l10n.pinToShelf,
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
                              l10n.removeBooks,
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
                            l10n.tocChaptersCount(_chapters.length),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: tokens.inkPrimary,
                            ),
                          ),
                        ),
                        InkPillChip(
                          label: _tocReversed
                              ? l10n.descendingOrder
                              : l10n.ascendingOrder,
                          onTap: () =>
                              setState(() => _tocReversed = !_tocReversed),
                        ),
                        if (_chapters.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          InkPillChip(
                            label: l10n.fullToc,
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
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.txtRuleEncodingMeta(
                                  ruleDisplay, encodingDisplay),
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
                                  label: l10n.switchTocRule,
                                  onTap: () => _showTocRuleSelector(book),
                                ),
                                InkPillChip(
                                  label: l10n.switchEncoding,
                                  onTap: () => _showEncodingSelector(book),
                                ),
                                InkPillChip(
                                  label: l10n.manageRuleLibrary,
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
                        l10n.noTocFound,
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
                                        l10n.currentReadingTag,
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
                              l10n.expandFullToc(_chapters.length),
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
              FloatingCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.annotationsTitle,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: tokens.inkPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    annotationsAsync.when(
                      loading: () => Text(l10n.loading),
                      error: (e, _) => Text('$e'),
                      data: (notes) {
                        if (notes.isEmpty) {
                          return Text(
                            l10n.noAnnotationsHint,
                            style: TextStyle(
                              fontSize: 12,
                              color: tokens.inkMuted,
                            ),
                          );
                        }
                        return Column(
                          children: notes.map((n) {
                            final kindLabel = n.kind == 'bookmark'
                                ? l10n.bookmarkTag
                                : (n.noteText.isNotEmpty
                                    ? l10n.highlightNoteTag
                                    : l10n.highlightTag);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Material(
                                color: tokens.surfaceVariant,
                                borderRadius: BorderRadius.circular(12),
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  onTap: () {
                                    final loc = ParsedAnnotationLocator.parse(
                                        n.locator);
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
                                              '$kindLabel · ${l10n.chapterLabelShort(n.chapterIndex + 1)}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: tokens.accentPrimary,
                                              ),
                                            ),
                                            GestureDetector(
                                              onTap: () => db
                                                  .softDeleteAnnotation(n.uuid),
                                              child: Text(
                                                l10n.delete,
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
                      l10n.localFileInfo,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: tokens.inkPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${l10n.pathLabel(book.filePath)}\n${l10n.fingerprintLabel(book.contentHash)}',
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
    final l10n = context.l10n;
    final titleCtrl = TextEditingController(text: book.title);
    final authorCtrl = TextEditingController(text: book.author);
    final newShelfCtrl = TextEditingController();
    int selectedShelfId =
        AppDatabase.resolveEffectiveShelfId(book.shelfId, shelves);
    String selectedStatus = isBookFinished(book) ? '已读完' : '在读';

    final result = await showInkModal<
        ({
          String title,
          String author,
          int shelfId,
          String newShelfName,
          String status,
        })>(
      context: context,
      title: l10n.editMetadata,
      disposables: [titleCtrl, authorCtrl, newShelfCtrl],
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final muted = InkBoxTokens.of(ctx).inkMuted;
          final ctxL10n = ctx.l10n;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkTextField(controller: titleCtrl, label: ctxL10n.bookTitleLabel),
              const SizedBox(height: 10),
              InkTextField(controller: authorCtrl, label: ctxL10n.authorLabel),
              const SizedBox(height: 10),
              Text(
                ctxL10n.shelfBelongsTo,
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
                    label: localizedShelfName(ctxL10n, s, isComic: false),
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
                label: ctxL10n.orCreateShelf,
                hintText: ctxL10n.shelfExampleBook,
                onChanged: (_) => setModalState(() {}),
              ),
              const SizedBox(height: 10),
              Text(
                ctxL10n.readingStatusLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: muted,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  ('在读', ctxL10n.shelfGroupReading),
                  ('已读完', ctxL10n.shelfGroupFinished),
                ].map((pair) {
                  return InkPillChip(
                    label: pair.$2,
                    selected: selectedStatus == pair.$1,
                    onTap: () => setModalState(() => selectedStatus = pair.$1),
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
          child: Text(ctx.l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop((
            title: titleCtrl.text.trim(),
            author: authorCtrl.text.trim(),
            shelfId: selectedShelfId,
            newShelfName: newShelfCtrl.text.trim(),
            status: selectedStatus,
          )),
          child: Text(ctx.l10n.save),
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
    final l10n = context.l10n;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final wide = isWideLayout(context);
    final ordered =
        _reversed ? widget.chapters.reversed.toList() : widget.chapters;
    final filtered = _query.isEmpty
        ? ordered
        : ordered
            .where(
              (c) => c.title.toLowerCase().contains(_query.toLowerCase()),
            )
            .toList();

    return SafeArea(
      child: Center(
        heightFactor: 1.0,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: wide ? 520 : double.infinity,
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              tokens.isFloatingCard ? 14 : 0,
              0,
              tokens.isFloatingCard ? 14 : 0,
              (tokens.isFloatingCard ? 14 : 0) + bottomInset,
            ),
            child: FloatingCard(
              radius: 22,
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
                            '${widget.bookTitle} (${widget.chapters.length})',
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
                          label: _reversed
                              ? l10n.descendingOrder
                              : l10n.ascendingOrder,
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
                      hintText: l10n.searchChapterHint,
                      onChanged: (v) => setState(() => _query = v.trim()),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Text(
                                l10n.noMatchingChapters,
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
                                  onTap: () =>
                                      Navigator.of(context).pop(ch.index),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10),
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
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 88,
        height: 122,
        child: hasFile
            ? Image.file(File(book.coverPath!), fit: BoxFit.cover)
            : Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1D3557), Color(0xFF3B608C)],
                  ),
                ),
                padding: const EdgeInsets.all(10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
