import 'package:material_ui/material_ui.dart';

/// Visual layout mode: detached FloatingCard (default) vs Classic flush MD3.
enum InkBoxUiStyle {
  floatingCard,
  classic,
}

/// Global application color theme preference.
enum InkBoxThemePreference {
  warmPaperLight,
  darkTheater,
  oledBlack,
  system,
}

/// Built-in 5 paper palettes for the book reader engine.
enum BookPaperTheme {
  white(
    label: '纸白',
    background: Color(0xFFFFFFFF),
    foreground: Color(0xFF1D1D1F),
    secondary: Color(0xFF7A7A80),
    highlight: Color(0xFFFFE599),
  ),
  parchment(
    label: '羊皮纸',
    background: Color(0xFFF5EFE2),
    foreground: Color(0xFF32291E),
    secondary: Color(0xFF877865),
    highlight: Color(0xFFEED29A),
  ),
  sage(
    label: '护眼绿',
    background: Color(0xFFDCE8DB),
    foreground: Color(0xFF233324),
    secondary: Color(0xFF5E7560),
    highlight: Color(0xFFBCE0B8),
  ),
  dark(
    label: '深灰夜',
    background: Color(0xFF1E2024),
    foreground: Color(0xFFC8C6C0),
    secondary: Color(0xFF777980),
    highlight: Color(0xFF463E26),
  ),
  oled(
    label: 'OLED黑',
    background: Color(0xFF000000),
    foreground: Color(0xFFA8A8A8),
    secondary: Color(0xFF5A5A5A),
    highlight: Color(0xFF332C18),
  );

  const BookPaperTheme({
    required this.label,
    required this.background,
    required this.foreground,
    required this.secondary,
    required this.highlight,
  });

  final String label;
  final Color background;
  final Color foreground;
  final Color secondary;
  final Color highlight;
}

/// Semantic design tokens for InkBox (Slate Ink & Warm Paper + FloatingCard).
@immutable
class InkBoxTokens extends ThemeExtension<InkBoxTokens> {
  const InkBoxTokens({
    required this.canvasBg,
    required this.cardSurface,
    required this.glassSurface,
    required this.surfaceVariant,
    required this.subtleBorder,
    required this.inkPrimary,
    required this.inkMuted,
    required this.accentPrimary,
    required this.accentSoft,
    required this.accentWarm,
    required this.statusOk,
    required this.cardRadius,
    required this.dockRadius,
    required this.cardShadows,
    required this.dockShadows,
    required this.uiStyle,
  });

  final Color canvasBg;
  final Color cardSurface;
  final Color glassSurface;
  final Color surfaceVariant;
  final Color subtleBorder;
  final Color inkPrimary;
  final Color inkMuted;
  final Color accentPrimary;
  final Color accentSoft;
  final Color accentWarm;
  final Color statusOk;
  final double cardRadius;
  final double dockRadius;
  final List<BoxShadow> cardShadows;
  final List<BoxShadow> dockShadows;
  final InkBoxUiStyle uiStyle;

  bool get isFloatingCard => uiStyle == InkBoxUiStyle.floatingCard;

  static InkBoxTokens of(BuildContext context) {
    final ext = Theme.of(context).extension<InkBoxTokens>();
    assert(ext != null, 'InkBoxTokens must be registered on ThemeData');
    return ext!;
  }

  @override
  InkBoxTokens copyWith({
    Color? canvasBg,
    Color? cardSurface,
    Color? glassSurface,
    Color? surfaceVariant,
    Color? subtleBorder,
    Color? inkPrimary,
    Color? inkMuted,
    Color? accentPrimary,
    Color? accentSoft,
    Color? accentWarm,
    Color? statusOk,
    double? cardRadius,
    double? dockRadius,
    List<BoxShadow>? cardShadows,
    List<BoxShadow>? dockShadows,
    InkBoxUiStyle? uiStyle,
  }) {
    return InkBoxTokens(
      canvasBg: canvasBg ?? this.canvasBg,
      cardSurface: cardSurface ?? this.cardSurface,
      glassSurface: glassSurface ?? this.glassSurface,
      surfaceVariant: surfaceVariant ?? this.surfaceVariant,
      subtleBorder: subtleBorder ?? this.subtleBorder,
      inkPrimary: inkPrimary ?? this.inkPrimary,
      inkMuted: inkMuted ?? this.inkMuted,
      accentPrimary: accentPrimary ?? this.accentPrimary,
      accentSoft: accentSoft ?? this.accentSoft,
      accentWarm: accentWarm ?? this.accentWarm,
      statusOk: statusOk ?? this.statusOk,
      cardRadius: cardRadius ?? this.cardRadius,
      dockRadius: dockRadius ?? this.dockRadius,
      cardShadows: cardShadows ?? this.cardShadows,
      dockShadows: dockShadows ?? this.dockShadows,
      uiStyle: uiStyle ?? this.uiStyle,
    );
  }

