import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/icons/ink_icons.dart';
import '../../core/l10n/l10n_helpers.dart';
import '../../core/layout/responsive_layout.dart';
import '../../core/theme/inkbox_theme.dart';
import '../../core/widgets/ink_controls.dart';
import '../../data/db/app_database.dart';
import '../../data/platform/platform_bridge.dart';
import '../../data/providers/app_providers.dart';
import 'manga_page_source.dart';
import 'manga_reader_settings.dart';

typedef MangaSpreadSlot = ({int first, int? second});

/// Computes dual-page pairing slots while keeping cover page isolated (if
/// [coverAlone]) and isolating any [wideSpreadIndices] onto their own slot.
List<MangaSpreadSlot> buildMangaSpreadSlots({
  required int pageCount,
  required bool coverAlone,
  required Set<int> wideSpreadIndices,
}) {
  if (pageCount <= 0) return const [];
  final slots = <MangaSpreadSlot>[];
  var idx = 0;
  if (coverAlone) {
    slots.add((first: 0, second: null));
    idx = 1;
  }
  while (idx < pageCount) {
    if (wideSpreadIndices.contains(idx)) {
      slots.add((first: idx, second: null));
      idx += 1;
    } else if (idx + 1 < pageCount && !wideSpreadIndices.contains(idx + 1)) {
      slots.add((first: idx, second: idx + 1));
      idx += 2;
    } else {
      slots.add((first: idx, second: null));
      idx += 1;
    }
  }
  return slots;
}

int slotIndexForMangaPage(List<MangaSpreadSlot> slots, int page) {
  if (slots.isEmpty) return 0;
  for (var i = 0; i < slots.length; i++) {
    if (slots[i].first == page || slots[i].second == page) return i;
  }
  return 0;
}

/// Complete V1.0 Manga Reading Engine (Mihon / Tachiyomi + FloatingCard Dark Theater):
/// - CBZ/ZIP, CB7/7Z, PDF image stream, and local image folder streaming
/// - 4 Reading Modes: RTL / LTR / Seamless Webtoon / Dual-Page Spread
/// - Rust pixel-level Smart White-Border Auto-Crop & Wide-Spread Auto-Split
/// - GPU Color Filters (Warm eye-care, Grayscale) + Sub-minimum Dimmer
/// - Mihon Tap Layouts (L-shaped, Edge, Kindle, Disabled) + Volume Key Paging
/// - Mihon 3-Tab FloatingCard Bottom Sheet (阅读模式 / 图像滤镜 / 常规)
class MangaReaderPage extends ConsumerStatefulWidget {
  const MangaReaderPage({
    super.key,
    required this.mangaId,
    this.initialChapterId,
  });

  final int mangaId;
  final int? initialChapterId;

  @override
  ConsumerState<MangaReaderPage> createState() => _MangaReaderPageState();
}

class _MangaReaderPageState extends ConsumerState<MangaReaderPage> {
  Manga? _manga;
  List<MangaChapter> _chapters = const [];
  int _chapterIdx = 0;
  MangaReadingMode _mode = MangaReadingMode.rtl;

  MangaPageSource? _source;
  int _chapterRequest = 0;
  bool _loading = true;
  int _currentPage = 0;
  bool _controlsVisible = false;
  bool _settingsSheetOpen = false;
  int _settingsTabIndex = 0; // 0: mode, 1: filter, 2: general
  Set<int> _wideSpreadIndices = const {};
  bool _effectiveDual = false;

  PageController _pageController = PageController();
  final ScrollController _webtoonScroll = ScrollController();
  StreamSubscription<PlatformEvent>? _eventSub;
  late final AppDatabase _db;
  late final PlatformBridge _platform;

  @override
  void initState() {
    super.initState();
    _db = ref.read(appDatabaseProvider);
    _platform = ref.read(platformBridgeProvider);
    _initReader();
  }

  @override
  void dispose() {
    _persistProgress();
    _eventSub?.cancel();
    _pageController.dispose();
    _webtoonScroll.dispose();
    _source?.dispose();
    _platform.setVolumeKeyPaging(false);
    _platform.setKeepScreenOn(false);
    super.dispose();
  }

