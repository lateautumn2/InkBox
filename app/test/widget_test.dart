import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkbox/core/icons/ink_icons.dart';
import 'package:inkbox/core/theme/inkbox_theme.dart';
import 'package:inkbox/core/theme/theme_controller.dart';
import 'package:inkbox/core/widgets/floating_surface.dart';
import 'package:inkbox/core/widgets/ink_controls.dart';
import 'package:inkbox/data/db/app_database.dart';
import 'package:inkbox/data/ffi/rust_core_bridge.dart';
import 'package:inkbox/data/platform/platform_bridge.dart';
import 'package:inkbox/data/providers/app_providers.dart';
import 'package:inkbox/main.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

class _WidgetTestPlatformBridge implements PlatformBridge {
  String? lastSpokenText;
  double? lastSpokenRate;
  double? lastSpokenPitch;
  String? lastSpokenLang;

  @override
  Stream<PlatformEvent> get events => const Stream.empty();
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
    String? voiceName,
  }) async {
    lastSpokenText = text;
    lastSpokenRate = rate;
    lastSpokenPitch = pitch;
    lastSpokenLang = language;
    return 'preview_uid';
  }

  @override
  Future<String?> stageDocumentUri(String uri, {String? fileName}) async =>
      null;
  @override
  Future<void> stopTts() async {}
  @override
  Future<List<TtsEngineOption>> getTtsEngines() async => const [
        TtsEngineOption(name: 'com.google.android.tts', label: 'Google 语音服务'),
      ];
  @override
  Future<List<TtsVoiceOption>> getTtsVoices({
    String? engine,
    String? language,
  }) async =>
      const [];
  @override
  Future<void> openSystemTtsSettings() async {}
  @override
  Future<bool> playAudioFile(
    String path, {
    double speed = 1.0,
    String? playbackId,
  }) async =>
      true;
  @override
  Future<void> pauseAudio() async {}
  @override
  Future<void> resumeAudio() async {}
  @override
  Future<void> stopAudio() async {}
  @override
  Future<void> setAudioSpeed(double speed) async {}
  @override
  Future<void> saveSecret(String key, String value) async {}
  @override
  Future<String?> readSecret(String key) async => null;
  @override
  Future<void> deleteSecret(String key) async {}
  @override
  Future<int> getPdfPageCount(String path) async => 0;
  @override
  Future<Uint8List?> renderPdfPage(String path, int pageIndex,
          {double scale = 2.0}) async =>
      null;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'inkbox_app_locale': 'zh'});
  });

  group('M1 Rust Core FFI Integration', () {
    test('loads native inkbox_core library and executes core + TOC APIs', () {
      final dllPath = p.normalize(
        p.join(
          Directory.current.path,
          '..',
          'rust_core',
          'target',
          'debug',
          Platform.isWindows ? 'inkbox_core.dll' : 'libinkbox_core.so',
        ),
      );
      expect(File(dllPath).existsSync(), isTrue, reason: 'Expected $dllPath');

      final bridge = RustCoreBridge.tryOpen(explicitLibraryPath: dllPath);
      expect(bridge, isNotNull);

      final health = bridge!.healthCheck();
      expect(health.engineName, 'inkbox_core');
      expect(health.supportedBookFormats, contains('epub'));
      expect(health.supportedComicFormats, contains('cbz'));

      expect(bridge.classifyPath('threebody.epub'), 'Book');
      expect(bridge.classifyPath('vagabond.cbz'), 'Comic');
      expect(bridge.classifyPath('unknown.bin'), 'Unknown');

      final rules = bridge.defaultTocRules();
      expect(rules.length, greaterThanOrEqualTo(10));

      final testRes = bridge.testTocRule(
        pattern: r'^第[\d一二三四五六七八九十]+章.{0,20}$',
        sampleText: '第一章 启程\r\n正文\r\n第二章 远航\r\n正文',
      );
      expect(testRes['valid'], isTrue);
      expect(testRes['match_count'], 2);

      final outcome = bridge.evaluateProgressMerge(
        local: {
          'content_hash': 'h1',
          'media_kind': 'book',
          'locator': 'ch:14;off:200',
          'progress_ratio': 0.42,
          'updated_at_epoch_ms': 2000,
          'device_id': 'phone',
          'device_name': 'Android',
        },
        remote: {
          'content_hash': 'h1',
          'media_kind': 'book',
          'locator': 'ch:15;off:100',
          'progress_ratio': 0.48,
          'updated_at_epoch_ms': 2500,
          'device_id': 'tablet',
          'device_name': 'Tablet',
        },
        lastSyncedEpochMs: 1000,
      );
      expect(outcome, 'Conflict');
    });
  });

  group('M1 Drift SQLite Database (Zero Default Demo Data)', () {
    test('starts with empty library, default shelves, and built-in TOC rules',
        () async {
      final db = AppDatabase.inMemory();
      addTearDown(db.close);

      final books = await db.watchAllBooks().first;
      final mangas = await db.watchAllMangas().first;
      final bookShelves = await db.getShelves('book');
      final mangaShelves = await db.getShelves('comic');
      final tocRules = await db.getTocRules();

      expect(books, isEmpty);
      expect(mangas, isEmpty);
      expect(bookShelves.map((s) => s.name), ['默认书架']);
      expect(mangaShelves.map((s) => s.name), ['默认漫画架']);
      expect(tocRules.length, greaterThanOrEqualTo(12));
    });
  });

  group('UI Navigation, Multi-Shelves, TTS Settings, Theme Presets & Overlay Verification', () {
    testWidgets(
        'renders clean 4-tab shell, multi-shelves without categories, TTS settings, and unobstructed Theme Presets sheet in FloatingCard mode',
        (tester) async {
      final db = AppDatabase.inMemory();
      final mockPlatform = _WidgetTestPlatformBridge();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            platformBridgeProvider.overrideWithValue(mockPlatform),
            rustCoreProvider.overrideWithValue(null),
          ],
          child: const InkBoxApp(),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();

      // 4 tabs: 书架, 漫画, 导入, 我的 (no 同步 tab)
      expect(find.text('书架'), findsWidgets);
      expect(find.text('漫画'), findsWidgets);
      expect(find.text('导入'), findsWidgets);
      expect(find.text('我的'), findsWidgets);
      expect(find.text('同步'), findsNothing);
      expect(find.byType(InkIconWidget), findsWidgets);

      // Bookshelf: default status groups ONLY (no 新建分类 custom category chip), tap shelf title to switch
      expect(find.text('默认书架'), findsOneWidget);
      expect(find.text('全部'), findsOneWidget);
      expect(find.text('在读'), findsOneWidget);
      expect(find.text('已读完'), findsOneWidget);
      expect(find.text('新建分类'), findsNothing);
      expect(find.text('文学'), findsNothing);
      expect(find.text('技术'), findsNothing);
      expect(find.text('三体 II · 黑暗森林'), findsNothing);

      // Create a second bookshelf "书架1（历史）" via shelf switcher and switch to it
      await tester.tap(find.text('默认书架'));
      await tester.pumpAndSettle();
      expect(find.text('新建书架'), findsOneWidget);
      await tester.tap(find.text('新建书架'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '书架1（历史）');
      await tester.tap(find.text('创建'));
      await tester.pumpAndSettle();
      expect(find.text('书架1（历史）'), findsOneWidget);

      // Theme Presets button MUST NOT appear on Bookshelf
      expect(find.byTooltip('主题预设'), findsNothing);

      // Switch to Manga tab -> default groups only, multi-manga-shelf switcher, no custom categories
      await tester.tap(find.text('漫画').last);
      await tester.pumpAndSettle();
      expect(find.text('默认漫画架'), findsOneWidget);
      expect(find.text('新建分类'), findsNothing);
      expect(find.text('浪客行'), findsNothing);
      expect(find.text('追更中'), findsNothing);
      expect(find.byTooltip('主题预设'), findsNothing);

      // Switch to Import tab -> clean header modal for Supported Formats + Import History, NO inline clutter card
      await tester.tap(find.text('导入').last);
      await tester.pumpAndSettle();
      expect(find.text('导入中心'), findsOneWidget);
      expect(find.text('导入历史 (0)'), findsOneWidget);
      expect(find.byTooltip('支持格式'), findsOneWidget);
      expect(find.textContaining('解析内核已就绪'), findsNothing);
      expect(find.textContaining('特性：'), findsNothing);
      expect(find.byTooltip('主题预设'), findsNothing);

      // Switch to Mine tab -> Multi-Shelf manager, TTS Settings, TOC Rules, WebDAV Sync, Appearance & Language
      await tester.tap(find.text('我的').last);
      await tester.pumpAndSettle();
      expect(find.text('多书架管理'), findsOneWidget);
      expect(find.text('TTS 语音朗读'), findsOneWidget);
      expect(find.text('WebDAV 同步'), findsOneWidget);
      expect(find.text('TXT 目录规则'), findsOneWidget);
      expect(find.text('外观与主题'), findsOneWidget);
      expect(find.text('自定义书架分类'), findsNothing);
      expect(find.byTooltip('主题预设'), findsOneWidget);

      // Enter TTS Settings page -> adjust pitch & test live preview
      await tester.tap(find.text('TTS 语音朗读'));
      await tester.pumpAndSettle();
      expect(find.text('TTS 语音设置'), findsOneWidget);
      expect(find.text('语速'), findsOneWidget);
      expect(find.text('音调'), findsOneWidget);
      await tester.tap(find.text('清亮 1.2'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('试听效果'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('试听效果'));
      await tester.pumpAndSettle();
      expect(mockPlatform.lastSpokenPitch, closeTo(1.25, 0.05));
      expect(mockPlatform.lastSpokenLang, 'zh-CN');
      await tester.tap(find.byType(InkCircleButton).first);
      await tester.pumpAndSettle();

      // Open Appearance / Theme Presets sheet in FloatingCard mode
      await tester.tap(find.text('外观与主题'));
      await tester.pumpAndSettle();
      expect(find.text('主题预设'), findsOneWidget);
      expect(find.text('悬浮卡片'), findsOneWidget);
      expect(find.text('经典贴边'), findsOneWidget);

      final ctx = tester.element(find.text('悬浮卡片'));
      expect(InkBoxTokens.of(ctx).isFloatingCard, isTrue);

      // Verify bottom control inside sheet (Monet InkSwitch row) is NOT covered by bottom floating dock
      final monetText = find.text('Material You 取色');
      expect(monetText, findsOneWidget);
      final monetSwitch = find.byType(InkSwitch);
      expect(monetSwitch, findsOneWidget);
      final container = ProviderScope.containerOf(ctx);
      expect(container.read(appearanceProvider).useDynamicColor, isFalse);
      // Actually tap the bottom-most InkSwitch inside the Theme Presets sheet!
      await tester.tap(monetSwitch);
      await tester.pumpAndSettle();
      expect(
        container.read(appearanceProvider).useDynamicColor,
        isTrue,
        reason: 'Bottom InkSwitch in Theme Presets sheet must receive tap without being blocked by FloatingCard dock',
      );

      // Dismiss bottom sheet by tapping barrier at top
      await tester.tapAt(const Offset(20, 40));
      await tester.pumpAndSettle();
      expect(find.text('悬浮卡片'), findsNothing);

      // Enter TOC Rules page from Mine -> test malformed JSON rejection, valid Legado JSON import, and live regex test
      await tester.tap(find.text('TXT 目录规则'));
      await tester.pumpAndSettle();
      expect(find.text('TXT 目录规则'), findsOneWidget);
      expect(find.text('粘贴 JSON'), findsOneWidget);

      final beforeCount = (await tester.runAsync(() => db.getTocRules()))!.length;
      await tester.tap(find.text('粘贴 JSON'));
      await tester.pumpAndSettle();
      // Verify InkTextField inner TextField has NO double nested border/fill from ThemeData
      final innerTf = tester.widget<TextField>(find.byType(TextField).first);
      expect(innerTf.decoration?.filled, isFalse);
      expect(innerTf.decoration?.enabledBorder, InputBorder.none);
      expect(innerTf.decoration?.focusedBorder, InputBorder.none);

      // Paste malformed JSON -> must NOT import garbage lines
      await tester.enterText(find.byType(TextField).first, '[{"name":"broken"');
      await tester.tap(find.text('导入').last);
      await tester.pumpAndSettle();
      expect((await tester.runAsync(() => db.getTocRules()))!.length, beforeCount);

      // Paste valid Legado JSON -> must import cleanly
      await tester.tap(find.text('粘贴 JSON'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).first,
        r'[{"name":"测试星标规则","rule":"^★\\d+.*$","enable":true}]',
      );
      await tester.tap(find.text('导入').last);
      await tester.pumpAndSettle();
      expect(
        (await tester.runAsync(() => db.getTocRules()))!.length,
        beforeCount + 1,
      );
      await tester.scrollUntilVisible(
        find.text('测试星标规则'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('测试星标规则'), findsOneWidget);

      // Creating a rule with invalid regex must be blocked by validation
      await tester.tap(find.byTooltip('新建规则'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), '坏正则');
      await tester.enterText(find.byType(TextField).at(1), '[unclosed');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(
        (await tester.runAsync(() => db.getTocRules()))!.length,
        beforeCount + 1,
      );

      // Navigate back to Mine, clear any lingering validation SnackBar, then enter WebDAV Sync subpage
      await tester.tap(find.byType(InkCircleButton).first);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.tap(find.text('WebDAV 同步'));
      await tester.pumpAndSettle();
      expect(find.text('WebDAV 同步中心'), findsOneWidget);
      expect(find.textContaining('体验多端进度冲突决策弹窗'), findsNothing);
      expect(find.byTooltip('主题预设'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
      await tester.runAsync(() => db.close());
    });
  });
}
