import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkbox/core/icons/ink_icons.dart';
import 'package:inkbox/core/navigation/app_router.dart';
import 'package:inkbox/core/theme/inkbox_theme.dart';
import 'package:inkbox/core/widgets/floating_surface.dart';
import 'package:inkbox/data/db/app_database.dart';
import 'package:inkbox/data/platform/platform_bridge.dart';
import 'package:inkbox/data/providers/app_providers.dart';
import 'package:inkbox/features/book_reader/book_paginator.dart';
import 'package:inkbox/features/book_reader/book_reader_page.dart';
import 'package:inkbox/features/book_reader/book_reader_settings.dart';
import 'package:inkbox/features/book_reader/page_turn_painter.dart';
import 'package:inkbox/features/book_reader/reader_highlight_canvas.dart';
import 'package:inkbox/features/bookshelf/bookshelf_page.dart';
import 'package:inkbox/main.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

class _TestPlatformBridge implements PlatformBridge {
  final StreamController<PlatformEvent> eventCtrl =
      StreamController<PlatformEvent>.broadcast();
  int _uidSeq = 0;
  final List<String> spokenTexts = [];
  String? lastUtteranceId;

  @override
  Stream<PlatformEvent> get events => eventCtrl.stream;
  @override
  Future<List<String>> pickDocuments() async => const [];
  @override
  Future<PickedDocumentsResult> pickDocumentsDetailed() async =>
      const PickedDocumentsResult();
  @override
  Future<PickedDirectory?> pickPersistentDirectory() async => null;
  @override
  Future<List<ScannedTreeFile>> scanPersistentDirectory(String treeUri) async =>
      const [];
  @override
  Future<void> setKeepScreenOn(bool enabled) async {}
  @override
  Future<void> setScreenBrightness(double? brightness) async {}
  @override
  Future<void> setVolumeKeyPaging(bool enabled) async {}
  @override
  Future<String?> speakText(
    String text, {
    double rate = 1.0,
    double pitch = 1.0,
    String? language,
    String? engine,
  }) async {
    spokenTexts.add(text);
    lastUtteranceId = 'utt_${++_uidSeq}';
    return lastUtteranceId;
  }
  @override
  Future<String?> stageDocumentUri(String uri, {String? fileName}) async =>
      null;
  @override
  Future<void> stopTts() async {}
  @override
  Future<List<TtsEngineOption>> getTtsEngines() async => const [];
  @override
  Future<void> openSystemTtsSettings() async {}
  @override
  Future<int> getPdfPageCount(String path) async => 0;
  @override
  Future<Uint8List?> renderPdfPage(String path, int pageIndex,
          {double scale = 2.0}) async =>
      null;
}

Future<void> _flushRealAsync(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 80)),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 60));
}

Future<void> _waitUntilLoaded(WidgetTester tester) async {
  for (var i = 0; i < 15; i++) {
    await _flushRealAsync(tester);
    if (find.byType(CircularProgressIndicator).evaluate().isEmpty) {
      return;
    }
  }
}

