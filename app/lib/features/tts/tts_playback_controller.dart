import 'dart:async';
import 'dart:io';

import 'package:material_ui/material_ui.dart';

import '../../data/platform/platform_bridge.dart';
import '../book_reader/book_reader_settings.dart';
import 'online_tts_client.dart';
import 'tts_models.dart';
import 'tts_text_chunker.dart';

enum TtsPlaybackStatus {
  idle,
  loading,
  playing,
  paused,
}

/// Unified TTS queue controller handling sentence-by-sentence playback, live
/// highlight offset tracking, concurrent online prefetching, sleep timers,
/// and seamless fallback to local Android TTS on network failure.
class TtsPlaybackController extends ChangeNotifier {
  TtsPlaybackController({
    required PlatformBridge platform,
    OnlineTtsClient? onlineClient,
  })  : _platform = platform,
        _onlineClient = onlineClient ?? OnlineTtsClient() {
    _eventSub = _platform.events.listen(_handlePlatformEvent);
  }

  final PlatformBridge _platform;
  final OnlineTtsClient _onlineClient;

  StreamSubscription<PlatformEvent>? _eventSub;
  TtsPlaybackStatus _status = TtsPlaybackStatus.idle;
  List<TtsSentenceChunk> _chunks = const [];
  int _chunkIndex = 0;
  int _sessionToken = 0;
  bool _excerptOnly = false;
  bool _usingFallbackLocal = false;
  String? _activeUtteranceId;
  String? _activePlaybackId;
  String? _activeAudioPath;
  DateTime? _sleepEndAt;
  Timer? _sleepTicker;
  bool _disposed = false;
  bool _hasLoadedAudio = false;

  void _safeNotify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  void _disposeEphemeralPath(String? path) {
    if (path == null || path.isEmpty) return;
    unawaited(_onlineClient.cache.deleteEphemeralFile(path));
  }

  void _clearPrefetchFutures() {
    if (_prefetchFutures.isEmpty) return;
    final pending = List<Future<({File? file, Object? error})>>.of(
      _prefetchFutures.values,
    );
    _prefetchFutures.clear();
    for (final fut in pending) {
      unawaited(
        fut.then((res) {
          _disposeEphemeralPath(res.file?.path);
        }),
      );
    }
  }

  BookReaderSettings _readerSettings = const BookReaderSettings();
  TtsConfigState _ttsConfig = const TtsConfigState();

  final Map<int, Future<({File? file, Object? error})>> _prefetchFutures = {};

  VoidCallback? onPageCompleted;
  void Function(String code)? onFallbackNotice;
  void Function(String code)? onErrorNotice;
  VoidCallback? onSleepTimerExpired;

  TtsPlaybackStatus get status => _status;
  bool get isActive => _status != TtsPlaybackStatus.idle;
  bool get isPlaying => _status == TtsPlaybackStatus.playing;
  bool get isPaused => _status == TtsPlaybackStatus.paused;
  bool get isExcerptOnly => _excerptOnly;
  bool get usingFallbackLocal => _usingFallbackLocal;
  DateTime? get sleepEndAt => _sleepEndAt;

  ({int start, int end})? get activeHighlightRange {
    if (!isActive || _excerptOnly || _chunks.isEmpty) return null;
    if (_chunkIndex < 0 || _chunkIndex >= _chunks.length) return null;
    final c = _chunks[_chunkIndex];
    return (start: c.startOffset, end: c.endOffset);
  }