  @override
  InkBoxTokens lerp(ThemeExtension<InkBoxTokens>? other, double t) {
    if (other is! InkBoxTokens) return this;
    return InkBoxTokens(
      canvasBg: Color.lerp(canvasBg, other.canvasBg, t)!,
      cardSurface: Color.lerp(cardSurface, other.cardSurface, t)!,
      glassSurface: Color.lerp(glassSurface, other.glassSurface, t)!,
      surfaceVariant: Color.lerp(surfaceVariant, other.surfaceVariant, t)!,
      subtleBorder: Color.lerp(subtleBorder, other.subtleBorder, t)!,
      inkPrimary: Color.lerp(inkPrimary, other.inkPrimary, t)!,
      inkMuted: Color.lerp(inkMuted, other.inkMuted, t)!,
      accentPrimary: Color.lerp(accentPrimary, other.accentPrimary, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      accentWarm: Color.lerp(accentWarm, other.accentWarm, t)!,
      statusOk: Color.lerp(statusOk, other.statusOk, t)!,
      cardRadius: cardRadius + (other.cardRadius - cardRadius) * t,
      dockRadius: dockRadius + (other.dockRadius - dockRadius) * t,
      cardShadows: t < 0.5 ? cardShadows : other.cardShadows,
      dockShadows: t < 0.5 ? dockShadows : other.dockShadows,
      uiStyle: t < 0.5 ? uiStyle : other.uiStyle,
    );
  }
}

class InkBoxTheme {
  static const Color slateInkLight = Color(0xFF3B5978);
  static const Color slateInkDark = Color(0xFF82A9D4);
  static const Color terracottaLight = Color(0xFFB86B4B);
  static const Color terracottaDark = Color(0xFFD88B6A);

  static ThemeData light({
    required InkBoxUiStyle uiStyle,
    Color? dynamicSeedColor,
  }) {
    final isFloating = uiStyle == InkBoxUiStyle.floatingCard;
    final dynamicScheme = dynamicSeedColor != null
        ? ColorScheme.fromSeed(
            seedColor: dynamicSeedColor,
            brightness: Brightness.light,
          )
        : null;
    final accent = dynamicScheme?.primary ?? slateInkLight;
    final accentSoft =
        dynamicScheme?.primaryContainer ?? const Color(0xFFE0EAF4);

    final tokens = InkBoxTokens(
      canvasBg: isFloating ? const Color(0xFFF3EFE8) : const Color(0xFFFAF8F4),
      cardSurface: const Color(0xFFFFFFFF),
      glassSurface: const Color(0xEBFFFFFF),
      surfaceVariant: const Color(0xFFEAE4DA),
      subtleBorder: const Color(0x172A2622),
      inkPrimary: const Color(0xFF22201E),
      inkMuted: const Color(0xFF6C665E),
      accentPrimary: accent,
      accentSoft: accentSoft,
      accentWarm: terracottaLight,
      statusOk: const Color(0xFF2E7D5B),
      cardRadius: isFloating ? 20 : 14,
      dockRadius: 28,
      cardShadows: isFloating
          ? const [
              BoxShadow(
                color: Color(0x18221D16),
                blurRadius: 18,
                spreadRadius: -6,
                offset: Offset(0, 8),
              ),
              BoxShadow(
                color: Color(0x0D221D16),
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ]
          : const [],
      dockShadows: const [
        BoxShadow(
          color: Color(0x24221D16),
          blurRadius: 26,
          spreadRadius: -8,
          offset: Offset(0, 12),
        ),
        BoxShadow(
          color: Color(0x10221D16),
          blurRadius: 6,
          offset: Offset(0, 2),
        ),
      ],
      uiStyle: uiStyle,
    );

    final colorScheme = (dynamicScheme ??
            ColorScheme.fromSeed(
              seedColor: slateInkLight,
              brightness: Brightness.light,
            ))
        .copyWith(
      primary: accent,
      secondary: terracottaLight,
      surface: tokens.cardSurface,
      surfaceContainerLowest: tokens.canvasBg,
      onSurface: tokens.inkPrimary,
      onSurfaceVariant: tokens.inkMuted,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: tokens.canvasBg,
      extensions: [tokens],
      dividerColor: tokens.subtleBorder,
      sliderTheme: SliderThemeData(
        activeTrackColor: tokens.accentPrimary,
        inactiveTrackColor: tokens.surfaceVariant,
        thumbColor: tokens.accentPrimary,
        overlayColor: tokens.accentPrimary.withValues(alpha: 0.14),
        trackHeight: 3.5,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: tokens.inkPrimary,
        contentTextStyle: TextStyle(
          fontSize: 12.5,
          color: tokens.cardSurface,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.surfaceVariant.withValues(alpha: 0.72),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: tokens.subtleBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: tokens.subtleBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: tokens.accentPrimary, width: 1.5),
        ),
      ),
      textTheme: Typography.material2021().black.apply(
            bodyColor: tokens.inkPrimary,
            displayColor: tokens.inkPrimary,
          ),
    );
  }

