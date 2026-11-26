import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/inkbox_theme.dart';

enum PageTurnMode {
  simulation('仿真'),
  cover('覆盖'),
  slide('滑动'),
  scroll('滚动');

  const PageTurnMode(this.label);
  final String label;
}

enum BookPageLayoutMode {
  auto,
  single,
  dual,
}

enum TapZoneAction {
  prevPage('上一页'),
  nextPage('下一页'),
  toggleMenu('菜单'),
  bookmark('书签'),
  tts('听书');

  const TapZoneAction(this.label);
  final String label;
}

enum TapZonePreset {
  standard('常规左右'),
  leftHand('左手单手'),
  rightHand('右手单手'),
  custom('自定义九宫格');

  const TapZonePreset(this.label);
  final String label;
}

@immutable
class ReplaceRuleConfig {
  const ReplaceRuleConfig({
    required this.name,
    required this.pattern,
    this.replacement = '',
    this.isRegex = false,
    this.enabled = true,
  });

  final String name;
  final String pattern;
  final String replacement;
  final bool isRegex;
  final bool enabled;

  Map<String, dynamic> toRustMap() => {
        'pattern': pattern,
        'replacement': replacement,
        'is_regex': isRegex,
        'enabled': enabled,
      };

  Map<String, dynamic> toJson() => {
        'name': name,
        'pattern': pattern,
        'replacement': replacement,
        'is_regex': isRegex,
        'enabled': enabled,
      };

  factory ReplaceRuleConfig.fromJson(Map<String, dynamic> json) {
    return ReplaceRuleConfig(
      name: json['name'] as String? ?? '净化规则',
      pattern: json['pattern'] as String? ?? '',
      replacement: json['replacement'] as String? ?? '',
      isRegex: json['is_regex'] as bool? ?? false,
      enabled: json['enabled'] as bool? ?? true,
    );
  }
}

@immutable
class BookReaderSettings {
  const BookReaderSettings({
    this.fontSize = 18.0,
    this.lineHeight = 1.75,
    this.paragraphSpacing = 12.0,
    this.horizontalPadding = 22.0,
    this.indentFirstLine = true,
    this.paperTheme = BookPaperTheme.white,
    this.pageTurnMode = PageTurnMode.simulation,
    this.pageLayoutMode = BookPageLayoutMode.auto,
    this.tapZonePreset = TapZonePreset.standard,
    this.customTapGrid = defaultStandardGrid,
    this.volumeKeyPaging = true,
    this.keepScreenOn = true,
    this.edgeBrightnessGesture = true,
    this.chineseConversion = 'None', // None | ToSimplified | ToTraditional
    this.ttsRate = 1.0,
    this.ttsPitch = 1.0,
    this.ttsLanguage = 'zh-CN',
    this.ttsEngine = '',
    this.ttsVoice = '',
    this.ttsAutoTurnPage = true,
    this.ttsSleepTimerMinutes = 0,
    this.autoScrollSpeed = 48.0,
    this.pdfReflowMode = false,
    this.replaceRules = const [],
  });

  static const List<TapZoneAction> defaultStandardGrid = [
    TapZoneAction.prevPage, TapZoneAction.prevPage, TapZoneAction.nextPage,
    TapZoneAction.prevPage, TapZoneAction.toggleMenu, TapZoneAction.nextPage,
    TapZoneAction.prevPage, TapZoneAction.nextPage, TapZoneAction.nextPage,
  ];

  static const List<TapZoneAction> leftHandGrid = [
    TapZoneAction.nextPage, TapZoneAction.prevPage, TapZoneAction.prevPage,
    TapZoneAction.nextPage, TapZoneAction.toggleMenu, TapZoneAction.prevPage,
    TapZoneAction.nextPage, TapZoneAction.nextPage, TapZoneAction.prevPage,
  ];

  static const List<TapZoneAction> rightHandGrid = [
    TapZoneAction.prevPage, TapZoneAction.nextPage, TapZoneAction.nextPage,
    TapZoneAction.prevPage, TapZoneAction.toggleMenu, TapZoneAction.nextPage,
    TapZoneAction.nextPage, TapZoneAction.nextPage, TapZoneAction.nextPage,
  ];

  final double fontSize;
  final double lineHeight;
  final double paragraphSpacing;
  final double horizontalPadding;
  final bool indentFirstLine;
  final BookPaperTheme paperTheme;
  final PageTurnMode pageTurnMode;
  final BookPageLayoutMode pageLayoutMode;
  final TapZonePreset tapZonePreset;
  final List<TapZoneAction> customTapGrid;
  final bool volumeKeyPaging;
  final bool keepScreenOn;
  final bool edgeBrightnessGesture;
  final String chineseConversion;
  final double ttsRate;
  final double ttsPitch;
  final String ttsLanguage;
  final String ttsEngine;
  final String ttsVoice;
  final bool ttsAutoTurnPage;
  final int ttsSleepTimerMinutes;
  final double autoScrollSpeed;
  final bool pdfReflowMode;
  final List<ReplaceRuleConfig> replaceRules;

