import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum MangaReadingMode {
  rtl('rtl', '从右到左'),
  ltr('ltr', '从左到右'),
  webtoon('webtoon', '条漫滚动'),
  dual('dual', '双页拼接');

  const MangaReadingMode(this.code, this.label);
  final String code;
  final String label;

  static MangaReadingMode fromCode(String code) {
    return MangaReadingMode.values.firstWhere(
      (e) => e.code == code,
      orElse: () => MangaReadingMode.rtl,
    );
  }
}

enum MangaScaleType {
  fitScreen('适应屏幕'),
  fitWidth('适应宽度'),
  fitHeight('适应高度'),
  original('原始尺寸');

  const MangaScaleType(this.label);
  final String label;
}

enum MangaTapLayout {
  lShaped('L型单手'),
  edge('左右边缘'),
  kindle('Kindle'),
  disabled('仅滑动');

  const MangaTapLayout(this.label);
  final String label;
}

enum MangaCanvasBg {
  pureBlack('纯黑', Color(0xFF0B0C0E)),
  darkGrey('深灰', Color(0xFF202227)),
  warmPaper('暖纸', Color(0xFFF3EFE8)),
  pureWhite('纯白', Color(0xFFFFFFFF));

  const MangaCanvasBg(this.label, this.color);
  final String label;
  final Color color;
}

@immutable
class MangaReaderSettings {
  const MangaReaderSettings({
    this.scaleType = MangaScaleType.fitScreen,
    this.tapLayout = MangaTapLayout.lShaped,
    this.canvasBg = MangaCanvasBg.pureBlack,
    this.autoCrop = true,
    this.splitWidePages = true,
    this.warmFilter = false,
    this.grayscaleFilter = false,
    this.dimmerOpacity = 0.0,
    this.webtoonSidePaddingPct = 0.0,
    this.volumeKeyPaging = true,
    this.keepScreenOn = true,
    this.showPageBadge = true,
  });

  final MangaScaleType scaleType;
  final MangaTapLayout tapLayout;
  final MangaCanvasBg canvasBg;
  final bool autoCrop;
  final bool splitWidePages;
  final bool warmFilter;
  final bool grayscaleFilter;
  final double dimmerOpacity; // 0.0 .. 0.65
  final double webtoonSidePaddingPct; // 0.0 .. 0.2
  final bool volumeKeyPaging;
  final bool keepScreenOn;
  final bool showPageBadge;

  /// Resolves tap at normalized (nx, ny) to -1 (prev), 0 (toggle menu), or +1 (next).
  int resolveTapDelta(double nx, double ny, {required bool isRtl}) {
    if (tapLayout == MangaTapLayout.disabled) return 0;

    // Center zone always toggles menu.
    if (nx > 0.30 && nx < 0.70 && ny > 0.28 && ny < 0.72) {
      return 0;
    }

    int rawDir; // -1 = left side / prev in LTR, +1 = right side / next in LTR
    switch (tapLayout) {
      case MangaTapLayout.lShaped:
        if (ny < 0.28) {
          rawDir = -1; // Top strip -> prev
        } else if (ny > 0.72) {
          rawDir = 1; // Bottom strip -> next
        } else {
          rawDir = nx < 0.5 ? -1 : 1;
        }
      case MangaTapLayout.edge:
        rawDir = nx < 0.5 ? -1 : 1;
      case MangaTapLayout.kindle:
        rawDir = nx < 0.28 ? -1 : 1;
      case MangaTapLayout.disabled:
        return 0;
    }

    return isRtl ? -rawDir : rawDir;
  }

