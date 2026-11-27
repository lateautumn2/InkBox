import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
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
import 'package:inkbox/features/webdav_sync/webdav_sync_service.dart';
import 'package:inkbox/l10n/app_localizations.dart';
import 'package:inkbox/main.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

class _RedesignMockPlatformBridge implements PlatformBridge {
  final StreamController<PlatformEvent> eventCtrl =
      StreamController<PlatformEvent>.broadcast();
  final List<String> spokenTexts = [];
  final List<String> playedAudioPaths = [];
  final Map<String, String> secureStore = {};
  bool speakShouldFail = false;
  double? lastBrightness;
  double? lastPlayedSpeed;
  double? lastAudioSpeed;

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
  Future<void> setScreenBrightness(double? brightness) async {
    lastBrightness = brightness;
  }

  @override
  Future<double?> getScreenBrightness() async => lastBrightness ?? 0.55;
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
  }) async {
    playedAudioPaths.add(path);
    lastPlayedSpeed = speed;
    return true;
  }
  @override
  Future<void> pauseAudio() async {}
  @override
  Future<void> resumeAudio() async {}
  @override
  Future<void> stopAudio() async {}
  @override
  Future<void> setAudioSpeed(double speed) async {
    lastAudioSpeed = speed;
  }
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
      expect(find.text('设置'), findsWidgets);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(AppShellScaffold)),
      );
      await tester.runAsync(
        () => container.read(appearanceProvider.notifier).setAppLocaleCode('en'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Books'), findsWidgets);
      expect(find.text('Manga'), findsWidgets);
      expect(find.text('Settings'), findsWidgets);

      await tester.runAsync(
        () => container.read(appearanceProvider.notifier).setAppLocaleCode('ja'),
      );
      await tester.pumpAndSettle();
      expect(find.text('本棚'), findsWidgets);
      expect(find.text('マンガ'), findsWidgets);
      expect(find.text('設定'), findsWidgets);

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

    test('applyTemplate encodeForUrl & TtsAudioCache configFingerprint work cleanly', () {
      final urlRendered = OnlineTtsClient.applyTemplate(
        'https://tts.example.com?v={{voice}}&r={{ratePct}}',
        text: 'hello',
        voice: '中文音色',
        rate: 1.5,
        pitch: 1.0,
        encodeForUrl: true,
      );
      expect(urlRendered, contains(Uri.encodeComponent('中文音色')));
      expect(urlRendered, contains('%2B50%25'));

      final jsonRendered = OnlineTtsClient.applyTemplate(
        '{"voice":"{{voice}}","ratePct":"{{ratePct}}","t":"{{textEncoded}}"}',
        text: 'a b',
        voice: '中文音色',
        rate: 1.5,
        pitch: 1.0,
        encodeForUrl: false,
      );
      expect(jsonRendered, contains('"voice":"中文音色"'));
      expect(jsonRendered, contains('"ratePct":"+50%"'));
      expect(jsonRendered, contains('"t":"a%20b"'));

      final cache = TtsAudioCache();
      final k1 = cache.keyFor(
        profileId: 'p1',
        configFingerprint: 'POST|https://a.example/tts|{"a":1}',
        voice: 'v',
        rate: 1.0,
        pitch: 1.0,
        format: 'mp3',
        text: 'hello',
      );
      final k2 = cache.keyFor(
        profileId: 'p1',
        configFingerprint: 'POST|https://b.example/tts|{"a":1}',
        voice: 'v',
        rate: 1.0,
        pitch: 1.0,
        format: 'mp3',
        text: 'hello',
      );
      expect(k1, isNot(k2));
    });

    test('TtsPlaybackController pause during loading prevents late play & safely drops failing prefetches', () async {
      final prevHttpOverrides = HttpOverrides.current;
      HttpOverrides.global = null;
      addTearDown(() => HttpOverrides.global = prevHttpOverrides);

      final tmpCache = Directory.systemTemp.createTempSync('inkbox_pause_load_');
      final gate = Completer<void>();
      var chunk0Hits = 0;

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        if (!gate.isCompleted) gate.complete();
        await server.close(force: true);
        if (tmpCache.existsSync()) tmpCache.deleteSync(recursive: true);
      });

      server.listen((req) async {
        try {
          final body = await utf8.decodeStream(req);
          if (body.contains('第一句')) {
            chunk0Hits++;
            if (chunk0Hits == 1) {
              await gate.future;
              req.response.statusCode = HttpStatus.ok;
              req.response.headers.contentType = ContentType('audio', 'mpeg');
              req.response.add([0x49, 0x44, 0x33, 0x01, 0x02]);
              await req.response.close();
            } else {
              req.response.statusCode = HttpStatus.ok;
              req.response.headers.contentType = ContentType('audio', 'mpeg');
              req.response.add([0x49, 0x44, 0x33, 0x03, 0x04]);
              await req.response.close();
            }
          } else if (body.contains('第二句') || body.contains('第三句')) {
            // Prefetched chunks fail with 500 — must NOT trigger unhandled Future errors
            req.response.statusCode = HttpStatus.internalServerError;
            await req.response.close();
          } else {
            req.response.statusCode = HttpStatus.ok;
            req.response.headers.contentType = ContentType('audio', 'mpeg');
            req.response.add([0x49, 0x44, 0x33, 0x03, 0x04]);
            await req.response.close();
          }
        } catch (_) {}
      });

      final platform = _RedesignMockPlatformBridge();
      final client = OnlineTtsClient(
        cache: TtsAudioCache(overrideDirPath: tmpCache.path),
      );
      final ctrl = TtsPlaybackController(platform: platform, onlineClient: client);
      addTearDown(() async {
        ctrl.dispose();
        await platform.eventCtrl.close();
      });

      final profile = OnlineTtsProfile(
        id: 'slow_online',
        name: 'Slow',
        kind: OnlineTtsProviderKind.openAiCompatible,
        endpointUrl: 'http://127.0.0.1:${server.port}/v1/audio/speech',
      );
      final chunks = const [
        TtsSentenceChunk(index: 0, startOffset: 0, endOffset: 3, text: '第一句'),
        TtsSentenceChunk(index: 1, startOffset: 3, endOffset: 6, text: '第二句'),
        TtsSentenceChunk(index: 2, startOffset: 6, endOffset: 9, text: '第三句'),
      ];

      final startFut = ctrl.startChunks(
        chunks,
        readerSettings: const BookReaderSettings(),
        ttsConfig: TtsConfigState(
          mode: TtsEngineMode.online,
          activeProfileId: 'slow_online',
          profiles: [profile],
          fallbackToLocalTts: false,
        ),
      );

      // Give server time to enter gate on chunk 0 and fail prefetches for chunks 1 & 2
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(ctrl.status, TtsPlaybackStatus.loading);

      await ctrl.pause();
      gate.complete();
      final startRes = await startFut;

      expect(startRes, isFalse);
      expect(ctrl.status, TtsPlaybackStatus.paused);
      expect(platform.playedAudioPaths, isEmpty);

      // Resume retries cleanly using fresh HTTP call and plays audio
      await ctrl.resume();
      expect(ctrl.status, TtsPlaybackStatus.playing);
      expect(platform.playedAudioPaths.length, 1);

      await ctrl.stop();
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });

    test('TtsConfigController sets hydrated and preserves pre-hydration mutations', () async {
      final persisted = {
        'mode': 'local',
        'activeProfileId': 'saved_p1',
        'profiles': [
          const OnlineTtsProfile(
            id: 'saved_p1',
            name: 'Saved Custom',
            kind: OnlineTtsProviderKind.openAiCompatible,
            endpointUrl: 'https://saved.example/v1/audio/speech',
          ).toJson(),
        ],
        'fallbackToLocalTts': true,
        'sleepAtChapterEnd': false,
      };
      SharedPreferences.setMockInitialValues({
        'inkbox_tts_config_v2': jsonEncode(persisted),
      });

      final platform = _RedesignMockPlatformBridge()
        ..secureStore['tts_secret_saved_p1'] = 'sk-from-keystore';
      final container1 = ProviderContainer(
        overrides: [platformBridgeProvider.overrideWithValue(platform)],
      );
      addTearDown(container1.dispose);

      container1.read(ttsConfigProvider);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      final loaded = container1.read(ttsConfigProvider);
      expect(loaded.hydrated, isTrue);
      expect(loaded.activeProfile.id, 'saved_p1');
      expect(loaded.secretFor('saved_p1'), 'sk-from-keystore');

      // Mutating before hydration finishes must not be clobbered by _hydrate()
      final container2 = ProviderContainer(
        overrides: [platformBridgeProvider.overrideWithValue(platform)],
      );
      addTearDown(container2.dispose);
      final notifier2 = container2.read(ttsConfigProvider.notifier);
      await notifier2.setMode(TtsEngineMode.online);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      final mutated = container2.read(ttsConfigProvider);
      expect(mutated.hydrated, isTrue);
      expect(mutated.mode, TtsEngineMode.online);
      await platform.eventCtrl.close();
    });

    testWidgets('Reader hides chapter scrubber on tab, edits 3x3 tap zones & speed, and supports edge brightness + swipe-up bookmark', (tester) async {
      final db = AppDatabase.inMemory();
      final tmp = Directory.systemTemp.createTempSync('inkbox_reader_gestures_');
      final platform = _RedesignMockPlatformBridge();
      late int bookId;

      await tester.runAsync(() async {
        final paras = List.generate(
          28,
          (i) => '第${i + 1}段测试阅读交互：左边缘上下滑动调节屏幕亮度，正文上滑快捷添加或取消本页书签，翻页标签支持自定义九宫格区域与滚屏速度。',
        ).join('\n');
        final file = File(p.join(tmp.path, 'gestures.txt'))
          ..writeAsStringSync('第一章 初见\n$paras');
        final now = DateTime.now().millisecondsSinceEpoch;
        bookId = await db.upsertBook(
          BooksCompanion.insert(
            contentHash: 'gesture_hash_1',
            title: '手势交互测试书',
            format: 'TXT',
            filePath: file.path,
            addedAtMs: now,
            lastReadAtMs: now,
          ),
        );
      });

      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() async => tester.binding.setSurfaceSize(null));

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
        if (find.byType(ReaderHighlightCanvas).evaluate().isNotEmpty) break;
      }

      // 1. Open menu -> chapter scrubber visible; open 翻页 tab -> scrubber hidden; close tab -> scrubber back
      await tester.tapAt(const Offset(200, 400));
      await tester.pumpAndSettle();
      expect(find.text('上一章'), findsOneWidget);
      expect(find.text('下一章'), findsOneWidget);

      await tester.tap(find.text('翻页').last);
      await tester.pumpAndSettle();
      expect(find.text('上一章'), findsNothing);
      expect(find.text('下一章'), findsNothing);
      expect(find.text('翻页点击区域（点击格子可自定义）'), findsOneWidget);
      expect(find.text('滚屏速度'), findsOneWidget);
      expect(find.byKey(const ValueKey('tap_grid_cell_0')), findsOneWidget);

      // Cycle cell 0 from 上一页 -> 下一页 and verify custom tap grid updates
      await tester.tap(find.byKey(const ValueKey('tap_grid_cell_0')));
      await tester.pumpAndSettle();
      final afterTapGrid = container.read(bookReaderSettingsProvider);
      expect(afterTapGrid.tapZonePreset, TapZonePreset.custom);
      expect(afterTapGrid.resolveTapAction(0.1, 0.1), TapZoneAction.nextPage);

      // Drag Auto-Scroll speed slider -> speed changes
      await tester.drag(find.byType(Slider).last, const Offset(80, 0));
      await tester.pumpAndSettle();
      expect(container.read(bookReaderSettingsProvider).autoScrollSpeed, isNot(48.0));

      // Toggle 翻页 tab off -> chapter scrubber comes back
      await tester.tap(find.text('翻页').last);
      await tester.pumpAndSettle();
      expect(find.text('上一章'), findsOneWidget);
      expect(find.text('下一章'), findsOneWidget);

      // Close menu
      await tester.tapAt(const Offset(200, 400));
      await tester.pumpAndSettle();

      // 2. Left-edge vertical drag up -> updates screen brightness & shows HUD
      await tester.timedDragFrom(
        const Offset(22, 420),
        const Offset(0, -140),
        const Duration(milliseconds: 180),
      );
      await tester.pump();
      expect(platform.lastBrightness, isNotNull);
      expect(platform.lastBrightness!, greaterThan(0.55));
      expect(find.textContaining(RegExp(r'^亮度 \d+%$')), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));

      // 3. Upward swipe in body -> adds bookmark; second upward swipe -> removes bookmark
      await tester.timedDragFrom(
        const Offset(220, 500),
        const Offset(0, -130),
        const Duration(milliseconds: 180),
      );
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
      await tester.pumpAndSettle();
      final bms1 = (await tester.runAsync(() => db.getAnnotationsFor('gesture_hash_1')))!
          .where((a) => !a.isDeleted && a.kind == 'bookmark')
          .toList();
      expect(bms1.length, 1);

      await tester.timedDragFrom(
        const Offset(220, 500),
        const Offset(0, -130),
        const Duration(milliseconds: 180),
      );
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
      await tester.pumpAndSettle();
      final bms2 = (await tester.runAsync(() => db.getAnnotationsFor('gesture_hash_1')))!
          .where((a) => !a.isDeleted && a.kind == 'bookmark')
          .toList();
      expect(bms2, isEmpty);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
      container.dispose();
      await platform.eventCtrl.close();
      await tester.runAsync(() async {
        await db.close();
        if (tmp.existsSync()) tmp.deleteSync(recursive: true);
      });
    });

    testWidgets('PageTurnStage simulation supports top-right & bottom-right corner curl', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() async => tester.binding.setSurfaceSize(null));

      var turns = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PageTurnStage(
              mode: PageTurnMode.simulation,
              currentPage: const ColoredBox(color: Colors.white, child: Center(child: Text('Cur'))),
              previousPage: const ColoredBox(color: Colors.white, child: Center(child: Text('Prev'))),
              nextPage: const ColoredBox(color: Colors.white, child: Center(child: Text('Next'))),
              paperColor: Colors.white,
              onTurnNext: () => turns++,
              onTurnPrev: () {},
              onTapNormalized: (_, _) {},
            ),
          ),
        ),
      );

      // Bottom-right corner drag
      final gBottom = await tester.startGesture(const Offset(375, 740));
      await gBottom.moveBy(const Offset(-140, -40));
      await tester.pump(const Duration(milliseconds: 16));
      await gBottom.moveBy(const Offset(-120, -20));
      await tester.pump(const Duration(milliseconds: 16));
      await gBottom.up();
      await tester.pumpAndSettle();
      expect(turns, 1);

      // Top-right corner drag
      final gTop = await tester.startGesture(const Offset(375, 60));
      await gTop.moveBy(const Offset(-140, 40));
      await tester.pump(const Duration(milliseconds: 16));
      await gTop.moveBy(const Offset(-120, 20));
      await tester.pump(const Duration(milliseconds: 16));
      await gTop.up();
      await tester.pumpAndSettle();
      expect(turns, 2);
    });

    test('Azure Speech, ms-ra-forwarder SSML POST, and Online TTS cache/prefetch config work cleanly', () async {
      final prevHttpOverrides = HttpOverrides.current;
      HttpOverrides.global = null;
      addTearDown(() => HttpOverrides.global = prevHttpOverrides);

      final tmpCache = Directory.systemTemp.createTempSync('inkbox_azure_ra_');
      String? azureKeyHeader;
      String? azureFormatHeader;
      String? azureBody;
      String? raMethod;
      String? raFormatHeader;
      String? raBody;

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
        if (tmpCache.existsSync()) tmpCache.deleteSync(recursive: true);
        final live = Directory('${tmpCache.path}_live');
        if (live.existsSync()) live.deleteSync(recursive: true);
      });

      server.listen((req) async {
        try {
          final body = await utf8.decodeStream(req);
          if (req.uri.path == '/cognitiveservices/v1') {
            azureKeyHeader = req.headers.value('ocp-apim-subscription-key');
            azureFormatHeader = req.headers.value('x-microsoft-outputformat');
            azureBody = body;
            req.response.statusCode = HttpStatus.ok;
            req.response.headers.contentType = ContentType('audio', 'mpeg');
            req.response.add([0x49, 0x44, 0x33, 0x01, 0x02]);
            await req.response.close();
          } else if (req.uri.path == '/api/ra') {
            raMethod = req.method;
            raFormatHeader = req.headers.value('format');
            raBody = body;
            req.response.statusCode = HttpStatus.ok;
            req.response.headers.contentType = ContentType('audio', 'mpeg');
            req.response.add([0x49, 0x44, 0x33, 0x03, 0x04]);
            await req.response.close();
          } else {
            req.response.statusCode = HttpStatus.notFound;
            await req.response.close();
          }
        } catch (_) {}
      });

      final cache = TtsAudioCache(overrideDirPath: tmpCache.path);
      final client = OnlineTtsClient(cache: cache);
      final base = 'http://127.0.0.1:${server.port}';

      // Azure Speech
      final azureProfile = OnlineTtsProfile(
        id: 'az_1',
        name: 'Azure',
        kind: OnlineTtsProviderKind.azureSpeech,
        endpointUrl: '$base/cognitiveservices/v1',
        azureRegion: 'eastus',
        voice: 'zh-CN-XiaoxiaoNeural',
      );
      await client.synthesizeToFile(
        profile: azureProfile,
        text: '测试 Azure 官方朗读',
        rate: 1.2,
        pitch: 1.0,
        apiKey: 'az-secret-key',
      );
      expect(azureKeyHeader, 'az-secret-key');
      expect(azureFormatHeader, 'audio-24khz-48kbitrate-mono-mp3');
      expect(azureBody, contains('zh-CN-XiaoxiaoNeural'));

      // ms-ra-forwarder SSML POST + enableCache: false leaves persistent cache at 0 bytes
      await cache.clear();
      final raProfile = OnlineTtsProfile(
        id: 'ra_1',
        name: 'ReadAloud Gateway',
        kind: OnlineTtsProviderKind.edgeTts,
        edgeUseGateway: true,
        edgeGatewayUseSsml: true,
        endpointUrl: '$base/api/ra',
        voice: 'zh-CN-YunxiNeural',
      );
      final ephemeral = await client.synthesizeToFile(
        profile: raProfile,
        text: '测试大声朗读转发网关',
        rate: 1.0,
        pitch: 1.0,
        enableCache: false,
      );
      expect(raMethod, 'POST');
      expect(raFormatHeader, 'audio-24khz-48kbitrate-mono-mp3');
      expect(raBody, contains('zh-CN-YunxiNeural'));
      expect(ephemeral.existsSync(), isTrue);
      expect(tmpCache.listSync(), isEmpty);
      expect(await cache.totalSizeBytes(), greaterThan(0));
      await cache.clear();
      expect(ephemeral.existsSync(), isFalse);
      expect(await cache.totalSizeBytes(), 0);

      // Config persistence for cacheEnabled / cacheMaxMb / prefetchCount
      SharedPreferences.setMockInitialValues({});
      final platform = _RedesignMockPlatformBridge();
      final container = ProviderContainer(
        overrides: [platformBridgeProvider.overrideWithValue(platform)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(ttsConfigProvider.notifier);
      await notifier.setCacheEnabled(false);
      await notifier.setCacheMaxMb(250);
      await notifier.setPrefetchCount(3);
      final cfg = container.read(ttsConfigProvider);
      expect(cfg.cacheEnabled, isFalse);
      expect(cfg.cacheMaxMb, 250);
      expect(cfg.prefetchCount, 3);
      await platform.eventCtrl.close();
    });

    test('P0 regressions: single-side rate, uppercase Edge token, non-overwriting _live files, and WebDAV SyncState preservation', () async {
      final prevHttpOverrides = HttpOverrides.current;
      HttpOverrides.global = null;
      addTearDown(() => HttpOverrides.global = prevHttpOverrides);

      // P0-2: Edge Sec-MS-GEC must hash using uppercase TRUSTED_CLIENT_TOKEN
      const sampleTicks = 133700000000000000;
      final expectedGec = sha256
          .convert(ascii.encode('${sampleTicks}6A5AA1D4EAFF4E9FB37E23D68491D6F4'))
          .toString()
          .toUpperCase();
      expect(OnlineTtsClient.debugSecMsGecForTicks(sampleTicks), expectedGec);

      // P0-3: Disabled cache writes unique ephemeral files without overwriting active clips & clear() cleans _live
      final tmpCache = Directory.systemTemp.createTempSync('inkbox_p0_tts_');
      addTearDown(() async {
        if (tmpCache.existsSync()) tmpCache.deleteSync(recursive: true);
        final live = Directory('${tmpCache.path}_live');
        if (live.existsSync()) live.deleteSync(recursive: true);
      });
      final cache = TtsAudioCache(overrideDirPath: tmpCache.path);
      final ephemeralFiles = <File>[];
      for (var i = 0; i < 6; i++) {
        ephemeralFiles.add(
          await cache.writeEphemeralFile('mp3', [0x49, 0x44, 0x33, i]),
        );
      }
      expect(ephemeralFiles.map((f) => f.path).toSet().length, 6);
      expect(ephemeralFiles.first.readAsBytesSync(), [0x49, 0x44, 0x33, 0]);
      expect(await cache.totalSizeBytes(), greaterThan(0));
      await cache.clear();
      expect(await cache.totalSizeBytes(), 0);
      expect(ephemeralFiles.any((f) => f.existsSync()), isFalse);

      // P0-1: Online TTS synthesizes at 1.0x and applies ttsRate once in MediaPlayer playback
      final sentSpeeds = <double>[];
      final ttsServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => ttsServer.close(force: true));
      ttsServer.listen((req) async {
        final raw = await utf8.decodeStream(req);
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        sentSpeeds.add((decoded['speed'] as num).toDouble());
        req.response.statusCode = HttpStatus.ok;
        req.response.headers.contentType = ContentType('audio', 'mpeg');
        req.response.add([0x49, 0x44, 0x33, sentSpeeds.length]);
        await req.response.close();
      });

      final platform = _RedesignMockPlatformBridge();
      final client = OnlineTtsClient(cache: cache);
      final ctrl = TtsPlaybackController(platform: platform, onlineClient: client);
      addTearDown(() async {
        ctrl.dispose();
        await platform.eventCtrl.close();
      });

      final oaiProfile = OnlineTtsProfile(
        id: 'p0_rate',
        name: 'RateCheck',
        kind: OnlineTtsProviderKind.openAiCompatible,
        endpointUrl: 'http://127.0.0.1:${ttsServer.port}/v1/audio/speech',
      );
      await ctrl.startChunks(
        const [
          TtsSentenceChunk(index: 0, startOffset: 0, endOffset: 3, text: '第一句'),
          TtsSentenceChunk(index: 1, startOffset: 3, endOffset: 6, text: '第二句'),
        ],
        readerSettings: const BookReaderSettings(ttsRate: 2.0),
        ttsConfig: TtsConfigState(
          mode: TtsEngineMode.online,
          activeProfileId: 'p0_rate',
          profiles: [oaiProfile],
          cacheEnabled: false,
          prefetchCount: 1,
        ),
      );
      expect(sentSpeeds, everyElement(1.0));
      expect(platform.lastPlayedSpeed, 2.0);

      await ctrl.updateRate(1.5);
      expect(platform.lastAudioSpeed, 1.5);
      await ctrl.stop();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // P0-5: WebDAV restoreBackupSnapshot preserves authoritative SyncState without dirtying it
      final db = AppDatabase.inMemory();
      addTearDown(db.close);
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.upsertBook(
        BooksCompanion.insert(
          contentHash: 'h1',
          title: 'WebDAV P0 Test',
          format: 'TXT',
          filePath: '/tmp/h1.txt',
          addedAtMs: now,
          lastReadAtMs: now,
        ),
      );

      final snapBytes = utf8.encode(
        jsonEncode({
          'sync/progress_index.json': jsonEncode({
            'records': {
              'h1': {
                'content_hash': 'h1',
                'media_kind': 'book',
                'locator': 'ch:2;off:15',
                'progress_ratio': 0.25,
                'updated_at_epoch_ms': 1000,
                'device_id': 'other_dev',
                'device_name': 'Other Tablet',
              },
            },
          }),
        }),
      );
      final davServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => davServer.close(force: true));
      davServer.listen((req) async {
        if (req.method == 'GET' && req.uri.path.endsWith('/snap.zip')) {
          req.response.statusCode = HttpStatus.ok;
          req.response.add(snapBytes);
        } else {
          req.response.statusCode = HttpStatus.notFound;
        }
        await req.response.close();
      });

      final tmpDav = Directory.systemTemp.createTempSync('inkbox_p0_dav_');
      addTearDown(() {
        if (tmpDav.existsSync()) tmpDav.deleteSync(recursive: true);
      });
      final syncSvc = WebDavSyncService(db: db, tempDirOverride: tmpDav.path);
      final davCfg = WebDavConfig(
        serverUrl: 'http://127.0.0.1:${davServer.port}',
        username: 'u',
        password: 'p',
        deviceId: 'local_phone',
        deviceName: 'Local Phone',
      );
      final restored = await syncSvc.restoreBackupSnapshot(davCfg, 'snap.zip');
      expect(restored, 1);

      final st = await db.getSyncState('h1');
      expect(st, isNotNull);
      expect(st!.updatedAtMs, 1000);
      expect(st.lastSyncedAtMs, greaterThanOrEqualTo(st.updatedAtMs));
      expect(st.deviceId, 'other_dev');
      expect(st.deviceName, 'Other Tablet');

      final restoredBook = await db.findBookByHash('h1');
      expect(restoredBook!.currentChapterIndex, 2);
      expect(restoredBook.currentCharOffset, 15);
      expect(restoredBook.progressRatio, closeTo(0.25, 0.001));
    });
  });
}
