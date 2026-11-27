import 'package:material_ui/material_ui.dart';

/// Visual layout mode: detached FloatingCard (default) vs Classic flush MD3.
enum InkBoxUiStyle {
  floatingCard,
  classic,
}

/// Global application color theme preference (Crisp Ink & Mineral Paper).
enum InkBoxThemePreference {
  crispLight,
  darkTheater,
  oledBlack,
  system,
  inkWash,
}

/// Built-in 5 paper palettes for the book reader engine.
enum BookPaperTheme {
  white(
    label: '素白',
    background: Color(0xFFFFFFFF),
    foreground: Color(0xFF1A1C20),
    secondary: Color(0xFF7A808B),
    highlight: Color(0xFFFFE082),
  ),
  parchment(
    label: '轻象牙',
    background: Color(0xFFF7F6F2),
    foreground: Color(0xFF232529),
    secondary: Color(0xFF7B7E85),
    highlight: Color(0xFFFBE192),
  ),
  sage(
    label: '青瓷',
    background: Color(0xFFEAF2EC),
    foreground: Color(0xFF1E2D24),
    secondary: Color(0xFF5F7366),
    highlight: Color(0xFFBDE2C3),
  ),
  dark(
    label: '墨灰夜',
    background: Color(0xFF1A1D22),
    foreground: Color(0xFFCED3DB),
    secondary: Color(0xFF7B8290),
    highlight: Color(0xFF3A4E66),
  ),
  oled(
    label: '纯黑夜',
    background: Color(0xFF000000),
    foreground: Color(0xFFADB3BE),
    secondary: Color(0xFF5E6572),
    highlight: Color(0xFF2C3B4D),
  ),
  inkWash(
    label: '水墨',
    background: Color(0xFFF3EEE2),
    foreground: Color(0xFF2C2C25),
    secondary: Color(0xFF686658),
    highlight: Color(0xFFE9C2AF),
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

/// Semantic design tokens for InkBox (Crisp Ink & Mineral Paper + FloatingCard).
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
  static const Color slateInkLight = Color(0xFF2F5C8F);
  static const Color slateInkDark = Color(0xFF6FA4E0);
  static const Color vermilionLight = Color(0xFFCF4B40);
  static const Color vermilionDark = Color(0xFFE86A60);

  static ThemeData light({
    required InkBoxUiStyle uiStyle,
    Color? dynamicSeedColor,
    bool inkWash = false,
  }) {
    final isFloating = uiStyle == InkBoxUiStyle.floatingCard;
    final dynamicScheme = !inkWash && dynamicSeedColor != null
        ? ColorScheme.fromSeed(
            seedColor: dynamicSeedColor,
            brightness: Brightness.light,
          )
        : null;
    final accent = inkWash
        ? const Color(0xFF455B51)
        : dynamicScheme?.primary ?? slateInkLight;
    final accentSoft = inkWash
        ? const Color(0xFFDEE5D8)
        : dynamicScheme?.primaryContainer ?? const Color(0xFFE3ECF6);

    final baseTokens = InkBoxTokens(
      canvasBg: isFloating ? const Color(0xFFF4F5F7) : const Color(0xFFFAFAFB),
      cardSurface: const Color(0xFFFFFFFF),
      glassSurface: const Color(0xEBFFFFFF),
      surfaceVariant: const Color(0xFFE9ECF1),
      subtleBorder: const Color(0x14161A22),
      inkPrimary: const Color(0xFF15171C),
      inkMuted: const Color(0xFF636A76),
      accentPrimary: accent,
      accentSoft: accentSoft,
      accentWarm: vermilionLight,
      statusOk: const Color(0xFF248A62),
      cardRadius: isFloating ? 16 : 12,
      dockRadius: 24,
      cardShadows: isFloating
          ? const [
              BoxShadow(
                color: Color(0x0E101828),
                blurRadius: 16,
                spreadRadius: -4,
                offset: Offset(0, 6),
              ),
              BoxShadow(
                color: Color(0x08101828),
                blurRadius: 3,
                offset: Offset(0, 1),
              ),
            ]
          : const [],
      dockShadows: const [
        BoxShadow(
          color: Color(0x1C101828),
          blurRadius: 22,
          spreadRadius: -6,
          offset: Offset(0, 10),
        ),
        BoxShadow(
          color: Color(0x0C101828),
          blurRadius: 5,
          offset: Offset(0, 2),
        ),
      ],
      uiStyle: uiStyle,
    );
    final tokens = inkWash
        ? baseTokens.copyWith(
            canvasBg: const Color(0xFFF3EEE2),
            cardSurface: const Color(0xFFFFFBF1),
            glassSurface: const Color(0xF5FFFBF1),
            surfaceVariant: const Color(0xFFEBE4D5),
            subtleBorder: const Color(0xFFDCD3C2),
            inkPrimary: const Color(0xFF2C2C25),
            inkMuted: const Color(0xFF686658),
            accentWarm: const Color(0xFFA44739),
            statusOk: const Color(0xFF4B654E),
          )
        : baseTokens;

    final colorScheme = (dynamicScheme ??
            ColorScheme.fromSeed(
              seedColor: accent,
              brightness: Brightness.light,
            ))
        .copyWith(
      primary: accent,
      secondary: tokens.accentWarm,
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
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.surfaceVariant.withValues(alpha: 0.72),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: tokens.subtleBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: tokens.subtleBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
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
    final accentSoft = dynamicScheme?.primaryContainer ??
        (oled ? const Color(0xFF1A283A) : const Color(0xFF1F2F43));

    final tokens = InkBoxTokens(
      canvasBg: oled ? const Color(0xFF000000) : const Color(0xFF101216),
      cardSurface: oled ? const Color(0xFF0D0F13) : const Color(0xFF181B21),
      glassSurface: oled ? const Color(0xEB0D0F13) : const Color(0xEB181B21),
      surfaceVariant: oled ? const Color(0xFF171A21) : const Color(0xFF222630),
      subtleBorder:
          oled ? const Color(0x1CFFFFFF) : const Color(0x17FFFFFF),
      inkPrimary: oled ? const Color(0xFFE4E6EB) : const Color(0xFFECEDF0),
      inkMuted: oled ? const Color(0xFF838A98) : const Color(0xFF9198A6),
      accentPrimary: accent,
      accentSoft: accentSoft,
      accentWarm: vermilionDark,
      statusOk: const Color(0xFF4DC191),
      cardRadius: isFloating ? 16 : 12,
      dockRadius: 24,
      cardShadows: isFloating
          ? const [
              BoxShadow(
                color: Color(0x5A000000),
                blurRadius: 16,
                spreadRadius: -4,
                offset: Offset(0, 6),
              ),
            ]
          : const [],
      dockShadows: const [
        BoxShadow(
          color: Color(0x88000000),
          blurRadius: 24,
          spreadRadius: -6,
          offset: Offset(0, 10),
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
      secondary: vermilionDark,
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
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.surfaceVariant.withValues(alpha: 0.72),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: tokens.subtleBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: tokens.subtleBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
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
