import 'dart:ui';

import 'package:material_ui/material_ui.dart';

import '../theme/inkbox_theme.dart';

/// Core FloatingCard container that adapts gracefully between
/// FloatingCard (elevated detached paper cards) and Classic MD3 surfaces.
class FloatingCard extends StatelessWidget {
  const FloatingCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.margin,
    this.radius,
    this.onTap,
    this.onLongPress,
    this.backgroundColor,
    this.borderColor,
    this.frosted = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double? radius;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? backgroundColor;
  final Color? borderColor;
  final bool frosted;

  @override
  Widget build(BuildContext context) {
    final tokens = InkBoxTokens.of(context);
    final effectiveRadius = radius ?? tokens.cardRadius;
    final bg = backgroundColor ??
        (frosted ? tokens.glassSurface : tokens.cardSurface);
    final border = borderColor ?? tokens.subtleBorder;

    Widget surface = Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(effectiveRadius),
        border: Border.all(color: border, width: 1),
        boxShadow: frosted ? tokens.dockShadows : tokens.cardShadows,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(effectiveRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(effectiveRadius),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );

    if (frosted) {
      surface = ClipRRect(
        borderRadius: BorderRadius.circular(effectiveRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: surface,
        ),
      );
    }

    if (margin != null) {
      surface = Padding(padding: margin!, child: surface);
    }
    return surface;
  }
}

/// Top header bar that renders as a detached FloatingCard island in
/// FloatingCard mode, or a clean flush header in Classic mode.
class FloatingHeaderBar extends StatelessWidget {
  const FloatingHeaderBar({
    super.key,
    required this.title,
    this.titleTrailing,
    this.onTitleTap,
    this.actions = const [],
  });

  final String title;
  final Widget? titleTrailing;
  final VoidCallback? onTitleTap;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final tokens = InkBoxTokens.of(context);
    Widget titleNode = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: tokens.inkPrimary,
                ),
          ),
        ),
        if (titleTrailing != null) ...[
          const SizedBox(width: 6),
          titleTrailing!,
        ],
      ],
    );

    if (onTitleTap != null) {
      titleNode = InkWell(
        onTap: onTitleTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
          child: titleNode,
        ),
      );
    }

    final row = Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: titleNode,
          ),
        ),
        ...actions,
      ],
    );

    if (tokens.isFloatingCard) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
        child: FloatingCard(
          radius: 22,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: row,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 14, 8),
      child: row,
    );
  }
}

/// Minimal circular icon button styled for InkBox's monochrome hand-drawn icons.
class InkCircleButton extends StatelessWidget {
  const InkCircleButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.highlighted = false,
  });

  final Widget icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final tokens = InkBoxTokens.of(context);
    final btn = Material(
      color: highlighted ? tokens.accentSoft : tokens.surfaceVariant,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Center(child: icon),
        ),
      ),
    );
    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: btn);
    }
    return btn;
  }
}

