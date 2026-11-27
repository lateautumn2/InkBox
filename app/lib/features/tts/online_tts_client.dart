import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import 'tts_audio_cache.dart';
import 'tts_models.dart';

class OnlineTtsException implements Exception {
  const OnlineTtsException(this.code, [this.detail]);
  final String code;
  final String? detail;

  @override
  String toString() => detail == null || detail!.isEmpty ? code : '$code: $detail';
}

class OnlineTtsTestResult {
  const OnlineTtsTestResult({
    required this.ok,
    required this.latencyMs,
    this.audioPath,
    this.errorCode,
    this.errorDetail,
  });

  final bool ok;
  final int latencyMs;
  final String? audioPath;
  final String? errorCode;
  final String? errorDetail;
}

/// Multi-protocol online TTS client supporting Microsoft Edge TTS (direct WSS +
/// custom gateway), OpenAI-compatible `/v1/audio/speech`, and Legado-compatible
/// custom HTTP templates.
class OnlineTtsClient {
  OnlineTtsClient({
    TtsAudioCache? cache,
    HttpClient Function()? httpClientFactory,
  })  : _cache = cache ?? TtsAudioCache(),
        _httpClientFactory = httpClientFactory ?? HttpClient.new;

  final TtsAudioCache _cache;
  final HttpClient Function() _httpClientFactory;

  static const _edgeToken = '6A5AA1D4EAFF4E9FB37E23D68491D6F4';
  static const _edgeChromiumVersion = '130.0.2849.68';
  static const _edgeSecMsGecVersion = '1-$_edgeChromiumVersion';
  static const Duration _defaultTimeout = Duration(seconds: 10);
  static final Random _rng = Random.secure();
  static int _seq = 0;

  TtsAudioCache get cache => _cache;

  Future<File> synthesizeToFile({
    required OnlineTtsProfile profile,
    required String text,
    required double rate,
    required double pitch,
    String apiKey = '',
    bool bypassCache = false,
    bool enableCache = true,
    int? maxCacheBytes,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw const OnlineTtsException('ERR_TTS_UNAVAILABLE', 'Empty text');
    }

    final ext = _resolveFileExt(profile.format);
    final configFingerprint =
        '${profile.kind.name}|${profile.edgeUseGateway}|${profile.edgeGatewayUseSsml}|${profile.azureRegion}|${profile.endpointUrl}|${profile.model}|${profile.httpMethod}|${profile.headersJson}|${profile.bodyTemplate}';
    final key = _cache.keyFor(
      profileId: profile.id,
      configFingerprint: configFingerprint,
      voice: profile.voice,
      rate: rate,
      pitch: pitch,
      format: ext,
      text: trimmed,
    );
    if (enableCache && !bypassCache) {
      final cached = await _cache.getCachedFile(key, ext);
      if (cached != null) return cached;
    }

    final bytes = switch (profile.kind) {
      OnlineTtsProviderKind.edgeTts => profile.edgeUseGateway
          ? await _synthesizeEdgeGateway(
              profile: profile,
              text: trimmed,
              rate: rate,
              pitch: pitch,
              apiKey: apiKey,
            )
          : await _synthesizeEdgeDirectWss(
              profile: profile,
              text: trimmed,
              rate: rate,
              pitch: pitch,
            ),
      OnlineTtsProviderKind.azureSpeech => await _synthesizeAzureSpeech(
          profile: profile,
          text: trimmed,
          rate: rate,
          pitch: pitch,
          apiKey: apiKey,
        ),
      OnlineTtsProviderKind.openAiCompatible => await _synthesizeOpenAi(
          profile: profile,
          text: trimmed,
          rate: rate,
          apiKey: apiKey,
        ),
      OnlineTtsProviderKind.customHttp => await _synthesizeCustomHttp(
          profile: profile,
          text: trimmed,
          rate: rate,
          pitch: pitch,
          apiKey: apiKey,
        ),
    };

    if (bytes.isEmpty) {
      throw const OnlineTtsException('ERR_INVALID_AUDIO', 'Empty response');
    }
    if (!enableCache) {
      return _cache.writeEphemeralFile(ext, bytes);
    }
    return _cache.putBytes(key, ext, bytes, maxBytesOverride: maxCacheBytes);
  }