  List<TapZoneAction> get effectiveTapGrid {
    switch (tapZonePreset) {
      case TapZonePreset.standard:
        return defaultStandardGrid;
      case TapZonePreset.leftHand:
        return leftHandGrid;
      case TapZonePreset.rightHand:
        return rightHandGrid;
      case TapZonePreset.custom:
        return customTapGrid.length == 9 ? customTapGrid : defaultStandardGrid;
    }
  }

  /// Resolves a normalized tap position (nx, ny in [0, 1]) via the 3x3 grid.
  TapZoneAction resolveTapAction(double nx, double ny) {
    final col = (nx * 3).floor().clamp(0, 2);
    final row = (ny * 3).floor().clamp(0, 2);
    return effectiveTapGrid[row * 3 + col];
  }

  BookReaderSettings copyWith({
    double? fontSize,
    double? lineHeight,
    double? paragraphSpacing,
    double? horizontalPadding,
    bool? indentFirstLine,
    BookPaperTheme? paperTheme,
    PageTurnMode? pageTurnMode,
    BookPageLayoutMode? pageLayoutMode,
    TapZonePreset? tapZonePreset,
    List<TapZoneAction>? customTapGrid,
    bool? volumeKeyPaging,
    bool? keepScreenOn,
    bool? edgeBrightnessGesture,
    String? chineseConversion,
    double? ttsRate,
    double? ttsPitch,
    String? ttsLanguage,
    String? ttsEngine,
    String? ttsVoice,
    bool? ttsAutoTurnPage,
    int? ttsSleepTimerMinutes,
    double? autoScrollSpeed,
    bool? pdfReflowMode,
    List<ReplaceRuleConfig>? replaceRules,
  }) {
    return BookReaderSettings(
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      paragraphSpacing: paragraphSpacing ?? this.paragraphSpacing,
      horizontalPadding: horizontalPadding ?? this.horizontalPadding,
      indentFirstLine: indentFirstLine ?? this.indentFirstLine,
      paperTheme: paperTheme ?? this.paperTheme,
      pageTurnMode: pageTurnMode ?? this.pageTurnMode,
      pageLayoutMode: pageLayoutMode ?? this.pageLayoutMode,
      tapZonePreset: tapZonePreset ?? this.tapZonePreset,
      customTapGrid: customTapGrid ?? this.customTapGrid,
      volumeKeyPaging: volumeKeyPaging ?? this.volumeKeyPaging,
      keepScreenOn: keepScreenOn ?? this.keepScreenOn,
      edgeBrightnessGesture:
          edgeBrightnessGesture ?? this.edgeBrightnessGesture,
      chineseConversion: chineseConversion ?? this.chineseConversion,
      ttsRate: ttsRate ?? this.ttsRate,
      ttsPitch: ttsPitch ?? this.ttsPitch,
      ttsLanguage: ttsLanguage ?? this.ttsLanguage,
      ttsEngine: ttsEngine ?? this.ttsEngine,
      ttsVoice: ttsVoice ?? this.ttsVoice,
      ttsAutoTurnPage: ttsAutoTurnPage ?? this.ttsAutoTurnPage,
      ttsSleepTimerMinutes: ttsSleepTimerMinutes ?? this.ttsSleepTimerMinutes,
      autoScrollSpeed: autoScrollSpeed ?? this.autoScrollSpeed,
      pdfReflowMode: pdfReflowMode ?? this.pdfReflowMode,
      replaceRules: replaceRules ?? this.replaceRules,
    );
  }

  Map<String, dynamic> toJson() => {
        'fontSize': fontSize,
        'lineHeight': lineHeight,
        'paragraphSpacing': paragraphSpacing,
        'horizontalPadding': horizontalPadding,
        'indentFirstLine': indentFirstLine,
        'paperTheme': paperTheme.index,
        'pageTurnMode': pageTurnMode.index,
        'pageLayoutMode': pageLayoutMode.index,
        'tapZonePreset': tapZonePreset.index,
        'customTapGrid': customTapGrid.map((a) => a.index).toList(),
        'volumeKeyPaging': volumeKeyPaging,
        'keepScreenOn': keepScreenOn,
        'edgeBrightnessGesture': edgeBrightnessGesture,
        'chineseConversion': chineseConversion,
        'ttsRate': ttsRate,
        'ttsPitch': ttsPitch,
        'ttsLanguage': ttsLanguage,
        'ttsEngine': ttsEngine,
        'ttsVoice': ttsVoice,
        'ttsAutoTurnPage': ttsAutoTurnPage,
        'ttsSleepTimerMinutes': ttsSleepTimerMinutes,
        'autoScrollSpeed': autoScrollSpeed,
        'pdfReflowMode': pdfReflowMode,
        'replaceRules': replaceRules.map((r) => r.toJson()).toList(),
      };