  Future<void> _initReader() async {
    final manga = await _db.findMangaById(widget.mangaId);
    if (!mounted) return;
    if (manga == null) {
      setState(() => _loading = false);
      return;
    }

    final chapters = await _db.chaptersForManga(manga.id);
    if (!mounted) return;

    var startChIdx = 0;
    if (widget.initialChapterId != null) {
      final found = chapters.indexWhere((c) => c.id == widget.initialChapterId);
      if (found >= 0) startChIdx = found;
    } else {
      final unreadIdx = chapters.indexWhere((c) => !c.isRead);
      if (unreadIdx >= 0) startChIdx = unreadIdx;
    }

    final settings = ref.read(mangaReaderSettingsProvider);
    await _platform.setKeepScreenOn(settings.keepScreenOn);
    await _platform.setVolumeKeyPaging(settings.volumeKeyPaging);

    _eventSub = _platform.events.listen((ev) {
      if (!mounted) return;
      if (ev.type == 'volume_key') {
        final dir = ev.payload['direction'];
        if (dir == 'down') {
          _stepPage(1);
        } else if (dir == 'up') {
          _stepPage(-1);
        }
      }
    });

    _manga = manga;
    _chapters = chapters;
    _mode = MangaReadingMode.fromCode(manga.preferredReadingMode);
    await _openChapter(startChIdx);
  }

  Future<void> _openChapter(int idx) async {
    if (_manga == null) return;
    final request = ++_chapterRequest;
    setState(() => _loading = true);
    await _source?.dispose();
    if (!mounted || request != _chapterRequest) return;

    final clamped =
        _chapters.isEmpty ? 0 : idx.clamp(0, _chapters.length - 1);
    final sourcePath = _chapters.isNotEmpty
        ? _chapters[clamped].sourcePath
        : _manga!.rootPath;
    final resumePage = _chapters.isNotEmpty ? _chapters[clamped].lastReadPage : 0;

    final src = MangaPageSource(
      sourcePath: sourcePath,
      format: _manga!.format,
      storage: ref.read(libraryStorageProvider),
      rustCore: ref.read(rustCoreProvider),
      platform: ref.read(platformBridgeProvider),
    );
    try {
      await src.open();
    } catch (_) {
      await src.dispose();
    }
    if (!mounted || request != _chapterRequest) {
      await src.dispose();
      return;
    }

    final startPage =
        src.pageCount > 0 ? resumePage.clamp(0, src.pageCount - 1) : 0;

    setState(() {
      _chapterIdx = clamped;
      _source = src;
      _currentPage = startPage;
      _wideSpreadIndices = const {};
      _loading = false;
    });

    final initialDual = _computeEffectiveDual(
      MediaQuery.maybeSizeOf(context) ?? const Size(400, 800),
      ref.read(mangaReaderSettingsProvider),
    );
    _effectiveDual = initialDual;
    final initSlot = slotIndexForMangaPage(
      _slotsFor(_effectiveDual, ref.read(mangaReaderSettingsProvider)),
      startPage,
    );
    _pageController.dispose();
    _pageController = PageController(initialPage: initSlot);

    src.preloadAround(
      startPage,
      computeCrop: ref.read(mangaReaderSettingsProvider).autoCrop,
    );
  }

  int get _totalPages => _source?.pageCount ?? 0;

  bool _computeEffectiveDual(Size viewport, MangaReaderSettings settings) {
    if (_mode == MangaReadingMode.webtoon) return false;
    if (_mode == MangaReadingMode.dual) return true;
    return settings.autoDualInLandscape &&
        viewport.width >= kDualPageMinWidth &&
        viewport.width > viewport.height;
  }

  List<MangaSpreadSlot> _slotsFor(bool dual, MangaReaderSettings settings) {
    if (_totalPages <= 0) return const [];
    if (!dual) {
      return List.generate(_totalPages, (i) => (first: i, second: null));
    }
    return buildMangaSpreadSlots(
      pageCount: _totalPages,
      coverAlone: settings.dualPageShift,
      wideSpreadIndices: _wideSpreadIndices,
    );
  }

