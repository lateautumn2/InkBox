import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/icons/ink_icons.dart';
import '../../core/theme/inkbox_theme.dart';
import '../../core/widgets/ink_controls.dart';
import '../../data/db/app_database.dart';
import '../../data/platform/platform_bridge.dart';
import '../../data/providers/app_providers.dart';
import 'manga_page_source.dart';
import 'manga_reader_settings.dart';

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
  bool _loading = true;
  int _currentPage = 0;
  bool _controlsVisible = false;
  bool _settingsSheetOpen = false;
  int _settingsTabIndex = 0; // 0: 模式, 1: 滤镜, 2: 常规

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
    setState(() => _loading = true);
    await _source?.dispose();

    final clamped =
        _chapters.isEmpty ? 0 : idx.clamp(0, _chapters.length - 1);
    final sourcePath = _chapters.isNotEmpty
        ? _chapters[clamped].sourcePath
        : _manga!.rootPath;
    final resumePage = _chapters.isNotEmpty ? _chapters[clamped].lastReadPage : 0;

    final src = MangaPageSource(
      sourcePath: sourcePath,
      rustCore: ref.read(rustCoreProvider),
      platform: ref.read(platformBridgeProvider),
    );
    await src.open();
    if (!mounted) return;

    final startPage =
        src.pageCount > 0 ? resumePage.clamp(0, src.pageCount - 1) : 0;

    _pageController.dispose();
    _pageController = PageController(initialPage: _slotForPage(startPage));

    setState(() {
      _chapterIdx = clamped;
      _source = src;
      _currentPage = startPage;
      _loading = false;
    });

    src.preloadAround(
      startPage,
      computeCrop: ref.read(mangaReaderSettingsProvider).autoCrop,
    );
  }

  int get _totalPages => _source?.pageCount ?? 0;

  /// Dual-page mode groups page 0 (cover) alone, then pairs [1,2], [3,4]...
  int get _slotCount {
    if (_totalPages == 0) return 0;
    if (_mode == MangaReadingMode.dual) {
      if (_totalPages == 1) return 1;
      return 1 + ((_totalPages - 1) / 2).ceil();
    }
    return _totalPages;
  }

  int _slotForPage(int page) {
    if (_mode != MangaReadingMode.dual) return page;
    if (page <= 0) return 0;
    return 1 + ((page - 1) ~/ 2);
  }

  int _firstPageOfSlot(int slot) {
    if (_mode != MangaReadingMode.dual) return slot;
    if (slot <= 0) return 0;
    return 1 + (slot - 1) * 2;
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

    final curSlot = _slotForPage(_currentPage);
    final targetSlot = curSlot + delta;
    if (targetSlot < 0) {
      if (_chapterIdx > 0) {
        _openChapter(_chapterIdx - 1);
      } else {
        _toast('已是第一页');
      }
      return;
    }
    if (targetSlot >= _slotCount) {
      if (_chapterIdx + 1 < _chapters.length) {
        _openChapter(_chapterIdx + 1);
      } else {
        _toast('本话已读完');
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
    setState(() => _currentPage = clamped);
    if (_mode != MangaReadingMode.webtoon && _pageController.hasClients) {
      _pageController.jumpToPage(_slotForPage(clamped));
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
    if (nextMode != MangaReadingMode.webtoon) {
      _pageController.dispose();
      _pageController = PageController(initialPage: _slotForPage(_currentPage));
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
    final settings = ref.watch(mangaReaderSettingsProvider);
    final settingsCtrl = ref.read(mangaReaderSettingsProvider.notifier);
    final chapterTitle =
        _chapters.isNotEmpty ? _chapters[_chapterIdx].title : (_manga?.title ?? '');
    final filter = _buildColorFilter(settings);

    Widget readerCanvas = _loading
        ? const Center(child: CircularProgressIndicator(color: Colors.white))
        : _totalPages == 0
            ? const Center(
                child: Text(
                  '该章节未发现可渲染图片',
                  style: TextStyle(color: Colors.white70),
                ),
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  final size = constraints.biggest;
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (d) => _handleCanvasTap(d, size),
                    child: _buildModeViewport(settings),
                  );
                },
              );

    if (filter != null) {
      readerCanvas = ColorFiltered(colorFilter: filter, child: readerCanvas);
    }

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
                        '$chapterTitle · ${_mode.label}',
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
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                            _manga?.title ?? '漫画阅读',
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
                      tooltip: '快捷切换智能裁边',
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
                      tooltip: '展开阅读器设置',
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

          // Detached Dark FloatingCard Bottom Scrubber + Mihon 3-Tab Settings Sheet
          if (_controlsVisible)
            Positioned(
              left: 12,
              right: 12,
              bottom: MediaQuery.of(context).padding.bottom + 12,
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
                          Text(
                            _mode == MangaReadingMode.rtl
                                ? '$_totalPages'
                                : '${_currentPage + 1}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Colors.white70,
                            ),
                          ),
                          Expanded(
                            child: Directionality(
                              textDirection: _mode == MangaReadingMode.rtl
                                  ? TextDirection.rtl
                                  : TextDirection.ltr,
                              child: Slider(
                                min: 0,
                                max: (_totalPages - 1).clamp(1, 9999).toDouble(),
                                value: _currentPage
                                    .clamp(0, (_totalPages - 1).clamp(1, 9999))
                                    .toDouble(),
                                activeColor: InkBoxTheme.slateInkDark,
                                onChanged: _totalPages > 1
                                    ? (v) => _jumpToPage(v.round())
                                    : null,
                              ),
                            ),
                          ),
                          Text(
                            _mode == MangaReadingMode.rtl
                                ? '${_currentPage + 1}'
                                : '$_totalPages',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Colors.white70,
                            ),
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
                            label: _mode.label,
                            active: true,
                            onTap: () => setState(() {
                              _settingsSheetOpen = true;
                              _settingsTabIndex = 0;
                            }),
                          ),
                          _DarkDockAction(
                            icon: InkIcon.crop,
                            label: '智能裁边',
                            active: settings.autoCrop,
                            onTap: () => settingsCtrl.update(
                              (s) => s.copyWith(autoCrop: !s.autoCrop),
                            ),
                          ),
                          _DarkDockAction(
                            icon: InkIcon.filter,
                            label: '图像滤镜',
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
                            label: '常规',
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
        ],
      ),
    );
  }

  Widget _buildModeViewport(MangaReaderSettings settings) {
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
            title: _manga?.title ?? '漫画',
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
      itemCount: _slotCount,
      onPageChanged: (slot) {
        final page = _firstPageOfSlot(slot);
        setState(() => _currentPage = page);
        _source?.preloadAround(page, computeCrop: settings.autoCrop);
        _persistProgress();
      },
      itemBuilder: (context, slot) {
        if (_mode == MangaReadingMode.dual) {
          if (slot == 0) {
            return _MangaSinglePageView(
              source: _source!,
              pageIndex: 0,
              title: _manga?.title ?? '漫画',
              settings: settings,
            );
          }
          final p1 = 1 + (slot - 1) * 2;
          final p2 = p1 + 1;
          return Row(
            children: [
              Expanded(
                child: p2 < _totalPages
                    ? _MangaSinglePageView(
                        source: _source!,
                        pageIndex: p2,
                        title: _manga?.title ?? '漫画',
                        settings: settings,
                      )
                    : const SizedBox.shrink(),
              ),
              Expanded(
                child: _MangaSinglePageView(
                  source: _source!,
                  pageIndex: p1,
                  title: _manga?.title ?? '漫画',
                  settings: settings,
                ),
              ),
            ],
          );
        }

        return _MangaSinglePageView(
          source: _source!,
          pageIndex: slot,
          title: _manga?.title ?? '漫画',
          settings: settings,
        );
      },
    );
  }

  Widget _buildMihonSettingsCard(
    MangaReaderSettings settings,
    MangaReaderSettingsController ctrl,
  ) {
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
                      '阅读模式',
                      active: _settingsTabIndex == 0,
                      onTap: () => setState(() => _settingsTabIndex = 0),
                    ),
                    const SizedBox(width: 6),
                    _SettingsTabPill(
                      '图像滤镜',
                      active: _settingsTabIndex == 1,
                      onTap: () => setState(() => _settingsTabIndex = 1),
                    ),
                    const SizedBox(width: 6),
                    _SettingsTabPill(
                      '常规',
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
                      m.label,
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
                      st.label,
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
              label: '自动切分跨页宽图',
              value: settings.splitWidePages,
              onChanged: (v) =>
                  ctrl.update((s) => s.copyWith(splitWidePages: v)),
            ),
          ] else if (_settingsTabIndex == 1) ...[
            _DarkSwitchRow(
              label: '智能裁切白边',
              value: settings.autoCrop,
              onChanged: (v) => ctrl.update((s) => s.copyWith(autoCrop: v)),
            ),
            _DarkSwitchRow(
              label: '夜间暖色护眼滤镜',
              value: settings.warmFilter,
              onChanged: (v) => ctrl.update((s) => s.copyWith(warmFilter: v)),
            ),
            _DarkSwitchRow(
              label: '黑白墨色增强 (灰度)',
              value: settings.grayscaleFilter,
              onChanged: (v) =>
                  ctrl.update((s) => s.copyWith(grayscaleFilter: v)),
            ),
            Row(
              children: [
                const Text(
                  '暗室调光',
                  style: TextStyle(fontSize: 12, color: Colors.white70),
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
                const Text(
                  '画布底色',
                  style: TextStyle(fontSize: 12, color: Colors.white70),
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
            const Text(
              '点击翻页布局',
              style: TextStyle(fontSize: 12, color: Colors.white70),
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
                      tl.label,
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
              label: '音量键翻页',
              value: settings.volumeKeyPaging,
              onChanged: (v) {
                ctrl.update((s) => s.copyWith(volumeKeyPaging: v));
                ref.read(platformBridgeProvider).setVolumeKeyPaging(v);
              },
            ),
            _DarkSwitchRow(
              label: '显示底角页码提示',
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
    required this.settings,
    this.isWebtoon = false,
  });

  final MangaPageSource source;
  final int pageIndex;
  final String title;
  final MangaReaderSettings settings;
  final bool isWebtoon;

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
          return const Center(
            child: Text('页面解码失败', style: TextStyle(color: Colors.white54)),
          );
        }

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