  Future<OnlineTtsTestResult> testConnection({
    required OnlineTtsProfile profile,
    required String sampleText,
    required double rate,
    required double pitch,
    String apiKey = '',
    bool enableCache = true,
    int? maxCacheBytes,
  }) async {
    final sw = Stopwatch()..start();
    try {
      final file = await synthesizeToFile(
        profile: profile,
        text: sampleText,
        rate: rate,
        pitch: pitch,
        apiKey: apiKey,
        bypassCache: true,
        enableCache: enableCache,
        maxCacheBytes: maxCacheBytes,
      );
      sw.stop();
      return OnlineTtsTestResult(
        ok: true,
        latencyMs: sw.elapsedMilliseconds,
        audioPath: file.path,
      );
    } on OnlineTtsException catch (e) {
      sw.stop();
      return OnlineTtsTestResult(
        ok: false,
        latencyMs: sw.elapsedMilliseconds,
        errorCode: e.code,
        errorDetail: e.detail,
      );
    } on TimeoutException {
      sw.stop();
      return OnlineTtsTestResult(
        ok: false,
        latencyMs: sw.elapsedMilliseconds,
        errorCode: 'ERR_NETWORK_TIMEOUT',
      );
    } catch (e) {
      sw.stop();
      return OnlineTtsTestResult(
        ok: false,
        latencyMs: sw.elapsedMilliseconds,
        errorCode: 'ERR_UNKNOWN',
        errorDetail: '$e',
      );
    }
  }