  factory BookReaderSettings.fromJson(Map<String, dynamic> json) {
    final pIdx = (json['paperTheme'] as num?)?.toInt() ?? 0;
    final mIdx = (json['pageTurnMode'] as num?)?.toInt() ?? 0;
    final lIdx = (json['pageLayoutMode'] as num?)?.toInt() ?? 0;
    final tIdx = (json['tapZonePreset'] as num?)?.toInt() ?? 0;
    final rawGrid = (json['customTapGrid'] as List<dynamic>?)
        ?.map((i) => TapZoneAction
            .values[(i as num).toInt().clamp(0, TapZoneAction.values.length - 1)])
        .toList();
    final rawRules = (json['replaceRules'] as List<dynamic>?)
        ?.map((e) => ReplaceRuleConfig.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    return BookReaderSettings(
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 18.0,
      lineHeight: (json['lineHeight'] as num?)?.toDouble() ?? 1.75,
      paragraphSpacing:
          (json['paragraphSpacing'] as num?)?.toDouble() ?? 12.0,
      horizontalPadding:
          (json['horizontalPadding'] as num?)?.toDouble() ?? 22.0,
      indentFirstLine: json['indentFirstLine'] as bool? ?? true,
      paperTheme: BookPaperTheme
          .values[pIdx.clamp(0, BookPaperTheme.values.length - 1)],
      pageTurnMode:
          PageTurnMode.values[mIdx.clamp(0, PageTurnMode.values.length - 1)],
      pageLayoutMode: BookPageLayoutMode
          .values[lIdx.clamp(0, BookPageLayoutMode.values.length - 1)],
      tapZonePreset: TapZonePreset
          .values[tIdx.clamp(0, TapZonePreset.values.length - 1)],
      customTapGrid:
          rawGrid != null && rawGrid.length == 9 ? rawGrid : defaultStandardGrid,
      volumeKeyPaging: json['volumeKeyPaging'] as bool? ?? true,
      keepScreenOn: json['keepScreenOn'] as bool? ?? true,
      edgeBrightnessGesture: json['edgeBrightnessGesture'] as bool? ?? true,
      chineseConversion: json['chineseConversion'] as String? ?? 'None',
      ttsRate: (json['ttsRate'] as num?)?.toDouble() ?? 1.0,
      ttsPitch: (json['ttsPitch'] as num?)?.toDouble() ?? 1.0,
      ttsLanguage: json['ttsLanguage'] as String? ?? 'zh-CN',
      ttsEngine: json['ttsEngine'] as String? ?? '',
      ttsVoice: json['ttsVoice'] as String? ?? '',
      ttsAutoTurnPage: json['ttsAutoTurnPage'] as bool? ?? true,
      ttsSleepTimerMinutes:
          (json['ttsSleepTimerMinutes'] as num?)?.toInt() ?? 0,
      autoScrollSpeed: (json['autoScrollSpeed'] as num?)?.toDouble() ?? 48.0,
      pdfReflowMode: json['pdfReflowMode'] as bool? ?? false,
      replaceRules: rawRules ?? const [],
    );
  }
}

class BookReaderSettingsController extends Notifier<BookReaderSettings> {
  static const _kKey = 'inkbox_book_reader_settings_v1';

  @override
  BookReaderSettings build() {
    _hydrate();
    return const BookReaderSettings();
  }

  Future<void> _hydrate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kKey);
      if (raw != null && raw.isNotEmpty) {
        state = BookReaderSettings.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
      }
    } catch (_) {}
  }

  Future<void> update(
    BookReaderSettings Function(BookReaderSettings current) mutator,
  ) async {
    state = mutator(state);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kKey, jsonEncode(state.toJson()));
    } catch (_) {}
  }

  Future<void> applySnapshotJson(Map<String, dynamic> json) async {
    state = BookReaderSettings.fromJson(json);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kKey, jsonEncode(state.toJson()));
    } catch (_) {}
  }
}

final bookReaderSettingsProvider =
    NotifierProvider<BookReaderSettingsController, BookReaderSettings>(
  BookReaderSettingsController.new,
);
