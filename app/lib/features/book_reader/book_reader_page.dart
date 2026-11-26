import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/icons/ink_icons.dart';
import '../../core/theme/inkbox_theme.dart';
import '../../core/widgets/floating_surface.dart';
import '../../core/widgets/ink_controls.dart';
import '../../data/db/app_database.dart';
import '../../data/ffi/rust_core_bridge.dart';
import '../../data/platform/platform_bridge.dart';
import '../../data/providers/app_providers.dart';
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
  String? _activeTtsUtteranceId;
  bool _ttsExcerptOnly = false;
  bool _ttsPausedForSettings = false;
  int _ttsScrollOffset = 0;
  Timer? _ttsSleepTimer;
  DateTime? _ttsSleepEndAt;

  bool _autoScrolling = false;
  Timer? _autoScrollTimer;
  final ScrollController _scrollCtrl = ScrollController();
  final ScrollController _tocScrollCtrl = ScrollController();
  final PageTurnController _pageTurnCtrl = PageTurnController();
  final GlobalKey<ReaderHighlightCanvasState> _activeCanvasKey =
      GlobalKey<ReaderHighlightCanvasState>();

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
    _sessionStart = DateTime.now();
    _scrollCtrl.addListener(_onScrollChanged);
    _initReader();
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _ttsSleepTimer?.cancel();
    _scrollCtrl.removeListener(_onScrollChanged);
    _scrollCtrl.dispose();
    _tocScrollCtrl.dispose();
    _eventSub?.cancel();
    _persistProgress(flushTime: true);
    _platform.setVolumeKeyPaging(false);
    _platform.setKeepScreenOn(false);
    _platform.stopTts();
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
    final book = await _db.findBookById(widget.bookId);
    if (!mounted) return;
    if (book == null) {
      setState(() => _loading = false);
      return;
    }

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
      } else if ((ev.type == 'tts_done' || ev.type == 'tts_error') &&
          _ttsPlaying &&
          !_ttsPausedForSettings) {
        final evUid = (ev.payload['utteranceId'] as String? ?? '').trim();
        if (_activeTtsUtteranceId != null &&
            evUid.isNotEmpty &&
            evUid != _activeTtsUtteranceId) {
          return;
        }
        if (ev.type == 'tts_error' || _ttsExcerptOnly) {
          _stopTtsPlayback();
          return;
        }
        final curSettings = ref.read(bookReaderSettingsProvider);
        final isScroll = !_isNativePdfBitmapMode &&
            curSettings.pageTurnMode == PageTurnMode.scroll;
        if (isScroll) {
          _advanceScrollTts(curSettings);
        } else if (curSettings.ttsAutoTurnPage && _canTurnNext) {
          _commitTurnNext(fromTtsAutoTurn: true);
          _speakCurrentPage();
        } else {
          _stopTtsPlayback();
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

    final tocChanged =
        fresh.tocRuleId != prevRuleId || fresh.forcedEncoding != prevEncoding;
    if (tocChanged) {
      await _reloadTocFromBook(
        fresh,
        targetChapter: chosen?.chapterIndex ?? _chapterIdx,
        initialOffset: chosen?.charOffset ?? 0,
      );
    } else {
      setState(() => _book = fresh);
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

  List<BookPageSlice> _paginateText(
    String text,
    Size viewport,
    EdgeInsets safePadding,
    BookReaderSettings settings,
  ) {
    final usableWidth =
        (viewport.width - settings.horizontalPadding * 2).clamp(100.0, 1400.0);
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
    );
  }

  void _ensurePaginated(
    Size viewport,
    EdgeInsets safePadding,
    BookReaderSettings settings,
  ) {
    final chapter = _loadedChapter;
    if (chapter == null) return;
    final hash = Object.hash(
      chapter.index,
      chapter.text.length,
      settings.fontSize,
      settings.lineHeight,
      settings.horizontalPadding,
      settings.indentFirstLine,
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

    final slices = _paginateText(chapter.text, viewport, safePadding, settings);
    _pages = slices;
    _pageIdx = BookPaginator.findPageForOffset(slices, _anchorCharOffset);

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
    return _pageIdx + 1 < _pages.length || _chapterIdx + 1 < _chapters.length;
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
        _toast('已是最后一页');
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
        _toast('已是第一页');
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
        _toast(forward ? '已是最后一页' : '已是第一页');
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
          _toast('已是最后一页');
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
          _toast('已是第一页');
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

  void _commitTurnNext({bool fromTtsAutoTurn = false}) {
    if (_pages.isNotEmpty && _pageIdx + 1 < _pages.length) {
      setState(() {
        _pageIdx++;
        _anchorCharOffset = _pages[_pageIdx].startOffset;
        _menuVisible = false;
        _sheetTab = null;
        _activeSelection = null;
        _inspectedAnnotation = null;
      });
      _persistProgress();
      if (_ttsPlaying && !_ttsExcerptOnly && !fromTtsAutoTurn) {
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
        if (_ttsPlaying && !_ttsExcerptOnly && !fromTtsAutoTurn) {
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

    _toast('已是最后一页');
  }

  void _commitTurnPrev() {
    if (_pages.isNotEmpty && _pageIdx > 0) {
      setState(() {
        _pageIdx--;
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
        setState(() {
          _nextChapter = _loadedChapter;
          _nextChapterPages = _pages;
          _chapterIdx--;
          _loadedChapter = _prevChapter;
          _pages = _prevChapterPages;
          _pageIdx = _pages.length - 1;
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

    _toast('已是第一页');
  }

  bool _tryInterceptCanvasTap(Offset globalPosition) {
    if (_menuVisible) return false;
    if (_activeSelection != null) {
      setState(() => _activeSelection = null);
      return true;
    }
    if (_activeCanvasKey.currentState?.tryHandleTapAtGlobal(globalPosition) ==
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
      return chBookmarks.where((a) {
        final off = ParsedAnnotationLocator.parse(a.locator).startOffset;
        return BookPaginator.findPageForOffset(pages, off) == pageIndex;
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
      _toast('已取消本页书签');
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
    _toast('已添加书签');
  }

  // --- Interactive Highlight / Underline (`划线`) & Notes ---

  void _startToolbarHighlightSelection() {
    if (_isNativePdfBitmapMode) {
      _toast('原版 PDF 位图暂不支持直接划线，请点击顶栏「文本重排」后再划线');
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
    } else if (_pages.isNotEmpty && !_pages[_pageIdx].isPlaceholder) {
      baseOff = _pages[_pageIdx].startOffset;
      targetText = _pages[_pageIdx].text;
    }

    if (targetText.trim().isEmpty) {
      _toast('当前页面没有可划线的文本内容');
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
    final slice = _pages[_pageIdx];
    if (slice.text.isEmpty) return true;
    final targetOffset = _activeSelection?.start ??
        (_inspectedAnnotation != null
            ? ParsedAnnotationLocator.parse(_inspectedAnnotation!.locator)
                .startOffset
            : slice.startOffset);
    final localRatio =
        (targetOffset - slice.startOffset) / slice.text.length;
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
    setState(() {
      _selectedHighlightColor = chosenColor;
      _activeSelection = null;
      _inspectedAnnotation = keepInspecting ? savedAnn : null;
    });
    _toast(cleanNote.isNotEmpty ? '已保存划线与想法' : '已添加划线');
  }

  Future<void> _promptNoteForActiveSelection() async {
    final sel = _activeSelection;
    if (sel == null) return;
    final noteCtrl = TextEditingController();
    final savedNote = await showInkModal<String>(
      context: context,
      title: '添加划线想法',
      subtitle: '“${sel.text}”',
      disposables: [noteCtrl],
      builder: (ctx) => InkTextField(
        controller: noteCtrl,
        autofocus: true,
        label: '你的想法',
        hintText: '写下此刻的批注或感想...',
        maxLines: 3,
        minLines: 2,
      ),
      actionsBuilder: (ctx) => [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(noteCtrl.text.trim()),
          child: const Text('保存划线与想法'),
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
    final noteCtrl = TextEditingController(text: ann.noteText);
    final updatedNote = await showInkModal<String>(
      context: context,
      title: '编辑划线想法',
      subtitle: ann.excerpt.isNotEmpty ? '“${ann.excerpt}”' : null,
      disposables: [noteCtrl],
      builder: (ctx) => InkTextField(
        controller: noteCtrl,
        autofocus: true,
        label: '想法内容',
        hintText: '输入或修改批注（留空则仅保留划线）',
        maxLines: 3,
        minLines: 2,
      ),
      actionsBuilder: (ctx) => [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(noteCtrl.text.trim()),
          child: const Text('保存'),
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
    _ttsSleepTimer?.cancel();
    _ttsSleepTimer = null;
    _ttsSleepEndAt = null;
    _activeTtsUtteranceId = null;
    _ttsExcerptOnly = false;
    _ttsPausedForSettings = false;
    await _platform.stopTts();
    if (mounted) {
      setState(() => _ttsPlaying = false);
      if (message != null) _toast(message);
    }
  }

  void _armTtsSleepTimerIfConfigured() {
    _ttsSleepTimer?.cancel();
    _ttsSleepTimer = null;
    _ttsSleepEndAt = null;
    final mins = ref.read(bookReaderSettingsProvider).ttsSleepTimerMinutes;
    if (mins > 0) {
      final dur = Duration(minutes: mins);
      _ttsSleepEndAt = DateTime.now().add(dur);
      _ttsSleepTimer = Timer(dur, () {
        _stopTtsPlayback(message: '定时关闭已到，已停止语音朗读');
      });
    }
  }

  Future<void> _openTtsSettingsFromReader() async {
    final wasPlaying = _ttsPlaying;
    if (wasPlaying) {
      _ttsPausedForSettings = true;
      _activeTtsUtteranceId = null;
      await _platform.stopTts();
    }
    if (!mounted) return;
    await context.push('/mine/tts-settings');
    if (!mounted) return;
    _ttsPausedForSettings = false;
    if (wasPlaying && _ttsPlaying) {
      _armTtsSleepTimerIfConfigured();
      if (!_ttsExcerptOnly) {
        await _speakCurrentPage();
      } else {
        await _stopTtsPlayback();
      }
    }
  }

  Future<void> _toggleTts() async {
    if (_ttsPlaying) {
      await _stopTtsPlayback(message: '已停止语音朗读');
    } else {
      final settings = ref.read(bookReaderSettingsProvider);
      if (!_isNativePdfBitmapMode &&
          settings.pageTurnMode == PageTurnMode.scroll) {
        _ttsScrollOffset = _currentScrollEstimatedOffset();
      }
      setState(() {
        _ttsPlaying = true;
        _ttsExcerptOnly = false;
      });
      _armTtsSleepTimerIfConfigured();
      final ok = await _speakCurrentPage();
      if (ok) {
        _toast('开始 TTS 语音听书');
      } else {
        await _stopTtsPlayback(message: '当前页面无可朗读文本或系统 TTS 未就绪');
      }
    }
  }

  Future<void> _speakArbitraryText(String rawText) async {
    final text = rawText.replaceAll('\n', ' ').trim();
    if (text.isEmpty) return;
    final settings = ref.read(bookReaderSettingsProvider);
    setState(() {
      _ttsPlaying = true;
      _ttsExcerptOnly = true;
    });
    _armTtsSleepTimerIfConfigured();
    final uid = await _platform.speakText(
      text,
      rate: settings.ttsRate,
      pitch: settings.ttsPitch,
      language: settings.ttsLanguage,
      engine: settings.ttsEngine.isEmpty ? null : settings.ttsEngine,
    );
    if (!mounted) return;
    if (uid == null) {
      await _stopTtsPlayback(message: '系统 TTS 未就绪');
    } else {
      _activeTtsUtteranceId = uid;
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

  Future<bool> _speakCurrentPage() async {
    final settings = ref.read(bookReaderSettingsProvider);
    String text = '';
    final isScroll =
        !_isNativePdfBitmapMode && settings.pageTurnMode == PageTurnMode.scroll;
    if (isScroll) {
      final formatted = BookPaginator.formatParagraphs(
        _loadedChapter?.text ?? '',
        indent: settings.indentFirstLine,
      );
      if (formatted.isNotEmpty) {
        final s = _ttsScrollOffset.clamp(0, formatted.length - 1);
        final e = _nextScrollChunkEnd(formatted, s);
        text = formatted.substring(s, e).replaceAll('\n', ' ');
      }
    } else if (_pages.isNotEmpty && !_pages[_pageIdx].isPlaceholder) {
      text = _pages[_pageIdx].text.replaceAll('\n', ' ');
    } else {
      text = (_loadedChapter?.text.replaceAll('\n', ' ') ?? '');
    }
    if (text.trim().isEmpty) return false;
    final uid = await _platform.speakText(
      text,
      rate: settings.ttsRate,
      pitch: settings.ttsPitch,
      language: settings.ttsLanguage,
      engine: settings.ttsEngine.isEmpty ? null : settings.ttsEngine,
    );
    if (!mounted) return false;
    if (uid == null) {
      _activeTtsUtteranceId = null;
      return false;
    }
    _activeTtsUtteranceId = uid;
    return true;
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
            _toast('已自动滚屏至全书末尾');
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
    final notes = await _db.getAnnotationsFor(book.contentHash);
    final buf = StringBuffer()
      ..writeln('# ${book.title} — 墨匣阅读笔记')
      ..writeln('> 作者：${book.author}\n');
    for (final n in notes) {
      buf.writeln('- **第 ${n.chapterIndex + 1} 章**：${n.excerpt}');
      if (n.noteText.isNotEmpty) buf.writeln('  - 想法：${n.noteText}');
    }
    await Clipboard.setData(ClipboardData(text: buf.toString()));
    _toast('已复制 ${notes.length} 条 Markdown 笔记到剪贴板');
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
  }) {
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
                child: ReaderHighlightCanvas(
                  key: interactive ? _activeCanvasKey : null,
                  text: slice.text,
                  baseOffset: slice.startOffset,
                  style: TextStyle(
                    fontSize: settings.fontSize,
                    height: settings.lineHeight,
                    color: paper.foreground,
                  ),
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
                  interactive: interactive && !slice.isPlaceholder,
                  onSelectionChanged:
                      interactive ? _activateSelection : null,
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
    final settings = ref.watch(bookReaderSettingsProvider);
    final settingsCtrl = ref.read(bookReaderSettingsProvider.notifier);
    final tokens = InkBoxTokens.of(context);
    final paper = settings.paperTheme;
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
          }

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
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                '第 ${_chapterIdx + 1}/${_chapters.isEmpty ? 1 : _chapters.length} 章 · 滚动',
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
                                key: _activeCanvasKey,
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
                                isDarkPaper: isDarkPaper,
                                accentColor: tokens.accentPrimary,
                                selectedColorHex: _selectedHighlightColor,
                                chapterHighlights: scrollChapterHighlights,
                                activeSelectionGlobal: _activeSelection != null
                                    ? (
                                        start: _activeSelection!.start,
                                        end: _activeSelection!.end,
                                      )
                                    : null,
                                interactive: (_loadedChapter?.text.trim().isNotEmpty ?? false),
                                onSelectionChanged: _activateSelection,
                                onHighlightTapped: _activateHighlightInspector,
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
                                      child: const Text('上一章'),
                                    )
                                  else
                                    const SizedBox.shrink(),
                                  if (_chapterIdx + 1 < _chapters.length)
                                    FilledButton(
                                      onPressed: () =>
                                          _loadChapter(_chapterIdx + 1),
                                      child: const Text('下一章'),
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
                )
              else if (_pages.isNotEmpty)
                Builder(
                  builder: (context) {
                    final cur = _pages[_pageIdx];

                    Widget? prev;
                    if (_pageIdx > 0) {
                      prev = _buildPageWidget(
                        _pages[_pageIdx - 1],
                        settings,
                        _pages.length,
                        annotations,
                        chapterPages: _pages,
                        accentColor: tokens.accentPrimary,
                      );
                    } else if (_chapterIdx > 0) {
                      if (_prevChapter != null &&
                          _prevChapter!.index == _chapterIdx - 1 &&
                          _prevChapterPages.isNotEmpty) {
                        prev = _buildPageWidget(
                          _prevChapterPages.last,
                          settings,
                          _prevChapterPages.length,
                          annotations,
                          chapterPages: _prevChapterPages,
                          accentColor: tokens.accentPrimary,
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
                    if (_pageIdx + 1 < _pages.length) {
                      next = _buildPageWidget(
                        _pages[_pageIdx + 1],
                        settings,
                        _pages.length,
                        annotations,
                        chapterPages: _pages,
                        accentColor: tokens.accentPrimary,
                      );
                    } else if (_chapterIdx + 1 < _chapters.length) {
                      if (_nextChapter != null &&
                          _nextChapter!.index == _chapterIdx + 1 &&
                          _nextChapterPages.isNotEmpty) {
                        next = _buildPageWidget(
                          _nextChapterPages.first,
                          settings,
                          _nextChapterPages.length,
                          annotations,
                          chapterPages: _nextChapterPages,
                          accentColor: tokens.accentPrimary,
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
                      currentPage: _buildPageWidget(
                        cur,
                        settings,
                        _pages.length,
                        annotations,
                        chapterPages: _pages,
                        accentColor: tokens.accentPrimary,
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
                      onBoundaryReached: (isEnd) =>
                          _toast(isEnd ? '已是最后一页' : '已是第一页'),
                      onTapNormalized: _handleTapNormalized,
                    );
                  },
                ),

              // Floating Interactive Highlight / Underline Bar (`划线` & `查看/删除已划线`)
              // Adaptively positioned at bottom when selecting upper text and at top when selecting lower text.
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
                  child: _buildHighlightFloatingBar(tokens),
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
                  child: FloatingCard(
                    frosted: true,
                    radius: 999,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Row(
                      children: [
                        InkIconWidget(
                          InkIcon.tts,
                          size: 18,
                          color: tokens.accentPrimary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'TTS 朗读中 · ${settings.ttsRate.toStringAsFixed(1)}x${_ttsSleepEndAt != null ? " · 定时" : ""}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: tokens.inkPrimary,
                            ),
                          ),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () {
                            final nextRate = settings.ttsRate >= 2.0
                                ? 0.8
                                : double.parse(
                                    (settings.ttsRate + 0.2).toStringAsFixed(1),
                                  );
                            settingsCtrl
                                .update((s) => s.copyWith(ttsRate: nextRate));
                            _speakCurrentPage();
                          },
                          child: const Text('语速'),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: _openTtsSettingsFromReader,
                          child: const Text('设置'),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: _toggleTts,
                          child: Text(
                            '停止',
                            style: TextStyle(color: tokens.accentWarm),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Detached FloatingCard Top Control Bar
              if (_menuVisible)
                Positioned(
                  top: safePadding.top + 8,
                  left: 12,
                  right: 12,
                  child: FloatingCard(
                    frosted: true,
                    radius: 20,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                              _book?.title ?? '书籍阅读',
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
                              settings.pdfReflowMode ? '原版PDF' : '文本重排',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: tokens.accentPrimary,
                              ),
                            ),
                          ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: '划线笔记',
                          onPressed: _startToolbarHighlightSelection,
                          icon: InkIconWidget(
                            InkIcon.highlight,
                            size: 18,
                            color: tokens.inkPrimary,
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: currentPageBookmarked ? '取消书签' : '添加书签',
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
                          tooltip: 'TTS 听书',
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
                          tooltip: '书籍详情',
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

              // Detached FloatingCard Bottom Control Dock
              if (_menuVisible)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: safePadding.bottom + 12,
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
                              child: const Text(
                                '上一章',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                            Expanded(
                              child: Slider(
                                min: 0,
                                max: (_chapters.length - 1)
                                    .clamp(1, 1000000)
                                    .toDouble(),
                                value: (_scrubChapterIdx ?? _chapterIdx)
                                    .clamp(0,
                                        (_chapters.length - 1).clamp(1, 1000000))
                                    .toDouble(),
                                onChanged: _chapters.length > 1
                                    ? (v) => setState(
                                        () => _scrubChapterIdx = v.round())
                                    : null,
                                onChangeEnd: _chapters.length > 1
                                    ? (v) {
                                        final target = v.round();
                                        setState(() => _scrubChapterIdx = null);
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
                              child: const Text(
                                '下一章',
                                style: TextStyle(fontSize: 12),
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
                              label: '目录',
                              active: _sheetTab == 'toc',
                              onTap: () {
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
                                  ? '日间'
                                  : '夜间',
                              active: false,
                              onTap: () {
                                final next = paper == BookPaperTheme.dark ||
                                        paper == BookPaperTheme.oled
                                    ? BookPaperTheme.parchment
                                    : BookPaperTheme.dark;
                                settingsCtrl
                                    .update((s) => s.copyWith(paperTheme: next));
                              },
                            ),
                            _ReaderTabBtn(
                              icon: InkIcon.typography,
                              label: '排版',
                              active: _sheetTab == 'style',
                              onTap: () => setState(() => _sheetTab =
                                  _sheetTab == 'style' ? null : 'style'),
                            ),
                            _ReaderTabBtn(
                              icon: InkIcon.pageCurl,
                              label: '翻页',
                              active: _sheetTab == 'anim',
                              onTap: () => setState(() => _sheetTab =
                                  _sheetTab == 'anim' ? null : 'anim'),
                            ),
                            _ReaderTabBtn(
                              icon: InkIcon.gear,
                              label: '更多',
                              active: _sheetTab == 'more',
                              onTap: () => setState(() => _sheetTab =
                                  _sheetTab == 'more' ? null : 'more'),
                            ),
                          ],
                        ),
                      ],
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
              '想法：${inspected.noteText}',
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
                    '划线',
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
                    '写想法',
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
                    _toast('已复制所选文字');
                  },
                  child: Text(
                    '复制',
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
                    '朗读',
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
                    inspected.noteText.isEmpty ? '写想法' : '改想法',
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
                    _toast('已复制划线原文');
                  },
                  child: Text(
                    '复制',
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
                    _toast('已删除划线');
                  },
                  child: Text(
                    '删除划线',
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
                      Tab(text: '目录 (${_chapters.length})'),
                      Tab(text: '书签/划线 (${annotations.length})'),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                InkPillChip(
                  label: _tocReversed ? '倒序' : '正序',
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
                            '暂无书签与划线笔记',
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
                                    : '第 ${a.chapterIndex + 1} 章书签',
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text('字号', style: TextStyle(fontSize: 12, color: tokens.inkMuted)),
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
                  ? '原字'
                  : settings.chineseConversion == 'ToTraditional'
                      ? '繁體'
                      : '简体',
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
            Text('行距', style: TextStyle(fontSize: 12, color: tokens.inkMuted)),
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: BookPaperTheme.values.map((t) {
            final active = settings.paperTheme == t;
            return GestureDetector(
              onTap: () => ctrl.update((s) => s.copyWith(paperTheme: t)),
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
                  t.label,
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
        const SizedBox(height: 6),
      ],
    );
  }

  Widget _buildAnimPanel(
    InkBoxTokens tokens,
    BookReaderSettings settings,
    BookReaderSettingsController ctrl,
  ) {
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
              label: m.label,
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
              label: p.label,
              selected: active,
              onTap: () => ctrl.update((s) => s.copyWith(tapZonePreset: p)),
            );
          }).toList(),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('自动滚屏', style: TextStyle(fontSize: 12, color: tokens.inkMuted)),
            FilledButton.tonal(
              onPressed: _toggleAutoScroll,
              child: Text(_autoScrolling ? '停止滚屏' : '开启自动滚屏'),
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '音量键翻页',
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
                '阅读时保持屏幕常亮',
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
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _openTtsSettingsFromReader,
                child: const Text('TTS 朗读设置', style: TextStyle(fontSize: 12)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () => _showPurificationDialog(settings, ctrl),
                child: const Text('正文净化规则', style: TextStyle(fontSize: 12)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: _exportNotesMarkdown,
                child: const Text('导出笔记', style: TextStyle(fontSize: 12)),
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
    final patCtrl = TextEditingController();
    final repCtrl = TextEditingController();
    final result = await showInkModal<({String pat, String rep})>(
      context: context,
      title: '添加正文净化替换规则',
      subtitle: '支持普通文本或正则表达式',
      disposables: [patCtrl, repCtrl],
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkTextField(
            controller: patCtrl,
            label: '待过滤文本或正则',
            hintText: '例如：请收藏本站.*',
            monospace: true,
          ),
          const SizedBox(height: 10),
          InkTextField(
            controller: repCtrl,
            label: '替换为（留空即删除）',
            hintText: '留空则直接移除匹配内容',
          ),
        ],
      ),
      actionsBuilder: (ctx) => [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop((
            pat: patCtrl.text.trim(),
            rep: repCtrl.text,
          )),
          child: const Text('添加并生效'),
        ),
      ],
    );
    if (result != null && result.pat.isNotEmpty) {
      await ctrl.update(
        (s) => s.copyWith(
          replaceRules: [
            ...s.replaceRules,
            ReplaceRuleConfig(
              name: '自定义净化',
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
    return FutureBuilder<Uint8List?>(
      future: platform.renderPdfPage(pdfPath, pageIndex, scale: 2.0),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final bytes = snap.data;
        if (bytes == null) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                '当前平台暂不支持原版 PDF 位图渲染，请点击顶栏「文本重排」体验 Rust 智能重排模式',
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
