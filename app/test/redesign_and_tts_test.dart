import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkbox/core/l10n/l10n_helpers.dart';
import 'package:inkbox/core/navigation/app_router.dart';
import 'package:inkbox/core/theme/inkbox_theme.dart';
import 'package:inkbox/core/theme/theme_controller.dart';
import 'package:inkbox/data/db/app_database.dart';
import 'package:inkbox/data/platform/platform_bridge.dart';
import 'package:inkbox/data/providers/app_providers.dart';
import 'package:inkbox/features/book_reader/book_paginator.dart';
import 'package:inkbox/features/book_reader/book_reader_page.dart';
import 'package:inkbox/features/book_reader/book_reader_settings.dart';
import 'package:inkbox/features/book_reader/page_turn_painter.dart';
import 'package:inkbox/features/book_reader/reader_highlight_canvas.dart';
import 'package:inkbox/features/manga_reader/manga_reader_page.dart';
import 'package:inkbox/features/tts/online_tts_client.dart';
import 'package:inkbox/features/tts/tts_audio_cache.dart';
import 'package:inkbox/features/tts/tts_models.dart';
import 'package:inkbox/features/tts/tts_playback_controller.dart';
import 'package:inkbox/features/tts/tts_text_chunker.dart';
import 'package:inkbox/l10n/app_localizations.dart';
import 'package:inkbox/main.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

class _RedesignMockPlatformBridge implements PlatformBridge {
  final StreamController<PlatformEvent> eventCtrl =
      StreamController<PlatformEvent>.broadcast();
  final List<String> spokenTexts = [];
  final Map<String, String> secureStore = {};
  bool speakShouldFail = false;

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
  Future<String?> stageDocumentUri(String uri, {String? fileName}) async =>
      null;
  @override
  Future<void> setKeepScreenOn(bool enabled) async {}
  @override
  Future<void> setVolumeKeyPaging(bool enabled) async {}
  @override
  Future<void> setScreenBrightness(double? brightness) async {}
  @override
  Future<String?> speakText(
    String text, {
    double rate = 1.0,
    double pitch = 1.0,
    String? language,
    String? engine,
    String? voiceName,
  }) async {
    if (speakShouldFail) return null;
    spokenTexts.add(text);
    return 'utt_${spokenTexts.length}';
  }

