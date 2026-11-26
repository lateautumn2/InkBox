import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'inkbox_theme.dart';

@immutable
class AppearanceState {
  const AppearanceState({
    this.uiStyle = InkBoxUiStyle.floatingCard,
    this.themePreference = InkBoxThemePreference.crispLight,
    this.useDynamicColor = false,
    this.appLocaleCode = 'system', // 'system' | 'zh' | 'en' | 'ja'
  });

  final InkBoxUiStyle uiStyle;
  final InkBoxThemePreference themePreference;
  final bool useDynamicColor;
  final String appLocaleCode;

  ThemeMode get themeMode {
    switch (themePreference) {
      case InkBoxThemePreference.crispLight:
        return ThemeMode.light;
      case InkBoxThemePreference.darkTheater:
      case InkBoxThemePreference.oledBlack:
        return ThemeMode.dark;
      case InkBoxThemePreference.system:
        return ThemeMode.system;
    }
  }

  bool get isOledDark => themePreference == InkBoxThemePreference.oledBlack;

  Locale? get resolvedLocale {
    switch (appLocaleCode) {
      case 'zh':
        return const Locale('zh');
      case 'en':
        return const Locale('en');
      case 'ja':
        return const Locale('ja');
      default:
        return null;
    }
  }

  AppearanceState copyWith({
    InkBoxUiStyle? uiStyle,
    InkBoxThemePreference? themePreference,
    bool? useDynamicColor,
    String? appLocaleCode,
  }) {
    return AppearanceState(
      uiStyle: uiStyle ?? this.uiStyle,
      themePreference: themePreference ?? this.themePreference,
      useDynamicColor: useDynamicColor ?? this.useDynamicColor,
      appLocaleCode: appLocaleCode ?? this.appLocaleCode,
    );
  }
}

class AppearanceController extends Notifier<AppearanceState> {
  static const _kUiStyle = 'inkbox_ui_style';
  static const _kThemePref = 'inkbox_theme_pref';
  static const _kDynamicColor = 'inkbox_dynamic_color';
  static const _kAppLocale = 'inkbox_app_locale';

  @override
  AppearanceState build() {
    _hydrate();
    return const AppearanceState();
  }

  Future<void> _hydrate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final styleIdx = prefs.getInt(_kUiStyle);
      final themeIdx = prefs.getInt(_kThemePref);
      final dynamicColor = prefs.getBool(_kDynamicColor);
      final localeCode = prefs.getString(_kAppLocale);
      state = AppearanceState(
        uiStyle: styleIdx != null && styleIdx < InkBoxUiStyle.values.length
            ? InkBoxUiStyle.values[styleIdx]
            : InkBoxUiStyle.floatingCard,
        themePreference: themeIdx != null &&
                themeIdx < InkBoxThemePreference.values.length
            ? InkBoxThemePreference.values[themeIdx]
            : InkBoxThemePreference.crispLight,
        useDynamicColor: dynamicColor ?? false,
        appLocaleCode: const {'system', 'zh', 'en', 'ja'}.contains(localeCode)
            ? localeCode!
            : 'system',
      );
    } catch (_) {
      // Safe fallback during isolated widget tests.
    }
  }

  Future<void> setUiStyle(InkBoxUiStyle style) async {
    state = state.copyWith(uiStyle: style);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kUiStyle, style.index);
  }

  Future<void> toggleUiStyle() async {
    final next = state.uiStyle == InkBoxUiStyle.floatingCard
        ? InkBoxUiStyle.classic
        : InkBoxUiStyle.floatingCard;
    await setUiStyle(next);
  }

  Future<void> setThemePreference(InkBoxThemePreference pref) async {
    state = state.copyWith(themePreference: pref);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kThemePref, pref.index);
  }

  Future<void> cycleThemePreference() async {
    const order = [
      InkBoxThemePreference.crispLight,
      InkBoxThemePreference.darkTheater,
      InkBoxThemePreference.oledBlack,
    ];
    final cur = order.indexOf(state.themePreference);
    final next = order[(cur + 1) % order.length];
    await setThemePreference(next);
  }

  Future<void> setUseDynamicColor(bool value) async {
    state = state.copyWith(useDynamicColor: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDynamicColor, value);
  }

  Future<void> setAppLocaleCode(String code) async {
    final safeCode =
        const {'system', 'zh', 'en', 'ja'}.contains(code) ? code : 'system';
    state = state.copyWith(appLocaleCode: safeCode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAppLocale, safeCode);
  }
}

final appearanceProvider =
    NotifierProvider<AppearanceController, AppearanceState>(
  AppearanceController.new,
);
