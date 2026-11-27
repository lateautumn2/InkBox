import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:drift/drift.dart' as drift;
import 'package:flutter/services.dart';
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
import '../../data/ffi/rust_core_bridge.dart';
import '../../data/platform/platform_bridge.dart';
import '../../data/platform/library_storage.dart';
import '../../data/providers/app_providers.dart';
import '../tts/tts_models.dart';
import '../tts/tts_playback_controller.dart';
import '../tts/tts_text_chunker.dart';
import 'book_paginator.dart';
import 'book_reader_settings.dart';
import 'page_turn_painter.dart';
import 'reader_highlight_canvas.dart';

/// Complete V1.0 Book Reader:
/// - Supports EPUB/TXT/PDF (Original + Smart Reflow)/MOBI/AZW3/FB2/MD
/// - 4 Page Turn Modes (Simulation Bezier Curl / Cover / Slide / Continuous Scroll + AutoScroll)
/// - Seamless preloaded cross-chapter page turning & animated tap/volume-key turns
/// - 9-Grid Custom Tap Zones + Volume Key Paging
/// - Interactive Text Highlighting / Underlining (`划线` & `想法`), Color Swatches, Handle Dragging
/// - Toggleable Per-Page Bookmarks (tap once to add & light up, tap again to cancel)
/// - Spacious TOC & Annotations panel (TXT rule/encoding settings live cleanly in BookDetailPage)
/// - Full TTS configuration integration (rate, pitch, language, engine, auto-turn, sleep timer)
class BookReaderPage extends ConsumerStatefulWidget {
  const BookReaderPage({
    super.key,
    required this.bookId,
    this.initialChapterIndex,
    this.initialCharOffset,
  });

  final int bookId;
  final int? initialChapterIndex;
  final int? initialCharOffset;

  @override
  ConsumerState<BookReaderPage> createState() => _BookReaderPageState();
}

class _BookReaderPageState extends ConsumerState<BookReaderPage> {
  Book? _book;
  final Map<String, ReadableMedia> _bookFiles = {};
  List<BookChapterRef> _chapters = const [];
  LoadedBookChapter? _loadedChapter;
  List<BookPageSlice> _pages = const [];

  // Preloaded adjacent chapters so dragging/tapping across chapter boundaries is instant
  LoadedBookChapter? _prevChapter;
  List<BookPageSlice> _prevChapterPages = const [];
  LoadedBookChapter? _nextChapter;
  List<BookPageSlice> _nextChapterPages = const [];
  int _preloadGeneration = 0;

  int _chapterIdx = 0;
  int? _scrubChapterIdx;
  int _pageIdx = 0;
  int _anchorCharOffset = 0;
  bool _loading = true;
  bool _tocReversed = false;

  bool _menuVisible = false;
  String? _sheetTab; // null | toc | style | anim | more
  bool _ttsPlaying = false;
  bool _ttsExcerptOnly = false;
  bool _ttsPausedForSettings = false;
  int _ttsScrollOffset = 0;
  late final TtsPlaybackController _ttsCtrl;
  BookPaperTheme _lastLightPaper = BookPaperTheme.white;
  double _readerBrightness = 1.0;
  bool _showBrightnessIndicator = false;
  Timer? _brightnessHideTimer;

  bool _autoScrolling = false;
  Timer? _autoScrollTimer;
  final ScrollController _scrollCtrl = ScrollController();
  final ScrollController _tocScrollCtrl = ScrollController();
  final PageTurnController _pageTurnCtrl = PageTurnController();
  final GlobalKey<ReaderHighlightCanvasState> _leftCanvasKey =
      GlobalKey<ReaderHighlightCanvasState>();
  final GlobalKey<ReaderHighlightCanvasState> _rightCanvasKey =
      GlobalKey<ReaderHighlightCanvasState>();
  bool _isDualSpread = false;

  // Interactive Highlight / Underline Selection & Inspection State
  List<Annotation> _annotations = const [];
  ({int start, int end, String text})? _activeSelection;
  Annotation? _inspectedAnnotation;
  String _selectedHighlightColor = kReaderHighlightColors.first;

  DateTime _sessionStart = DateTime.now();
  StreamSubscription<PlatformEvent>? _eventSub;
  Size? _lastViewport;
  EdgeInsets _lastSafePadding = EdgeInsets.zero;
  int _lastSettingsHash = 0;
  bool _scrollJumpingToEnd = false;
  bool _lastScrollBookmarked = false;
  late final AppDatabase _db;
  late final PlatformBridge _platform;

  @override
  void initState() {
    super.initState();
    _db = ref.read(appDatabaseProvider);
    _platform = ref.read(platformBridgeProvider);
    final initPaper = ref.read(bookReaderSettingsProvider).paperTheme;
    if (initPaper != BookPaperTheme.dark && initPaper != BookPaperTheme.oled) {
      _lastLightPaper = initPaper;
    }
    _ttsCtrl = TtsPlaybackController(platform: _platform)
      ..addListener(_onTtsControllerChanged)
      ..onPageCompleted = _handleTtsPageCompleted
      ..onFallbackNotice = ((code) {
        if (mounted) _toast(context.l10n.ttsOnlineFallbackNotice);
      })
      ..onErrorNotice = ((code) {
        if (mounted) _toast(localizeError(context.l10n, code));
      })
      ..onSleepTimerExpired = (() {
        if (mounted) {
          setState(() => _ttsPlaying = false);
          _toast(context.l10n.ttsTimerExpiredToast);
        }
      });
    _sessionStart = DateTime.now();
    _scrollCtrl.addListener(_onScrollChanged);
    _initReader();
  }

  void _onTtsControllerChanged() {
    if (!mounted) return;
    setState(() {
      _ttsPlaying = _ttsCtrl.isActive;
    });
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _brightnessHideTimer?.cancel();
    _scrollCtrl.removeListener(_onScrollChanged);
    _scrollCtrl.dispose();
    _tocScrollCtrl.dispose();
    _eventSub?.cancel();
    _persistProgress(flushTime: true);
    _platform.setVolumeKeyPaging(false);
    _platform.setKeepScreenOn(false);
    _ttsCtrl.removeListener(_onTtsControllerChanged);
    _ttsCtrl.dispose();
    for (final media in _bookFiles.values) {
      unawaited(media.close());
    }
    _bookFiles.clear();
    super.dispose();
  }

  void _onScrollChanged() {
    if (!mounted || _loading || _scrollJumpingToEnd) return;
    final settings = ref.read(bookReaderSettingsProvider);
    if (_isNativePdfBitmapMode || settings.pageTurnMode != PageTurnMode.scroll) {
      return;
    }
    _anchorCharOffset = _currentScrollEstimatedOffset();
    final hasBm = _bookmarksForPage(
      allAnnotations: _annotations,
      chapterIndex: _chapterIdx,
      isScrollMode: true,
    ).isNotEmpty;
    if (hasBm != _lastScrollBookmarked) {
      _lastScrollBookmarked = hasBm;
      setState(() {});
    }
  }

  Future<void> _initReader() async {
    final entry = await _db.findBookById(widget.bookId);
    if (!mounted) return;
    if (entry == null) {
      setState(() => _loading = false);
      return;
    }
    final book = await _readableBook(entry);
    if (!mounted) return;

    final settings = ref.read(bookReaderSettingsProvider);
    await _platform.setKeepScreenOn(settings.keepScreenOn);
    await _platform.setVolumeKeyPaging(settings.volumeKeyPaging);

    _eventSub = _platform.events.listen((ev) {
      if (!mounted) return;
      if (ev.type == 'volume_key') {
        final dir = ev.payload['direction'];
        if (dir == 'down') {
          _triggerTurnNext();
        } else if (dir == 'up') {
          _triggerTurnPrev();
        }
      }
    });

    final tocRules = await _db.getTocRules();
    final forcedRule = book.tocRuleId != null
        ? tocRules.where((r) => r.id == book.tocRuleId).firstOrNull
        : null;
    final loader = BookContentLoader(rustCore: ref.read(rustCoreProvider));
    final tocResult = await loader.loadChapterToc(
      book,
      tocRules: tocRules,
      forcedRule: forcedRule,
    );
    if (!mounted) return;
    final chapters = tocResult.chapters;

    final hasExplicitStart = widget.initialChapterIndex != null;
    final startCh = (widget.initialChapterIndex ?? book.currentChapterIndex)
        .clamp(0, chapters.isEmpty ? 0 : chapters.length - 1);
    final startOffset =
        widget.initialCharOffset ?? (hasExplicitStart ? 0 : book.currentCharOffset);
    _book = book;
    _chapters = chapters;
    _chapterIdx = startCh;
    _anchorCharOffset = startOffset;
    _annotations = await _db.getAnnotationsFor(book.contentHash);
    if (!mounted) return;

    await _loadChapter(startCh, initialOffset: startOffset);
  }

  Future<Book> _readableBook(Book entry) async {
    if (!LibraryStorage.isDocument(entry.filePath)) return entry;
    final previous = _bookFiles[entry.filePath];
    if (previous != null) return entry.copyWith(filePath: previous.path);
    try {
      final media = await ref.read(libraryStorageProvider).open(
        entry.filePath,
        extension: entry.format,
      );
      if (!mounted) {
        await media.close();
        return entry;
      }
      _bookFiles[entry.filePath] = media;
      return entry.copyWith(filePath: media.path);
    } catch (_) {
      return entry;
    }
  }

  Future<void> _refreshAnnotations() async {
    final book = _book;
    if (book == null) return;
    try {
      final list = await _db.getAnnotationsFor(book.contentHash);
      if (mounted) {
        setState(() => _annotations = list);
      }
    } catch (_) {}
  }

  Future<void> _openBookDetailFromReader() async {
    final book = _book;
    if (book == null) return;
    final prevRuleId = book.tocRuleId;
    final prevEncoding = book.forcedEncoding;
    setState(() {
      _menuVisible = false;
      _sheetTab = null;
    });
    final chosen = await context
        .push<({int chapterIndex, int charOffset})>('/book/${book.id}?fromReader=1');
    if (!mounted) return;
    final fresh = await _db.findBookById(book.id);
    if (!mounted || fresh == null) return;
    await _refreshAnnotations();

    final resolved = await _readableBook(fresh);
    if (!mounted) return;
    final tocChanged = fresh.tocRuleId != prevRuleId ||
        fresh.forcedEncoding != prevEncoding ||
        resolved.filePath != book.filePath;
    if (tocChanged) {
      await _reloadTocFromBook(
        resolved,
        targetChapter: chosen?.chapterIndex ?? _chapterIdx,
        initialOffset: chosen?.charOffset ?? 0,
      );
    } else {
      setState(() => _book = resolved);
      if (chosen != null) {
        await _loadChapter(
          chosen.chapterIndex,
          initialOffset: chosen.charOffset,
        );
      }
    }
  }

  Future<void> _reloadTocFromBook(
    Book fresh, {
    int? targetChapter,
    int initialOffset = 0,
  }) async {
    final tocRules = await _db.getTocRules();
    final forcedRule = fresh.tocRuleId != null
        ? tocRules.where((r) => r.id == fresh.tocRuleId).firstOrNull
        : null;
    final loader = BookContentLoader(rustCore: ref.read(rustCoreProvider));
    final tocResult = await loader.loadChapterToc(
      fresh,
      tocRules: tocRules,
      forcedRule: forcedRule,
    );
    if (!mounted) return;
    final nextIdx = (targetChapter ?? _chapterIdx).clamp(
      0,
      tocResult.chapters.isEmpty ? 0 : tocResult.chapters.length - 1,
    );
    setState(() {
      _book = fresh;
      _chapters = tocResult.chapters;
    });
    await _loadChapter(nextIdx, initialOffset: initialOffset);
  }