  Future<Uint8List> _synthesizeOpenAi({
    required OnlineTtsProfile profile,
    required String text,
    required double rate,
    required String apiKey,
  }) async {
    var base = profile.endpointUrl.trim();
    if (base.isEmpty) {
      base = 'https://api.openai.com/v1/audio/speech';
    } else if (!base.endsWith('/audio/speech') && !base.endsWith('/speech')) {
      base = base.endsWith('/') ? '${base}audio/speech' : '$base/audio/speech';
    }
    final uri = Uri.parse(base);
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (apiKey.trim().isNotEmpty) 'Authorization': 'Bearer ${apiKey.trim()}',
    };
    final body = jsonEncode({
      'model': profile.model.trim().isEmpty ? 'tts-1' : profile.model.trim(),
      'input': text,
      'voice': profile.voice.trim().isEmpty ? 'alloy' : profile.voice.trim(),
      'response_format': _resolveFileExt(profile.format),
      'speed': double.parse(rate.clamp(0.25, 4.0).toStringAsFixed(2)),
    });
    return _sendHttpRequest(
      method: 'POST',
      uri: uri,
      headers: headers,
      body: body,
    );
  }

  Future<Uint8List> _synthesizeEdgeGateway({
    required OnlineTtsProfile profile,
    required String text,
    required double rate,
    required double pitch,
    required String apiKey,
  }) async {
    final endpoint = profile.endpointUrl.trim();
    if (endpoint.isEmpty) {
      throw const OnlineTtsException('ERR_UNKNOWN', 'Missing gateway URL');
    }
    if (endpoint.contains('{{')) {
      return _synthesizeCustomHttp(
        profile: profile,
        text: text,
        rate: rate,
        pitch: pitch,
        apiKey: apiKey,
      );
    }
    final parsed = Uri.parse(endpoint);
    if (profile.edgeGatewayUseSsml ||
        parsed.path.toLowerCase().endsWith('/api/ra')) {
      final ssml = _buildSsml(
        voice: profile.voice,
        text: text,
        rate: rate,
        pitch: pitch,
      );
      final headers = <String, String>{
        'Content-Type': 'text/plain; charset=utf-8',
        'Format': _azureOutputFormat(profile.format),
        if (apiKey.trim().isNotEmpty) 'Authorization': 'Bearer ${apiKey.trim()}',
      };
      return _sendHttpRequest(
        method: 'POST',
        uri: parsed,
        headers: headers,
        body: ssml,
      );
    }
    final qp = Map<String, String>.from(parsed.queryParameters)
      ..putIfAbsent('text', () => text)
      ..putIfAbsent(
        'voiceName',
        () => profile.voice.isEmpty ? 'zh-CN-XiaoxiaoNeural' : profile.voice,
      )
      ..putIfAbsent('rate', () => _formatSignedPct((rate - 1.0) * 100))
      ..putIfAbsent('pitch', () => _formatSignedPct((pitch - 1.0) * 50));
    final uri = parsed.replace(queryParameters: qp);
    final headers = <String, String>{
      if (apiKey.trim().isNotEmpty) 'Authorization': 'Bearer ${apiKey.trim()}',
    };
    return _sendHttpRequest(method: 'GET', uri: uri, headers: headers);
  }

  Future<Uint8List> _synthesizeAzureSpeech({
    required OnlineTtsProfile profile,
    required String text,
    required double rate,
    required double pitch,
    required String apiKey,
  }) async {
    var endpoint = profile.endpointUrl.trim();
    if (endpoint.isEmpty) {
      final region =
          profile.azureRegion.trim().isEmpty ? 'eastus' : profile.azureRegion.trim();
      endpoint = 'https://$region.tts.speech.microsoft.com/cognitiveservices/v1';
    }
    final uri = Uri.parse(endpoint);
    final headers = <String, String>{
      'Content-Type': 'application/ssml+xml',
      'X-Microsoft-OutputFormat': _azureOutputFormat(profile.format),
      'User-Agent': 'InkBox',
      if (apiKey.trim().isNotEmpty) 'Ocp-Apim-Subscription-Key': apiKey.trim(),
    };
    final ssml = _buildSsml(
      voice: profile.voice,
      text: text,
      rate: rate,
      pitch: pitch,
    );
    return _sendHttpRequest(
      method: 'POST',
      uri: uri,
      headers: headers,
      body: ssml,
    );
  }

  String _buildSsml({
    required String voice,
    required String text,
    required double rate,
    required double pitch,
  }) {
    final safeVoice = voice.trim().isEmpty ? 'zh-CN-XiaoxiaoNeural' : voice.trim();
    final locale = _localeFromVoice(safeVoice);
    final ratePct = _formatSignedPct((rate - 1.0) * 100);
    final pitchHz = _formatSignedHz((pitch - 1.0) * 20);
    final escapedText = _xmlEscape(text);
    return "<speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' xml:lang='$locale'>"
        "<voice name='$safeVoice'>"
        "<prosody pitch='$pitchHz' rate='$ratePct' volume='+0%'>$escapedText</prosody>"
        '</voice></speak>';
  }

  static String _azureOutputFormat(String format) {
    return switch (_resolveFileExt(format)) {
      'opus' => 'audio-24khz-48kbitrate-mono-opus',
      'wav' => 'riff-24khz-16bit-mono-pcm',
      _ => 'audio-24khz-48kbitrate-mono-mp3',
    };
  }

  Future<Uint8List> _synthesizeCustomHttp({
    required OnlineTtsProfile profile,
    required String text,
    required double rate,
    required double pitch,
    required String apiKey,
  }) async {
    final urlStr = applyTemplate(
      profile.endpointUrl.trim(),
      text: text,
      voice: profile.voice,
      rate: rate,
      pitch: pitch,
    );
    if (urlStr.isEmpty) {
      throw const OnlineTtsException('ERR_UNKNOWN', 'Empty endpoint URL');
    }
    final uri = Uri.parse(urlStr);

    final headers = <String, String>{};
    if (profile.headersJson.trim().isNotEmpty) {
      try {
        final rawMap = jsonDecode(
          applyTemplate(
            profile.headersJson,
            text: _jsonStringEscape(text),
            voice: _jsonStringEscape(profile.voice),
            rate: rate,
            pitch: pitch,
            encodeForUrl: false,
          ),
        );
        if (rawMap is Map) {
          for (final entry in rawMap.entries) {
            headers['${entry.key}'] = '${entry.value}';
          }
        }
      } catch (_) {}
    }
    if (apiKey.trim().isNotEmpty &&
        !headers.keys.any((k) => k.toLowerCase() == 'authorization')) {
      headers['Authorization'] = 'Bearer ${apiKey.trim()}';
    }

    String? body;
    final method = profile.httpMethod.toUpperCase() == 'GET' ? 'GET' : 'POST';
    if (method == 'POST') {
      final rawBody = profile.bodyTemplate.trim().isNotEmpty
          ? profile.bodyTemplate
          : '{"text":"{{text}}","voice":"{{voice}}","rate":{{rate}}}';
      body = applyTemplate(
        rawBody,
        text: _jsonStringEscape(text),
        voice: _jsonStringEscape(profile.voice),
        rate: rate,
        pitch: pitch,
        encodeForUrl: false,
      );
      if (!headers.keys.any((k) => k.toLowerCase() == 'content-type')) {
        headers['Content-Type'] = 'application/json';
      }
    }

    return _sendHttpRequest(
      method: method,
      uri: uri,
      headers: headers,
      body: body,
      allowJsonAudioEnvelope: true,
    );
  }

  Future<Uint8List> _sendHttpRequest({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    String? body,
    bool allowJsonAudioEnvelope = false,
  }) async {
    final client = _httpClientFactory()..connectionTimeout = _defaultTimeout;
    try {
      final req = await client.openUrl(method, uri).timeout(_defaultTimeout);
      headers.forEach(req.headers.set);
      if (body != null) {
        req.add(utf8.encode(body));
      }
      final resp = await req.close().timeout(_defaultTimeout);
      final chunks = <int>[];
      await for (final c in resp.timeout(_defaultTimeout)) {
        chunks.addAll(c);
      }
      final bytes = Uint8List.fromList(chunks);
      final contentType =
          (resp.headers.contentType?.mimeType ?? '').toLowerCase();

      if (resp.statusCode == 401) {
        throw OnlineTtsException('ERR_HTTP_401', _previewBody(bytes));
      }
      if (resp.statusCode == 403) {
        throw OnlineTtsException('ERR_HTTP_403', _previewBody(bytes));
      }
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw OnlineTtsException(
          'ERR_HTTP_STATUS',
          'HTTP ${resp.statusCode} ${_previewBody(bytes)}'.trim(),
        );
      }

      if (contentType.startsWith('text/') || contentType == 'application/json') {
        if (allowJsonAudioEnvelope && contentType == 'application/json') {
          final extracted = await _tryExtractJsonAudio(bytes);
          if (extracted != null) return extracted;
        }
        throw OnlineTtsException('ERR_INVALID_AUDIO', _previewBody(bytes));
      }

      // Guard against HTML/JSON error pages served without proper Content-Type
      if (bytes.isEmpty || _looksLikeMarkupOrJson(bytes)) {
        if (allowJsonAudioEnvelope && _looksLikeJson(bytes)) {
          final extracted = await _tryExtractJsonAudio(bytes);
          if (extracted != null) return extracted;
        }
        throw OnlineTtsException('ERR_INVALID_AUDIO', _previewBody(bytes));
      }
      return bytes;
    } on SocketException catch (e) {
      throw OnlineTtsException('ERR_NETWORK_TIMEOUT', e.message);
    } on TimeoutException {
      throw const OnlineTtsException('ERR_NETWORK_TIMEOUT');
    } finally {
      client.close(force: true);
    }
  }

  Future<Uint8List?> _tryExtractJsonAudio(Uint8List bytes) async {
    try {
      final map = jsonDecode(utf8.decode(bytes));
      if (map is! Map) return null;
      final b64 = map['audio'] ?? map['data'] ?? map['audioContent'];
      if (b64 is String && b64.trim().isNotEmpty) {
        final cleaned = b64.contains(',') ? b64.split(',').last : b64;
        return base64Decode(cleaned.trim());
      }
      final url = map['url'] ?? map['audioUrl'];
      if (url is String && url.startsWith('http')) {
        return await _sendHttpRequest(
          method: 'GET',
          uri: Uri.parse(url),
          headers: const {},
        );
      }
    } catch (_) {}
    return null;
  }

  Future<Uint8List> _synthesizeEdgeDirectWss({
    required OnlineTtsProfile profile,
    required String text,
    required double rate,
    required double pitch,
  }) async {
    final connId = _randomHex32();
    final secMsGec = _generateSecMsGec();
    final wssUrl =
        'wss://speech.platform.bing.com/consumer/speech/synthesize/readaloud/edge/v1'
        '?TrustedClientToken=$_edgeToken'
        '&Sec-MS-GEC=$secMsGec'
        '&Sec-MS-GEC-Version=$_edgeSecMsGecVersion'
        '&ConnectionId=$connId';

    WebSocket? ws;
    try {
      ws = await WebSocket.connect(
        wssUrl,
        headers: const {
          'Pragma': 'no-cache',
          'Cache-Control': 'no-cache',
          'Origin': 'chrome-extension://jdiccldimpdaibmpdkjnbmckianbfold',
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/$_edgeChromiumVersion Safari/537.36 Edg/$_edgeChromiumVersion',
        },
      ).timeout(_defaultTimeout);
    } on WebSocketException catch (e) {
      final msg = '$e';
      if (msg.contains('403')) {
        throw OnlineTtsException('ERR_EDGE_403', msg);
      }
      throw OnlineTtsException('ERR_NETWORK_TIMEOUT', msg);
    } on HttpException catch (e) {
      if (e.message.contains('403')) {
        throw OnlineTtsException('ERR_EDGE_403', e.message);
      }
      throw OnlineTtsException('ERR_NETWORK_TIMEOUT', e.message);
    } on TimeoutException {
      throw const OnlineTtsException('ERR_NETWORK_TIMEOUT');
    }

    final audioBytes = BytesBuilder(copy: false);
    final completer = Completer<Uint8List>();
    final reqId = _randomHex32();
    final timestamp = DateTime.now().toUtc().toIso8601String();

    final sub = ws.listen(
      (event) {
        if (event is String) {
          if (event.contains('Path:turn.end')) {
            if (!completer.isCompleted) {
              completer.complete(audioBytes.takeBytes());
            }
          }
        } else if (event is List<int>) {
          if (event.length >= 2) {
            final headerLen = (event[0] << 8) | event[1];
            final payloadStart = 2 + headerLen;
            if (payloadStart <= event.length) {
              final headerText =
                  utf8.decode(event.sublist(2, payloadStart), allowMalformed: true);
              if (headerText.contains('Path:audio')) {
                audioBytes.add(event.sublist(payloadStart));
              }
            }
          }
        }
      },
      onError: (Object err) {
        if (!completer.isCompleted) {
          completer.completeError(
            OnlineTtsException('ERR_NETWORK_TIMEOUT', '$err'),
          );
        }
      },
      onDone: () {
        if (!completer.isCompleted) {
          final collected = audioBytes.takeBytes();
          if (collected.isNotEmpty) {
            completer.complete(collected);
          } else {
            completer.completeError(
              const OnlineTtsException('ERR_EDGE_403', 'Connection closed'),
            );
          }
        }
      },
      cancelOnError: true,
    );

    final configMsg =
        'X-Timestamp:$timestamp\r\nContent-Type:application/json; charset=utf-8\r\n'
        'Path:speech.config\r\n\r\n'
        '{"context":{"synthesis":{"audio":{"metadataoptions":{'
        '"sentenceBoundaryEnabled":"false","wordBoundaryEnabled":"false"},'
        '"outputFormat":"audio-24khz-48kbitrate-mono-mp3"}}}}';
    ws.add(configMsg);

    final ssml = _buildSsml(
      voice: profile.voice,
      text: text,
      rate: rate,
      pitch: pitch,
    );
    final ssmlMsg =
        'X-RequestId:$reqId\r\nContent-Type:application/ssml+xml\r\n'
        'X-Timestamp:$timestamp\r\nPath:ssml\r\n\r\n$ssml';
    ws.add(ssmlMsg);

    try {
      return await completer.future.timeout(_defaultTimeout);
    } finally {
      await sub.cancel();
      await ws.close();
    }
  }

  static String applyTemplate(
    String template, {
    required String text,
    required String voice,
    required double rate,
    required double pitch,
    bool encodeForUrl = true,
  }) {
    final rateStr = rate.toStringAsFixed(2);
    final ratePct = _formatSignedPct((rate - 1.0) * 100);
    final pitchStr = pitch.toStringAsFixed(2);
    final speakSpeed = (rate * 10).round().clamp(1, 50).toString();
    return template
        .replaceAll('{{textEncoded}}', Uri.encodeComponent(text))
        .replaceAll('{{text}}', text)
        .replaceAll('{{voice}}', encodeForUrl ? Uri.encodeComponent(voice) : voice)
        .replaceAll(
          '{{ratePct}}',
          encodeForUrl ? Uri.encodeComponent(ratePct) : ratePct,
        )
        .replaceAll('{{rate}}', rateStr)
        .replaceAll('{{pitch}}', pitchStr)
        .replaceAll('{{speakSpeed}}', speakSpeed);
  }

  static String _generateSecMsGec() {
    const winEpochOffsetSec = 11644473600;
    var ticks =
        (DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000) + winEpochOffsetSec;
    ticks -= ticks % 300;
    return debugSecMsGecForTicks(ticks * 10000000);
  }

  @visibleForTesting
  static String debugSecMsGecForTicks(int winTicks) {
    final hashInput = '$winTicks$_edgeToken';
    return sha256.convert(ascii.encode(hashInput)).toString().toUpperCase();
  }

  static String _randomHex32() {
    _seq = (_seq + 1) & 0xFFFFFFFF;
    final a = _rng.nextInt(0x10000000);
    final b = _rng.nextInt(0x10000000);
    final c = DateTime.now().microsecondsSinceEpoch ^ _seq;
    return md5.convert(utf8.encode('$a:$b:$c:$_seq')).toString();
  }

  static String _resolveFileExt(String format) {
    final lower = format.trim().toLowerCase();
    return kOnlineAudioFormats.contains(lower) ? lower : 'mp3';
  }

  static String _formatSignedPct(double pct) {
    final rounded = pct.round();
    return rounded >= 0 ? '+$rounded%' : '$rounded%';
  }

  static String _formatSignedHz(double hz) {
    final rounded = hz.round();
    return rounded >= 0 ? '+${rounded}Hz' : '${rounded}Hz';
  }

  static String _localeFromVoice(String voice) {
    final parts = voice.split('-');
    if (parts.length >= 2) return '${parts[0]}-${parts[1]}';
    return 'zh-CN';
  }

  static String _xmlEscape(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  static String _jsonStringEscape(String input) {
    final encoded = jsonEncode(input);
    return encoded.substring(1, encoded.length - 1);
  }

  static bool _looksLikeJson(Uint8List bytes) {
    for (final b in bytes.take(32)) {
      if (b == 0x20 || b == 0x0A || b == 0x0D || b == 0x09) continue;
      return b == 0x7B || b == 0x5B;
    }
    return false;
  }

  static bool _looksLikeMarkupOrJson(Uint8List bytes) {
    for (final b in bytes.take(32)) {
      if (b == 0x20 || b == 0x0A || b == 0x0D || b == 0x09) continue;
      return b == 0x7B || b == 0x5B || b == 0x3C;
    }
    return false;
  }

  static String _previewBody(Uint8List bytes) {
    if (bytes.isEmpty) return '';
    final str = utf8.decode(bytes.take(180).toList(), allowMalformed: true);
    return str.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
