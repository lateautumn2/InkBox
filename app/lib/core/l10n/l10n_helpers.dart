import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/db/app_database.dart';
import '../../features/book_reader/book_reader_settings.dart';
import '../../features/manga_reader/manga_reader_settings.dart';
import '../../features/tts/tts_models.dart';
import '../../l10n/app_localizations.dart';
import '../theme/inkbox_theme.dart';

extension BuildContextL10n on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// Complete delegate list compatible with Flutter 3.50 modular `material_ui`,
/// `cupertino_ui`, and generated [AppLocalizations].
const List<LocalizationsDelegate<dynamic>> kInkBoxLocalizationsDelegates =
    <LocalizationsDelegate<dynamic>>[
  AppLocalizations.delegate,
  ...GlobalMaterialLocalizations.delegates,
];

enum ShelfFilterGroup {
  all,
  reading,
  finished;

  String labelOf(AppLocalizations l10n) => switch (this) {
        ShelfFilterGroup.all => l10n.shelfGroupAll,
        ShelfFilterGroup.reading => l10n.shelfGroupReading,
        ShelfFilterGroup.finished => l10n.shelfGroupFinished,
      };
}

bool isBookFinished(Book b) =>
    b.progressRatio >= 0.99 ||
    b.shelfGroup == '已读完' ||
    b.shelfGroup == 'finished';

bool isMangaFinished(Manga m) =>
    (m.totalChapters > 0 && m.unreadCount == 0) ||
    m.shelfGroup == '已读完' ||
    m.shelfGroup == 'finished';

String localizedShelfName(
  AppLocalizations l10n,
  Shelf? shelf, {
  required bool isComic,
}) {
  if (shelf == null) {
    return isComic ? l10n.defaultMangaShelf : l10n.defaultBookshelf;
  }
  if (shelf.isDefault &&
      (shelf.name == kDefaultBookShelfName ||
          shelf.name == kDefaultMangaShelfName)) {
    return isComic ? l10n.defaultMangaShelf : l10n.defaultBookshelf;
  }
  return shelf.name;
}

String localizedAuthor(AppLocalizations l10n, String rawAuthor) {
  final t = rawAuthor.trim();
  if (t.isEmpty || t == '未知作者' || t == 'Unknown Author' || t == '著者不明') {
    return l10n.unknownAuthor;
  }
  return t;
}

String localizedChapterTitle(AppLocalizations l10n, String rawTitle) {
  final t = rawTitle.trim();
  if (t.isEmpty || t == '准备阅读') return l10n.readyToRead;
  return t;
}

String localizedTtsLanguage(AppLocalizations l10n, String code) {
  return switch (code) {
    'zh-CN' => l10n.ttsLangZhCn,
    'zh-TW' => l10n.ttsLangZhTw,
    'zh-HK' => l10n.ttsLangZhHk,
    'en-US' => l10n.ttsLangEnUs,
    'ja-JP' => l10n.ttsLangJaJp,
    'system' => l10n.ttsLangSystem,
    _ => code,
  };
}

String ttsPreviewSampleText(String ttsLanguageCode, String appLocaleCode) {
  final effective = ttsLanguageCode == 'system' ? appLocaleCode : ttsLanguageCode;
  if (effective.startsWith('en')) {
    return 'InkBox Reader, previewing your current voice and speed settings.';
  }
  if (effective.startsWith('ja')) {
    return 'InkBoxリーダーです。現在の音声と読み上げ速度を試聴しています。';
  }
  return '墨匣阅读器，正在为您试听当前语音朗读效果。';
}

String localizeError(AppLocalizations l10n, Object error) {
  final raw = error is PlatformException
      ? '${error.code} ${error.message ?? ""}'
      : '$error';
  if (raw.contains('ERR_FILE_NOT_FOUND')) return l10n.errFileNotFound;
  if (raw.contains('ERR_FILE_EMPTY')) return l10n.errFileEmpty;
  if (raw.contains('ERR_STREAM_OPEN')) return l10n.errStreamOpen;
  if (raw.contains('ERR_WORK_DIRECTORY')) return l10n.errWorkDirectory;
  if (raw.contains('ERR_UNSUPPORTED_TYPE')) return l10n.errUnsupportedType;
  if (raw.contains('ERR_TTS_UNAVAILABLE') ||
      raw.contains('ERR_TTS_NOT_READY')) {
    return l10n.errTtsUnavailable;
  }
  if (raw.contains('ERR_TTS_TIMEOUT')) return l10n.errTtsTimeout;
  if (raw.contains('ERR_TTS_SPEAK_FAILED')) return l10n.errTtsSpeakFailed;
  if (raw.contains('ERR_EDGE_403')) return l10n.errEdge403;
  if (raw.contains('ERR_NETWORK_TIMEOUT')) return l10n.errNetworkTimeout;
  if (raw.contains('ERR_HTTP_401')) return l10n.errHttp401;
  if (raw.contains('ERR_HTTP_403')) return l10n.errHttp403;
  if (raw.contains('ERR_HTTP_STATUS')) return l10n.errHttpStatus;
  if (raw.contains('ERR_INVALID_AUDIO')) return l10n.errInvalidAudio;
  return raw.trim().isEmpty ? l10n.errUnknown : raw;
}