  @override
  Future<void> stopTts() async {}
  @override
  Future<List<TtsEngineOption>> getTtsEngines() async => const [];
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
  Future<void> saveSecret(String key, String value) async =>
      secureStore[key] = value;
  @override
  Future<String?> readSecret(String key) async => secureStore[key];
  @override
  Future<void> deleteSecret(String key) async => secureStore.remove(key);
  @override
  Future<int> getPdfPageCount(String path) async => 0;
  @override
  Future<Uint8List?> renderPdfPage(
    String path,
    int pageIndex, {
    double scale = 2.0,
  }) async =>
      null;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'inkbox_app_locale': 'zh'});
  });

  group('Dual-page Book & Manga Layouts', () {
    test('BookPaginator paragraphSpacing adjusts layout while keeping offsets 1:1', () {
      const sample = '第一段示例内容，用于测试段落间距布局。\n\n第二段紧随其后。';
      const style = TextStyle(fontSize: 18, height: 1.75);

      final smallSpan = BookPaginator.buildStyledSpan(
        sample,
        style,
        paragraphSpacing: 2.0,
      );
      final largeSpan = BookPaginator.buildStyledSpan(
        sample,
        style,
        paragraphSpacing: 24.0,
      );

      expect(smallSpan.toPlainText(), sample);
      expect(largeSpan.toPlainText(), sample);

      final tpSmall = TextPainter(
        text: smallSpan,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 320);
      final tpLarge = TextPainter(
        text: largeSpan,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 320);

      expect(tpLarge.height, greaterThan(tpSmall.height));

      final multiPara = List.generate(
        18,
        (i) => '这是第${i + 1}段测试正文，包含足够的字符用于跨越多页并验证连续偏移与段距效果。',
      ).join('\n');
      final pages = BookPaginator.paginate(
        text: multiPara,
        maxWidth: 300,
        maxHeight: 400,
        style: style,
        paragraphSpacing: 16.0,
      );
      expect(pages.length, greaterThanOrEqualTo(2));
      expect(pages[1].startOffset, greaterThan(0));
    });

    testWidgets('Tablet landscape 1280x800 renders 2-page spread & turns by 2',
        (tester) async {
      final db = AppDatabase.inMemory();
      final tmp = Directory.systemTemp.createTempSync('inkbox_dual_spread_');
      final platform = _RedesignMockPlatformBridge();
      late int bookId;

      await tester.runAsync(() async {
        final paras = List.generate(
          42,
          (i) => '第${i + 1}段测试双屏并排排版：左侧为奇数页，右侧为偶数页，中间带有温和书脊分隔阴影与独立页脚。',
        ).join('\n');
        final file = File(p.join(tmp.path, 'dual.txt'))
          ..writeAsStringSync('第一章 启程\n$paras');
        final now = DateTime.now().millisecondsSinceEpoch;
        bookId = await db.upsertBook(
          BooksCompanion.insert(
            contentHash: 'dual_hash_1',
            title: '双页测试书',
            format: 'TXT',
            filePath: file.path,
            addedAtMs: now,
            lastReadAtMs: now,
          ),
        );
      });

      await tester.binding.setSurfaceSize(const Size(1280, 800));
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          platformBridgeProvider.overrideWithValue(platform),
          rustCoreProvider.overrideWithValue(null),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: kInkBoxLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: InkBoxTheme.light(uiStyle: InkBoxUiStyle.floatingCard),
            home: BookReaderPage(bookId: bookId),
          ),
        ),
      );
      for (var i = 0; i < 12; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump();
        if (find.byType(ReaderHighlightCanvas).evaluate().length >= 2) break;
      }

      expect(find.byType(ReaderHighlightCanvas), findsNWidgets(2));
      expect(find.textContaining('· 1/'), findsOneWidget);
      expect(find.textContaining('· 2/'), findsOneWidget);

      await tester.drag(find.byType(PageTurnStage), const Offset(-320, 0));
      await tester.pumpAndSettle();

      expect(find.byType(ReaderHighlightCanvas), findsNWidgets(2));
      expect(find.textContaining('· 3/'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await platform.eventCtrl.close();
      await tester.runAsync(() async {
        await db.close();
        if (tmp.existsSync()) tmp.deleteSync(recursive: true);
      });
      await tester.binding.setSurfaceSize(null);
    });

    test('buildMangaSpreadSlots handles cover isolation, wide spreads, and odd tails', () {
      expect(
        buildMangaSpreadSlots(
          pageCount: 0,
          coverAlone: true,
          wideSpreadIndices: {},
        ),
        isEmpty,
      );

      expect(
        buildMangaSpreadSlots(
          pageCount: 6,
          coverAlone: true,
          wideSpreadIndices: {},
        ),
        [
          (first: 0, second: null),
          (first: 1, second: 2),
          (first: 3, second: 4),
          (first: 5, second: null),
        ],
      );

      final withWide = buildMangaSpreadSlots(
        pageCount: 6,
        coverAlone: true,
        wideSpreadIndices: {2},
      );
      expect(withWide, [
        (first: 0, second: null),
        (first: 1, second: null),
        (first: 2, second: null),
        (first: 3, second: 4),
        (first: 5, second: null),
      ]);
      expect(slotIndexForMangaPage(withWide, 2), 2);
      expect(slotIndexForMangaPage(withWide, 4), 3);

      expect(
        buildMangaSpreadSlots(
          pageCount: 4,
          coverAlone: false,
          wideSpreadIndices: {1},
        ),
        [
          (first: 0, second: null),
          (first: 1, second: null),
          (first: 2, second: 3),
        ],
      );
    });
  });

  group('3-Language Localization & Cross-Locale Compatibility', () {
    test('app_zh.arb, app_en.arb, app_ja.arb have identical keys and non-empty values', () {
      final root = Directory.current.path;
      Map<String, dynamic> loadArb(String file) => jsonDecode(
            File(p.join(root, 'lib', 'l10n', file)).readAsStringSync(),
          ) as Map<String, dynamic>;

      final zh = loadArb('app_zh.arb');
      final en = loadArb('app_en.arb');
      final ja = loadArb('app_ja.arb');

      Set<String> msgKeys(Map<String, dynamic> m) =>
          m.keys.where((k) => !k.startsWith('@')).toSet();

      final zhKeys = msgKeys(zh);
      final enKeys = msgKeys(en);
      final jaKeys = msgKeys(ja);

      expect(enKeys, zhKeys);
      expect(jaKeys, zhKeys);

      for (final k in zhKeys) {
        expect('${zh[k]}'.trim(), isNotEmpty, reason: 'Empty zh key: $k');
        expect('${en[k]}'.trim(), isNotEmpty, reason: 'Empty en key: $k');
        expect('${ja[k]}'.trim(), isNotEmpty, reason: 'Empty ja key: $k');
      }
    });

    testWidgets('Live locale switch updates shell zh -> en -> ja', (tester) async {
      final db = AppDatabase.inMemory();
      final platform = _RedesignMockPlatformBridge();
      appRouter.go('/bookshelf');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            platformBridgeProvider.overrideWithValue(platform),
            rustCoreProvider.overrideWithValue(null),
          ],
          child: const InkBoxApp(),
        ),
      );
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();

      expect(find.text('书架'), findsWidgets);
      expect(find.text('我的'), findsWidgets);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(AppShellScaffold)),
      );
      await tester.runAsync(
        () => container.read(appearanceProvider.notifier).setAppLocaleCode('en'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Books'), findsWidgets);
      expect(find.text('Manga'), findsWidgets);
      expect(find.text('Me'), findsWidgets);

      await tester.runAsync(
        () => container.read(appearanceProvider.notifier).setAppLocaleCode('ja'),
      );
      await tester.pumpAndSettle();
      expect(find.text('本棚'), findsWidgets);
      expect(find.text('マンガ'), findsWidgets);
      expect(find.text('マイ'), findsWidgets);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
      await platform.eventCtrl.close();
      await tester.runAsync(() => db.close());
    });

    test('isBookFinished & isMangaFinished handle zh/en DB tokens and progress ratio', () {
      const baseBook = Book(
        id: 1,
        contentHash: 'h',
        title: 't',
        author: 'a',
        format: 'TXT',
        filePath: '/a.txt',
        coverPath: '',
        shelfGroup: '在读',
        shelfId: 1,
        isPinned: false,
        cloudFileSynced: false,
        currentChapterIndex: 0,
        currentCharOffset: 0,
        currentChapterTitle: '',
        progressRatio: 0.2,
        readingTimeSec: 0,
        tocRuleId: null,
        forcedEncoding: null,
        isArchived: false,
        addedAtMs: 0,
        lastReadAtMs: 0,
      );
      expect(isBookFinished(baseBook), isFalse);
      expect(isBookFinished(baseBook.copyWith(shelfGroup: '已读完')), isTrue);
      expect(isBookFinished(baseBook.copyWith(shelfGroup: 'finished')), isTrue);
      expect(isBookFinished(baseBook.copyWith(progressRatio: 0.99)), isTrue);

      const baseManga = Manga(
        id: 1,
        contentHash: 'm',
        title: 'm',
        author: 'a',
        format: 'CBZ',
        rootPath: '/m',
        coverPath: '',
        shelfGroup: '在读',
        shelfId: 1,
        isPinned: false,
        cloudFileSynced: false,
        autoCrop: true,
        splitWidePages: true,
        preferredReadingMode: 'rtl',
        totalChapters: 3,
        unreadCount: 2,
        isArchived: false,
        addedAtMs: 0,
        lastReadAtMs: 0,
      );
      expect(isMangaFinished(baseManga), isFalse);
      expect(isMangaFinished(baseManga.copyWith(shelfGroup: '已读完')), isTrue);
      expect(isMangaFinished(baseManga.copyWith(shelfGroup: 'finished')), isTrue);
      expect(isMangaFinished(baseManga.copyWith(unreadCount: 0)), isTrue);
    });
  });

  group('Online TTS Client, Chunker, Fallback & Secret Safety', () {
    test('TtsTextChunker preserves global offsets across sentences', () {
      const body = '第一句比较完整并且达到一定长度以便独立分句。第二句也具有自然句号！\n第三句在这里。';
      final chunks = TtsTextChunker.split(body, baseOffset: 100);
      expect(chunks.length, greaterThanOrEqualTo(2));
      for (final c in chunks) {
        expect(c.startOffset, greaterThanOrEqualTo(100));
        expect(c.endOffset, greaterThan(c.startOffset));
        final sub = body
            .substring(c.startOffset - 100, c.endOffset - 100)
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        expect(sub, c.text);
      }
    });

    test('OnlineTtsClient handles OpenAI, caching, auth errors, JSON rejection, Custom HTTP & Legado JSON', () async {
      final tmpCache = Directory.systemTemp.createTempSync('inkbox_tts_cache_');
      var openAiHits = 0;
      String? lastAuthHeader;
      String? lastCustomQuery;
      String? lastCustomBody;

      final prevHttpOverrides = HttpOverrides.current;
      HttpOverrides.global = null;
      addTearDown(() => HttpOverrides.global = prevHttpOverrides);

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
        if (tmpCache.existsSync()) tmpCache.deleteSync(recursive: true);
      });

      server.listen((req) async {
        final path = req.uri.path;
        if (path == '/v1/audio/speech') {
          openAiHits++;
          lastAuthHeader = req.headers.value(HttpHeaders.authorizationHeader);
          await utf8.decodeStream(req);
          req.response.statusCode = HttpStatus.ok;
          req.response.headers.contentType = ContentType('audio', 'mpeg');
          req.response.add([0x49, 0x44, 0x33, 0x03, 0x00, 0x01, 0x02]);
          await req.response.close();
        } else if (path.startsWith('/unauth')) {
          req.response.statusCode = HttpStatus.unauthorized;
          await req.response.close();
        } else if (path.startsWith('/forbidden')) {
          req.response.statusCode = HttpStatus.forbidden;
          await req.response.close();
        } else if (path.startsWith('/json-err')) {
          req.response.statusCode = HttpStatus.ok;
          req.response.headers.contentType = ContentType.json;
          req.response.write('{"error":"quota exceeded"}');
          await req.response.close();
        } else if (path == '/custom-get') {
          lastCustomQuery = req.uri.query;
          req.response.statusCode = HttpStatus.ok;
          req.response.headers.contentType = ContentType('audio', 'mpeg');
          req.response.add([0x49, 0x44, 0x33, 0x04, 0x05]);
          await req.response.close();
        } else if (path == '/custom-post') {
          lastCustomBody = await utf8.decodeStream(req);
          req.response.statusCode = HttpStatus.ok;
          req.response.headers.contentType = ContentType('audio', 'mpeg');
          req.response.add([0x49, 0x44, 0x33, 0x06, 0x07]);
          await req.response.close();
        } else if (path == '/edge-gw') {
          await utf8.decodeStream(req);
          req.response.statusCode = HttpStatus.ok;
          req.response.headers.contentType = ContentType('audio', 'mpeg');
          req.response.add([0x49, 0x44, 0x33, 0x08, 0x09]);
          await req.response.close();
        } else {
          req.response.statusCode = HttpStatus.notFound;
          await req.response.close();
        }
      });

      final client = OnlineTtsClient(
        cache: TtsAudioCache(overrideDirPath: tmpCache.path),
      );
      final base = 'http://127.0.0.1:${server.port}';

      // 1. OpenAI 200 + second call hits cache
      final openAiProfile = OnlineTtsProfile(
        id: 'oai_test',
        name: 'OpenAI',
        kind: OnlineTtsProviderKind.openAiCompatible,
        endpointUrl: '$base/v1',
        voice: 'nova',
      );
      final f1 = await client.synthesizeToFile(
        profile: openAiProfile,
        text: 'Hello Cache',
        rate: 1.2,
        pitch: 1.0,
        apiKey: 'secret-123',
      );
      expect(f1.existsSync(), isTrue);
      expect(lastAuthHeader, 'Bearer secret-123');
      expect(openAiHits, 1);

      final f2 = await client.synthesizeToFile(
        profile: openAiProfile,
        text: 'Hello Cache',
        rate: 1.2,
        pitch: 1.0,
        apiKey: 'secret-123',
      );
      expect(f2.path, f1.path);
      expect(openAiHits, 1);

      // 2. HTTP 401 / 403 / JSON 200 rejection
      await expectLater(
        () => client.synthesizeToFile(
          profile: openAiProfile.copyWith(id: 'u1', endpointUrl: '$base/unauth'),
          text: 'test',
          rate: 1.0,
          pitch: 1.0,
        ),
        throwsA(isA<OnlineTtsException>().having((e) => e.code, 'code', 'ERR_HTTP_401')),
      );
      await expectLater(
        () => client.synthesizeToFile(
          profile: openAiProfile.copyWith(id: 'u2', endpointUrl: '$base/forbidden'),
          text: 'test',
          rate: 1.0,
          pitch: 1.0,
        ),
        throwsA(isA<OnlineTtsException>().having((e) => e.code, 'code', 'ERR_HTTP_403')),
      );
      await expectLater(
        () => client.synthesizeToFile(
          profile: openAiProfile.copyWith(id: 'u3', endpointUrl: '$base/json-err'),
          text: 'test',
          rate: 1.0,
          pitch: 1.0,
        ),
        throwsA(isA<OnlineTtsException>().having((e) => e.code, 'code', 'ERR_INVALID_AUDIO')),
      );

      // 3. Custom HTTP GET & POST + Edge Gateway
      final customGet = OnlineTtsProfile(
        id: 'cg',
        name: 'Custom GET',
        kind: OnlineTtsProviderKind.customHttp,
        httpMethod: 'GET',
        endpointUrl: '$base/custom-get?text={{textEncoded}}&spd={{speakSpeed}}',
      );
      await client.synthesizeToFile(
        profile: customGet,
        text: '你好 世界',
        rate: 1.5,
        pitch: 1.0,
      );
      expect(lastCustomQuery, contains('spd=15'));

      final customPost = OnlineTtsProfile(
        id: 'cp',
        name: 'Custom POST',
        kind: OnlineTtsProviderKind.customHttp,
        httpMethod: 'POST',
        endpointUrl: '$base/custom-post',
        bodyTemplate: '{"text":"{{text}}","voice":"{{voice}}","rate":{{rate}}}',
        voice: 'Xiaoxiao',
      );
      await client.synthesizeToFile(
        profile: customPost,
        text: '测试换行\n正文',
        rate: 1.1,
        pitch: 1.0,
      );
      expect(lastCustomBody, contains('"voice":"Xiaoxiao"'));
      expect(jsonDecode(lastCustomBody!), isA<Map>());

      final edgeGw = OnlineTtsProfile(
        id: 'eg',
        name: 'Edge GW',
        kind: OnlineTtsProviderKind.edgeTts,
        edgeUseGateway: true,
        endpointUrl: '$base/edge-gw',
      );
      final gwRes = await client.testConnection(
        profile: edgeGw,
        sampleText: 'hi',
        rate: 1.0,
        pitch: 1.0,
      );
      expect(gwRes.ok, isTrue);

      // 4. Legado HTTP TTS import + Safe JSON secret omission
      final parsed = parseLegadoHttpTtsJson(
        '[{"name":"Azure测试","url":"https://tts.example.com/api,{\\"method\\":\\"POST\\",\\"body\\":\\"{\\\\\\"text\\\\\\":\\\\\\"{{speakText}}\\\\\\"}\\"}","header":"{\\"X-Key\\":\\"abc\\"}"}]',
      );
      expect(parsed.length, 1);
      expect(parsed.first.name, 'Azure测试');
      expect(parsed.first.httpMethod, 'POST');
      expect(parsed.first.bodyTemplate, contains('{{text}}'));

      final state = TtsConfigState(
        mode: TtsEngineMode.online,
        profiles: [openAiProfile],
        secrets: {'oai_test': 'sk-top-secret-never-export'},
      );
      expect(
        jsonEncode(state.toSafeJson()),
        isNot(contains('sk-top-secret-never-export')),
      );
    });

    test('TtsPlaybackController falls back to local TTS only when enabled', () async {
      final prevHttpOverrides = HttpOverrides.current;
      HttpOverrides.global = null;
      addTearDown(() => HttpOverrides.global = prevHttpOverrides);

      final probe = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final closedPort = probe.port;
      await probe.close(force: true);

      final platform = _RedesignMockPlatformBridge();
      final client = OnlineTtsClient();
      final ctrl = TtsPlaybackController(platform: platform, onlineClient: client);
      addTearDown(() async {
        ctrl.dispose();
        await platform.eventCtrl.close();
      });

      final brokenOnline = OnlineTtsProfile(
        id: 'broken',
        name: 'Broken',
        kind: OnlineTtsProviderKind.openAiCompatible,
        endpointUrl: 'http://127.0.0.1:$closedPort/v1/audio/speech',
      );
      final chunks = TtsTextChunker.split('测试在线失败自动回退本地朗读功能。');

      String? fallbackCode;
      String? errorCode;
      ctrl.onFallbackNotice = (c) => fallbackCode = c;
      ctrl.onErrorNotice = (c) => errorCode = c;

      final okFallback = await ctrl.startChunks(
        chunks,
        readerSettings: const BookReaderSettings(),
        ttsConfig: TtsConfigState(
          mode: TtsEngineMode.online,
          activeProfileId: 'broken',
          profiles: [brokenOnline],
          fallbackToLocalTts: true,
        ),
      );
      expect(okFallback, isTrue);
      expect(ctrl.usingFallbackLocal, isTrue);
      expect(fallbackCode, isNotNull);
      expect(platform.spokenTexts, isNotEmpty);

      await ctrl.stop();
      platform.spokenTexts.clear();
      fallbackCode = null;
      errorCode = null;

      final okStrict = await ctrl.startChunks(
        chunks,
        readerSettings: const BookReaderSettings(),
        ttsConfig: TtsConfigState(
          mode: TtsEngineMode.online,
          activeProfileId: 'broken',
          profiles: [brokenOnline],
          fallbackToLocalTts: false,
        ),
      );
      expect(okStrict, isFalse);
      expect(ctrl.status, TtsPlaybackStatus.paused);
      expect(errorCode, isNotNull);
      expect(platform.spokenTexts, isEmpty);
    });
  });
}