  void _handleDecodedMangaPage(DecodedMangaPage page) {
    if (!page.isWideSpread || _wideSpreadIndices.contains(page.index)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _wideSpreadIndices.contains(page.index)) return;
      final settings = ref.read(mangaReaderSettingsProvider);
      setState(() {
        _wideSpreadIndices = {..._wideSpreadIndices, page.index};
      });
      if (_effectiveDual &&
          _mode != MangaReadingMode.webtoon &&
          _pageController.hasClients) {
        final newSlots = _slotsFor(_effectiveDual, settings);
        _pageController.jumpToPage(slotIndexForMangaPage(newSlots, _currentPage));
      }
    });
  }

  void _stepPage(int delta) {
    if (_mode == MangaReadingMode.webtoon) {
      if (!_webtoonScroll.hasClients) return;
      final viewportH = MediaQuery.of(context).size.height * 0.78;
      final target = (_webtoonScroll.offset + delta * viewportH)
          .clamp(0.0, _webtoonScroll.position.maxScrollExtent);
      _webtoonScroll.animateTo(
        target,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
      return;
    }

    final settings = ref.read(mangaReaderSettingsProvider);
    final slots = _slotsFor(_effectiveDual, settings);
    final curSlot = slotIndexForMangaPage(slots, _currentPage);
    final targetSlot = curSlot + delta;
    if (targetSlot < 0) {
      if (_chapterIdx > 0) {
        _openChapter(_chapterIdx - 1);
      } else {
        _toast(context.l10n.firstPageToast);
      }
      return;
    }
    if (targetSlot >= slots.length) {
      if (_chapterIdx + 1 < _chapters.length) {
        _openChapter(_chapterIdx + 1);
      } else {
        _toast(context.l10n.chapterFinishedToast);
      }
      return;
    }

    _pageController.animateToPage(
      targetSlot,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  void _jumpToPage(int page) {
    if (_totalPages == 0) return;
    final clamped = page.clamp(0, _totalPages - 1);
    final settings = ref.read(mangaReaderSettingsProvider);
    final slots = _slotsFor(_effectiveDual, settings);
    setState(() => _currentPage = clamped);
    if (_mode != MangaReadingMode.webtoon && _pageController.hasClients) {
      _pageController.jumpToPage(slotIndexForMangaPage(slots, clamped));
    }
    _persistProgress();
  }

  Future<void> _persistProgress() async {
    final manga = _manga;
    if (manga == null || _chapters.isEmpty) return;
    final ch = _chapters[_chapterIdx];
    await _db.updateMangaChapterProgress(
          mangaId: manga.id,
          chapterId: ch.id,
          lastReadPage: _currentPage,
          pageCount: _totalPages > 0 ? _totalPages : ch.pageCount,
        );
  }

  Future<void> _changeReadingMode(MangaReadingMode nextMode) async {
    setState(() => _mode = nextMode);
    if (_manga != null) {
      await ref.read(appDatabaseProvider).updateMangaMeta(
            _manga!.id,
            preferredReadingMode: nextMode.code,
          );
    }
    if (!mounted) return;
    if (nextMode != MangaReadingMode.webtoon) {
      final settings = ref.read(mangaReaderSettingsProvider);
      final dual = _computeEffectiveDual(
        MediaQuery.maybeSizeOf(context) ?? const Size(400, 800),
        settings,
      );
      _effectiveDual = dual;
      final slots = _slotsFor(dual, settings);
      _pageController.dispose();
      _pageController = PageController(
        initialPage: slotIndexForMangaPage(slots, _currentPage),
      );
      setState(() {});
    }
  }

  void _handleCanvasTap(TapUpDetails details, Size size) {
    final settings = ref.read(mangaReaderSettingsProvider);
    final nx = (details.localPosition.dx / size.width).clamp(0.0, 1.0);
    final ny = (details.localPosition.dy / size.height).clamp(0.0, 1.0);
    final delta = settings.resolveTapDelta(
      nx,
      ny,
      isRtl: _mode == MangaReadingMode.rtl || _mode == MangaReadingMode.dual,
    );

    if (delta == 0) {
      setState(() {
        _controlsVisible = !_controlsVisible;
        if (!_controlsVisible) _settingsSheetOpen = false;
      });
    } else {
      setState(() {
        _controlsVisible = false;
        _settingsSheetOpen = false;
      });
      _stepPage(delta);
    }
  }

  ColorFilter? _buildColorFilter(MangaReaderSettings settings) {
    if (settings.grayscaleFilter) {
      return const ColorFilter.matrix([
        0.2126, 0.7152, 0.0722, 0, 0,
        0.2126, 0.7152, 0.0722, 0, 0,
        0.2126, 0.7152, 0.0722, 0, 0,
        0, 0, 0, 1, 0,
      ]);
    }
    if (settings.warmFilter) {
      // Gentle amber eye-care warmth reducing blue channel ~22%
      return const ColorFilter.matrix([
        1.0, 0, 0, 0, 10,
        0, 0.94, 0, 0, 4,
        0, 0, 0.78, 0, 0,
        0, 0, 0, 1, 0,
      ]);
    }
    return null;
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(milliseconds: 1400)),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final settings = ref.watch(mangaReaderSettingsProvider);
    final settingsCtrl = ref.read(mangaReaderSettingsProvider.notifier);
    final chapterTitle =
        _chapters.isNotEmpty ? _chapters[_chapterIdx].title : (_manga?.title ?? '');
    final filter = _buildColorFilter(settings);

    Widget readerCanvas = _loading
        ? const Center(child: CircularProgressIndicator(color: Colors.white))
        : _totalPages == 0
            ? Center(
                child: Text(
                  l10n.mangaNoImagesInChapter,
                  style: const TextStyle(color: Colors.white70),
                ),
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  final size = constraints.biggest;
                  final dual = _computeEffectiveDual(size, settings);
                  final slots = _slotsFor(dual, settings);
                  if (dual != _effectiveDual) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      setState(() => _effectiveDual = dual);
                      if (_mode != MangaReadingMode.webtoon &&
                          _pageController.hasClients) {
                        _pageController.jumpToPage(
                          slotIndexForMangaPage(slots, _currentPage),
                        );
                      }
                    });
                  }
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (d) => _handleCanvasTap(d, size),
                    child: _buildModeViewport(settings, dual, slots),
                  );
                },
              );

    if (filter != null) {
      readerCanvas = ColorFiltered(colorFilter: filter, child: readerCanvas);
    }

    final wideControls = MediaQuery.sizeOf(context).width > 680;

    return Scaffold(
      backgroundColor: settings.canvasBg.color,
      body: Stack(
        children: [
          Positioned.fill(child: readerCanvas),

          // Sub-minimum darkroom dimmer mask
          if (settings.dimmerOpacity > 0.01)
            Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: settings.dimmerOpacity),
                ),
              ),
            ),

          // Subtle corner indicator when controls are hidden
          if (!_controlsVisible && settings.showPageBadge && _totalPages > 0)
            Positioned(
              left: 14,
              right: 14,
              bottom: MediaQuery.of(context).padding.bottom + 10,
              child: IgnorePointer(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$chapterTitle · ${_effectiveDual ? l10n.mangaReadingModeDual : _mode.labelOf(l10n)}',
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${_currentPage + 1} / $_totalPages',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Detached Dark FloatingCard Top Bar
          if (_controlsVisible)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 12,
              right: 12,
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: wideControls ? 620 : double.infinity,
                  ),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xEB1A1C21),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white12),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x80000000),
                          blurRadius: 20,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => context.pop(),
                          icon: const InkIconWidget(
                            InkIcon.back,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _manga?.title ?? l10n.navManga,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                chapterTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white60,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: l10n.mangaToggleCropTooltip,
                          onPressed: () => settingsCtrl
                              .update((s) => s.copyWith(autoCrop: !s.autoCrop)),
                          icon: InkIconWidget(
                            InkIcon.crop,
                            size: 18,
                            color: settings.autoCrop
                                ? InkBoxTheme.slateInkDark
                                : Colors.white70,
                          ),
                        ),
                        IconButton(
                          tooltip: l10n.mangaToggleSettingsTooltip,
                          onPressed: () => setState(
                              () => _settingsSheetOpen = !_settingsSheetOpen),
                          icon: InkIconWidget(
                            InkIcon.gear,
                            size: 18,
                            color: _settingsSheetOpen
                                ? InkBoxTheme.slateInkDark
                                : Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Detached Dark FloatingCard Bottom Scrubber + Mihon 3-Tab Settings Sheet
          if (_controlsVisible)
            Positioned(
              left: 12,
              right: 12,
              bottom: MediaQuery.of(context).padding.bottom + 12,
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: wideControls ? 620 : double.infinity,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!_settingsSheetOpen) ...[
                        // Floating Page Scrubber Pill (RTL-mirrored when RTL active!)
                        Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xEB1A1C21),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                onPressed: _chapterIdx > 0
                                    ? () => _openChapter(_chapterIdx - 1)
                                    : null,
                                icon: const InkIconWidget(
                                  InkIcon.back,
                                  size: 16,
                                  color: Colors.white70,
                                ),
                              ),
                              Builder(
                                builder: (_) {
                                  final isRtlScrubber =
                                      _mode == MangaReadingMode.rtl ||
                                          _mode == MangaReadingMode.dual;
                                  return Expanded(
                                    child: Row(
                                      children: [
                                        Text(
                                          isRtlScrubber
                                              ? '$_totalPages'
                                              : '${_currentPage + 1}',
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            color: Colors.white70,
                                          ),
                                        ),
                                        Expanded(
                                          child: Directionality(
                                            textDirection: isRtlScrubber
                                                ? TextDirection.rtl
                                                : TextDirection.ltr,
                                            child: Slider(
                                              min: 0,
                                              max: (_totalPages - 1)
                                                  .clamp(1, 9999)
                                                  .toDouble(),
                                              value: _currentPage
                                                  .clamp(
                                                    0,
                                                    (_totalPages - 1)
                                                        .clamp(1, 9999),
                                                  )
                                                  .toDouble(),
                                              activeColor:
                                                  InkBoxTheme.slateInkDark,
                                              onChanged: _totalPages > 1
                                                  ? (v) => _jumpToPage(v.round())
                                                  : null,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          isRtlScrubber
                                              ? '${_currentPage + 1}'
                                              : '$_totalPages',
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            color: Colors.white70,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                onPressed: _chapterIdx + 1 < _chapters.length
                                    ? () => _openChapter(_chapterIdx + 1)
                                    : null,
                                icon: Transform(
                                  alignment: Alignment.center,
                                  transform: Matrix4.diagonal3Values(-1, 1, 1),
                                  child: const InkIconWidget(
                                    InkIcon.back,
                                    size: 16,
                                    color: Colors.white70,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Quick Action Floating Dock
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 11,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xF21A1C21),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _DarkDockAction(
                                icon: InkIcon.pageCurl,
                                label: _mode.labelOf(l10n),
                                active: true,
                                onTap: () => setState(() {
                                  _settingsSheetOpen = true;
                                  _settingsTabIndex = 0;
                                }),
                              ),
                              _DarkDockAction(
                                icon: InkIcon.crop,
                                label: l10n.smartCropLabel,
                                active: settings.autoCrop,
                                onTap: () => settingsCtrl.update(
                                  (s) => s.copyWith(autoCrop: !s.autoCrop),
                                ),
                              ),
                              _DarkDockAction(
                                icon: InkIcon.filter,
                                label: l10n.mangaTabFilter,
                                active: settings.warmFilter ||
                                    settings.grayscaleFilter ||
                                    settings.dimmerOpacity > 0,
                                onTap: () => setState(() {
                                  _settingsSheetOpen = true;
                                  _settingsTabIndex = 1;
                                }),
                              ),
                              _DarkDockAction(
                                icon: InkIcon.gear,
                                label: l10n.mangaTabGeneral,
                                active: false,
                                onTap: () => setState(() {
                                  _settingsSheetOpen = true;
                                  _settingsTabIndex = 2;
                                }),
                              ),
                            ],
                          ),
                        ),
                      ] else
                        _buildMihonSettingsCard(settings, settingsCtrl),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildModeViewport(
    MangaReaderSettings settings,
    bool dual,
    List<MangaSpreadSlot> slots,
  ) {
    final l10n = context.l10n;
    final decodeFailedText = l10n.mangaDecodeFailed;
    final fallbackTitle = _manga?.title ?? l10n.navManga;

    if (_mode == MangaReadingMode.webtoon) {
      final hPad =
          MediaQuery.of(context).size.width * settings.webtoonSidePaddingPct;
      return ListView.builder(
        controller: _webtoonScroll,
        padding: EdgeInsets.symmetric(horizontal: hPad),
        itemCount: _totalPages,
        itemBuilder: (context, index) {
          _source?.preloadAround(index, computeCrop: settings.autoCrop);
          return _MangaSinglePageView(
            source: _source!,
            pageIndex: index,
            title: fallbackTitle,
            decodeFailedText: decodeFailedText,
            settings: settings,
            isWebtoon: true,
          );
        },
      );
    }

    final reverse =
        _mode == MangaReadingMode.rtl || _mode == MangaReadingMode.dual;

    return PageView.builder(
      controller: _pageController,
      reverse: reverse,
      itemCount: slots.length,
      onPageChanged: (slot) {
        if (slot < 0 || slot >= slots.length) return;
        final page = slots[slot].first;
        setState(() => _currentPage = page);
        _source?.preloadAround(page, computeCrop: settings.autoCrop);
        _persistProgress();
      },
      itemBuilder: (context, slot) {
        final item = slots[slot];
        if (!dual || item.second == null) {
          return _MangaSinglePageView(
            source: _source!,
            pageIndex: item.first,
            title: fallbackTitle,
            decodeFailedText: decodeFailedText,
            settings: settings,
            onDecodedPage: _handleDecodedMangaPage,
          );
        }

        final p1 = item.first;
        final p2 = item.second!;
        final leftIdx = reverse ? p2 : p1;
        final rightIdx = reverse ? p1 : p2;

        return Row(
          children: [
            Expanded(
              child: _MangaSinglePageView(
                source: _source!,
                pageIndex: leftIdx,
                title: fallbackTitle,
                decodeFailedText: decodeFailedText,
                settings: settings,
                onDecodedPage: _handleDecodedMangaPage,
              ),
            ),
            Expanded(
              child: _MangaSinglePageView(
                source: _source!,
                pageIndex: rightIdx,
                title: fallbackTitle,
                decodeFailedText: decodeFailedText,
                settings: settings,
                onDecodedPage: _handleDecodedMangaPage,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMihonSettingsCard(
    MangaReaderSettings settings,
    MangaReaderSettingsController ctrl,
  ) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xF51A1C21),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x99000000),
            blurRadius: 26,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    _SettingsTabPill(
                      l10n.mangaTabMode,
                      active: _settingsTabIndex == 0,
                      onTap: () => setState(() => _settingsTabIndex = 0),
                    ),
                    const SizedBox(width: 6),
                    _SettingsTabPill(
                      l10n.mangaTabFilter,
                      active: _settingsTabIndex == 1,
                      onTap: () => setState(() => _settingsTabIndex = 1),
                    ),
                    const SizedBox(width: 6),
                    _SettingsTabPill(
                      l10n.mangaTabGeneral,
                      active: _settingsTabIndex == 2,
                      onTap: () => setState(() => _settingsTabIndex = 2),
                    ),
                  ],
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => setState(() => _settingsSheetOpen = false),
                icon: const InkIconWidget(
                  InkIcon.close,
                  size: 16,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_settingsTabIndex == 0) ...[
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 3.4,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: MangaReadingMode.values.map((m) {
                final active = _mode == m;
                return GestureDetector(
                  onTap: () => _changeReadingMode(m),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: active ? const Color(0xFF263547) : Colors.white10,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: active ? InkBoxTheme.slateInkDark : Colors.white12,
                      ),
                    ),
                    child: Text(
                      m.labelOf(l10n),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: active ? Colors.white : Colors.white70,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              children: MangaScaleType.values.map((st) {
                final active = settings.scaleType == st;
                return GestureDetector(
                  onTap: () => ctrl.update((s) => s.copyWith(scaleType: st)),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: active ? InkBoxTheme.slateInkDark : Colors.white10,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      st.labelOf(l10n),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: active ? const Color(0xFF0D1620) : Colors.white70,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            _DarkSwitchRow(
              label: l10n.mangaAutoDualLandscape,
              value: settings.autoDualInLandscape,
              onChanged: (v) =>
                  ctrl.update((s) => s.copyWith(autoDualInLandscape: v)),
            ),
            _DarkSwitchRow(
              label: l10n.mangaCoverAlone,
              value: settings.dualPageShift,
              onChanged: (v) {
                ctrl.update((s) => s.copyWith(dualPageShift: v));
                if (_effectiveDual &&
                    _mode != MangaReadingMode.webtoon &&
                    _pageController.hasClients) {
                  final newSlots = _slotsFor(
                    true,
                    settings.copyWith(dualPageShift: v),
                  );
                  _pageController.jumpToPage(
                    slotIndexForMangaPage(newSlots, _currentPage),
                  );
                }
              },
            ),
            _DarkSwitchRow(
              label: l10n.splitWidePagesLabel,
              value: settings.splitWidePages,
              onChanged: (v) =>
                  ctrl.update((s) => s.copyWith(splitWidePages: v)),
            ),
          ] else if (_settingsTabIndex == 1) ...[
            _DarkSwitchRow(
              label: l10n.mangaAutoCrop,
              value: settings.autoCrop,
              onChanged: (v) => ctrl.update((s) => s.copyWith(autoCrop: v)),
            ),
            _DarkSwitchRow(
              label: l10n.mangaWarmFilter,
              value: settings.warmFilter,
              onChanged: (v) => ctrl.update((s) => s.copyWith(warmFilter: v)),
            ),
            _DarkSwitchRow(
              label: l10n.mangaGrayscaleFilter,
              value: settings.grayscaleFilter,
              onChanged: (v) =>
                  ctrl.update((s) => s.copyWith(grayscaleFilter: v)),
            ),
            Row(
              children: [
                Text(
                  l10n.mangaDimmerLabel,
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
                Expanded(
                  child: Slider(
                    min: 0.0,
                    max: 0.65,
                    value: settings.dimmerOpacity,
                    activeColor: InkBoxTheme.slateInkDark,
                    onChanged: (v) =>
                        ctrl.update((s) => s.copyWith(dimmerOpacity: v)),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Text(
                  l10n.mangaCanvasBgLabel,
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
                const SizedBox(width: 12),
                ...MangaCanvasBg.values.map((bg) {
                  final active = settings.canvasBg == bg;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => ctrl.update((s) => s.copyWith(canvasBg: bg)),
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: bg.color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: active
                                ? InkBoxTheme.slateInkDark
                                : Colors.white38,
                            width: active ? 2.5 : 1,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ] else ...[
            Text(
              l10n.mangaTapLayoutLabel,
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: MangaTapLayout.values.map((tl) {
                final active = settings.tapLayout == tl;
                return GestureDetector(
                  onTap: () => ctrl.update((s) => s.copyWith(tapLayout: tl)),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: active ? InkBoxTheme.slateInkDark : Colors.white10,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      tl.labelOf(l10n),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: active ? const Color(0xFF0D1620) : Colors.white70,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            _DarkSwitchRow(
              label: l10n.volumeKeyPaging,
              value: settings.volumeKeyPaging,
              onChanged: (v) {
                ctrl.update((s) => s.copyWith(volumeKeyPaging: v));
                ref.read(platformBridgeProvider).setVolumeKeyPaging(v);
              },
            ),
            _DarkSwitchRow(
              label: l10n.mangaShowPageBadge,
              value: settings.showPageBadge,
              onChanged: (v) =>
                  ctrl.update((s) => s.copyWith(showPageBadge: v)),
            ),
          ],
        ],
      ),
    );
  }
}

class _MangaSinglePageView extends StatefulWidget {
  const _MangaSinglePageView({
    required this.source,
    required this.pageIndex,
    required this.title,
    required this.decodeFailedText,
    required this.settings,
    this.isWebtoon = false,
    this.onDecodedPage,
  });

  final MangaPageSource source;
  final int pageIndex;
  final String title;
  final String decodeFailedText;
  final MangaReaderSettings settings;
  final bool isWebtoon;
  final ValueChanged<DecodedMangaPage>? onDecodedPage;

  @override
  State<_MangaSinglePageView> createState() => _MangaSinglePageViewState();
}

class _MangaSinglePageViewState extends State<_MangaSinglePageView> {
  final TransformationController _zoomCtrl = TransformationController();
  late Future<DecodedMangaPage?> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.source.loadPage(
      widget.pageIndex,
      computeCrop: widget.settings.autoCrop,
    );
  }

  @override
  void didUpdateWidget(covariant _MangaSinglePageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pageIndex != widget.pageIndex ||
        oldWidget.source != widget.source) {
      _future = widget.source.loadPage(
        widget.pageIndex,
        computeCrop: widget.settings.autoCrop,
      );
    }
  }

  @override
  void dispose() {
    _zoomCtrl.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    final zoomed = _zoomCtrl.value.getMaxScaleOnAxis() > 1.1;
    _zoomCtrl.value =
        zoomed ? Matrix4.identity() : Matrix4.diagonal3Values(2.2, 2.2, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final fit = switch (widget.settings.scaleType) {
      MangaScaleType.fitScreen => BoxFit.contain,
      MangaScaleType.fitWidth => BoxFit.fitWidth,
      MangaScaleType.fitHeight => BoxFit.fitHeight,
      MangaScaleType.original => BoxFit.none,
    };

    return FutureBuilder<DecodedMangaPage?>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return SizedBox(
            height: widget.isWebtoon ? 480 : double.infinity,
            child: const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white54,
              ),
            ),
          );
        }
        final page = snap.data;
        if (page == null) {
          return Center(
            child: Text(
              widget.decodeFailedText,
              style: const TextStyle(color: Colors.white54),
            ),
          );
        }
        widget.onDecodedPage?.call(page);

        Widget img = Image.memory(
          Uint8List.fromList(page.bytes),
          fit: widget.isWebtoon ? BoxFit.fitWidth : fit,
          gaplessPlayback: true,
        );

        if (widget.settings.autoCrop) {
          final r = page.cropRect;
          final wFactor = (r.right - r.left).clamp(0.45, 1.0);
          final hFactor = (r.bottom - r.top).clamp(0.45, 1.0);
          if (wFactor < 0.99 || hFactor < 0.99) {
            final alignX = ((r.left + r.right) - 1.0) / (1.0 - wFactor + 0.0001);
            final alignY = ((r.top + r.bottom) - 1.0) / (1.0 - hFactor + 0.0001);
            img = ClipRect(
              child: Align(
                alignment: Alignment(
                  alignX.clamp(-1.0, 1.0),
                  alignY.clamp(-1.0, 1.0),
                ),
                widthFactor: wFactor,
                heightFactor: hFactor,
                child: img,
              ),
            );
          }
        }

        if (widget.isWebtoon) return img;

        return GestureDetector(
          onDoubleTap: _handleDoubleTap,
          child: InteractiveViewer(
            transformationController: _zoomCtrl,
            minScale: 1.0,
            maxScale: 4.0,
            child: Center(child: img),
          ),
        );
      },
    );
  }
}

class _DarkDockAction extends StatelessWidget {
  const _DarkDockAction({
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
    final c = active ? InkBoxTheme.slateInkDark : Colors.white70;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkIconWidget(icon, size: 18, color: c),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(fontSize: 10.5, color: c)),
        ],
      ),
    );
  }
}

class _SettingsTabPill extends StatelessWidget {
  const _SettingsTabPill(
    this.label, {
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: active ? InkBoxTheme.slateInkDark : Colors.white10,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: active ? const Color(0xFF0D1620) : Colors.white70,
          ),
        ),
      ),
    );
  }
}

class _DarkSwitchRow extends StatelessWidget {
  const _DarkSwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12.5, color: Colors.white),
          ),
          InkSwitch(
            value: value,
            onChanged: onChanged,
            activeColor: InkBoxTheme.slateInkDark,
            inactiveColor: Colors.white12,
            thumbColor: Colors.white,
          ),
        ],
      ),
    );
  }
}
