import 'package:material_ui/material_ui.dart';

import '../icons/ink_icons.dart';
import '../theme/inkbox_theme.dart';
import 'floating_surface.dart';

/// Modern rounded filled input styled to match InkBox's FloatingCard aesthetic
/// (replaces legacy underlined Material inputs).
class InkTextField extends StatefulWidget {
  const InkTextField({
    super.key,
    this.controller,
    this.label,
    this.hintText,
    this.helperText,
    this.obscureText = false,
    this.autofocus = false,
    this.maxLines = 1,
    this.minLines,
    this.keyboardType,
    this.onChanged,
    this.onSubmitted,
    this.prefixIcon,
    this.suffix,
    this.monospace = false,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hintText;
  final String? helperText;
  final bool obscureText;
  final bool autofocus;
  final int maxLines;
  final int? minLines;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final InkIcon? prefixIcon;
  final Widget? suffix;
  final bool monospace;

  @override
  State<InkTextField> createState() => _InkTextFieldState();
}

class _InkTextFieldState extends State<InkTextField> {
  final FocusNode _focusNode = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (mounted) setState(() => _focused = _focusNode.hasFocus);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = InkBoxTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null && widget.label!.isNotEmpty) ...[
          Text(
            widget.label!,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _focused ? tokens.accentPrimary : tokens.inkMuted,
            ),
          ),
          const SizedBox(height: 6),
        ],
        AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            color: tokens.surfaceVariant.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _focused ? tokens.accentPrimary : tokens.subtleBorder,
              width: _focused ? 1.5 : 1,
            ),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: 12,
            vertical: widget.maxLines > 1 ? 4 : 2,
          ),
          child: Row(
            crossAxisAlignment: widget.maxLines > 1
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              if (widget.prefixIcon != null) ...[
                Padding(
                  padding: EdgeInsets.only(top: widget.maxLines > 1 ? 9 : 0),
                  child: InkIconWidget(
                    widget.prefixIcon!,
                    size: 16,
                    color: _focused ? tokens.accentPrimary : tokens.inkMuted,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  obscureText: widget.obscureText,
                  autofocus: widget.autofocus,
                  maxLines: widget.obscureText ? 1 : widget.maxLines,
                  minLines: widget.minLines,
                  keyboardType: widget.keyboardType,
                  onChanged: widget.onChanged,
                  onSubmitted: widget.onSubmitted,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: tokens.inkPrimary,
                    fontFamily: widget.monospace ? 'monospace' : null,
                  ),
                  decoration: InputDecoration(
                    hintText: widget.hintText,
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: tokens.inkMuted.withValues(alpha: 0.75),
                    ),
                    filled: false,
                    fillColor: Colors.transparent,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              if (widget.suffix != null) widget.suffix!,
            ],
          ),
        ),
        if (widget.helperText != null && widget.helperText!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            widget.helperText!,
            style: TextStyle(fontSize: 11, color: tokens.inkMuted),
          ),
        ],
      ],
    );
  }
}

/// Crisp custom pill toggle switch aligned with InkBoxTokens.
class InkSwitch extends StatelessWidget {
  const InkSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor,
    this.inactiveColor,
    this.thumbColor,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color? activeColor;
  final Color? inactiveColor;
  final Color? thumbColor;

  @override
  Widget build(BuildContext context) {
    final tokens = InkBoxTokens.of(context);
    final enabled = onChanged != null;
    final trackOn = activeColor ?? tokens.accentPrimary;
    final trackOff = inactiveColor ?? tokens.surfaceVariant;
    final knobColor = thumbColor ??
        (value ? Theme.of(context).colorScheme.onPrimary : tokens.cardSurface);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? () => onChanged!(!value) : null,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.45,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: 46,
          height: 26,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: value ? trackOn : trackOff,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: value ? Colors.transparent : tokens.subtleBorder,
            ),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: knobColor,
                shape: BoxShape.circle,
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x22000000),
                    blurRadius: 3,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tactile pill chip replacing raw Material ChoiceChip/ActionChip/InputChip.
