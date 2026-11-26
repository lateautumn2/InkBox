import 'package:material_ui/material_ui.dart';

const double kCompactMaxWidth = 600.0;
const double kExpandedMinWidth = 840.0;
const double kDualPageMinWidth = 680.0;
const double kForcedDualMinWidth = 540.0;
const double kMaxContentWidth = 760.0;
const double kMaxModalWidth = 460.0;
const double kMaxSingleReaderWidth = 640.0;

bool isWideLayout(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= kCompactMaxWidth;

bool isExpandedLayout(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= kExpandedMinWidth;

SliverGridDelegateWithMaxCrossAxisExtent adaptiveShelfGridDelegate(
  BuildContext context, {
  double childAspectRatio = 0.62,
}) {
  return SliverGridDelegateWithMaxCrossAxisExtent(
    maxCrossAxisExtent: 136,
    mainAxisSpacing: 12,
    crossAxisSpacing: 10,
    childAspectRatio: childAspectRatio,
  );
}

class ResponsiveConstrainedBody extends StatelessWidget {
  const ResponsiveConstrainedBody({
    super.key,
    required this.child,
    this.maxWidth = kMaxContentWidth,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width <= maxWidth) return child;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
