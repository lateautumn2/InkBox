import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'inkbox_theme.dart';

@immutable
class AppearanceState {
  const AppearanceState({
    this.uiStyle = InkBoxUiStyle.floatingCard,
    this.themePreference = InkBoxThemePreference.warmPaperLight,
    this.useDynamicColor = false,
  });

  final InkBoxUiStyle uiStyle;
  final InkBoxThemePreference themePreference;
  final bool useDynamicColor;

  ThemeMode get themeMode {
    switch (themePreference) {
      case InkBoxThemePreference.warmPaperLight:
        return ThemeMode.light;
      case InkBoxThemePreference.darkTheater:
      case InkBoxThemePreference.oledBlack:
        return ThemeMode.dark;
      case InkBoxThemePreference.system:
        return ThemeMode.system;
    }
  }

  bool get isOledDark => themePreference == InkBoxThemePreference.oledBlack;

  AppearanceState copyWith({
    InkBoxUiStyle? uiStyle,
    InkBoxThemePreference? themePreference,
    bool? useDynamicColor,
  }) {
    return AppearanceState(
      uiStyle: uiStyle ?? this.uiStyle,
      themePreference: themePreference ?? this.themePreference,
      useDynamicColor: useDynamicColor ?? this.useDynamicColor,
    );
  }
}

class AppearanceController extends Notifier<AppearanceState> {
  static const _kUiStyle = 'inkbox_ui_style';
  static const _kThemePref = 'inkbox_theme_pref';
  static const _kDynamicColor = 'inkbox_dynamic_color';

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
      state = AppearanceState(
        uiStyle: styleIdx != null && styleIdx < InkBoxUiStyle.values.length
            ? InkBoxUiStyle.values[styleIdx]
            : InkBoxUiStyle.floatingCard,
        themePreference: themeIdx != null &&
                themeIdx < InkBoxThemePreference.values.length
            ? InkBoxThemePreference.values[themeIdx]
            : InkBoxThemePreference.warmPaperLight,
        useDynamicColor: dynamicColor ?? false,
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
      InkBoxThemePreference.warmPaperLight,
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
}

final appearanceProvider =
    NotifierProvider<AppearanceController, AppearanceState>(
  AppearanceController.new,
);