  String? get remainingSleepLabel {
    final end = _sleepEndAt;
    if (end == null) return null;
    final diff = end.difference(DateTime.now());
    if (diff.isNegative) return '00:00';
    final mins = diff.inMinutes;
    final secs = diff.inSeconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void updateConfigs({
    required BookReaderSettings readerSettings,
    required TtsConfigState ttsConfig,
  }) {
    _readerSettings = readerSettings;
    _ttsConfig = ttsConfig;
  }

  void armSleepTimer(int minutes) {
    _sleepTicker?.cancel();
    _sleepTicker = null;
    if (minutes <= 0) {
      _sleepEndAt = null;
      _safeNotify();
      return;
    }
    _sleepEndAt = DateTime.now().add(Duration(minutes: minutes));
    _sleepTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      final end = _sleepEndAt;
      if (end == null || _disposed) return;
      if (!DateTime.now().isBefore(end)) {
        stop();
        onSleepTimerExpired?.call();
      } else {
        _safeNotify();
      }
    });
    _safeNotify();
  }

  Future<bool> startChunks(
    List<TtsSentenceChunk> chunks, {
    required BookReaderSettings readerSettings,
    required TtsConfigState ttsConfig,
    bool excerptOnly = false,
  }) async {
    if (_disposed) return false;
    _readerSettings = readerSettings;
    _ttsConfig = ttsConfig;
    if (chunks.isEmpty) return false;

    final token = ++_sessionToken;
    _clearPrefetchFutures();
    _chunks = chunks;
    _chunkIndex = 0;
    _excerptOnly = excerptOnly;
    _usingFallbackLocal = false;
    _hasLoadedAudio = false;
    _activeUtteranceId = null;
    _activePlaybackId = null;
    final prevAudio = _activeAudioPath;
    _activeAudioPath = null;
    await _platform.stopTts();
    await _platform.stopAudio();
    _disposeEphemeralPath(prevAudio);
    if (_disposed) return false;
    return _playIndex(0, token);
  }

  Future<void> pause() async {
    if (_disposed ||
        (_status != TtsPlaybackStatus.playing &&
            _status != TtsPlaybackStatus.loading)) {
      return;
    }
    final wasLoading = _status == TtsPlaybackStatus.loading;
    _status = TtsPlaybackStatus.paused;
    if (wasLoading) {
      _sessionToken++;
      _activePlaybackId = null;
      _hasLoadedAudio = false;
      _clearPrefetchFutures();
    } else if (_useOnline) {
      await _platform.pauseAudio();
    } else {
      _activeUtteranceId = null;
      await _platform.stopTts();
    }
    _safeNotify();
  }

  Future<void> resume() async {
    if (_disposed || _status != TtsPlaybackStatus.paused || _chunks.isEmpty) {
      return;
    }
    if (_useOnline && _hasLoadedAudio) {
      _status = TtsPlaybackStatus.playing;
      await _platform.resumeAudio();
      _safeNotify();
    } else {
      await _playIndex(_chunkIndex, _sessionToken);
    }
  }

  Future<void> nextSentence() async {
    if (_disposed || !isActive || _chunks.isEmpty) return;
    if (_chunkIndex + 1 < _chunks.length) {
      await _playIndex(_chunkIndex + 1, _sessionToken);
    } else if (!_excerptOnly) {
      onPageCompleted?.call();
    }
  }

  Future<void> prevSentence() async {
    if (_disposed || !isActive || _chunks.isEmpty) return;
    final target = (_chunkIndex - 1).clamp(0, _chunks.length - 1);
    await _playIndex(target, _sessionToken);
  }

  Future<void> updateRate(double nextRate) async {
    if (_disposed) return;
    _readerSettings = _readerSettings.copyWith(ttsRate: nextRate);
    if (_status == TtsPlaybackStatus.playing) {
      if (_useOnline) {
        // Online clips are always synthesized at 1.0x and sped up in MediaPlayer,
        // so both active playback and 1.0x prefetched chunks stay valid.
        await _platform.setAudioSpeed(nextRate);
      } else {
        await _playIndex(_chunkIndex, _sessionToken);
      }
    }
    _safeNotify();
  }

  Future<void> stop() async {
    _sessionToken++;
    _clearPrefetchFutures();
    _sleepTicker?.cancel();
    _sleepTicker = null;
    _sleepEndAt = null;
    _activeUtteranceId = null;
    _activePlaybackId = null;
    final prevAudio = _activeAudioPath;
    _activeAudioPath = null;
    _chunks = const [];
    _chunkIndex = 0;
    _excerptOnly = false;
    _usingFallbackLocal = false;
    _hasLoadedAudio = false;
    _status = TtsPlaybackStatus.idle;
    await _platform.stopTts();
    await _platform.stopAudio();
    _disposeEphemeralPath(prevAudio);
    _safeNotify();
  }

  bool get _useOnline =>
      _ttsConfig.mode == TtsEngineMode.online && !_usingFallbackLocal;

  Future<bool> _playIndex(int idx, int token) async {
    if (_disposed ||
        token != _sessionToken ||
        idx < 0 ||
        idx >= _chunks.length) {
      return false;
    }
    _chunkIndex = idx;
    _hasLoadedAudio = false;
    final chunk = _chunks[idx];

    if (_useOnline) {
      _status = TtsPlaybackStatus.loading;
      _safeNotify();
      for (var offset = 1; offset <= _ttsConfig.prefetchCount; offset++) {
        _schedulePrefetch(idx + offset, token);
      }

      File? audioFile;
      OnlineTtsException? failure;
      for (var attempt = 0; attempt < 2; attempt++) {
        try {
          final prefetched = _prefetchFutures.remove(idx);
          if (prefetched != null) {
            final res = await prefetched;
            if (res.error != null) throw res.error!;
            audioFile = res.file;
          } else {
            audioFile = await _synthesizeOnline(chunk.text);
          }
          if (_disposed || token != _sessionToken) return false;
          failure = null;
          break;
        } on OnlineTtsException catch (e) {
          failure = e;
          // Auth/403 won't heal in 100ms retry
          if (e.code == 'ERR_HTTP_401' ||
              e.code == 'ERR_HTTP_403' ||
              e.code == 'ERR_EDGE_403') {
            break;
          }
        } catch (e) {
          failure = OnlineTtsException('ERR_UNKNOWN', '$e');
        }
      }

      if (_disposed || token != _sessionToken) return false;

      if (audioFile != null) {
        final pid = 'audio_${token}_$idx';
        final prevAudio = _activeAudioPath;
        _activePlaybackId = pid;
        _activeUtteranceId = null;
        _activeAudioPath = audioFile.path;
        _status = TtsPlaybackStatus.playing;
        _safeNotify();
        final started = await _platform.playAudioFile(
          audioFile.path,
          speed: _readerSettings.ttsRate,
          playbackId: pid,
        );
        if (prevAudio != null && prevAudio != audioFile.path) {
          _disposeEphemeralPath(prevAudio);
        }
        if (_disposed) {
          if (_activeAudioPath == audioFile.path) _activeAudioPath = null;
          _disposeEphemeralPath(audioFile.path);
          return false;
        }
        if (started && token == _sessionToken) {
          _hasLoadedAudio = true;
          return true;
        }
        if (_activeAudioPath == audioFile.path) _activeAudioPath = null;
        _disposeEphemeralPath(audioFile.path);
        failure = const OnlineTtsException('ERR_TTS_SPEAK_FAILED');
      }

      if (_ttsConfig.fallbackToLocalTts) {
        _usingFallbackLocal = true;
        onFallbackNotice?.call(failure?.code ?? 'ERR_UNKNOWN');
      } else {
        _hasLoadedAudio = false;
        _status = TtsPlaybackStatus.paused;
        onErrorNotice?.call(failure?.code ?? 'ERR_UNKNOWN');
        _safeNotify();
        return false;
      }
    }

    // Local system TTS path (default or fallback)
    if (_disposed || token != _sessionToken) return false;
    _status = TtsPlaybackStatus.playing;
    _activePlaybackId = null;
    _safeNotify();
    try {
      final uid = await _platform.speakText(
        chunk.text,
        rate: _readerSettings.ttsRate,
        pitch: _readerSettings.ttsPitch,
        language: _readerSettings.ttsLanguage,
        engine:
            _readerSettings.ttsEngine.isEmpty ? null : _readerSettings.ttsEngine,
        voiceName:
            _readerSettings.ttsVoice.isEmpty ? null : _readerSettings.ttsVoice,
      );
      if (_disposed || token != _sessionToken) return false;
      if (uid == null) {
        await stop();
        return false;
      }
      _activeUtteranceId = uid;
      return true;
    } catch (_) {
      if (!_disposed && token == _sessionToken) {
        await stop();
      }
      return false;
    }
  }

  void _schedulePrefetch(int idx, int token) {
    if (token != _sessionToken || idx < 0 || idx >= _chunks.length) return;
    if (_prefetchFutures.containsKey(idx)) return;
    _prefetchFutures[idx] = _synthesizeOnline(_chunks[idx].text)
        .then<({File? file, Object? error})>(
      (f) => (file: f, error: null),
      onError: (Object err) => (file: null, error: err),
    );
  }

  Future<File> _synthesizeOnline(String text) {
    final profile = _ttsConfig.activeProfile;
    final secret = _ttsConfig.secretFor(profile.id);
    // Synthesize at 1.0x and apply ttsRate once in MediaPlayer playback.
    return _onlineClient.synthesizeToFile(
      profile: profile,
      text: text,
      rate: 1.0,
      pitch: _readerSettings.ttsPitch,
      apiKey: secret,
      enableCache: _ttsConfig.cacheEnabled,
      maxCacheBytes: _ttsConfig.cacheMaxMb * 1024 * 1024,
    );
  }

  void _handlePlatformEvent(PlatformEvent ev) {
    if (_disposed || _status != TtsPlaybackStatus.playing) return;

    if (ev.type == 'tts_done' || ev.type == 'tts_error') {
      final evUid = (ev.payload['utteranceId'] as String? ?? '').trim();
      if (_activeUtteranceId != null &&
          evUid.isNotEmpty &&
          evUid != _activeUtteranceId) {
        return;
      }
      if (ev.type == 'tts_error') {
        stop();
        onErrorNotice?.call('ERR_TTS_SPEAK_FAILED');
        return;
      }
      _advanceAfterChunk();
    } else if (ev.type == 'audio_done' || ev.type == 'audio_error') {
      final pid = (ev.payload['playbackId'] as String? ?? '').trim();
      if (_activePlaybackId != null && pid.isNotEmpty && pid != _activePlaybackId) {
        return;
      }
      _hasLoadedAudio = false;
      final finishedPath = _activeAudioPath;
      _activeAudioPath = null;
      _disposeEphemeralPath(finishedPath);
      if (ev.type == 'audio_error') {
        if (_ttsConfig.fallbackToLocalTts) {
          _usingFallbackLocal = true;
          onFallbackNotice?.call('ERR_TTS_SPEAK_FAILED');
          _playIndex(_chunkIndex, _sessionToken);
        } else {
          _status = TtsPlaybackStatus.paused;
          onErrorNotice?.call('ERR_TTS_SPEAK_FAILED');
          _safeNotify();
        }
        return;
      }
      _advanceAfterChunk();
    }
  }

  void _advanceAfterChunk() {
    if (_disposed) return;
    if (_excerptOnly) {
      stop();
      return;
    }
    if (_chunkIndex + 1 < _chunks.length) {
      _playIndex(_chunkIndex + 1, _sessionToken);
    } else {
      onPageCompleted?.call();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _sessionToken++;
    _clearPrefetchFutures();
    _sleepTicker?.cancel();
    _eventSub?.cancel();
    _platform.stopTts();
    _platform.stopAudio();
    _disposeEphemeralPath(_activeAudioPath);
    _activeAudioPath = null;
    super.dispose();
  }
}