  static ThemeData dark({
    required InkBoxUiStyle uiStyle,
    bool oled = false,
    Color? dynamicSeedColor,
  }) {
    final isFloating = uiStyle == InkBoxUiStyle.floatingCard;
    final dynamicScheme = dynamicSeedColor != null
        ? ColorScheme.fromSeed(
            seedColor: dynamicSeedColor,
            brightness: Brightness.dark,
          )
        : null;
    final accent = dynamicScheme?.primary ?? slateInkDark;
    final accentSoft =
        dynamicScheme?.primaryContainer ?? const Color(0xFF243344);

    final tokens = InkBoxTokens(
      canvasBg: oled ? const Color(0xFF000000) : const Color(0xFF101114),
      cardSurface: oled ? const Color(0xFF101114) : const Color(0xFF1A1C21),
      glassSurface: oled ? const Color(0xEB101114) : const Color(0xEB1A1C21),
      surfaceVariant: const Color(0xFF24272F),
      subtleBorder: const Color(0x16FFFFFF),
      inkPrimary: const Color(0xFFEAE8E3),
      inkMuted: const Color(0xFF989690),
      accentPrimary: accent,
      accentSoft: accentSoft,
      accentWarm: terracottaDark,
      statusOk: const Color(0xFF55B388),
      cardRadius: isFloating ? 20 : 14,
      dockRadius: 28,
      cardShadows: isFloating
          ? const [
              BoxShadow(
                color: Color(0x70000000),
                blurRadius: 18,
                spreadRadius: -6,
                offset: Offset(0, 8),
              ),
            ]
          : const [],
      dockShadows: const [
        BoxShadow(
          color: Color(0x99000000),
          blurRadius: 28,
          spreadRadius: -8,
          offset: Offset(0, 12),
        ),
      ],
      uiStyle: uiStyle,
    );

    final colorScheme = (dynamicScheme ??
            ColorScheme.fromSeed(
              seedColor: slateInkDark,
              brightness: Brightness.dark,
            ))
        .copyWith(
      primary: accent,
      secondary: terracottaDark,
      surface: tokens.cardSurface,
      surfaceContainerLowest: tokens.canvasBg,
      onSurface: tokens.inkPrimary,
      onSurfaceVariant: tokens.inkMuted,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: tokens.canvasBg,
      extensions: [tokens],
      dividerColor: tokens.subtleBorder,
      sliderTheme: SliderThemeData(
        activeTrackColor: tokens.accentPrimary,
        inactiveTrackColor: tokens.surfaceVariant,
        thumbColor: tokens.accentPrimary,
        overlayColor: tokens.accentPrimary.withValues(alpha: 0.14),
        trackHeight: 3.5,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: tokens.inkPrimary,
        contentTextStyle: TextStyle(
          fontSize: 12.5,
          color: tokens.cardSurface,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.surfaceVariant.withValues(alpha: 0.72),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: tokens.subtleBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: tokens.subtleBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: tokens.accentPrimary, width: 1.5),
        ),
      ),
      textTheme: Typography.material2021().white.apply(
            bodyColor: tokens.inkPrimary,
            displayColor: tokens.inkPrimary,
          ),
    );
  }
}