  MangaReaderSettings copyWith({
    MangaScaleType? scaleType,
    MangaTapLayout? tapLayout,
    MangaCanvasBg? canvasBg,
    bool? autoCrop,
    bool? splitWidePages,
    bool? warmFilter,
    bool? grayscaleFilter,
    double? dimmerOpacity,
    double? webtoonSidePaddingPct,
    bool? volumeKeyPaging,
    bool? keepScreenOn,
    bool? showPageBadge,
  }) {
    return MangaReaderSettings(
      scaleType: scaleType ?? this.scaleType,
      tapLayout: tapLayout ?? this.tapLayout,
      canvasBg: canvasBg ?? this.canvasBg,
      autoCrop: autoCrop ?? this.autoCrop,
      splitWidePages: splitWidePages ?? this.splitWidePages,
      warmFilter: warmFilter ?? this.warmFilter,
      grayscaleFilter: grayscaleFilter ?? this.grayscaleFilter,
      dimmerOpacity: dimmerOpacity ?? this.dimmerOpacity,
      webtoonSidePaddingPct:
          webtoonSidePaddingPct ?? this.webtoonSidePaddingPct,
      volumeKeyPaging: volumeKeyPaging ?? this.volumeKeyPaging,
      keepScreenOn: keepScreenOn ?? this.keepScreenOn,
      showPageBadge: showPageBadge ?? this.showPageBadge,
    );
  }

  Map<String, dynamic> toJson() => {
        'scaleType': scaleType.index,
        'tapLayout': tapLayout.index,
        'canvasBg': canvasBg.index,
        'autoCrop': autoCrop,
        'splitWidePages': splitWidePages,
        'warmFilter': warmFilter,
        'grayscaleFilter': grayscaleFilter,
        'dimmerOpacity': dimmerOpacity,
        'webtoonSidePaddingPct': webtoonSidePaddingPct,
        'volumeKeyPaging': volumeKeyPaging,
        'keepScreenOn': keepScreenOn,
        'showPageBadge': showPageBadge,
      };

  factory MangaReaderSettings.fromJson(Map<String, dynamic> json) {
    final sIdx = (json['scaleType'] as num?)?.toInt() ?? 0;
    final tIdx = (json['tapLayout'] as num?)?.toInt() ?? 0;
    final bIdx = (json['canvasBg'] as num?)?.toInt() ?? 0;
    return MangaReaderSettings(
      scaleType:
          MangaScaleType.values[sIdx.clamp(0, MangaScaleType.values.length - 1)],
      tapLayout:
          MangaTapLayout.values[tIdx.clamp(0, MangaTapLayout.values.length - 1)],
      canvasBg:
          MangaCanvasBg.values[bIdx.clamp(0, MangaCanvasBg.values.length - 1)],
      autoCrop: json['autoCrop'] as bool? ?? true,
      splitWidePages: json['splitWidePages'] as bool? ?? true,
      warmFilter: json['warmFilter'] as bool? ?? false,
      grayscaleFilter: json['grayscaleFilter'] as bool? ?? false,
      dimmerOpacity: (json['dimmerOpacity'] as num?)?.toDouble() ?? 0.0,
      webtoonSidePaddingPct:
          (json['webtoonSidePaddingPct'] as num?)?.toDouble() ?? 0.0,
      volumeKeyPaging: json['volumeKeyPaging'] as bool? ?? true,
      keepScreenOn: json['keepScreenOn'] as bool? ?? true,
      showPageBadge: json['showPageBadge'] as bool? ?? true,
    );
  }
}

class MangaReaderSettingsController extends Notifier<MangaReaderSettings> {
  static const _kKey = 'inkbox_manga_reader_settings_v1';

  @override
  MangaReaderSettings build() {
    _hydrate();
    return const MangaReaderSettings();
  }

  Future<void> _hydrate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kKey);
      if (raw != null && raw.isNotEmpty) {
        state = MangaReaderSettings.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
      }
    } catch (_) {}
  }

  Future<void> update(
    MangaReaderSettings Function(MangaReaderSettings current) mutator,
  ) async {
    state = mutator(state);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kKey, jsonEncode(state.toJson()));
    } catch (_) {}
  }

  Future<void> applySnapshotJson(Map<String, dynamic> json) async {
    state = MangaReaderSettings.fromJson(json);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kKey, jsonEncode(state.toJson()));
    } catch (_) {}
  }
}

final mangaReaderSettingsProvider =
    NotifierProvider<MangaReaderSettingsController, MangaReaderSettings>(
  MangaReaderSettingsController.new,
);