Future<int> _insertRealTempNovel(AppDatabase db, Directory tmpDir) async {
  final ch1Paras = List.generate(
    18,
    (i) =>
        '这是第一章第 ${i + 1} 段正文内容，用于在真实文本文件下验证分页引擎、滚动翻页与跨章节顺滑切换能力。夜风掠过青石古道，星光落在窗棂之上。',
  ).join('\r\n\r\n');
  final ch2Paras = List.generate(
    14,
    (i) =>
        '这是第二章第 ${i + 1} 段正文内容，猜疑链与技术爆炸的推演在此展开，每一页都保持精准字符锚点。',
  ).join('\r\n\r\n');
  const ch3Paras = '这是第三章终章正文，全书圆满收尾。';

  final txtFile = File(p.join(tmpDir.path, 'real_novel.txt'))
    ..writeAsStringSync(
      '第一章 启程之夜\r\n$ch1Paras\r\n\r\n第二章 猜疑链与技术爆炸\r\n$ch2Paras\r\n\r\n第三章 终章归途\r\n$ch3Paras',
    );
  final now = DateTime.now().millisecondsSinceEpoch;
  return db.upsertBook(
    BooksCompanion.insert(
      contentHash: 'test_real_novel_hash',
      title: '测试实书',
      author: const drift.Value('测试作者'),
      format: 'TXT',
      filePath: txtFile.path,
      currentChapterTitle: const drift.Value('第一章 启程之夜'),
      addedAtMs: now,
      lastReadAtMs: now,
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Book Page Turn Stage (Simulation / Cover / Slide)', () {
    testWidgets(
        'supports drag, tap-animated, and reverse page turns in all 3 modes',
        (tester) async {
      for (final mode in [
        PageTurnMode.simulation,
        PageTurnMode.cover,
        PageTurnMode.slide,
      ]) {
        var pageIndex = 0;
        final pages = [
          'Chapter 1 - Page 1',
          'Chapter 1 - Page 2',
          'Chapter 2 - Page 1',
        ];
        final ctrl = PageTurnController();

        await tester.pumpWidget(
          MaterialApp(
            theme: InkBoxTheme.light(uiStyle: InkBoxUiStyle.floatingCard),
            home: StatefulBuilder(
              builder: (context, setState) {
                return Scaffold(
                  body: PageTurnStage(
                    controller: ctrl,
                    mode: mode,
                    paperColor: BookPaperTheme.parchment.background,
                    currentPage: Center(child: Text(pages[pageIndex])),
                    previousPage: pageIndex > 0
                        ? Center(child: Text(pages[pageIndex - 1]))
                        : null,
                    nextPage: pageIndex + 1 < pages.length
                        ? Center(child: Text(pages[pageIndex + 1]))
                        : null,
                    canTurnPrev: pageIndex > 0,
                    canTurnNext: pageIndex + 1 < pages.length,
                    onTurnNext: () => setState(() => pageIndex++),
                    onTurnPrev: () => setState(() => pageIndex--),
                    onTapNormalized: (nx, ny) {
                      if (nx > 0.66) ctrl.turnNext();
                      if (nx < 0.33) ctrl.turnPrev();
                    },
                  ),
                );
              },
            ),
          ),
        );

        expect(find.text('Chapter 1 - Page 1'), findsOneWidget);

        await tester.drag(find.byType(PageTurnStage), const Offset(-260, 0));
        await tester.pumpAndSettle();
        expect(pageIndex, 1, reason: 'Drag next failed in $mode');
        expect(find.text('Chapter 1 - Page 2'), findsOneWidget);

        final rect = tester.getRect(find.byType(PageTurnStage));
        await tester.tapAt(Offset(rect.right - 20, rect.center.dy));
        await tester.pumpAndSettle();
        expect(pageIndex, 2, reason: 'Tap next failed in $mode');
        expect(find.text('Chapter 2 - Page 1'), findsOneWidget);

        await tester.drag(find.byType(PageTurnStage), const Offset(260, 0));
        await tester.pumpAndSettle();
        expect(pageIndex, 1, reason: 'Drag prev failed in $mode');
        expect(find.text('Chapter 1 - Page 2'), findsOneWidget);
      }
    });
  });

  group('BookReaderPage Full Integration (Real Temp Novel)', () {
    testWidgets('Scroll mode turns pages by tap and advances chapter at bottom',
        (tester) async {
      final db = AppDatabase.inMemory();
      final tmp = Directory.systemTemp.createTempSync('inkbox_reader_scroll_');
      late int bookId;
      await tester.runAsync(() async {
        bookId = await _insertRealTempNovel(db, tmp);
      });
      await tester.binding.setSurfaceSize(const Size(390, 780));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          platformBridgeProvider.overrideWithValue(_TestPlatformBridge()),
          rustCoreProvider.overrideWithValue(null),
        ],
      );

      await container
          .read(bookReaderSettingsProvider.notifier)
          .update((s) => s.copyWith(pageTurnMode: PageTurnMode.scroll));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: InkBoxTheme.light(uiStyle: InkBoxUiStyle.floatingCard),
            home: BookReaderPage(bookId: bookId),
          ),
        ),
      );
      await _waitUntilLoaded(tester);

      expect(find.textContaining('第 1/3 章'), findsOneWidget);

      var reachedCh2 = false;
      for (var i = 0; i < 12; i++) {
        await tester.tapAt(const Offset(360, 400));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 260));
        await _waitUntilLoaded(tester);
        if (find.textContaining('第 2/3 章').evaluate().isNotEmpty) {
          reachedCh2 = true;
          break;
        }
      }
      expect(reachedCh2, isTrue,
          reason: 'Scroll tap paging should reach Chapter 2');

      await tester.tapAt(const Offset(30, 400));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 260));
      await _waitUntilLoaded(tester);
      expect(find.textContaining('第 1/3 章'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await tester.runAsync(() => db.close());
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        if (tmp.existsSync()) tmp.deleteSync(recursive: true);
      });
    });

    testWidgets(
        'Simulation and Cover modes advance pages and seamlessly cross chapter boundaries',
        (tester) async {
      for (final mode in [PageTurnMode.simulation, PageTurnMode.cover]) {
        final db = AppDatabase.inMemory();
        final tmp =
            Directory.systemTemp.createTempSync('inkbox_reader_paged_');
        late int bookId;
        await tester.runAsync(() async {
          bookId = await _insertRealTempNovel(db, tmp);
        });

        await tester.binding.setSurfaceSize(const Size(390, 780));

        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            platformBridgeProvider.overrideWithValue(_TestPlatformBridge()),
            rustCoreProvider.overrideWithValue(null),
          ],
        );

        await container
            .read(bookReaderSettingsProvider.notifier)
            .update((s) => s.copyWith(pageTurnMode: mode));

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: InkBoxTheme.light(uiStyle: InkBoxUiStyle.floatingCard),
              home: BookReaderPage(bookId: bookId),
            ),
          ),
        );
        await _waitUntilLoaded(tester);

        expect(find.byType(PageTurnStage), findsOneWidget);
        expect(find.textContaining('1/'), findsWidgets);

        var reachedChapter2 = false;
        for (var i = 0; i < 10; i++) {
          await tester.drag(find.byType(PageTurnStage), const Offset(-260, 0));
          await tester.pumpAndSettle();
          await _flushRealAsync(tester);
          if (find.textContaining('猜疑链与技术爆炸').evaluate().isNotEmpty) {
            reachedChapter2 = true;
            break;
          }
        }
        expect(
          reachedChapter2,
          isTrue,
          reason:
              'Expected dragging in $mode to advance across chapter 1 -> chapter 2',
        );

        await tester.drag(find.byType(PageTurnStage), const Offset(260, 0));
        await tester.pumpAndSettle();
        await _flushRealAsync(tester);
        expect(find.textContaining('启程之夜'), findsWidgets);

        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
        await tester.runAsync(() => db.close());
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          if (tmp.existsSync()) tmp.deleteSync(recursive: true);
        });
      }
      await tester.binding.setSurfaceSize(null);
    });

    testWidgets(
        'supports text underlining (划线), bookmark single-page toggle, clean reader TOC, BookDetail TOC jump, and 3-col FloatingCard grid',
        (tester) async {
      final db = AppDatabase.inMemory();
      final tmp = Directory.systemTemp.createTempSync('inkbox_reader_hl_bm_');
      await tester.runAsync(() async {
        await _insertRealTempNovel(db, tmp);
      });
      await tester.binding.setSurfaceSize(const Size(390, 780));

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          platformBridgeProvider.overrideWithValue(_TestPlatformBridge()),
          rustCoreProvider.overrideWithValue(null),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const InkBoxApp(),
        ),
      );
      await _waitUntilLoaded(tester);

      // Requirement 3: FloatingCard Bookshelf uses 3-column grid (matching Classic MD3)
      final sliverGridFinder = find.byType(SliverGrid);
      expect(sliverGridFinder, findsOneWidget);
      final sliverGrid = tester.widget<SliverGrid>(sliverGridFinder);
      final delegate = sliverGrid.gridDelegate
          as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, 3);
      expect(find.byType(BookshelfPage), findsOneWidget);

      // Open BookDetailPage via grid item's more icon -> verify TOC & TXT rule/encoding controls live here (Req 6 & 7)
      await tester.tap(
        find.descendant(
          of: find.byType(SliverGrid),
          matching: find.byWidgetPredicate(
            (w) => w is InkIconWidget && w.icon == InkIcon.more,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 350));
      await _waitUntilLoaded(tester);
      await tester.pumpAndSettle();

      expect(find.text('书籍详情'), findsOneWidget);
      expect(find.textContaining('章节目录 (3)'), findsOneWidget);
      expect(find.text('切换目录规则'), findsOneWidget);
      expect(find.text('切换编码'), findsOneWidget);
      expect(find.text('修改书架'), findsOneWidget);
      expect(find.text('第二章 猜疑链与技术爆炸'), findsOneWidget);

      // Tap Chapter 2 directly in BookDetailPage TOC -> opens BookReaderPage at Chapter 2!
      await tester.tap(find.text('第二章 猜疑链与技术爆炸'));
      await tester.pump(const Duration(milliseconds: 350));
      await _waitUntilLoaded(tester);
      await tester.pumpAndSettle();
      expect(find.byType(BookReaderPage), findsOneWidget);
      expect(find.textContaining('第二章 猜疑链与技术爆炸'), findsWidgets);

      // Open reader menu (center tap) and expand TOC -> verify NO rule/encoding clutter in reader TOC (Req 6)
      await tester.tapAt(const Offset(195, 390));
      await tester.pumpAndSettle();
      await tester.tap(find.text('目录'));
      await tester.pumpAndSettle();
      expect(find.text('目录 (3)'), findsOneWidget);
      expect(find.text('切换目录规则'), findsNothing);
      expect(find.text('切换规则'), findsNothing);
      expect(find.text('管理规则库'), findsNothing);

      // Requirement 5: Bookmark toggle on same page -> tap once adds & lights up, tap again cancels!
      expect(find.byTooltip('添加书签'), findsOneWidget);
      await tester.tap(find.byTooltip('添加书签'));
      await _flushRealAsync(tester);
      await tester.pumpAndSettle();

      var activeAnns = await tester.runAsync(
        () async => (await db.getAllAnnotations())
            .where((a) => !a.isDeleted && a.kind == 'bookmark')
            .toList(),
      );
      expect(activeAnns!.length, 1);
      expect(find.byTooltip('取消书签'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is InkIconWidget && w.icon == InkIcon.bookmarkFilled,
        ),
        findsWidgets,
      );

      // Tap bookmark button a second time on the SAME page -> removes bookmark & unlights!
      await tester.tap(find.byTooltip('取消书签'));
      await _flushRealAsync(tester);
      await tester.pumpAndSettle();

      activeAnns = await tester.runAsync(
        () async => (await db.getAllAnnotations())
            .where((a) => !a.isDeleted && a.kind == 'bookmark')
            .toList(),
      );
      expect(activeAnns, isEmpty);
      expect(find.byTooltip('添加书签'), findsOneWidget);

      // Dismiss menu by tapping center canvas
      await tester.tapAt(const Offset(195, 220));
      await tester.pumpAndSettle();

      // Requirement 4: Long-press text on ReaderHighlightCanvas -> select clause -> tap 划线 -> verify underline!
      final canvasFinder = find.byKey(
        tester
            .widgetList<ReaderHighlightCanvas>(
              find.byType(ReaderHighlightCanvas),
            )
            .firstWhere((w) => w.interactive)
            .key!,
      );
      final canvasRect = tester.getRect(canvasFinder);
      final targetPt = Offset(canvasRect.left + 60, canvasRect.top + 16);
      await tester.longPressAt(targetPt);
      await tester.pumpAndSettle();

      expect(find.text('划线'), findsOneWidget);
      expect(find.text('写想法'), findsOneWidget);
      await tester.tap(find.text('划线'));
      await _flushRealAsync(tester);
      await tester.pumpAndSettle();

      // Verify highlight annotation persisted in DB AND visually underlined on the rendered TextSpan!
      final hlAnns = await tester.runAsync(
        () async => (await db.getAllAnnotations())
            .where((a) => !a.isDeleted && a.kind == 'highlight')
            .toList(),
      );
      expect(hlAnns!.length, 1);
      expect(hlAnns.first.excerpt, isNotEmpty);

      bool hasUnderlineSpan = false;
      for (final textWidget in tester.widgetList<Text>(find.byType(Text))) {
        final rootSpan = textWidget.textSpan;
        if (rootSpan is TextSpan && rootSpan.children != null) {
          for (final child in rootSpan.children!) {
            if (child is TextSpan &&
                child.style?.decoration == TextDecoration.underline) {
              hasUnderlineSpan = true;
            }
          }
        }
      }
      expect(
        hasUnderlineSpan,
        isTrue,
        reason: 'Saved highlight must render TextDecoration.underline on page text',
      );

      // Tap the underlined text on page -> opens Highlight Inspector -> tap 删除划线 -> removes underline!
      await tester.tapAt(targetPt);
      await tester.pumpAndSettle();
      expect(find.text('删除划线'), findsOneWidget);
      await tester.tap(find.text('删除划线'));
      await _flushRealAsync(tester);
      await tester.pumpAndSettle();

      final remainingHl = await tester.runAsync(
        () async => (await db.getAllAnnotations())
            .where((a) => !a.isDeleted && a.kind == 'highlight')
            .toList(),
      );
      expect(remainingHl, isEmpty);

      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(() => db.close());
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        if (tmp.existsSync()) tmp.deleteSync(recursive: true);
      });
      await tester.binding.setSurfaceSize(null);
    });

    testWidgets(
        'edge cases: multi-shelf book isolation & move, independent multi-page bookmarks, scroll wavy note highlight, and empty/1-char text safety',
        (tester) async {
      // 1. Unit boundary checks on ReaderHighlightCanvas helpers (empty & 1-char text)
      expect(ReaderHighlightCanvas.selectInitialClause(''), (localStart: 0, localEnd: 0));
      expect(ReaderHighlightCanvas.selectClauseAround('', 5), (localStart: 0, localEnd: 0));
      expect(ReaderHighlightCanvas.selectClauseAround('道', 0), (localStart: 0, localEnd: 1));
      expect(
        ReaderHighlightCanvas.resolveHighlights(
          text: '',
          baseOffset: 0,
          chapterHighlights: const [],
        ),
        isEmpty,
      );

      final db = AppDatabase.inMemory();
      final tmp = Directory.systemTemp.createTempSync('inkbox_edge_cases_');
      late int bookId;
      late int histShelfId;
      late int econShelfId;
      await tester.runAsync(() async {
        final s1 = await db.createShelf('书架1（历史）', 'book');
        final s2 = await db.createShelf('书架2（经济）', 'book');
        histShelfId = s1!.id;
        econShelfId = s2!.id;
        bookId = await _insertRealTempNovel(db, tmp);
        await db.moveBooksToShelf([bookId], histShelfId);
      });
      await tester.binding.setSurfaceSize(const Size(390, 780));

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          platformBridgeProvider.overrideWithValue(_TestPlatformBridge()),
          rustCoreProvider.overrideWithValue(null),
        ],
      );
      container.read(activeBookShelfIdProvider.notifier).state = histShelfId;
      appRouter.go('/bookshelf');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const InkBoxApp(),
        ),
      );
      await _waitUntilLoaded(tester);

      // Book is visible on 书架1（历史）, hidden on 书架2（经济）
      expect(find.text('书架1（历史）'), findsOneWidget);
      expect(find.text('测试实书'), findsWidgets);

      container.read(activeBookShelfIdProvider.notifier).state = econShelfId;
      await tester.pumpAndSettle();
      expect(find.text('书架2（经济）'), findsOneWidget);
      expect(find.text('测试实书'), findsNothing);

      // Switch back to 书架1（历史）, open BookDetailPage, move book to 书架2（经济） via UI
      container.read(activeBookShelfIdProvider.notifier).state = histShelfId;
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(SliverGrid),
          matching: find.byWidgetPredicate(
            (w) => w is InkIconWidget && w.icon == InkIcon.more,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 350));
      await _waitUntilLoaded(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.text('修改书架'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('书架2（经济）'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确定'));
      await _flushRealAsync(tester);
      await tester.pumpAndSettle();
      expect(find.text('书架：书架2（经济）'), findsOneWidget);

      // Enter reader from BookDetailPage -> test independent bookmarks across Page 1 & Page 2
      await tester.tap(find.textContaining('继续阅读'));
      await tester.pump(const Duration(milliseconds: 350));
      await _waitUntilLoaded(tester);
      await tester.pumpAndSettle();

      // Add bookmark on Page 1
      await tester.tapAt(const Offset(195, 390));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('添加书签'));
      await _flushRealAsync(tester);
      await tester.pumpAndSettle();
      expect(find.byTooltip('取消书签'), findsOneWidget);

      // Dismiss menu, turn to Page 2 -> Page 2 must NOT show 取消书签
      await tester.tapAt(const Offset(195, 220));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(PageTurnStage), const Offset(-260, 0));
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(195, 390));
      await tester.pumpAndSettle();
      expect(find.byTooltip('添加书签'), findsOneWidget);
      // Add bookmark on Page 2 as well -> now 2 distinct page bookmarks exist
      await tester.tap(find.byTooltip('添加书签'));
      await _flushRealAsync(tester);
      await tester.pumpAndSettle();
      expect(find.byTooltip('取消书签'), findsOneWidget);

      // Switch to Scroll mode and add a wavy-underline Note via toolbar 划线笔记 button
      await tester.tap(find.text('翻页'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('滚动'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('划线笔记'));
      await tester.pumpAndSettle();
      expect(find.text('写想法'), findsOneWidget);
      await tester.tap(find.text('写想法'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '核心推演批注');
      await tester.tap(find.text('保存划线与想法'));
      await _flushRealAsync(tester);
      await tester.pumpAndSettle();

      bool hasWavyNoteSpan = false;
      for (final textWidget in tester.widgetList<Text>(find.byType(Text))) {
        final rootSpan = textWidget.textSpan;
        if (rootSpan is TextSpan && rootSpan.children != null) {
          for (final child in rootSpan.children!) {
            if (child is TextSpan &&
                child.style?.decoration == TextDecoration.underline &&
                child.style?.decorationStyle == TextDecorationStyle.wavy) {
              hasWavyNoteSpan = true;
            }
          }
        }
      }
      expect(hasWavyNoteSpan, isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(() => db.close());
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        if (tmp.existsSync()) tmp.deleteSync(recursive: true);
      });
      await tester.binding.setSurfaceSize(null);
    });

    testWidgets(
        'adversarial regressions: mid-paragraph wrapped page bookmark toggle, Simp/Trad & indent highlight survival, narrow 280dp font-30 swatch highlight, status revert, exact annotation offset jump, and TTS utterance isolation',
        (tester) async {
      // 1. Unit verification: Simplified <-> Traditional & indentFirstLine highlight resolution
      const tradPage = '　　猜疑鏈與技術爆炸的推演在此展開。\n\n　　第二段宇宙社會學公理。';
      const noIndentPage = '猜疑链与技术爆炸的推演在此展开。\n\n第二段宇宙社会学公理。';
      final simpHighlight = Annotation(
        id: 1,
        uuid: 'hl_simp_1',
        contentHash: 'h1',
        mediaKind: 'book',
        kind: 'highlight',
        chapterIndex: 0,
        locator: 'ch:0;off:2;end:10',
        excerpt: '猜疑链与技术爆炸',
        noteText: '',
        colorHex: '#A8D5BA',
        isDeleted: false,
        updatedAtMs: 100,
      );
      final resolvedOnTrad = ReaderHighlightCanvas.resolveHighlights(
        text: tradPage,
        baseOffset: 0,
        chapterHighlights: [simpHighlight],
      );
      expect(resolvedOnTrad.length, 1);
      expect(
        tradPage.substring(
          resolvedOnTrad.first.localStart,
          resolvedOnTrad.first.localEnd,
        ),
        '猜疑鏈與技術爆炸',
      );

      final crossParaHighlight = Annotation(
        id: 2,
        uuid: 'hl_cross_para',
        contentHash: 'h1',
        mediaKind: 'book',
        kind: 'highlight',
        chapterIndex: 0,
        locator: 'ch:0;off:11;end:27',
        excerpt: '推演在此展开。\n\n　　第二段宇宙',
        noteText: '',
        colorHex: '#A2C8EC',
        isDeleted: false,
        updatedAtMs: 101,
      );
      final resolvedNoIndent = ReaderHighlightCanvas.resolveHighlights(
        text: noIndentPage,
        baseOffset: 0,
        chapterHighlights: [crossParaHighlight],
      );
      expect(resolvedNoIndent.length, 1);
      expect(
        noIndentPage.substring(
          resolvedNoIndent.first.localStart,
          resolvedNoIndent.first.localEnd,
        ),
        '推演在此展开。\n\n第二段宇宙',
      );

      // 2. Continuous zero-newline paragraph: every page boundary has pages[k].startOffset == pages[k-1].endOffset
      final zeroBreakPara = List.generate(
        60,
        (i) => '连续无换行长段落第${i + 1}句用于严苛检验跨页半开区间边界偏移与书签点亮取消逻辑绝不错位。',
      ).join();
      final contPages = BookPaginator.paginate(
        text: zeroBreakPara,
        maxWidth: 320,
        maxHeight: 420,
        style: const TextStyle(fontSize: 18, height: 1.8),
      );
      expect(contPages.length, greaterThanOrEqualTo(3));
      expect(contPages[1].startOffset, equals(contPages[0].endOffset));
      for (var k = 0; k < contPages.length; k++) {
        expect(BookPaginator.findPageForOffset(contPages, contPages[k].startOffset), k);
      }

      // 3. Full widget integration on continuous zero-newline novel
      final db = AppDatabase.inMemory();
      final tmp = Directory.systemTemp.createTempSync('inkbox_adv_reg_');
      final platform = _TestPlatformBridge();
      late int bookId;
      await tester.runAsync(() async {
        final f = File(p.join(tmp.path, 'continuous.txt'))
          ..writeAsStringSync('第一章 连绵长段\r\n$zeroBreakPara\r\n第二章 续篇\r\n$zeroBreakPara');
        final now = DateTime.now().millisecondsSinceEpoch;
        bookId = await db.upsertBook(
          BooksCompanion.insert(
            contentHash: 'continuous_hash_1',
            title: '长段测试书',
            author: const drift.Value('测试作者'),
            format: 'TXT',
            filePath: f.path,
            currentChapterTitle: const drift.Value('第一章 连绵长段'),
            addedAtMs: now,
            lastReadAtMs: now,
          ),
        );
      });

      await tester.binding.setSurfaceSize(const Size(390, 780));
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          platformBridgeProvider.overrideWithValue(platform),
          rustCoreProvider.overrideWithValue(null),
        ],
      );
      appRouter.go('/bookshelf');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const InkBoxApp(),
        ),
      );
      await _waitUntilLoaded(tester);

      // Test marking finished ("标为读完") and reverting back to reading ("标为在读" & BookDetail edit)
      // Note: .last targets the _BookGridItem (whereas .first in '所有' is _ContinueReadingCard)
      await tester.longPress(find.text('长段测试书').last);
      await tester.pumpAndSettle();
      expect(find.text('标为读完'), findsOneWidget);
      await tester.tap(find.text('标为读完'));
      await _flushRealAsync(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.text('已读完'));
      await tester.pumpAndSettle();
      expect(find.text('长段测试书'), findsWidgets);

      // Long-press in 已读完 -> batch bar now offers 标为在读 -> reverts cleanly to 在读!
      await tester.longPress(find.text('长段测试书').last);
      await tester.pumpAndSettle();
      expect(find.text('标为在读'), findsOneWidget);
      await tester.tap(find.text('标为在读'));
      await _flushRealAsync(tester);
      await tester.pumpAndSettle();
      expect(find.text('长段测试书'), findsNothing);

      await tester.tap(find.text('在读'));
      await tester.pumpAndSettle();
      expect(find.text('长段测试书'), findsWidgets);

      // Open BookReaderPage and turn to Page 2 (mid-paragraph wrapped page!)
      await tester.tap(find.text('长段测试书').first);
      await tester.pump(const Duration(milliseconds: 350));
      await _waitUntilLoaded(tester);
      await tester.pumpAndSettle();
      expect(find.textContaining('1/'), findsWidgets);

      await tester.drag(find.byType(PageTurnStage), const Offset(-260, 0));
      await tester.pumpAndSettle();
      expect(find.textContaining('2/'), findsWidgets);

      // Toggle bookmark ON on Page 2 -> MUST light up on Page 2, and toggling again MUST cancel!
      await tester.tapAt(const Offset(195, 390));
      await tester.pumpAndSettle();
      expect(find.byTooltip('添加书签'), findsOneWidget);
      await tester.tap(find.byTooltip('添加书签'));
      await _flushRealAsync(tester);
      await tester.pumpAndSettle();
      expect(find.byTooltip('取消书签'), findsOneWidget);

      // Tap again on Page 2 -> cancels cleanly (0 bookmarks left)
      await tester.tap(find.byTooltip('取消书签'));
      await _flushRealAsync(tester);
      await tester.pumpAndSettle();
      expect(find.byTooltip('添加书签'), findsOneWidget);

      // Add bookmark on Page 3 so we can test exact-page jump from BookDetailPage!
      await tester.tapAt(const Offset(195, 220));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(PageTurnStage), const Offset(-260, 0));
      await tester.pumpAndSettle();
      expect(find.textContaining('3/'), findsWidgets);

      await tester.tapAt(const Offset(195, 390));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('添加书签'));
      await _flushRealAsync(tester);
      await tester.pumpAndSettle();
      expect(find.byTooltip('取消书签'), findsOneWidget);

      // Open BookDetailPage from reader when currently on Page 1 -> tap Page 3 bookmark -> lands on Page 3!
      await tester.tapAt(const Offset(195, 220));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(PageTurnStage), const Offset(260, 0));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(PageTurnStage), const Offset(260, 0));
      await tester.pumpAndSettle();
      expect(find.textContaining('1/'), findsWidgets);

      await tester.tapAt(const Offset(195, 390));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('书籍详情'));
      await tester.pump(const Duration(milliseconds: 350));
      await _waitUntilLoaded(tester);
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.textContaining('书签 · 第 1 章'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.textContaining('书签 · 第 1 章'));
      await tester.pump(const Duration(milliseconds: 350));
      await _waitUntilLoaded(tester);
      await tester.pumpAndSettle();
      expect(find.textContaining('3/'), findsWidgets);

      // Test TTS utterance isolation: start TTS on Page 3 -> open TtsSettingsPage -> preview finishes -> Page stays 3!
      await tester.tapAt(const Offset(195, 390));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('TTS 听书'));
      await _flushRealAsync(tester);
      await tester.pumpAndSettle();
      // Dismiss reader menu so TTS mini dock appears
      await tester.tapAt(const Offset(195, 220));
      await tester.pumpAndSettle();
      expect(find.textContaining('TTS 朗读中'), findsOneWidget);

      await tester.tap(find.text('设置'));
      await tester.pumpAndSettle();
      expect(find.text('TTS 语音朗读设置'), findsOneWidget);

      await tester.tap(find.text('试听当前语音效果'));
      await _flushRealAsync(tester);
      await tester.pumpAndSettle();
      final previewUid = platform.lastUtteranceId!;
      platform.eventCtrl.add(
        PlatformEvent(type: 'tts_done', payload: {'utteranceId': previewUid}),
      );
      await _flushRealAsync(tester);
      await tester.pumpAndSettle();

      // Pop back to reader -> still on Page 3, and reader resumes TTS cleanly!
      await tester.tap(find.byType(InkCircleButton).first);
      await _flushRealAsync(tester);
      await tester.pumpAndSettle();
      expect(find.textContaining('3/'), findsWidgets);
      final resumedReaderUid = platform.lastUtteranceId!;
      platform.eventCtrl.add(
        PlatformEvent(
          type: 'tts_done',
          payload: {'utteranceId': resumedReaderUid},
        ),
      );
      await _flushRealAsync(tester);
      await tester.pumpAndSettle();
      expect(find.textContaining('4/'), findsWidgets);

      // Stop TTS
      await tester.tap(find.text('停止'));
      await _flushRealAsync(tester);
      await tester.pumpAndSettle();

      // Test narrow viewport (<320dp) + max font size (30) + color swatch immediate highlight!
      await tester.binding.setSurfaceSize(const Size(280, 680));
      await container
          .read(bookReaderSettingsProvider.notifier)
          .update((s) => s.copyWith(fontSize: 30));
      await _flushRealAsync(tester);
      await tester.pumpAndSettle();

      final narrowCanvasFinder = find.byKey(
        tester
            .widgetList<ReaderHighlightCanvas>(
              find.byType(ReaderHighlightCanvas),
            )
            .firstWhere((w) => w.interactive)
            .key!,
      );
      final narrowRect = tester.getRect(narrowCanvasFinder);
      await tester.longPressAt(Offset(narrowRect.left + 40, narrowRect.top + 24));
      await tester.pumpAndSettle();
      expect(find.text('划线'), findsOneWidget);

      // Tap the 3rd color swatch (#A8D5BA green) directly WITHOUT tapping "划线" -> immediately saves & transitions to inspector!
      final greenSwatchColor = parseHexColor(kReaderHighlightColors[2]);
      await tester.tap(
        find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).color == greenSwatchColor,
        ),
      );
      await _flushRealAsync(tester);
      await tester.pumpAndSettle();
      expect(find.text('删除划线'), findsOneWidget);

      final savedHls = await tester.runAsync(
        () async => (await db.getAnnotationsFor('continuous_hash_1'))
            .where((a) => a.kind == 'highlight')
            .toList(),
      );
      expect(savedHls!.length, 1);
      expect(savedHls.first.colorHex, kReaderHighlightColors[2]);

      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await platform.eventCtrl.close();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(() => db.close());
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        if (tmp.existsSync()) tmp.deleteSync(recursive: true);
      });
      await tester.binding.setSurfaceSize(null);
      expect(bookId, greaterThan(0));
    });
  });
}