extension BookPaperThemeL10n on BookPaperTheme {
  String labelOf(AppLocalizations l10n) => switch (this) {
        BookPaperTheme.white => l10n.paperWhite,
        BookPaperTheme.parchment => l10n.paperIvory,
        BookPaperTheme.sage => l10n.paperSage,
        BookPaperTheme.dark => l10n.paperDark,
        BookPaperTheme.oled => l10n.paperOled,
        BookPaperTheme.inkWash => l10n.themeInkWash,
      };
}

extension PageTurnModeL10n on PageTurnMode {
  String labelOf(AppLocalizations l10n) => switch (this) {
        PageTurnMode.simulation => l10n.turnSimulation,
        PageTurnMode.cover => l10n.turnCover,
        PageTurnMode.slide => l10n.turnSlide,
        PageTurnMode.scroll => l10n.turnScroll,
      };
}

extension BookPageLayoutModeL10n on BookPageLayoutMode {
  String labelOf(AppLocalizations l10n) => switch (this) {
        BookPageLayoutMode.auto => l10n.layoutAuto,
        BookPageLayoutMode.single => l10n.layoutSingle,
        BookPageLayoutMode.dual => l10n.layoutDual,
      };
}

extension TapZonePresetL10n on TapZonePreset {
  String labelOf(AppLocalizations l10n) => switch (this) {
        TapZonePreset.standard => l10n.tapZoneStandard,
        TapZonePreset.leftHand => l10n.tapZoneLeftHand,
        TapZonePreset.rightHand => l10n.tapZoneRightHand,
        TapZonePreset.custom => l10n.tapZoneCustom,
      };
}

extension MangaReadingModeL10n on MangaReadingMode {
  String labelOf(AppLocalizations l10n) => switch (this) {
        MangaReadingMode.rtl => l10n.mangaReadingModeRtl,
        MangaReadingMode.ltr => l10n.mangaReadingModeLtr,
        MangaReadingMode.webtoon => l10n.mangaReadingModeWebtoon,
        MangaReadingMode.dual => l10n.mangaReadingModeDual,
      };
}

extension MangaScaleTypeL10n on MangaScaleType {
  String labelOf(AppLocalizations l10n) => switch (this) {
        MangaScaleType.fitScreen => l10n.mangaScaleFitScreen,
        MangaScaleType.fitWidth => l10n.mangaScaleFitWidth,
        MangaScaleType.fitHeight => l10n.mangaScaleFitHeight,
        MangaScaleType.original => l10n.mangaScaleOriginal,
      };
}

extension MangaTapLayoutL10n on MangaTapLayout {
  String labelOf(AppLocalizations l10n) => switch (this) {
        MangaTapLayout.lShaped => l10n.mangaTapLShaped,
        MangaTapLayout.edge => l10n.mangaTapEdge,
        MangaTapLayout.kindle => l10n.mangaTapKindle,
        MangaTapLayout.disabled => l10n.mangaTapDisabled,
      };
}

extension TapZoneActionL10n on TapZoneAction {
  String labelOf(AppLocalizations l10n) => switch (this) {
        TapZoneAction.prevPage => l10n.tapActionPrev,
        TapZoneAction.nextPage => l10n.tapActionNext,
        TapZoneAction.toggleMenu => l10n.tapActionMenu,
        TapZoneAction.bookmark => l10n.tapActionBookmark,
        TapZoneAction.tts => l10n.tapActionTts,
      };
}

extension OnlineTtsProviderKindL10n on OnlineTtsProviderKind {
  String labelOf(AppLocalizations l10n) => switch (this) {
        OnlineTtsProviderKind.edgeTts => l10n.ttsProviderEdge,
        OnlineTtsProviderKind.azureSpeech => l10n.ttsProviderAzure,
        OnlineTtsProviderKind.openAiCompatible => l10n.ttsProviderOpenAi,
        OnlineTtsProviderKind.customHttp => l10n.ttsProviderCustomHttp,
      };
}
