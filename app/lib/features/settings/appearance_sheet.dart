import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/icons/ink_icons.dart';
import '../../core/l10n/l10n_helpers.dart';
import '../../core/layout/responsive_layout.dart';
import '../../core/theme/inkbox_theme.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/widgets/floating_surface.dart';
import '../../core/widgets/ink_controls.dart';

/// Opens the Theme Presets bottom sheet on the root Navigator overlay.
Future<void> showAppearanceSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => const _AppearanceSheet(),
  );
}

class _AppearanceSheet extends ConsumerWidget {
  const _AppearanceSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = InkBoxTokens.of(context);
    final l10n = context.l10n;
    final appearance = ref.watch(appearanceProvider);
    final ctrl = ref.read(appearanceProvider.notifier);
    final wide = isWideLayout(context);

    return SafeArea(
      child: Center(
        heightFactor: 1.0,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: wide ? kMaxModalWidth : double.infinity,
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              tokens.isFloatingCard ? 14 : 0,
              0,
              tokens.isFloatingCard ? 14 : 0,
              tokens.isFloatingCard ? 14 : 0,
            ),
            child: FloatingCard(
              frosted: true,
              radius: 22,
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: tokens.inkMuted.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        InkIconWidget(
                          InkIcon.floatingCard,
                          size: 20,
                          color: tokens.accentPrimary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          l10n.themePresets,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.uiStyleLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: tokens.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _ChoicePill(
                            label: l10n.uiStyleFloating,
                            selected: appearance.uiStyle ==
                                InkBoxUiStyle.floatingCard,
                            onTap: () =>
                                ctrl.setUiStyle(InkBoxUiStyle.floatingCard),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ChoicePill(
                            label: l10n.uiStyleClassic,
                            selected:
                                appearance.uiStyle == InkBoxUiStyle.classic,
                            onTap: () =>
                                ctrl.setUiStyle(InkBoxUiStyle.classic),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.colorThemeLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: tokens.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _ChoicePill(
                          label: l10n.themeCrispLight,
                          selected: appearance.themePreference ==
                              InkBoxThemePreference.crispLight,
                          onTap: () => ctrl.setThemePreference(
                            InkBoxThemePreference.crispLight,
                          ),
                        ),
                        _ChoicePill(
                          label: l10n.themeDarkTheater,
                          selected: appearance.themePreference ==
                              InkBoxThemePreference.darkTheater,
                          onTap: () => ctrl.setThemePreference(
                            InkBoxThemePreference.darkTheater,
                          ),
                        ),
                        _ChoicePill(
                          label: l10n.themeOledBlack,
                          selected: appearance.themePreference ==
                              InkBoxThemePreference.oledBlack,
                          onTap: () => ctrl.setThemePreference(
                            InkBoxThemePreference.oledBlack,
                          ),
                        ),
                        _ChoicePill(
                          label: l10n.themeFollowSystem,
                          selected: appearance.themePreference ==
                              InkBoxThemePreference.system,
                          onTap: () => ctrl.setThemePreference(
                            InkBoxThemePreference.system,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.dynamicColorTitle,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: tokens.inkPrimary,
                                ),
                              ),
                              Text(
                                l10n.dynamicColorSubtitle,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: tokens.inkMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        InkSwitch(
                          value: appearance.useDynamicColor,
                          onChanged: ctrl.setUseDynamicColor,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChoicePill extends StatelessWidget {
  const _ChoicePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = InkBoxTokens.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? tokens.accentPrimary : tokens.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected
                ? Theme.of(context).colorScheme.onPrimary
                : tokens.inkPrimary,
          ),
        ),
      ),
    );
  }
}