  void _scrollTocToCurrentChapter() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_tocScrollCtrl.hasClients || _chapters.isEmpty) return;
      final visualIndex =
          _tocReversed ? (_chapters.length - 1 - _chapterIdx) : _chapterIdx;
      const itemExtent = 44.0;
      final target = (visualIndex * itemExtent - itemExtent * 1.5)
          .clamp(0.0, _tocScrollCtrl.position.maxScrollExtent);
      _tocScrollCtrl.jumpTo(target);
    });
  }

  void _clearSelectionAndInspector() {
    if (_activeSelection != null || _inspectedAnnotation != null) {
      setState(() {
        _activeSelection = null;
        _inspectedAnnotation = null;
      });
    }
  }

  Future<void> _loadChapter(
    int idx, {
    int initialOffset = 0,
    bool jumpEnd = false,
  }) async {
    if (_book == null || _chapters.isEmpty) return;
    final clamped = idx.clamp(0, _chapters.length - 1);
    final gen = ++_preloadGeneration;
    setState(() {
      _loading = true;
      _activeSelection = null;
      _inspectedAnnotation = null;
    });

    final settings = ref.read(bookReaderSettingsProvider);
    final loader = BookContentLoader(rustCore: ref.read(rustCoreProvider));
    final loaded = await loader.loadChapterContent(
      _book!,
      _chapters[clamped],
      settings,
    );
    if (!mounted || gen != _preloadGeneration) return;

    setState(() {
      _chapterIdx = clamped;
      _loadedChapter = loaded;
      _anchorCharOffset = jumpEnd ? loaded.text.length : initialOffset;
      _pages = const [];
      _prevChapter = null;
      _prevChapterPages = const [];
      _nextChapter = null;
      _nextChapterPages = const [];
      _pageIdx = 0;
      _loading = false;
      _scrollJumpingToEnd = jumpEnd;
    });

    _resetScrollPositionAfterChapterLoad(
      jumpEnd: jumpEnd,
      initialOffset: initialOffset,
    );
    _persistProgress();
    unawaited(_preloadAdjacentChapters(gen));
  }

  void _resetScrollPositionAfterChapterLoad({
    required bool jumpEnd,
    int initialOffset = 0,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollCtrl.hasClients) return;
      final maxExt = _scrollCtrl.position.maxScrollExtent;
      double target = 0.0;
      if (jumpEnd) {
        target = maxExt;
      } else if (initialOffset > 0 && maxExt > 0) {
        final settings = ref.read(bookReaderSettingsProvider);
        final formatted = BookPaginator.formatParagraphs(
          _loadedChapter?.text ?? '',
          indent: settings.indentFirstLine,
        );
        if (formatted.isNotEmpty) {
          target = (initialOffset / formatted.length) * maxExt;
        }
      }
      _scrollCtrl.jumpTo(target.clamp(0.0, maxExt));
      _scrollJumpingToEnd = false;
    });
  }

  Future<void> _preloadAdjacentChapters(int gen) async {
    final book = _book;
    if (book == null || _chapters.isEmpty) return;
    final settings = ref.read(bookReaderSettingsProvider);
    final loader = BookContentLoader(rustCore: ref.read(rustCoreProvider));

    LoadedBookChapter? loadedNext;
    LoadedBookChapter? loadedPrev;

    if (_chapterIdx + 1 < _chapters.length &&
        (_nextChapter == null || _nextChapter!.index != _chapterIdx + 1)) {
      try {
        loadedNext = await loader.loadChapterContent(
          book,
          _chapters[_chapterIdx + 1],
          settings,
        );
      } catch (_) {}
    }
    if (!mounted || gen != _preloadGeneration) return;

    if (_chapterIdx > 0 &&
        (_prevChapter == null || _prevChapter!.index != _chapterIdx - 1)) {
      try {
        loadedPrev = await loader.loadChapterContent(
          book,
          _chapters[_chapterIdx - 1],
          settings,
        );
      } catch (_) {}
    }
    if (!mounted || gen != _preloadGeneration) return;

    if (loadedNext != null || loadedPrev != null) {
      setState(() {
        if (loadedNext != null) {
          _nextChapter = loadedNext;
          _nextChapterPages = _lastViewport != null
              ? _paginateText(
                  loadedNext.text,
                  _lastViewport!,
                  _lastSafePadding,
                  settings,
                )
              : const [];
        }
        if (loadedPrev != null) {
          _prevChapter = loadedPrev;
          _prevChapterPages = _lastViewport != null
              ? _paginateText(
                  loadedPrev.text,
                  _lastViewport!,
                  _lastSafePadding,
                  settings,
                )
              : const [];
        }
      });
    }
  }

  bool _computeIsDualSpread(Size viewport, BookReaderSettings settings) {
    if (_isNativePdfBitmapMode || settings.pageTurnMode == PageTurnMode.scroll) {
      return false;
    }
    return switch (settings.pageLayoutMode) {
      BookPageLayoutMode.single => false,
      BookPageLayoutMode.dual => viewport.width >= kForcedDualMinWidth,
      BookPageLayoutMode.auto =>
        viewport.width >= kDualPageMinWidth && viewport.width > viewport.height,
    };
  }

  int get _pageStep => _isDualSpread ? 2 : 1;

  List<BookPageSlice> _paginateText(
    String text,
    Size viewport,
    EdgeInsets safePadding,
    BookReaderSettings settings,
  ) {
    final dual = _computeIsDualSpread(viewport, settings);
    final double usableWidth;
    if (dual) {
      final outerH = settings.horizontalPadding.clamp(16.0, 32.0);
      const gutter = 44.0;
      usableWidth =
          ((viewport.width - outerH * 2 - gutter) / 2).clamp(160.0, 640.0);
    } else {
      final colWidth = math.min(viewport.width, kMaxSingleReaderWidth);
      usableWidth = (colWidth - settings.horizontalPadding * 2)
          .clamp(100.0, kMaxSingleReaderWidth);
    }
    final usableHeight =
        (viewport.height - safePadding.top - safePadding.bottom - 96.0)
            .clamp(140.0, 2000.0);
    return BookPaginator.paginate(
      text: text,
      maxWidth: usableWidth,
      maxHeight: usableHeight,
      style: TextStyle(
        fontSize: settings.fontSize,
        height: settings.lineHeight,
        color: settings.paperTheme.foreground,
      ),
      indentParagraphs: settings.indentFirstLine,
      paragraphSpacing: settings.paragraphSpacing,
    );
  }

  void _ensurePaginated(
    Size viewport,
    EdgeInsets safePadding,
    BookReaderSettings settings,
  ) {
    final chapter = _loadedChapter;
    if (chapter == null) return;
    final dual = _computeIsDualSpread(viewport, settings);
    final hash = Object.hash(
      chapter.index,
      chapter.text.length,
      settings.fontSize,
      settings.lineHeight,
      settings.paragraphSpacing,
      settings.horizontalPadding,
      settings.indentFirstLine,
      settings.pageLayoutMode,
      dual,
      viewport.width.round(),
      viewport.height.round(),
      safePadding.top.round(),
      safePadding.bottom.round(),
    );
    if (_pages.isNotEmpty &&
        _lastViewport == viewport &&
        _lastSafePadding == safePadding &&
        _lastSettingsHash == hash) {
      return;
    }
    _lastViewport = viewport;
    _lastSafePadding = safePadding;
    _lastSettingsHash = hash;
    _isDualSpread = dual;

    final slices = _paginateText(chapter.text, viewport, safePadding, settings);
    _pages = slices;
    final rawIdx = BookPaginator.findPageForOffset(slices, _anchorCharOffset);
    _pageIdx = dual ? (rawIdx ~/ 2) * 2 : rawIdx;

    if (_prevChapter != null) {
      _prevChapterPages =
          _paginateText(_prevChapter!.text, viewport, safePadding, settings);
    }
    if (_nextChapter != null) {
      _nextChapterPages =
          _paginateText(_nextChapter!.text, viewport, safePadding, settings);
    }
  }

  Future<void> _persistProgress({bool flushTime = false}) async {
    final book = _book;
    if (book == null || _chapters.isEmpty) return;
    final chProgress =
        _pages.isNotEmpty ? (_pageIdx + 1) / _pages.length : 0.0;
    final totalRatio =
        ((_chapterIdx + chProgress) / _chapters.length).clamp(0.0, 1.0);
    final deltaSec = flushTime
        ? DateTime.now().difference(_sessionStart).inSeconds.clamp(0, 7200)
        : 0;
    if (flushTime) _sessionStart = DateTime.now();

    try {
      await _db.updateBookProgress(
        id: book.id,
        chapterIndex: _chapterIdx,
        charOffset: _anchorCharOffset,
        chapterTitle: _chapters[_chapterIdx].title,
        progressRatio: totalRatio,
        readingTimeDeltaSec: deltaSec,
      );
    } catch (_) {}
  }

  bool get _isNativePdfBitmapMode {
    final settings = ref.read(bookReaderSettingsProvider);
    return _book != null &&
        _book!.format.toUpperCase() == 'PDF' &&
        File(_book!.filePath).existsSync() &&
        !settings.pdfReflowMode;
  }

  bool get _canTurnNext {
    if (_isNativePdfBitmapMode) {
      return _chapterIdx + 1 < _chapters.length;
    }
    if (_pages.isEmpty) return _chapterIdx + 1 < _chapters.length;
    return _pageIdx + _pageStep < _pages.length ||
        _chapterIdx + 1 < _chapters.length;
  }

  bool get _canTurnPrev {
    if (_isNativePdfBitmapMode) {
      return _chapterIdx > 0;
    }
    if (_pages.isEmpty) return _chapterIdx > 0;
    return _pageIdx > 0 || _chapterIdx > 0;
  }

  void _triggerTurnNext() {
    if (_loading) return;
    _clearSelectionAndInspector();
    final settings = ref.read(bookReaderSettingsProvider);

    if (_isNativePdfBitmapMode) {
      if (_chapterIdx + 1 < _chapters.length) {
        _loadChapter(_chapterIdx + 1);
      } else {
        _toast(context.l10n.lastPageToast);
      }
      return;
    }

    if (settings.pageTurnMode == PageTurnMode.scroll) {
      _scrollPageBy(forward: true);
      return;
    }

    if (!_pageTurnCtrl.turnNext()) {
      if (!_pageTurnCtrl.isAnimating) {
        _commitTurnNext();
      }
    }
  }

  void _triggerTurnPrev() {
    if (_loading) return;
    _clearSelectionAndInspector();
    final settings = ref.read(bookReaderSettingsProvider);

    if (_isNativePdfBitmapMode) {
      if (_chapterIdx > 0) {
        _loadChapter(_chapterIdx - 1);
      } else {
        _toast(context.l10n.firstPageToast);
      }
      return;
    }

    if (settings.pageTurnMode == PageTurnMode.scroll) {
      _scrollPageBy(forward: false);
      return;
    }

    if (!_pageTurnCtrl.turnPrev()) {
      if (!_pageTurnCtrl.isAnimating) {
        _commitTurnPrev();
      }
    }
  }

  void _scrollPageBy({required bool forward}) {
    if (!_scrollCtrl.hasClients) {
      if (forward && _chapterIdx + 1 < _chapters.length) {
        _loadChapter(_chapterIdx + 1);
      } else if (!forward && _chapterIdx > 0) {
        _loadChapter(_chapterIdx - 1, jumpEnd: true);
      } else {
        _toast(
          forward ? context.l10n.lastPageToast : context.l10n.firstPageToast,
        );
      }
      return;
    }

    final pos = _scrollCtrl.position;
    final step = (pos.viewportDimension * 0.82).clamp(160.0, 900.0);
    if (forward) {
      if (pos.pixels >= pos.maxScrollExtent - 10) {
        if (_chapterIdx + 1 < _chapters.length) {
          _loadChapter(_chapterIdx + 1);
        } else {
          _toast(context.l10n.lastPageToast);
        }
      } else {
        final target = (pos.pixels + step).clamp(0.0, pos.maxScrollExtent);
        _scrollCtrl.animateTo(
          target,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
        );
      }
    } else {
      if (pos.pixels <= 10) {
        if (_chapterIdx > 0) {
          _loadChapter(_chapterIdx - 1, jumpEnd: true);
        } else {
          _toast(context.l10n.firstPageToast);
        }
      } else {
        final target = (pos.pixels - step).clamp(0.0, pos.maxScrollExtent);
        _scrollCtrl.animateTo(
          target,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  void _commitTurnNext() {
    final nextIdx = _pageIdx + _pageStep;
    if (_pages.isNotEmpty && nextIdx < _pages.length) {
      setState(() {
        _pageIdx = _isDualSpread ? (nextIdx ~/ 2) * 2 : nextIdx;
        _anchorCharOffset = _pages[_pageIdx].startOffset;
        _menuVisible = false;
        _sheetTab = null;
        _activeSelection = null;
        _inspectedAnnotation = null;
      });
      _persistProgress();
      if (_ttsPlaying && !_ttsExcerptOnly) {
        unawaited(_speakCurrentPage());
      }
      return;
    }

    if (_chapterIdx + 1 < _chapters.length) {
      if (_nextChapter != null &&
          _nextChapter!.index == _chapterIdx + 1 &&
          _nextChapterPages.isNotEmpty) {
        final gen = ++_preloadGeneration;
        setState(() {
          _prevChapter = _loadedChapter;
          _prevChapterPages = _pages;
          _chapterIdx++;
          _loadedChapter = _nextChapter;
          _pages = _nextChapterPages;
          _pageIdx = 0;
          _anchorCharOffset = _pages.first.startOffset;
          _nextChapter = null;
          _nextChapterPages = const [];
          _menuVisible = false;
          _sheetTab = null;
          _activeSelection = null;
          _inspectedAnnotation = null;
        });
        _persistProgress();
        unawaited(_preloadAdjacentChapters(gen));
        if (_ttsPlaying && !_ttsExcerptOnly) {
          unawaited(_speakCurrentPage());
        }
      } else {
        _loadChapter(_chapterIdx + 1).then((_) {
          if (mounted && _ttsPlaying && !_ttsExcerptOnly) {
            unawaited(_speakCurrentPage());
          }
        });
      }
      return;
    }

    _toast(context.l10n.lastPageToast);
  }

  void _commitTurnPrev() {
    if (_pages.isNotEmpty && _pageIdx > 0) {
      final rawPrev = (_pageIdx - _pageStep).clamp(0, _pages.length - 1);
      final targetIdx = _isDualSpread ? (rawPrev ~/ 2) * 2 : rawPrev;
      setState(() {
        _pageIdx = targetIdx;
        _anchorCharOffset = _pages[_pageIdx].startOffset;
        _menuVisible = false;
        _sheetTab = null;
        _activeSelection = null;
        _inspectedAnnotation = null;
      });
      _persistProgress();
      if (_ttsPlaying && !_ttsExcerptOnly) {
        unawaited(_speakCurrentPage());
      }
      return;
    }

    if (_chapterIdx > 0) {
      if (_prevChapter != null &&
          _prevChapter!.index == _chapterIdx - 1 &&
          _prevChapterPages.isNotEmpty) {
        final gen = ++_preloadGeneration;
        final rawLast = _prevChapterPages.length - 1;
        final targetLast = _isDualSpread ? (rawLast ~/ 2) * 2 : rawLast;
        setState(() {
          _nextChapter = _loadedChapter;
          _nextChapterPages = _pages;
          _chapterIdx--;
          _loadedChapter = _prevChapter;
          _pages = _prevChapterPages;
          _pageIdx = targetLast;
          _anchorCharOffset = _pages[_pageIdx].startOffset;
          _prevChapter = null;
          _prevChapterPages = const [];
          _menuVisible = false;
          _sheetTab = null;
          _activeSelection = null;
          _inspectedAnnotation = null;
        });
        _persistProgress();
        unawaited(_preloadAdjacentChapters(gen));
        if (_ttsPlaying && !_ttsExcerptOnly) {
          unawaited(_speakCurrentPage());
        }
      } else {
        _loadChapter(_chapterIdx - 1, jumpEnd: true).then((_) {
          if (mounted && _ttsPlaying && !_ttsExcerptOnly) {
            unawaited(_speakCurrentPage());
          }
        });
      }
      return;
    }

    _toast(context.l10n.firstPageToast);
  }

  bool _tryInterceptCanvasTap(Offset globalPosition) {
    if (_menuVisible) return false;
    if (_activeSelection != null) {
      setState(() => _activeSelection = null);
      return true;
    }
    if (_leftCanvasKey.currentState?.tryHandleTapAtGlobal(globalPosition) ==
            true ||
        _rightCanvasKey.currentState?.tryHandleTapAtGlobal(globalPosition) ==
            true) {
      return true;
    }
    if (_inspectedAnnotation != null) {
      setState(() => _inspectedAnnotation = null);
      return true;
    }
    return false;
  }

  void _handleTapNormalized(double nx, double ny) {
    if (_menuVisible) {
      setState(() {
        _menuVisible = false;
        _sheetTab = null;
      });
      return;
    }
    if (_activeSelection != null || _inspectedAnnotation != null) {
      _clearSelectionAndInspector();
      return;
    }
    final settings = ref.read(bookReaderSettingsProvider);
    final action = settings.resolveTapAction(nx, ny);
    switch (action) {
      case TapZoneAction.prevPage:
        _triggerTurnPrev();
      case TapZoneAction.nextPage:
        _triggerTurnNext();
      case TapZoneAction.toggleMenu:
        setState(() {
          _menuVisible = true;
          _sheetTab = null;
        });
      case TapZoneAction.bookmark:
        _togglePageBookmark();
      case TapZoneAction.tts:
        _toggleTts();
    }
  }

  // --- Per-Page Toggleable Bookmarks ---

  int _currentScrollEstimatedOffset() {
    final settings = ref.read(bookReaderSettingsProvider);
    final formatted = BookPaginator.formatParagraphs(
      _loadedChapter?.text ?? '',
      indent: settings.indentFirstLine,
    );
    if (formatted.isEmpty || !_scrollCtrl.hasClients) return _anchorCharOffset;
    final maxExt = _scrollCtrl.position.maxScrollExtent;
    if (maxExt <= 0) return 0;
    final ratio = (_scrollCtrl.offset / maxExt).clamp(0.0, 1.0);
    return (ratio * formatted.length).round().clamp(0, formatted.length);
  }

  List<Annotation> _bookmarksForPage({
    required List<Annotation> allAnnotations,
    required int chapterIndex,
    List<BookPageSlice>? pages,
    int? pageIndex,
    bool isScrollMode = false,
  }) {
    final chBookmarks = allAnnotations
        .where((a) =>
            !a.isDeleted &&
            a.kind == 'bookmark' &&
            a.chapterIndex == chapterIndex)
        .toList();
    if (chBookmarks.isEmpty) return const [];

    if (_isNativePdfBitmapMode) {
      return chBookmarks;
    }
    if (isScrollMode) {
      final est = _currentScrollEstimatedOffset();
      return chBookmarks.where((a) {
        final off = ParsedAnnotationLocator.parse(a.locator).startOffset;
        return (off - est).abs() <= 320;
      }).toList();
    }
    if (pages != null && pages.isNotEmpty && pageIndex != null) {
      final secondIdx = _isDualSpread && pageIndex + 1 < pages.length
          ? pageIndex + 1
          : null;
      return chBookmarks.where((a) {
        final off = ParsedAnnotationLocator.parse(a.locator).startOffset;
        final bmPage = BookPaginator.findPageForOffset(pages, off);
        return bmPage == pageIndex || (secondIdx != null && bmPage == secondIdx);
      }).toList();
    }
    return chBookmarks;
  }

  Future<void> _togglePageBookmark() async {
    final book = _book;
    if (book == null) return;
    final settings = ref.read(bookReaderSettingsProvider);
    final isScroll =
        !_isNativePdfBitmapMode && settings.pageTurnMode == PageTurnMode.scroll;

    final allAnns = await _db.getAnnotationsFor(book.contentHash);
    final existingOnPage = _bookmarksForPage(
      allAnnotations: allAnns,
      chapterIndex: _chapterIdx,
      pages: _pages,
      pageIndex: _pageIdx,
      isScrollMode: isScroll,
    );

    if (existingOnPage.isNotEmpty) {
      for (final b in existingOnPage) {
        await _db.softDeleteAnnotation(b.uuid);
      }
      await _refreshAnnotations();
      if (mounted) _toast(context.l10n.bookmarkRemovedToast);
      return;
    }

    final int targetOffset;
    final String rawPageText;
    if (isScroll) {
      final formatted = BookPaginator.formatParagraphs(
        _loadedChapter?.text ?? '',
        indent: settings.indentFirstLine,
      );
      targetOffset = _currentScrollEstimatedOffset();
      final subStart = targetOffset.clamp(0, formatted.length);
      final subEnd = (subStart + 60).clamp(subStart, formatted.length);
      rawPageText = formatted.substring(subStart, subEnd);
    } else if (_pages.isNotEmpty) {
      targetOffset = _pages[_pageIdx].startOffset;
      rawPageText = _pages[_pageIdx].text;
    } else {
      targetOffset = _anchorCharOffset;
      rawPageText = _loadedChapter?.text ?? '';
    }

    final cleaned = rawPageText.replaceAll('\n', ' ').trim();
    final snippet = cleaned.length > 48
        ? '${cleaned.substring(0, 48)}...'
        : (cleaned.isEmpty ? (_chapters[_chapterIdx].title) : cleaned);
    final now = DateTime.now().millisecondsSinceEpoch;

    await _db.upsertAnnotation(
      AnnotationsCompanion.insert(
        uuid: 'bm_${book.id}_${_chapterIdx}_$targetOffset',
        contentHash: book.contentHash,
        mediaKind: 'book',
        kind: 'bookmark',
        chapterIndex: drift.Value(_chapterIdx),
        locator: 'ch:$_chapterIdx;off:$targetOffset',
        excerpt: drift.Value(snippet),
        noteText: const drift.Value(''),
        updatedAtMs: now,
      ),
    );
    await _refreshAnnotations();
    if (mounted) _toast(context.l10n.bookmarkAddedToast);
  }

  // --- Interactive Highlight / Underline (`划线`) & Notes ---

  void _startToolbarHighlightSelection() {
    if (_isNativePdfBitmapMode) {
      _toast(context.l10n.pdfBitmapNoHighlightToast);
      return;
    }
    final settings = ref.read(bookReaderSettingsProvider);
    final isScroll = settings.pageTurnMode == PageTurnMode.scroll;

    String targetText = '';
    int baseOff = 0;
    if (isScroll) {
      final formatted = BookPaginator.formatParagraphs(
        _loadedChapter?.text ?? '',
        indent: settings.indentFirstLine,
      );
      baseOff = _currentScrollEstimatedOffset()
          .clamp(0, formatted.isEmpty ? 0 : formatted.length - 1);
      final endWindow = (baseOff + 240).clamp(baseOff, formatted.length);
      targetText = formatted.substring(baseOff, endWindow);
    } else if (_pages.isNotEmpty) {
      final slice = !_pages[_pageIdx].isPlaceholder
          ? _pages[_pageIdx]
          : (_isDualSpread &&
                  _pageIdx + 1 < _pages.length &&
                  !_pages[_pageIdx + 1].isPlaceholder
              ? _pages[_pageIdx + 1]
              : null);
      if (slice != null) {
        baseOff = slice.startOffset;
        targetText = slice.text;
      }
    }

    if (targetText.trim().isEmpty) {
      _toast(context.l10n.noHighlightableTextToast);
      return;
    }

    final initial = ReaderHighlightCanvas.selectInitialClause(targetText);
    var ls = initial.localStart;
    var le = initial.localEnd;
    while (ls < le - 1 && targetText[ls].trim().isEmpty) {
      ls++;
    }
    while (le > ls + 1 && targetText[le - 1].trim().isEmpty) {
      le--;
    }
    final excerpt = targetText.substring(ls, le);
    _activateSelection(
      baseOff + ls,
      baseOff + le,
      excerpt,
    );
  }

  void _activateSelection(int s, int e, String txt) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    setState(() {
      _menuVisible = false;
      _sheetTab = null;
      _inspectedAnnotation = null;
      _activeSelection = (start: s, end: e, text: txt);
    });
  }

  void _activateHighlightInspector(Annotation ann) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    setState(() {
      _menuVisible = false;
      _sheetTab = null;
      _activeSelection = null;
      _selectedHighlightColor = ann.colorHex;
      _inspectedAnnotation = ann;
    });
  }

  bool _shouldPlaceHighlightBarAtBottom() {
    if (_pages.isEmpty) return true;
    final left = _pages[_pageIdx];
    final right = _isDualSpread && _pageIdx + 1 < _pages.length
        ? _pages[_pageIdx + 1]
        : null;
    final targetOffset = _activeSelection?.start ??
        (_inspectedAnnotation != null
            ? ParsedAnnotationLocator.parse(_inspectedAnnotation!.locator)
                .startOffset
            : left.startOffset);
    final targetSlice =
        (right != null && targetOffset >= right.startOffset) ? right : left;
    if (targetSlice.text.isEmpty) return true;
    final localRatio =
        (targetOffset - targetSlice.startOffset) / targetSlice.text.length;
    return localRatio < 0.42;
  }

  Future<void> _saveActiveHighlight({
    String? noteText,
    String? colorHexOverride,
    bool keepInspecting = false,
  }) async {
    final book = _book;
    final sel = _activeSelection;
    if (book == null || sel == null || sel.text.trim().isEmpty) return;

    final chosenColor = colorHexOverride ?? _selectedHighlightColor;
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = _annotations.where((a) {
      if (a.isDeleted ||
          a.chapterIndex != _chapterIdx ||
          (a.kind != 'highlight' && a.kind != 'note')) {
        return false;
      }
      final loc = ParsedAnnotationLocator.parse(a.locator);
      return loc.startOffset == sel.start && loc.endOffset == sel.end;
    }).firstOrNull;

    final cleanNote =
        noteText != null ? noteText.trim() : (existing?.noteText ?? '');
    final targetUuid =
        existing?.uuid ?? 'hl_${book.id}_${now}_${sel.start}_${sel.end}';
    final targetKind = cleanNote.isNotEmpty ? 'note' : 'highlight';

    await _db.upsertAnnotation(
      AnnotationsCompanion.insert(
        uuid: targetUuid,
        contentHash: book.contentHash,
        mediaKind: 'book',
        kind: targetKind,
        chapterIndex: drift.Value(_chapterIdx),
        locator: 'ch:$_chapterIdx;off:${sel.start};end:${sel.end}',
        excerpt: drift.Value(sel.text.trim()),
        noteText: drift.Value(cleanNote),
        colorHex: drift.Value(chosenColor),
        isDeleted: const drift.Value(false),
        updatedAtMs: now,
      ),
    );
    await _refreshAnnotations();
    if (!mounted) return;
    final savedAnn =
        _annotations.where((a) => a.uuid == targetUuid).firstOrNull;
    final l10n = context.l10n;
    setState(() {
      _selectedHighlightColor = chosenColor;
      _activeSelection = null;
      _inspectedAnnotation = keepInspecting ? savedAnn : null;
    });
    _toast(
      cleanNote.isNotEmpty ? l10n.noteSavedToast : l10n.highlightSavedToast,
    );
  }

  Future<void> _promptNoteForActiveSelection() async {
    final sel = _activeSelection;
    if (sel == null) return;
    final l10n = context.l10n;
    final noteCtrl = TextEditingController();
    final savedNote = await showInkModal<String>(
      context: context,
      title: l10n.addNoteTitle,
      subtitle: '“${sel.text}”',
      disposables: [noteCtrl],
      builder: (ctx) => InkTextField(
        controller: noteCtrl,
        autofocus: true,
        label: l10n.yourNoteLabel,
        hintText: l10n.yourNoteHint,
        maxLines: 3,
        minLines: 2,
      ),
      actionsBuilder: (ctx) => [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(noteCtrl.text.trim()),
          child: Text(l10n.saveHighlightNote),
        ),
      ],
    );
    if (savedNote != null && mounted) {
      await _saveActiveHighlight(noteText: savedNote);
    }
  }

  Future<void> _updateInspectedHighlightColor(
    Annotation ann,
    String colorHex,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.upsertAnnotation(
      AnnotationsCompanion.insert(
        uuid: ann.uuid,
        contentHash: ann.contentHash,
        mediaKind: ann.mediaKind,
        kind: ann.kind,
        chapterIndex: drift.Value(ann.chapterIndex),
        locator: ann.locator,
        excerpt: drift.Value(ann.excerpt),
        noteText: drift.Value(ann.noteText),
        colorHex: drift.Value(colorHex),
        isDeleted: const drift.Value(false),
        updatedAtMs: now,
      ),
    );
    await _refreshAnnotations();
    if (mounted) {
      setState(() {
        _selectedHighlightColor = colorHex;
        _inspectedAnnotation = ann.copyWith(
          colorHex: colorHex,
          updatedAtMs: now,
        );
      });
    }
  }

  Future<void> _editInspectedHighlightNote(Annotation ann) async {
    final l10n = context.l10n;
    final noteCtrl = TextEditingController(text: ann.noteText);
    final updatedNote = await showInkModal<String>(
      context: context,
      title: l10n.editNoteTitle,
      subtitle: ann.excerpt.isNotEmpty ? '“${ann.excerpt}”' : null,
      disposables: [noteCtrl],
      builder: (ctx) => InkTextField(
        controller: noteCtrl,
        autofocus: true,
        label: l10n.yourNoteLabel,
        hintText: l10n.yourNoteHint,
        maxLines: 3,
        minLines: 2,
      ),
      actionsBuilder: (ctx) => [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(noteCtrl.text.trim()),
          child: Text(l10n.save),
        ),
      ],
    );
    if (updatedNote == null || !mounted) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final nextKind = updatedNote.isNotEmpty ? 'note' : 'highlight';
    await _db.upsertAnnotation(
      AnnotationsCompanion.insert(
        uuid: ann.uuid,
        contentHash: ann.contentHash,
        mediaKind: ann.mediaKind,
        kind: nextKind,
        chapterIndex: drift.Value(ann.chapterIndex),
        locator: ann.locator,
        excerpt: drift.Value(ann.excerpt),
        noteText: drift.Value(updatedNote),
        colorHex: drift.Value(ann.colorHex),
        isDeleted: const drift.Value(false),
        updatedAtMs: now,
      ),
    );
    await _refreshAnnotations();
    if (mounted) {
      setState(() {
        _inspectedAnnotation = ann.copyWith(
          kind: nextKind,
          noteText: updatedNote,
          updatedAtMs: now,
        );
      });
    }
  }

  // --- TTS Voice Reading & Sleep Timer ---

  Future<void> _stopTtsPlayback({String? message}) async {
    _ttsExcerptOnly = false;
    _ttsPausedForSettings = false;
    await _ttsCtrl.stop();
    if (mounted) {
      setState(() => _ttsPlaying = false);
      if (message != null) _toast(message);
    }
  }

  void _handleTtsPageCompleted() {
    if (!mounted || !_ttsPlaying || _ttsPausedForSettings) return;
    if (_ttsExcerptOnly) {
      unawaited(_stopTtsPlayback());
      return;
    }
    final curSettings = ref.read(bookReaderSettingsProvider);
    final ttsCfg = ref.read(ttsConfigProvider);
    final isScroll =
        !_isNativePdfBitmapMode && curSettings.pageTurnMode == PageTurnMode.scroll;

    if (ttsCfg.sleepAtChapterEnd) {
      if (isScroll) {
        final formatted = BookPaginator.formatParagraphs(
          _loadedChapter?.text ?? '',
          indent: curSettings.indentFirstLine,
        );
        if (_nextScrollChunkEnd(formatted, _ttsScrollOffset) >=
            formatted.length) {
          unawaited(
            _stopTtsPlayback(message: context.l10n.ttsSleepChapterDoneToast),
          );
          return;
        }
      } else if (_pageIdx + _pageStep >= _pages.length) {
        unawaited(
          _stopTtsPlayback(message: context.l10n.ttsSleepChapterDoneToast),
        );
        return;
      }
    }

    if (isScroll) {
      unawaited(_advanceScrollTts(curSettings));
    } else if (curSettings.ttsAutoTurnPage && _canTurnNext) {
      _commitTurnNext();
    } else {
      unawaited(_stopTtsPlayback());
    }
  }

  Future<void> _openTtsSettingsFromReader() async {
    final wasPlaying = _ttsPlaying;
    if (wasPlaying) {
      _ttsPausedForSettings = true;
      await _ttsCtrl.pause();
    }
    if (!mounted) return;
    await context.push('/mine/tts-settings');
    if (!mounted) return;
    _ttsPausedForSettings = false;
    if (wasPlaying && _ttsPlaying) {
      final settings = ref.read(bookReaderSettingsProvider);
      _ttsCtrl.armSleepTimer(settings.ttsSleepTimerMinutes);
      if (!_ttsExcerptOnly) {
        await _speakCurrentPage();
      } else {
        await _stopTtsPlayback();
      }
    }
  }

  Future<void> _toggleTts() async {
    if (_ttsPlaying || _ttsCtrl.isActive) {
      await _stopTtsPlayback(message: context.l10n.ttsStoppedToast);
    } else {
      final settings = ref.read(bookReaderSettingsProvider);
      final l10n = context.l10n;
      final isScroll =
          !_isNativePdfBitmapMode && settings.pageTurnMode == PageTurnMode.scroll;
      if (isScroll) {
        _ttsScrollOffset = _currentScrollEstimatedOffset();
      }
      setState(() {
        _ttsPlaying = true;
        _ttsExcerptOnly = false;
      });
      _ttsCtrl.armSleepTimer(settings.ttsSleepTimerMinutes);
      final ok = await _speakCurrentPage();
      if (!mounted) return;
      if (ok) {
        _toast(l10n.ttsStartedToast);
      } else {
        await _stopTtsPlayback(message: l10n.ttsUnavailableToast);
      }
    }
  }

  Future<void> _speakArbitraryText(String rawText) async {
    final chunks = TtsTextChunker.split(rawText.replaceAll('\n', ' ').trim());
    if (chunks.isEmpty) return;
    final settings = ref.read(bookReaderSettingsProvider);
    final ttsCfg = ref.read(ttsConfigProvider);
    setState(() {
      _ttsPlaying = true;
      _ttsExcerptOnly = true;
    });
    _ttsCtrl.armSleepTimer(settings.ttsSleepTimerMinutes);
    final ok = await _ttsCtrl.startChunks(
      chunks,
      readerSettings: settings,
      ttsConfig: ttsCfg,
      excerptOnly: true,
    );
    if (!mounted) return;
    if (!ok) {
      await _stopTtsPlayback(message: context.l10n.ttsUnavailableToast);
    }
  }

  int _nextScrollChunkEnd(String formatted, int from) {
    if (from >= formatted.length) return formatted.length;
    final maxEnd = (from + 700).clamp(from, formatted.length);
    if (maxEnd >= formatted.length) return formatted.length;
    final slice = formatted.substring(from, maxEnd);
    final idx = slice.lastIndexOf(RegExp(r'[。！？\n]'));
    if (idx >= 120) return from + idx + 1;
    return maxEnd;
  }

  Future<void> _advanceScrollTts(BookReaderSettings curSettings) async {
    final formatted = BookPaginator.formatParagraphs(
      _loadedChapter?.text ?? '',
      indent: curSettings.indentFirstLine,
    );
    final nextStart = _nextScrollChunkEnd(formatted, _ttsScrollOffset);
    if (nextStart < formatted.length) {
      _ttsScrollOffset = nextStart;
      if (_scrollCtrl.hasClients && formatted.isNotEmpty) {
        final maxExt = _scrollCtrl.position.maxScrollExtent;
        if (maxExt > 0) {
          final target =
              ((_ttsScrollOffset / formatted.length) * maxExt).clamp(0.0, maxExt);
          unawaited(
            _scrollCtrl.animateTo(
              target,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
            ),
          );
        }
      }
      await _speakCurrentPage();
    } else if (curSettings.ttsAutoTurnPage && _chapterIdx + 1 < _chapters.length) {
      _ttsScrollOffset = 0;
      await _loadChapter(_chapterIdx + 1);
      if (mounted && _ttsPlaying) {
        await _speakCurrentPage();
      }
    } else {
      await _stopTtsPlayback();
    }
  }

  List<TtsSentenceChunk> _buildCurrentPageChunks(BookReaderSettings settings) {
    final isScroll =
        !_isNativePdfBitmapMode && settings.pageTurnMode == PageTurnMode.scroll;
    if (isScroll) {
      final formatted = BookPaginator.formatParagraphs(
        _loadedChapter?.text ?? '',
        indent: settings.indentFirstLine,
      );
      if (formatted.isEmpty) return const [];
      final s = _ttsScrollOffset.clamp(0, formatted.length - 1);
      final e = _nextScrollChunkEnd(formatted, s);
      return TtsTextChunker.split(formatted.substring(s, e), baseOffset: s);
    }
    if (_pages.isNotEmpty) {
      final chunks = <TtsSentenceChunk>[];
      final left = _pages[_pageIdx];
      if (!left.isPlaceholder && left.text.trim().isNotEmpty) {
        chunks.addAll(
          TtsTextChunker.split(left.text, baseOffset: left.startOffset),
        );
      }
      if (_isDualSpread && _pageIdx + 1 < _pages.length) {
        final right = _pages[_pageIdx + 1];
        if (!right.isPlaceholder && right.text.trim().isNotEmpty) {
          final rawRight =
              TtsTextChunker.split(right.text, baseOffset: right.startOffset);
          for (final c in rawRight) {
            chunks.add(
              TtsSentenceChunk(
                index: chunks.length,
                startOffset: c.startOffset,
                endOffset: c.endOffset,
                text: c.text,
              ),
            );
          }
        }
      }
      return chunks;
    }
    final raw = _loadedChapter?.text ?? '';
    return TtsTextChunker.split(raw);
  }

  Future<bool> _speakCurrentPage() async {
    final settings = ref.read(bookReaderSettingsProvider);
    final ttsCfg = ref.read(ttsConfigProvider);
    final chunks = _buildCurrentPageChunks(settings);
    if (chunks.isEmpty) return false;
    return _ttsCtrl.startChunks(
      chunks,
      readerSettings: settings,
      ttsConfig: ttsCfg,
    );
  }

  void _toggleAutoScroll() {
    if (_autoScrolling) {
      _autoScrollTimer?.cancel();
      setState(() => _autoScrolling = false);
    } else {
      ref.read(bookReaderSettingsProvider.notifier).update(
            (s) => s.copyWith(pageTurnMode: PageTurnMode.scroll),
          );
      setState(() {
        _autoScrolling = true;
        _menuVisible = false;
        _sheetTab = null;
      });
      _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
        if (!_scrollCtrl.hasClients || _loading || _scrollJumpingToEnd) return;
        final speed = ref.read(bookReaderSettingsProvider).autoScrollSpeed;
        final next = _scrollCtrl.offset + speed * 0.05;
        if (next >= _scrollCtrl.position.maxScrollExtent) {
          if (_chapterIdx + 1 < _chapters.length) {
            _loadChapter(_chapterIdx + 1);
          } else {
            _autoScrollTimer?.cancel();
            setState(() => _autoScrolling = false);
            _toast(context.l10n.autoScrollReachedEnd);
          }
        } else {
          _scrollCtrl.jumpTo(next);
        }
      });
    }
  }

  Future<void> _exportNotesMarkdown() async {
    final book = _book;
    if (book == null) return;
    final l10n = context.l10n;
    final notes = await _db.getAnnotationsFor(book.contentHash);
    final buf = StringBuffer()
      ..writeln('# ${book.title}')
      ..writeln('> ${localizedAuthor(l10n, book.author)}\n');
    for (final n in notes) {
      buf.writeln('- **${l10n.chapterLabelShort(n.chapterIndex + 1)}**：${n.excerpt}');
      if (n.noteText.isNotEmpty) buf.writeln('  - ${l10n.notePrefix(n.noteText)}');
    }
    await Clipboard.setData(ClipboardData(text: buf.toString()));
    _toast(l10n.exportNotesSuccess(notes.length));
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
          shape: const StadiumBorder(),
          margin: EdgeInsets.fromLTRB(
            24,
            0,
            24,
            _menuVisible ? 168 : 112,
          ),
          duration: const Duration(milliseconds: 1400),
        ),
      );
  }

  Widget _buildPageWidget(
    BookPageSlice slice,
    BookReaderSettings settings,
    int totalPages,
    List<Annotation> allAnnotations, {
    required List<BookPageSlice> chapterPages,
    required Color accentColor,
    int? chapterIndexOverride,
    String? chapterTitleOverride,
    bool interactive = false,
    GlobalKey<ReaderHighlightCanvasState>? canvasKey,
    bool embeddedColumn = false,
  }) {
    final l10n = context.l10n;
    final paper = settings.paperTheme;
    final isDarkPaper = paper.background.computeLuminance() < 0.25;
    final chIdx = chapterIndexOverride ?? _chapterIdx;
    final chapterTitle = chapterTitleOverride ??
        (_chapters.isNotEmpty ? _chapters[chIdx].title : '');
    final safeTotal = totalPages <= 0 ? 1 : totalPages;
    final overallPct = _chapters.isEmpty
        ? 0.0
        : ((chIdx + (slice.pageIndex + 1) / safeTotal) /
                _chapters.length *
                100)
            .clamp(0.0, 100.0);

    final chapterHighlights = allAnnotations
        .where((a) =>
            !a.isDeleted &&
            a.chapterIndex == chIdx &&
            (a.kind == 'highlight' || a.kind == 'note'))
        .toList();
    final pageHasBookmark = _bookmarksForPage(
      allAnnotations: allAnnotations,
      chapterIndex: chIdx,
      pages: chapterPages,
      pageIndex: slice.pageIndex,
    ).isNotEmpty;

    final colWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                chapterTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: paper.secondary),
              ),
            ),
            if (_ttsPlaying && interactive)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: InkIconWidget(
                  InkIcon.tts,
                  size: 13,
                  color: accentColor,
                ),
              ),
            if (pageHasBookmark)
              InkIconWidget(
                InkIcon.bookmarkFilled,
                size: 14,
                color: accentColor,
              ),
          ],
        ),
        const SizedBox(height: 14),
        Expanded(
          child: slice.isPlaceholder
              ? Center(
                  child: Text(
                    l10n.emptyChapterPlaceholder,
                    style: TextStyle(fontSize: 14, color: paper.secondary),
                  ),
                )
              : ReaderHighlightCanvas(
                  key: canvasKey,
                  text: slice.text,
                  baseOffset: slice.startOffset,
                  style: TextStyle(
                    fontSize: settings.fontSize,
                    height: settings.lineHeight,
                    color: paper.foreground,
                  ),
                  paragraphSpacing: settings.paragraphSpacing,
                  isDarkPaper: isDarkPaper,
                  accentColor: accentColor,
                  selectedColorHex: _selectedHighlightColor,
                  chapterHighlights: chapterHighlights,
                  activeSelectionGlobal: interactive && _activeSelection != null
                      ? (
                          start: _activeSelection!.start,
                          end: _activeSelection!.end,
                        )
                      : null,
                  ttsHighlightGlobal:
                      interactive ? _ttsCtrl.activeHighlightRange : null,
                  interactive: interactive && !slice.isPlaceholder,
                  onSelectionChanged: interactive ? _activateSelection : null,
                  onHighlightTapped:
                      interactive ? _activateHighlightInspector : null,
                  onDismissSelection: interactive
                      ? () => setState(() => _activeSelection = null)
                      : null,
                ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${overallPct.toStringAsFixed(1)}% · ${slice.pageIndex + 1}/$safeTotal',
              style: TextStyle(
                fontSize: 11,
                color: paper.secondary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            Text(
              _book?.format ?? 'EPUB',
              style: TextStyle(fontSize: 11, color: paper.secondary),
            ),
          ],
        ),
      ],
    );

    if (embeddedColumn) return colWidget;

    return ColoredBox(
      color: paper.background,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kMaxSingleReaderWidth),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: settings.horizontalPadding,
                vertical: 12,
              ),
              child: colWidget,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpreadOrSingleWidget({
    required int startPageIdx,
    required BookReaderSettings settings,
    required List<BookPageSlice> chapterPages,
    required List<Annotation> allAnnotations,
    required Color accentColor,
    required bool dual,
    int? chapterIndexOverride,
    String? chapterTitleOverride,
    bool interactive = false,
  }) {
    if (chapterPages.isEmpty) {
      return ColoredBox(color: settings.paperTheme.background);
    }
    final clampedIdx = startPageIdx.clamp(0, chapterPages.length - 1);
    if (!dual) {
      return _buildPageWidget(
        chapterPages[clampedIdx],
        settings,
        chapterPages.length,
        allAnnotations,
        chapterPages: chapterPages,
        accentColor: accentColor,
        chapterIndexOverride: chapterIndexOverride,
        chapterTitleOverride: chapterTitleOverride,
        interactive: interactive,
        canvasKey: interactive ? _leftCanvasKey : null,
      );
    }

    final paper = settings.paperTheme;
    final isDarkPaper = paper.background.computeLuminance() < 0.25;
    final leftSlice = chapterPages[clampedIdx];
    final rightSlice = clampedIdx + 1 < chapterPages.length
        ? chapterPages[clampedIdx + 1]
        : null;
    final outerH = settings.horizontalPadding.clamp(16.0, 32.0);
    final chIdx = chapterIndexOverride ?? _chapterIdx;
    final nextChapterTitle = chIdx + 1 < _chapters.length
        ? _chapters[chIdx + 1].title
        : null;

    return ColoredBox(
      color: paper.background,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: outerH, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _buildPageWidget(
                  leftSlice,
                  settings,
                  chapterPages.length,
                  allAnnotations,
                  chapterPages: chapterPages,
                  accentColor: accentColor,
                  chapterIndexOverride: chapterIndexOverride,
                  chapterTitleOverride: chapterTitleOverride,
                  interactive: interactive,
                  canvasKey: interactive ? _leftCanvasKey : null,
                  embeddedColumn: true,
                ),
              ),
              SizedBox(
                width: 44,
                child: Center(
                  child: Container(
                    width: 14,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          (isDarkPaper ? Colors.white : Colors.black)
                              .withValues(alpha: isDarkPaper ? 0.08 : 0.06),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: rightSlice != null
                    ? _buildPageWidget(
                        rightSlice,
                        settings,
                        chapterPages.length,
                        allAnnotations,
                        chapterPages: chapterPages,
                        accentColor: accentColor,
                        chapterIndexOverride: chapterIndexOverride,
                        chapterTitleOverride: chapterTitleOverride,
                        interactive: interactive,
                        canvasKey: interactive ? _rightCanvasKey : null,
                        embeddedColumn: true,
                      )
                    : Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              context.l10n.endOfChapterHint,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: paper.secondary,
                              ),
                            ),
                            if (nextChapterTitle != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                context.l10n.nextChapterHint(nextChapterTitle),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: paper.secondary.withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransitionPlaceholderPage(
    BookReaderSettings settings,
    String chapterTitle,
  ) {
    final paper = settings.paperTheme;
    return ColoredBox(
      color: paper.background,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: settings.horizontalPadding,
            vertical: 12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                chapterTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: paper.secondary),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    chapterTitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: settings.fontSize + 1,
                      fontWeight: FontWeight.w600,
                      color: paper.secondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final settings = ref.watch(bookReaderSettingsProvider);
    final settingsCtrl = ref.read(bookReaderSettingsProvider.notifier);
    final ttsCfg = ref.watch(ttsConfigProvider);
    final tokens = InkBoxTokens.of(context);
    final paper = settings.paperTheme;
    if (paper != BookPaperTheme.dark && paper != BookPaperTheme.oled) {
      _lastLightPaper = paper;
    }
    final isDarkPaper = paper.background.computeLuminance() < 0.25;
    final safePadding = MediaQuery.paddingOf(context);
    final isRealPdf = _book != null &&
        _book!.format.toUpperCase() == 'PDF' &&
        File(_book!.filePath).existsSync();

    final annotations = _annotations;

    final isScrollMode =
        !(isRealPdf && !settings.pdfReflowMode) &&
        settings.pageTurnMode == PageTurnMode.scroll;

    return Scaffold(
      backgroundColor: paper.background,
      body: LayoutBuilder(
        builder: (context, outerConstraints) {
          if (!_loading &&
              !(isRealPdf && !settings.pdfReflowMode) &&
              settings.pageTurnMode != PageTurnMode.scroll) {
            _ensurePaginated(outerConstraints.biggest, safePadding, settings);
          } else {
            _isDualSpread = false;
          }

          final dual = _isDualSpread;
          final step = _pageStep;
          final wideScreen = outerConstraints.maxWidth > 720;

          final currentPageBookmarked = !_loading &&
              _bookmarksForPage(
                allAnnotations: annotations,
                chapterIndex: _chapterIdx,
                pages: _pages,
                pageIndex: _pageIdx,
                isScrollMode: isScrollMode,
              ).isNotEmpty;

          final scrollChapterHighlights = annotations
              .where((a) =>
                  !a.isDeleted &&
                  a.chapterIndex == _chapterIdx &&
                  (a.kind == 'highlight' || a.kind == 'note'))
              .toList();

          return Stack(
            children: [
              if (_loading)
                Center(
                  child: CircularProgressIndicator(color: tokens.accentPrimary),
                )
              else if (isRealPdf && !settings.pdfReflowMode)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (d) {
                    final sz = MediaQuery.sizeOf(context);
                    _handleTapNormalized(
                      (d.globalPosition.dx / sz.width).clamp(0.0, 1.0),
                      (d.globalPosition.dy / sz.height).clamp(0.0, 1.0),
                    );
                  },
                  child: _NativePdfPageCanvas(
                    pdfPath: _book!.filePath,
                    pageIndex: _chapterIdx,
                    platform: ref.read(platformBridgeProvider),
                  ),
                )
              else if (settings.pageTurnMode == PageTurnMode.scroll)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (d) {
                    if (_tryInterceptCanvasTap(d.globalPosition)) return;
                    final sz = MediaQuery.sizeOf(context);
                    _handleTapNormalized(
                      (d.globalPosition.dx / sz.width).clamp(0.0, 1.0),
                      (d.globalPosition.dy / sz.height).clamp(0.0, 1.0),
                    );
                  },
                  child: SafeArea(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: kMaxSingleReaderWidth,
                        ),
                        child: Column(
                          children: [
                            Padding(
                              padding: EdgeInsets.fromLTRB(
                                settings.horizontalPadding,
                                10,
                                settings.horizontalPadding,
                                4,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      _loadedChapter?.title ?? '',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: paper.secondary,
                                      ),
                                    ),
                                  ),
                                  if (currentPageBookmarked)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 6),
                                      child: InkIconWidget(
                                        InkIcon.bookmarkFilled,
                                        size: 13,
                                        color: tokens.accentPrimary,
                                      ),
                                    ),
                                  Text(
                                    l10n.scrollModeLabel(
                                      _chapterIdx + 1,
                                      _chapters.isEmpty ? 1 : _chapters.length,
                                    ),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: paper.secondary,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: ListView(
                                controller: _scrollCtrl,
                                physics: _activeSelection != null
                                    ? const NeverScrollableScrollPhysics()
                                    : const AlwaysScrollableScrollPhysics(),
                                padding: EdgeInsets.symmetric(
                                  horizontal: settings.horizontalPadding,
                                  vertical: 14,
                                ),
                                children: [
                                  Text(
                                    _loadedChapter?.title ?? '',
                                    style: TextStyle(
                                      fontSize: settings.fontSize + 4,
                                      fontWeight: FontWeight.w700,
                                      color: paper.foreground,
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  ReaderHighlightCanvas(
                                    key: _leftCanvasKey,
                                    text: BookPaginator.formatParagraphs(
                                      _loadedChapter?.text ?? '',
                                      indent: settings.indentFirstLine,
                                    ),
                                    baseOffset: 0,
                                    style: TextStyle(
                                      fontSize: settings.fontSize,
                                      height: settings.lineHeight,
                                      color: paper.foreground,
                                    ),
                                    paragraphSpacing: settings.paragraphSpacing,
                                    isDarkPaper: isDarkPaper,
                                    accentColor: tokens.accentPrimary,
                                    selectedColorHex: _selectedHighlightColor,
                                    chapterHighlights: scrollChapterHighlights,
                                    activeSelectionGlobal:
                                        _activeSelection != null
                                            ? (
                                                start: _activeSelection!.start,
                                                end: _activeSelection!.end,
                                              )
                                            : null,
                                    ttsHighlightGlobal:
                                        _ttsCtrl.activeHighlightRange,
                                    interactive: (_loadedChapter?.text
                                            .trim()
                                            .isNotEmpty ??
                                        false),
                                    onSelectionChanged: _activateSelection,
                                    onHighlightTapped:
                                        _activateHighlightInspector,
                                    onDismissSelection: () =>
                                        setState(() => _activeSelection = null),
                                  ),
                                  const SizedBox(height: 32),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      if (_chapterIdx > 0)
                                        OutlinedButton(
                                          onPressed: () =>
                                              _loadChapter(_chapterIdx - 1),
                                          child: Text(l10n.prevChapter),
                                        )
                                      else
                                        const SizedBox.shrink(),
                                      if (_chapterIdx + 1 < _chapters.length)
                                        FilledButton(
                                          onPressed: () =>
                                              _loadChapter(_chapterIdx + 1),
                                          child: Text(l10n.nextChapter),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              else if (_pages.isNotEmpty)
                Builder(
                  builder: (context) {
                    Widget? prev;
                    if (_pageIdx > 0) {
                      final prevStart =
                          dual ? ((_pageIdx - step) ~/ 2) * 2 : _pageIdx - 1;
                      prev = _buildSpreadOrSingleWidget(
                        startPageIdx: prevStart.clamp(0, _pages.length - 1),
                        settings: settings,
                        chapterPages: _pages,
                        allAnnotations: annotations,
                        accentColor: tokens.accentPrimary,
                        dual: dual,
                      );
                    } else if (_chapterIdx > 0) {
                      if (_prevChapter != null &&
                          _prevChapter!.index == _chapterIdx - 1 &&
                          _prevChapterPages.isNotEmpty) {
                        final rawLast = _prevChapterPages.length - 1;
                        final prevLastStart = dual ? (rawLast ~/ 2) * 2 : rawLast;
                        prev = _buildSpreadOrSingleWidget(
                          startPageIdx: prevLastStart,
                          settings: settings,
                          chapterPages: _prevChapterPages,
                          allAnnotations: annotations,
                          accentColor: tokens.accentPrimary,
                          dual: dual,
                          chapterIndexOverride: _chapterIdx - 1,
                          chapterTitleOverride: _prevChapter!.title,
                        );
                      } else {
                        prev = _buildTransitionPlaceholderPage(
                          settings,
                          _chapters[_chapterIdx - 1].title,
                        );
                      }
                    }

                    Widget? next;
                    if (_pageIdx + step < _pages.length) {
                      final nextStart =
                          dual ? ((_pageIdx + step) ~/ 2) * 2 : _pageIdx + 1;
                      next = _buildSpreadOrSingleWidget(
                        startPageIdx: nextStart,
                        settings: settings,
                        chapterPages: _pages,
                        allAnnotations: annotations,
                        accentColor: tokens.accentPrimary,
                        dual: dual,
                      );
                    } else if (_chapterIdx + 1 < _chapters.length) {
                      if (_nextChapter != null &&
                          _nextChapter!.index == _chapterIdx + 1 &&
                          _nextChapterPages.isNotEmpty) {
                        next = _buildSpreadOrSingleWidget(
                          startPageIdx: 0,
                          settings: settings,
                          chapterPages: _nextChapterPages,
                          allAnnotations: annotations,
                          accentColor: tokens.accentPrimary,
                          dual: dual,
                          chapterIndexOverride: _chapterIdx + 1,
                          chapterTitleOverride: _nextChapter!.title,
                        );
                      } else {
                        next = _buildTransitionPlaceholderPage(
                          settings,
                          _chapters[_chapterIdx + 1].title,
                        );
                      }
                    }

                    return PageTurnStage(
                      controller: _pageTurnCtrl,
                      mode: settings.pageTurnMode,
                      isDualSpread: dual,
                      currentPage: _buildSpreadOrSingleWidget(
                        startPageIdx: _pageIdx,
                        settings: settings,
                        chapterPages: _pages,
                        allAnnotations: annotations,
                        accentColor: tokens.accentPrimary,
                        dual: dual,
                        interactive: true,
                      ),
                      previousPage: prev,
                      nextPage: next,
                      canTurnPrev: _canTurnPrev,
                      canTurnNext: _canTurnNext,
                      paperColor: paper.background,
                      selectionActive: _activeSelection != null,
                      onInterceptTap: _tryInterceptCanvasTap,
                      onTurnNext: _commitTurnNext,
                      onTurnPrev: _commitTurnPrev,
                      onBoundaryReached: (isEnd) => _toast(
                        isEnd ? l10n.lastPageToast : l10n.firstPageToast,
                      ),
                      onTapNormalized: _handleTapNormalized,
                    );
                  },
                ),

              // Reader brightness dimming veil (edge-swipe adjustable)
              if (_readerBrightness < 0.995)
                Positioned.fill(
                  child: IgnorePointer(
                    child: ColoredBox(
                      color: Colors.black.withValues(
                        alpha: (1.0 - _readerBrightness).clamp(0.0, 0.75),
                      ),
                    ),
                  ),
                ),

              // Left-edge vertical brightness gesture strip
              if (settings.edgeBrightnessGesture &&
                  !_loading &&
                  !_menuVisible &&
                  _activeSelection == null &&
                  _inspectedAnnotation == null)
                Positioned(
                  left: 0,
                  top: safePadding.top + 40,
                  bottom: safePadding.bottom + 40,
                  width: 36,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onVerticalDragUpdate: (d) {
                      _brightnessHideTimer?.cancel();
                      setState(() {
                        _readerBrightness =
                            (_readerBrightness - d.delta.dy / 300.0)
                                .clamp(0.25, 1.0);
                        _showBrightnessIndicator = true;
                      });
                    },
                    onVerticalDragEnd: (_) {
                      _brightnessHideTimer?.cancel();
                      _brightnessHideTimer = Timer(
                        const Duration(milliseconds: 1400),
                        () {
                          if (mounted) {
                            setState(() => _showBrightnessIndicator = false);
                          }
                        },
                      );
                    },
                  ),
                ),

              if (_showBrightnessIndicator)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Center(
                      child: FloatingCard(
                        frosted: true,
                        radius: 999,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 9,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkIconWidget(
                              InkIcon.brightness,
                              size: 16,
                              color: tokens.accentPrimary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              l10n.brightnessIndicator(
                                (_readerBrightness * 100).round(),
                              ),
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: tokens.inkPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // Floating Interactive Highlight / Underline Bar
              if ((_activeSelection != null || _inspectedAnnotation != null) &&
                  !_menuVisible)
                Positioned(
                  left: 14,
                  right: 14,
                  top: _shouldPlaceHighlightBarAtBottom()
                      ? null
                      : safePadding.top + 10,
                  bottom: _shouldPlaceHighlightBarAtBottom()
                      ? safePadding.bottom + 16
                      : null,
                  child: Center(
                    child: ConstrainedBox(
                      constraints:
                          const BoxConstraints(maxWidth: kMaxModalWidth),
                      child: _buildHighlightFloatingBar(tokens),
                    ),
                  ),
                ),

              // Floating TTS Mini Dock
              if (_ttsPlaying &&
                  !_menuVisible &&
                  _activeSelection == null &&
                  _inspectedAnnotation == null)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: safePadding.bottom + 18,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: FloatingCard(
                        frosted: true,
                        radius: 999,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: Row(
                          children: [
                            InkIconWidget(
                              InkIcon.tts,
                              size: 17,
                              color: tokens.accentPrimary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.ttsPlayingStatus(
                                      ttsCfg.mode == TtsEngineMode.online &&
                                              !_ttsCtrl.usingFallbackLocal
                                          ? ttsCfg.activeProfile.name
                                          : l10n.ttsModeLocal,
                                      settings.ttsRate.toStringAsFixed(1),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: tokens.inkPrimary,
                                    ),
                                  ),
                                  if (_ttsCtrl.remainingSleepLabel != null)
                                    Text(
                                      _ttsCtrl.remainingSleepLabel!,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: tokens.inkMuted,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              tooltip: l10n.ttsPrevSentence,
                              onPressed: () => unawaited(_ttsCtrl.prevSentence()),
                              icon: InkIconWidget(
                                InkIcon.skipPrev,
                                size: 16,
                                color: tokens.inkPrimary,
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              tooltip: _ttsCtrl.isPaused
                                  ? l10n.ttsResume
                                  : l10n.ttsPause,
                              onPressed: () => unawaited(
                                _ttsCtrl.isPaused
                                    ? _ttsCtrl.resume()
                                    : _ttsCtrl.pause(),
                              ),
                              icon: InkIconWidget(
                                _ttsCtrl.isPaused
                                    ? InkIcon.play
                                    : InkIcon.pause,
                                size: 17,
                                color: tokens.accentPrimary,
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              tooltip: l10n.ttsNextSentence,
                              onPressed: () => unawaited(_ttsCtrl.nextSentence()),
                              icon: InkIconWidget(
                                InkIcon.skipNext,
                                size: 16,
                                color: tokens.inkPrimary,
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              tooltip: l10n.ttsSettingsBtn,
                              onPressed: _openTtsSettingsFromReader,
                              icon: InkIconWidget(
                                InkIcon.gear,
                                size: 16,
                                color: tokens.inkPrimary,
                              ),
                            ),
                            TextButton(
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                minimumSize: Size.zero,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 6,
                                ),
                              ),
                              onPressed: _toggleTts,
                              child: Text(
                                l10n.ttsStop,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: tokens.accentWarm,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // Detached FloatingCard Top Control Bar
              if (_menuVisible)
                Positioned(
                  top: safePadding.top + 8,
                  left: 12,
                  right: 12,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: wideScreen ? 680 : double.infinity,
                      ),
                      child: FloatingCard(
                        frosted: true,
                        radius: 20,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
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
                            const SizedBox(width: 8),
                            Expanded(
                              child: GestureDetector(
                                onTap: _openBookDetailFromReader,
                                child: Text(
                                  _book?.title ?? l10n.bookDetailsTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: tokens.inkPrimary,
                                  ),
                                ),
                              ),
                            ),
                            if (isRealPdf)
                              TextButton(
                                onPressed: () => settingsCtrl.update(
                                  (s) => s.copyWith(
                                      pdfReflowMode: !s.pdfReflowMode),
                                ),
                                child: Text(
                                  settings.pdfReflowMode
                                      ? l10n.originalPdf
                                      : l10n.textReflow,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: tokens.accentPrimary,
                                  ),
                                ),
                              ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              tooltip: l10n.highlightNotesTooltip,
                              onPressed: _startToolbarHighlightSelection,
                              icon: InkIconWidget(
                                InkIcon.highlight,
                                size: 18,
                                color: tokens.inkPrimary,
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              tooltip: currentPageBookmarked
                                  ? l10n.removeBookmarkTooltip
                                  : l10n.addBookmarkTooltip,
                              onPressed: _togglePageBookmark,
                              icon: Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: currentPageBookmarked
                                      ? tokens.accentSoft
                                      : Colors.transparent,
                                  shape: BoxShape.circle,
                                ),
                                child: InkIconWidget(
                                  currentPageBookmarked
                                      ? InkIcon.bookmarkFilled
                                      : InkIcon.bookmark,
                                  size: 17,
                                  color: currentPageBookmarked
                                      ? tokens.accentPrimary
                                      : tokens.inkPrimary,
                                ),
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              tooltip: l10n.ttsListenTooltip,
                              onPressed: _toggleTts,
                              icon: InkIconWidget(
                                InkIcon.tts,
                                size: 18,
                                color: _ttsPlaying
                                    ? tokens.accentPrimary
                                    : tokens.inkPrimary,
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              tooltip: l10n.bookDetailsTitle,
                              onPressed: _openBookDetailFromReader,
                              icon: InkIconWidget(
                                InkIcon.more,
                                size: 18,
                                color: tokens.inkPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // Detached FloatingCard Bottom Control Dock
              if (_menuVisible)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: safePadding.bottom + 12,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: wideScreen ? 680 : double.infinity,
                      ),
                      child: FloatingCard(
                        frosted: true,
                        radius: 26,
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_scrubChapterIdx != null && _chapters.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  '${_chapters[_scrubChapterIdx!.clamp(0, _chapters.length - 1)].title} (${_scrubChapterIdx! + 1}/${_chapters.length})',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: tokens.accentPrimary,
                                  ),
                                ),
                              ),
                            Row(
                              children: [
                                TextButton(
                                  onPressed: _chapterIdx > 0
                                      ? () => _loadChapter(_chapterIdx - 1)
                                      : null,
                                  child: Text(
                                    l10n.prevChapter,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                Expanded(
                                  child: Slider(
                                    min: 0,
                                    max: (_chapters.length - 1)
                                        .clamp(1, 1000000)
                                        .toDouble(),
                                    value: (_scrubChapterIdx ?? _chapterIdx)
                                        .clamp(
                                            0,
                                            (_chapters.length - 1)
                                                .clamp(1, 1000000))
                                        .toDouble(),
                                    onChanged: _chapters.length > 1
                                        ? (v) => setState(
                                            () => _scrubChapterIdx = v.round())
                                        : null,
                                    onChangeEnd: _chapters.length > 1
                                        ? (v) {
                                            final target = v.round();
                                            setState(
                                                () => _scrubChapterIdx = null);
                                            if (target != _chapterIdx) {
                                              _loadChapter(target);
                                            }
                                          }
                                        : null,
                                  ),
                                ),
                                TextButton(
                                  onPressed: _chapterIdx + 1 < _chapters.length
                                      ? () => _loadChapter(_chapterIdx + 1)
                                      : null,
                                  child: Text(
                                    l10n.nextChapter,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),

                            if (_sheetTab == 'toc')
                              _buildTocPanel(tokens, annotations),
                            if (_sheetTab == 'style')
                              _buildStylePanel(tokens, settings, settingsCtrl),
                            if (_sheetTab == 'anim')
                              _buildAnimPanel(tokens, settings, settingsCtrl),
                            if (_sheetTab == 'more')
                              _buildMorePanel(tokens, settings, settingsCtrl),

                            const Divider(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _ReaderTabBtn(
                                  icon: InkIcon.toc,
                                  label: l10n.readerTabToc,
                                  active: _sheetTab == 'toc',
                                  onTap: () {
                                    ScaffoldMessenger.of(context)
                                        .hideCurrentSnackBar();
                                    final opening = _sheetTab != 'toc';
                                    setState(
                                        () => _sheetTab = opening ? 'toc' : null);
                                    if (opening) _scrollTocToCurrentChapter();
                                  },
                                ),
                                _ReaderTabBtn(
                                  icon: paper == BookPaperTheme.dark ||
                                          paper == BookPaperTheme.oled
                                      ? InkIcon.sun
                                      : InkIcon.moon,
                                  label: paper == BookPaperTheme.dark ||
                                          paper == BookPaperTheme.oled
                                      ? l10n.readerTabLight
                                      : l10n.readerTabDark,
                                  active: false,
                                  onTap: () {
                                    final next = paper == BookPaperTheme.dark ||
                                            paper == BookPaperTheme.oled
                                        ? _lastLightPaper
                                        : BookPaperTheme.dark;
                                    settingsCtrl.update(
                                        (s) => s.copyWith(paperTheme: next));
                                  },
                                ),
                                _ReaderTabBtn(
                                  icon: InkIcon.typography,
                                  label: l10n.readerTabStyle,
                                  active: _sheetTab == 'style',
                                  onTap: () {
                                    ScaffoldMessenger.of(context)
                                        .hideCurrentSnackBar();
                                    setState(() => _sheetTab =
                                        _sheetTab == 'style' ? null : 'style');
                                  },
                                ),
                                _ReaderTabBtn(
                                  icon: InkIcon.pageCurl,
                                  label: l10n.readerTabTurn,
                                  active: _sheetTab == 'anim',
                                  onTap: () {
                                    ScaffoldMessenger.of(context)
                                        .hideCurrentSnackBar();
                                    setState(() => _sheetTab =
                                        _sheetTab == 'anim' ? null : 'anim');
                                  },
                                ),
                                _ReaderTabBtn(
                                  icon: InkIcon.gear,
                                  label: l10n.readerTabMore,
                                  active: _sheetTab == 'more',
                                  onTap: () {
                                    ScaffoldMessenger.of(context)
                                        .hideCurrentSnackBar();
                                    setState(() => _sheetTab =
                                        _sheetTab == 'more' ? null : 'more');
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHighlightFloatingBar(InkBoxTokens tokens) {
    final l10n = context.l10n;
    final inspected = _inspectedAnnotation;
    final activeSel = _activeSelection;

    return FloatingCard(
      frosted: true,
      radius: 22,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (inspected != null && inspected.noteText.trim().isNotEmpty) ...[
            Text(
              l10n.notePrefix(inspected.noteText),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: tokens.inkPrimary,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              ...kReaderHighlightColors.map((hex) {
                final color = parseHexColor(hex);
                final selected = (inspected != null
                        ? inspected.colorHex.toUpperCase()
                        : _selectedHighlightColor.toUpperCase()) ==
                    hex.toUpperCase();
                return GestureDetector(
                  onTap: () {
                    if (inspected != null) {
                      _updateInspectedHighlightColor(inspected, hex);
                    } else if (activeSel != null) {
                      _saveActiveHighlight(
                        colorHexOverride: hex,
                        keepInspecting: true,
                      );
                    } else {
                      setState(() => _selectedHighlightColor = hex);
                    }
                  },
                  child: Container(
                    width: 22,
                    height: 22,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected
                            ? tokens.inkPrimary
                            : Colors.black.withValues(alpha: 0.16),
                        width: selected ? 2.2 : 1,
                      ),
                    ),
                  ),
                );
              }),
              const Spacer(),
              GestureDetector(
                onTap: _clearSelectionAndInspector,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: InkIconWidget(
                    InkIcon.close,
                    size: 16,
                    color: tokens.inkMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (activeSel != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                TextButton(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => _saveActiveHighlight(),
                  child: Text(
                    l10n.highlightAction,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: tokens.accentPrimary,
                    ),
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: _promptNoteForActiveSelection,
                  child: Text(
                    l10n.writeNoteAction,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: tokens.inkPrimary,
                    ),
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () async {
                    final txt = activeSel.text;
                    await Clipboard.setData(ClipboardData(text: txt));
                    _clearSelectionAndInspector();
                    _toast(l10n.copiedToast);
                  },
                  child: Text(
                    l10n.copy,
                    style: TextStyle(fontSize: 13, color: tokens.inkPrimary),
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () {
                    final txt = activeSel.text;
                    _clearSelectionAndInspector();
                    _speakArbitraryText(txt);
                  },
                  child: Text(
                    l10n.readLabel,
                    style: TextStyle(fontSize: 13, color: tokens.inkPrimary),
                  ),
                ),
              ],
            )
          else if (inspected != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                TextButton(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => _editInspectedHighlightNote(inspected),
                  child: Text(
                    inspected.noteText.isEmpty
                        ? l10n.writeNoteAction
                        : l10n.editNoteAction,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: tokens.accentPrimary,
                    ),
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: inspected.excerpt),
                    );
                    _clearSelectionAndInspector();
                    _toast(l10n.copiedToast);
                  },
                  child: Text(
                    l10n.copy,
                    style: TextStyle(fontSize: 13, color: tokens.inkPrimary),
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () async {
                    await _db.softDeleteAnnotation(inspected.uuid);
                    await _refreshAnnotations();
                    _clearSelectionAndInspector();
                    _toast(l10n.highlightDeletedToast);
                  },
                  child: Text(
                    l10n.deleteHighlightAction,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: tokens.accentWarm,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  /// Spacious TOC & Bookmarks/Notes panel — all TXT rule/encoding settings live in BookDetailPage
  /// so maximum vertical space is dedicated to browsing chapters.
  Widget _buildTocPanel(InkBoxTokens tokens, List<Annotation> annotations) {
    final l10n = context.l10n;
    final panelHeight =
        (MediaQuery.sizeOf(context).height * 0.45).clamp(240.0, 410.0);

    return SizedBox(
      height: panelHeight,
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TabBar(
                    labelColor: tokens.accentPrimary,
                    unselectedLabelColor: tokens.inkMuted,
                    tabs: [
                      Tab(text: l10n.tocTabTitle(_chapters.length)),
                      Tab(text: l10n.annotationsTabTitle(annotations.length)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                InkPillChip(
                  label: _tocReversed
                      ? l10n.descendingOrder
                      : l10n.ascendingOrder,
                  onTap: () {
                    setState(() => _tocReversed = !_tocReversed);
                    _scrollTocToCurrentChapter();
                  },
                ),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  ListView.builder(
                    controller: _tocScrollCtrl,
                    itemExtent: 44,
                    itemCount: _chapters.length,
                    itemBuilder: (_, i) {
                      final chIndex =
                          _tocReversed ? (_chapters.length - 1 - i) : i;
                      final ch = _chapters[chIndex];
                      final active = chIndex == _chapterIdx;
                      return InkWell(
                        onTap: () {
                          setState(() {
                            _menuVisible = false;
                            _sheetTab = null;
                          });
                          _loadChapter(chIndex);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
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
                                  size: 14,
                                  color: tokens.accentPrimary,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  annotations.isEmpty
                      ? Center(
                          child: Text(
                            l10n.noAnnotationsReaderHint,
                            style:
                                TextStyle(fontSize: 12, color: tokens.inkMuted),
                          ),
                        )
                      : ListView.builder(
                          itemCount: annotations.length,
                          itemBuilder: (_, i) {
                            final a = annotations[i];
                            final loc =
                                ParsedAnnotationLocator.parse(a.locator);
                            return ListTile(
                              dense: true,
                              leading: InkIconWidget(
                                a.kind == 'bookmark'
                                    ? InkIcon.bookmarkFilled
                                    : InkIcon.highlight,
                                size: 15,
                                color: tokens.accentPrimary,
                              ),
                              title: Text(
                                a.excerpt.isNotEmpty
                                    ? a.excerpt
                                    : l10n.chapterLabelShort(a.chapterIndex + 1),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12),
                              ),
                              subtitle: a.noteText.isNotEmpty
                                  ? Text(
                                      a.noteText,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 11),
                                    )
                                  : null,
                              trailing: GestureDetector(
                                onTap: () async {
                                  await _db.softDeleteAnnotation(a.uuid);
                                  await _refreshAnnotations();
                                },
                                child: InkIconWidget(
                                  InkIcon.trash,
                                  size: 14,
                                  color: tokens.inkMuted,
                                ),
                              ),
                              onTap: () {
                                setState(() {
                                  _menuVisible = false;
                                  _sheetTab = null;
                                });
                                _loadChapter(
                                  a.chapterIndex,
                                  initialOffset: loc.startOffset,
                                );
                              },
                            );
                          },
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStylePanel(
    InkBoxTokens tokens,
    BookReaderSettings settings,
    BookReaderSettingsController ctrl,
  ) {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(
              l10n.fontSizeLabel,
              style: TextStyle(fontSize: 12, color: tokens.inkMuted),
            ),
            const SizedBox(width: 10),
            OutlinedButton(
              onPressed: () => ctrl.update(
                (s) => s.copyWith(fontSize: (s.fontSize - 1).clamp(12, 30)),
              ),
              child: const Text('A-'),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('${settings.fontSize.round()}'),
            ),
            OutlinedButton(
              onPressed: () => ctrl.update(
                (s) => s.copyWith(fontSize: (s.fontSize + 1).clamp(12, 30)),
              ),
              child: const Text('A+'),
            ),
            const Spacer(),
            InkPillChip(
              label: settings.chineseConversion == 'None'
                  ? l10n.chineseOriginal
                  : settings.chineseConversion == 'ToTraditional'
                      ? l10n.chineseTrad
                      : l10n.chineseSimp,
              selected: settings.chineseConversion != 'None',
              onTap: () {
                const order = ['None', 'ToTraditional', 'ToSimplified'];
                final next =
                    order[(order.indexOf(settings.chineseConversion) + 1) % 3];
                ctrl.update((s) => s.copyWith(chineseConversion: next));
                _loadChapter(_chapterIdx, initialOffset: _anchorCharOffset);
              },
            ),
          ],
        ),
        Row(
          children: [
            Text(
              l10n.lineHeightLabel,
              style: TextStyle(fontSize: 12, color: tokens.inkMuted),
            ),
            Expanded(
              child: Slider(
                min: 1.3,
                max: 2.4,
                value: settings.lineHeight,
                onChanged: (v) => ctrl.update((s) => s.copyWith(lineHeight: v)),
              ),
            ),
            Text(
              settings.lineHeight.toStringAsFixed(1),
              style: const TextStyle(fontSize: 11.5),
            ),
          ],
        ),
        Row(
          children: [
            Text(
              l10n.paragraphSpacingLabel,
              style: TextStyle(fontSize: 12, color: tokens.inkMuted),
            ),
            Expanded(
              child: Slider(
                min: 0.0,
                max: 28.0,
                value: settings.paragraphSpacing.clamp(0.0, 28.0),
                onChanged: (v) =>
                    ctrl.update((s) => s.copyWith(paragraphSpacing: v)),
              ),
            ),
            Text(
              '${settings.paragraphSpacing.round()}',
              style: const TextStyle(fontSize: 11.5),
            ),
          ],
        ),
        Row(
          children: [
            Text(
              l10n.layoutModeLabel,
              style: TextStyle(fontSize: 12, color: tokens.inkMuted),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: BookPageLayoutMode.values.map((lm) {
                  return InkPillChip(
                    label: lm.labelOf(l10n),
                    selected: settings.pageLayoutMode == lm,
                    onTap: () =>
                        ctrl.update((s) => s.copyWith(pageLayoutMode: lm)),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.firstLineIndentLabel,
                style: TextStyle(fontSize: 12, color: tokens.inkMuted),
              ),
              InkSwitch(
                value: settings.indentFirstLine,
                onChanged: (v) =>
                    ctrl.update((s) => s.copyWith(indentFirstLine: v)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: BookPaperTheme.values.map((t) {
              final active = settings.paperTheme == t;
              return GestureDetector(
                onTap: () {
                  if (t != BookPaperTheme.dark && t != BookPaperTheme.oled) {
                    _lastLightPaper = t;
                  }
                  ctrl.update((s) => s.copyWith(paperTheme: t));
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: t.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: active ? tokens.accentPrimary : tokens.subtleBorder,
                      width: active ? 2 : 1,
                    ),
                  ),
                  child: Text(
                    t.labelOf(l10n),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: t.foreground,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 6),
      ],
    );
  }

  Widget _buildAnimPanel(
    InkBoxTokens tokens,
    BookReaderSettings settings,
    BookReaderSettingsController ctrl,
  ) {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: PageTurnMode.values.map((m) {
            final active = settings.pageTurnMode == m;
            return InkPillChip(
              label: m.labelOf(l10n),
              selected: active,
              onTap: () {
                if (m != PageTurnMode.scroll && _autoScrolling) {
                  _autoScrollTimer?.cancel();
                  setState(() => _autoScrolling = false);
                }
                ctrl.update((s) => s.copyWith(pageTurnMode: m));
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: TapZonePreset.values.map((p) {
            final active = settings.tapZonePreset == p;
            return InkPillChip(
              label: p.labelOf(l10n),
              selected: active,
              onTap: () => ctrl.update((s) => s.copyWith(tapZonePreset: p)),
            );
          }).toList(),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.autoScrollLabel,
              style: TextStyle(fontSize: 12, color: tokens.inkMuted),
            ),
            FilledButton.tonal(
              onPressed: _toggleAutoScroll,
              child: Text(
                _autoScrolling ? l10n.stopAutoScroll : l10n.startAutoScroll,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMorePanel(
    InkBoxTokens tokens,
    BookReaderSettings settings,
    BookReaderSettingsController ctrl,
  ) {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.volumeKeyPaging,
                style: TextStyle(fontSize: 13, color: tokens.inkPrimary),
              ),
              InkSwitch(
                value: settings.volumeKeyPaging,
                onChanged: (v) {
                  ctrl.update((s) => s.copyWith(volumeKeyPaging: v));
                  ref.read(platformBridgeProvider).setVolumeKeyPaging(v);
                },
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.keepScreenOn,
                style: TextStyle(fontSize: 13, color: tokens.inkPrimary),
              ),
              InkSwitch(
                value: settings.keepScreenOn,
                onChanged: (v) {
                  ctrl.update((s) => s.copyWith(keepScreenOn: v));
                  ref.read(platformBridgeProvider).setKeepScreenOn(v);
                },
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.edgeBrightnessGesture,
                style: TextStyle(fontSize: 13, color: tokens.inkPrimary),
              ),
              InkSwitch(
                value: settings.edgeBrightnessGesture,
                onChanged: (v) =>
                    ctrl.update((s) => s.copyWith(edgeBrightnessGesture: v)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _openTtsSettingsFromReader,
                child: Text(
                  l10n.ttsSettingsBtn,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () => _showPurificationDialog(settings, ctrl),
                child: Text(
                  l10n.purificationBtn,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: _exportNotesMarkdown,
                child: Text(
                  l10n.exportNotesBtn,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _showPurificationDialog(
    BookReaderSettings settings,
    BookReaderSettingsController ctrl,
  ) async {
    final l10n = context.l10n;
    final patCtrl = TextEditingController();
    final repCtrl = TextEditingController();
    final result = await showInkModal<({String pat, String rep})>(
      context: context,
      title: l10n.purificationDialogTitle,
      disposables: [patCtrl, repCtrl],
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkTextField(
            controller: patCtrl,
            label: l10n.purificationPatternLabel,
            hintText: l10n.purificationPatternHint,
            monospace: true,
          ),
          const SizedBox(height: 10),
          InkTextField(
            controller: repCtrl,
            label: l10n.purificationReplacementLabel,
            hintText: l10n.purificationReplacementHint,
          ),
        ],
      ),
      actionsBuilder: (ctx) => [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop((
            pat: patCtrl.text.trim(),
            rep: repCtrl.text,
          )),
          child: Text(l10n.addAndApply),
        ),
      ],
    );
    if (result != null && result.pat.isNotEmpty) {
      await ctrl.update(
        (s) => s.copyWith(
          replaceRules: [
            ...s.replaceRules,
            ReplaceRuleConfig(
              name: l10n.purificationBtn,
              pattern: result.pat,
              replacement: result.rep,
              isRegex: true,
            ),
          ],
        ),
      );
      await _loadChapter(_chapterIdx, initialOffset: _anchorCharOffset);
    }
  }
}

class _NativePdfPageCanvas extends StatelessWidget {
  const _NativePdfPageCanvas({
    required this.pdfPath,
    required this.pageIndex,
    required this.platform,
  });

  final String pdfPath;
  final int pageIndex;
  final PlatformBridge platform;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FutureBuilder<Uint8List?>(
      future: platform.renderPdfPage(pdfPath, pageIndex, scale: 2.0),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final bytes = snap.data;
        if (bytes == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                l10n.pdfUnsupportedPlatform,
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return InteractiveViewer(
          minScale: 1.0,
          maxScale: 4.5,
          child: Center(
            child: Image.memory(bytes, fit: BoxFit.contain),
          ),
        );
      },
    );
  }
}

class _ReaderTabBtn extends StatelessWidget {
  const _ReaderTabBtn({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final InkIcon icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = InkBoxTokens.of(context);
    final color = active ? tokens.accentPrimary : tokens.inkMuted;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkIconWidget(icon, size: 19, color: color),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