class InkPillChip extends StatelessWidget {
  const InkPillChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.onLongPress,
    this.onDelete,
    this.leadingIcon,
    this.elevated = false,
    this.danger = false,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDelete;
  final InkIcon? leadingIcon;
  final bool elevated;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final tokens = InkBoxTokens.of(context);
    final bg = selected
        ? (danger ? tokens.accentWarm : tokens.accentPrimary)
        : (elevated && tokens.isFloatingCard
            ? tokens.cardSurface
            : tokens.surfaceVariant);
    final fg = selected
        ? Theme.of(context).colorScheme.onPrimary
        : (danger ? tokens.accentWarm : tokens.inkPrimary);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? Colors.transparent : tokens.subtleBorder,
          ),
          boxShadow: !selected && elevated && tokens.isFloatingCard
              ? tokens.cardShadows
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leadingIcon != null) ...[
              InkIconWidget(leadingIcon!, size: 13, color: fg),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
            if (onDelete != null) ...[
              const SizedBox(width: 5),
              GestureDetector(
                onTap: onDelete,
                child: InkIconWidget(InkIcon.close, size: 12, color: fg),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class InkOptionItem<T> {
  const InkOptionItem({
    required this.value,
    required this.label,
    this.subtitle,
    this.icon,
    this.danger = false,
  });

  final T value;
  final String label;
  final String? subtitle;
  final InkIcon? icon;
  final bool danger;
}

/// Modern frosted FloatingCard bottom-sheet selector rendered on the root Navigator
/// (so FloatingCard bottom pill dock never covers it!).
Future<T?> showInkOptionSheet<T>({
  required BuildContext context,
  required String title,
  String? subtitle,
  required List<InkOptionItem<T>> options,
  T? selectedValue,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      final tokens = InkBoxTokens.of(ctx);
      final bottomInset = MediaQuery.viewInsetsOf(ctx).bottom;
      final isWide = MediaQuery.sizeOf(ctx).width >= 600;
      return SafeArea(
        child: Center(
          heightFactor: 1.0,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isWide ? 460 : double.infinity,
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                tokens.isFloatingCard ? 14 : 0,
                0,
                tokens.isFloatingCard ? 14 : 0,
                (tokens.isFloatingCard ? 14 : 0) + bottomInset,
              ),
              child: FloatingCard(
                frosted: true,
                radius: 22,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(ctx).height * 0.72,
                  ),
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
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          title,
                          style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: tokens.inkPrimary,
                              ),
                        ),
                      ),
                      if (subtitle != null && subtitle.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            subtitle,
                            style:
                                TextStyle(fontSize: 12, color: tokens.inkMuted),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: options.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 6),
                          itemBuilder: (_, idx) {
                            final opt = options[idx];
                            final active = selectedValue != null &&
                                opt.value == selectedValue;
                            final fg = opt.danger
                                ? tokens.accentWarm
                                : (active
                                    ? tokens.accentPrimary
                                    : tokens.inkPrimary);
                            return Material(
                              color: active
                                  ? tokens.accentSoft
                                  : tokens.surfaceVariant.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(14),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: () => Navigator.of(ctx).pop(opt.value),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    children: [
                                      if (opt.icon != null) ...[
                                        InkIconWidget(
                                          opt.icon!,
                                          size: 18,
                                          color: fg,
                                        ),
                                        const SizedBox(width: 10),
                                      ],
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              opt.label,
                                              style: TextStyle(
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w600,
                                                color: fg,
                                              ),
                                            ),
                                            if (opt.subtitle != null &&
                                                opt.subtitle!.isNotEmpty) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                opt.subtitle!,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: tokens.inkMuted,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      if (active)
                                        InkIconWidget(
                                          InkIcon.check,
                                          size: 16,
                                          color: tokens.accentPrimary,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// Modern frosted FloatingCard modal dialog rendered on the root Navigator
/// (replaces legacy Material AlertDialog). Any controllers passed in [disposables]
/// are automatically disposed only after the dialog route exit animation unmounts.
Future<T?> showInkModal<T>({
  required BuildContext context,
  required String title,
  String? subtitle,
  required Widget Function(BuildContext ctx) builder,
  List<Widget> Function(BuildContext ctx)? actionsBuilder,
  List<ChangeNotifier> disposables = const [],
}) {
  return showDialog<T>(
    context: context,
    useRootNavigator: true,
    builder: (ctx) {
      final tokens = InkBoxTokens.of(ctx);
      final actions = actionsBuilder?.call(ctx) ?? const <Widget>[];
      return _InkModalLifecycle(
        disposables: disposables,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: FloatingCard(
              frosted: true,
              radius: 22,
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w700,
                      color: tokens.inkPrimary,
                    ),
                  ),
                  if (subtitle != null && subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: tokens.inkMuted),
                    ),
                  ],
                  const SizedBox(height: 14),
                  builder(ctx),
                  if (actions.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        for (var i = 0; i < actions.length; i++) ...[
                          if (i > 0) const SizedBox(width: 8),
                          actions[i],
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        ),
      );
    },
  );
}

class _InkModalLifecycle extends StatefulWidget {
  const _InkModalLifecycle({
    required this.disposables,
    required this.child,
  });

  final List<ChangeNotifier> disposables;
  final Widget child;

  @override
  State<_InkModalLifecycle> createState() => _InkModalLifecycleState();
}

class _InkModalLifecycleState extends State<_InkModalLifecycle> {
  @override
  void dispose() {
    for (final d in widget.disposables) {
      d.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
