import 'package:material_ui/material_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Hand-drawn monochrome ink icon catalog (zero full-color fills / zero emojis).
enum InkIcon {
  bookshelf,
  manga,
  importTray,
  syncCloud,
  search,
  grid,
  list,
  sort,
  toc,
  bookmark,
  tts,
  typography,
  pageCurl,
  moon,
  sun,
  crop,
  filter,
  folder,
  file,
  note,
  gear,
  back,
  play,
  plus,
  refresh,
  rotate,
  more,
  check,
  spark,
  floatingCard,
  user,
  trash,
  history,
  chevronRight,
  chevronDown,
  bookmarkFilled,
  highlight,
  close,
  language,
  pause,
  skipPrev,
  skipNext,
  dualPage,
  brightness,
  info,
}

/// Renders a bespoke hand-drawn monochrome ink line-art SVG icon that
/// automatically adapts to light warm paper, dark theater, and active accents.
class InkIconWidget extends StatelessWidget {
  const InkIconWidget(
    this.icon, {
    super.key,
    this.size = 22,
    this.color,
    this.strokeWidth = 1.65,
  });

  final InkIcon icon;
  final double size;
  final Color? color;
  final double strokeWidth;

  static String buildSvg(
    InkIcon icon, {
    required String strokeHex,
    double strokeWidth = 1.65,
  }) {
    final body = (_paths[icon] ?? _paths[InkIcon.bookshelf]!)
        .replaceAll('{ink}', strokeHex);
    return '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none"
     stroke="$strokeHex" stroke-width="$strokeWidth"
     stroke-linecap="round" stroke-linejoin="round">
  $body
</svg>
''';
  }

  @override
  Widget build(BuildContext context) {
    final resolved =
        color ?? IconTheme.of(context).color ?? Theme.of(context).colorScheme.onSurface;
    final r = (resolved.r * 255).round().toRadixString(16).padLeft(2, '0');
    final g = (resolved.g * 255).round().toRadixString(16).padLeft(2, '0');
    final b = (resolved.b * 255).round().toRadixString(16).padLeft(2, '0');
    final hex = '#$r$g$b';

    return Opacity(
      opacity: resolved.a,
      child: SvgPicture.string(
        buildSvg(icon, strokeHex: hex, strokeWidth: strokeWidth),
        width: size,
        height: size,
        semanticsLabel: icon.name,
      ),
    );
  }

  static const Map<InkIcon, String> _paths = {
    InkIcon.bookshelf:
        '<path d="M4.3 5.2c1.2-.1 2.4-.1 3.5.1.1 4.4.1 8.8 0 13.2-1.2.1-2.4.1-3.5 0-.1-4.4-.1-8.9 0-13.3Z"/>'
        '<path d="M8.9 5.5c1.3-.1 2.5-.1 3.7.1.1 4.3.1 8.7 0 13-1.2.1-2.5.1-3.7 0-.1-4.4-.1-8.7 0-13.1Z"/>'
        '<path d="M14.1 6.1c1.2-.3 2.4-.5 3.6-.7.9 4.2 1.7 8.4 2.5 12.6-1.2.3-2.4.5-3.6.7-.8-4.2-1.7-8.4-2.5-12.6Z"/>'
        '<path d="M3.4 19.6c5.8-.1 11.5.1 17.2 0"/>',
    InkIcon.manga:
        '<path d="M4.5 5.2c4.8-.4 10.1-.2 14.9.1.4 3.8.2 7.8-.1 11.4-2.8.2-5.7.1-8.4.2l-3.8 2.9.6-3c-1.1-.1-2.2-.1-3.2-.2-.3-3.7-.2-7.6 0-11.4Z"/>'
        '<path d="M7.8 9.2c1.6-.1 3.3-.1 4.9.1"/>'
        '<path d="M7.9 12.6c2.4.1 5.2-.1 7.4-.1"/>',
    InkIcon.importTray:
        '<path d="M12.1 3.8c-.1 3.5.1 7.1 0 10.6"/>'
        '<path d="M8.6 11.2c1.2 1.2 2.3 2.5 3.5 3.6 1.2-1.2 2.4-2.4 3.5-3.7"/>'
        '<path d="M4.6 14.8c-.1 1.7.1 3.5.3 4.8 4.6.3 9.6.2 14.2-.1.2-1.4.3-3.1.2-4.7"/>',
    InkIcon.syncCloud:
        '<path d="M6.8 16.8c-2.2-.2-3.7-1.8-3.6-3.9.1-1.9 1.5-3.3 3.4-3.6.7-2.6 3.1-4.3 5.8-4.1 2.5.2 4.5 2 4.9 4.4 1.8.4 3.2 1.9 3.1 3.7-.1 2-1.7 3.5-3.8 3.5"/>'
        '<path d="M9.4 14.6a2.9 2.9 0 0 1 4.8-1.1"/>'
        '<path d="M14.5 11.9l-.1 1.8-1.8-.2"/>'
        '<path d="M14.5 15.8a2.9 2.9 0 0 1-4.7 1.1"/>'
        '<path d="M9.5 18.4l.1-1.8 1.8.2"/>',
    InkIcon.search:
        '<path d="M10.7 4.4c3.6-.1 6.4 2.7 6.3 6.2-.1 3.5-2.9 6.3-6.4 6.2-3.5-.1-6.2-2.9-6.1-6.4.1-3.4 2.8-5.9 6.2-6Z"/>'
        '<path d="M15.4 15.5c1.4 1.3 2.8 2.8 4.2 4.1"/>',
    InkIcon.grid:
        '<path d="M4.5 4.8c1.9-.2 3.9-.1 5.6 0 .1 1.9.1 3.8 0 5.5-1.8.1-3.7.2-5.6 0-.1-1.8-.1-3.7 0-5.5Z"/>'
        '<path d="M13.9 4.7c1.9-.1 3.8-.1 5.6.1.1 1.8.1 3.7 0 5.5-1.8.1-3.8.1-5.6 0-.1-1.9-.1-3.8 0-5.6Z"/>'
        '<path d="M4.6 13.9c1.8-.1 3.7-.1 5.5 0 .1 1.9.1 3.8 0 5.6-1.8.1-3.7.1-5.5 0-.1-1.9-.1-3.8 0-5.6Z"/>'
        '<path d="M13.9 14c1.9-.1 3.8-.1 5.6 0 .1 1.8.1 3.7 0 5.5-1.8.1-3.8.1-5.6 0-.1-1.8-.1-3.7 0-5.5Z"/>',
    InkIcon.list:
        '<path d="M5.2 6.8h.5M9.2 6.7c3.2-.2 6.5-.1 9.7 0"/>'
        '<path d="M5.1 12h.6M9.1 12c3.3-.1 6.6.1 9.8 0"/>'
        '<path d="M5.2 17.3h.5M9.2 17.2c3.1-.1 6.4 0 9.6-.1"/>',
    InkIcon.sort:
        '<path d="M7.6 5.1c-.1 4.6.1 9.3 0 13.8"/>'
        '<path d="M4.8 15.8c1 1.1 1.9 2.2 2.8 3.2.9-1 1.9-2.1 2.8-3.1"/>'
        '<path d="M16.4 18.9c.1-4.6-.1-9.3 0-13.8"/>'
        '<path d="M13.6 8.2c1-1.1 1.9-2.2 2.8-3.2.9 1 1.9 2.1 2.8 3.1"/>',
    InkIcon.toc:
        '<path d="M5.2 6.5c4.6-.2 9.1-.1 13.6 0"/>'
        '<path d="M5.3 12c3.8-.1 7.6 0 11.4-.1"/>'
        '<path d="M5.2 17.4c4.2-.1 8.5.1 12.7 0"/>',
    InkIcon.bookmark:
        '<path d="M6.8 4.4c3.5-.3 7-.2 10.4 0 .2 5 .1 10.1.2 15.2-1.8-1.4-3.6-2.7-5.4-4-1.8 1.3-3.6 2.7-5.3 4 .1-5.1-.1-10.2.1-15.2Z"/>',
    InkIcon.tts:
        '<path d="M4.8 13.8c-.2-4.6 3.1-8.5 7.3-8.4 4.2.1 7.4 3.9 7.1 8.5"/>'
        '<path d="M4.7 13.5c1.3-.1 2.6.2 2.8 1.5.2 1.4.2 2.8-.2 3.9-1.2.3-2.5.1-2.8-1.2-.2-1.4-.1-2.8.2-4.2Z"/>'
        '<path d="M19.3 13.5c-1.3-.1-2.6.2-2.8 1.5-.2 1.4-.2 2.8.2 3.9 1.2.3 2.5.1 2.8-1.2.2-1.4.1-2.8-.2-4.2Z"/>',
    InkIcon.typography:
        '<path d="M4.8 17.8c1.4-3.8 2.9-7.7 4.4-11.5 1.4 3.9 2.9 7.7 4.2 11.6"/>'
        '<path d="M6.4 13.8c1.8-.1 3.7-.1 5.5 0"/>'
        '<path d="M15.4 11.8c1.1-.8 2.8-.7 3.4.5.5 1.1.3 3.4.4 5.3"/>'
        '<path d="M19 14.3c-1.6-.2-3.5.3-3.7 1.8-.2 1.5 1.8 2.1 3.6.9"/>',
    InkIcon.pageCurl:
        '<path d="M5.4 4.5c3.7-.2 7.5-.1 11.2 0 .2 4.9.1 9.8.1 14.8-3.8.2-7.5.1-11.3 0-.1-5-.1-9.9 0-14.8Z"/>'
        '<path d="M16.7 13.6c-1.8.2-3.6.3-4.6 1.5-.9 1.1-1 2.6-.9 4.2"/>',
    InkIcon.moon:
        '<path d="M17.8 14.8c-1.6.9-3.6 1.1-5.4.4-2.8-1-4.5-3.8-4.1-6.8.3-1.8 1.2-3.3 2.6-4.3-3.5.3-6.4 3.2-6.6 6.8-.2 4.1 3 7.6 7.1 7.9 2.8.2 5.4-1.3 6.4-4Z"/>',
    InkIcon.sun:
        '<circle cx="12" cy="12" r="3.6"/>'
        '<path d="M12 4.2v1.9M12 17.9v1.9M4.2 12h1.9M17.9 12h1.9M6.5 6.5l1.3 1.4M16.2 16.2l1.3 1.3M17.5 6.5l-1.3 1.3M7.8 16.2l-1.3 1.3"/>',
    InkIcon.crop:
        '<path d="M7.6 4.2c-.1 4.2 0 8.5.1 12.6 4.1.1 8.3 0 12.4-.1"/>'
        '<path d="M4.1 7.6c4.2-.1 8.4-.1 12.6 0 .1 4.1.1 8.2 0 12.3"/>',
    InkIcon.filter:
        '<path d="M5 7.4h14M5 12.2h14M5 17h14"/>'
        '<circle cx="9.2" cy="7.4" r="1.8"/>'
        '<circle cx="15.2" cy="12.2" r="1.8"/>'
        '<circle cx="10.8" cy="17" r="1.8"/>',
    InkIcon.folder:
        '<path d="M4.2 6.6c1.9-.2 3.7-.1 5.5 0l1.8 2c2.8-.1 5.6 0 8.3.1.2 3.4.1 6.9 0 10.3-5.2.2-10.4.2-15.6 0-.2-4.1-.1-8.3 0-12.4Z"/>',
    InkIcon.file:
        '<path d="M6.4 4.3c2.9-.1 5.7-.1 8.5 0l3.1 3.3c.1 4.1.1 8.1 0 12.1-3.9.2-7.8.1-11.6 0-.2-5.1-.1-10.3 0-15.4Z"/>'
        '<path d="M14.6 4.4c-.1 1.2 0 2.4.1 3.5 1.1.1 2.2.1 3.3 0"/>',
    InkIcon.note:
        '<path d="M15.8 4.8c1.1 1.1 2.3 2.2 3.3 3.4-3.3 3.4-6.7 6.8-10.1 10.1-1.5.4-3 .7-4.5 1 .4-1.5.8-3 1.2-4.5 3.4-3.3 6.7-6.7 10.1-10Z"/>'
        '<path d="M13.6 7.1l3.2 3.2"/>',
    InkIcon.gear:
        '<circle cx="12" cy="12" r="3.1"/>'
        '<path d="M12 4.3v2.1M12 17.6v2.1M4.3 12h2.1M17.6 12h2.1M6.6 6.6l1.5 1.5M15.9 15.9l1.5 1.5M17.4 6.6l-1.5 1.5M8.1 15.9l-1.5 1.5"/>',
    InkIcon.back:
        '<path d="M14.8 6.1c-2 2-4.1 3.9-6 5.9 1.9 2 4 4 6 5.9"/>',
    InkIcon.play:
        '<path d="M8.2 6.2c3.3 1.9 6.6 3.8 9.8 5.8-3.3 1.9-6.5 3.9-9.8 5.8-.1-3.9-.1-7.7 0-11.6Z"/>',
    InkIcon.plus:
        '<path d="M12 5.4c-.1 4.4.1 8.8 0 13.2"/>'
        '<path d="M5.4 12c4.4-.1 8.8.1 13.2 0"/>',
    InkIcon.refresh:
        '<path d="M18.6 11.4a6.7 6.7 0 1 1-1.9-4.7"/>'
        '<path d="M17.3 4.2l.2 3.3-3.3-.2"/>',
    InkIcon.rotate:
        '<path d="M6.2 7.8c2.6-2.5 6.8-2.6 9.5-.1 1.6 1.5 2.4 3.6 2.2 5.7"/>'
        '<path d="M17.8 16.2c-2.6 2.5-6.8 2.6-9.5.1-1.6-1.5-2.4-3.6-2.2-5.7"/>'
        '<path d="M14.9 4.8l1.7 3-3.1.8"/>',
    InkIcon.more:
        '<circle cx="6.5" cy="12" r="1.2"/>'
        '<circle cx="12" cy="12" r="1.2"/>'
        '<circle cx="17.5" cy="12" r="1.2"/>',
    InkIcon.check:
        '<path d="M5.6 12.4c1.5 1.4 2.9 2.9 4.3 4.4 2.8-3.3 5.7-6.5 8.6-9.7"/>',
    InkIcon.spark:
        '<path d="M12 4.3c.6 3.5 2.1 5.5 5.7 6.2-3.6.7-5.1 2.6-5.7 6.2-.6-3.6-2.1-5.5-5.7-6.2 3.6-.7 5.1-2.7 5.7-6.2Z"/>',
    InkIcon.floatingCard:
        '<path d="M5.2 6.4c4.5-.2 9.1-.1 13.6 0 .2 3.4.1 6.8 0 10.2-4.5.2-9.1.2-13.6 0-.2-3.4-.1-6.8 0-10.2Z"/>'
        '<path d="M7.5 19.6c3 .1 6 .1 9 0"/>',
    InkIcon.user:
        '<circle cx="12" cy="8.2" r="3.4"/>'
        '<path d="M5.4 19.4c.5-3.4 3.2-5.4 6.6-5.4 3.4 0 6.1 2 6.6 5.4"/>',
    InkIcon.trash:
        '<path d="M5.2 7.2c4.5-.2 9.1-.2 13.6 0"/>'
        '<path d="M9.4 7.1V5.2c1.7-.2 3.5-.2 5.2 0v1.9"/>'
        '<path d="M7.1 7.4l.7 11.7c2.8.2 5.6.2 8.4 0l.7-11.7"/>'
        '<path d="M10.4 10.6v5.4M13.6 10.6v5.4"/>',
    InkIcon.history:
        '<path d="M5.4 11.8a6.8 6.8 0 1 1 2 5.1"/>'
        '<path d="M5.2 7.6l.2 4.2 4-.8"/>'
        '<path d="M12.1 8.4v4l2.7 1.7"/>',
    InkIcon.chevronRight:
        '<path d="M9.4 6.2c2 1.9 4.1 3.9 6 5.8-1.9 2-4 3.9-6 5.8"/>',
    InkIcon.chevronDown:
        '<path d="M6.2 9.4c1.9 2 3.9 4.1 5.8 6 2-1.9 3.9-4 5.8-6"/>',
    InkIcon.bookmarkFilled:
        '<path d="M6.8 4.4c3.5-.3 7-.2 10.4 0 .2 5 .1 10.1.2 15.2-1.8-1.4-3.6-2.7-5.4-4-1.8 1.3-3.6 2.7-5.3 4 .1-5.1-.1-10.2.1-15.2Z" fill="{ink}"/>',
    InkIcon.highlight:
        '<path d="M14.8 4.6l4.6 4.6-8.4 8.4-4.6.6.6-4.6 7.8-9Z"/>'
        '<path d="M4.2 20h15.6"/>',
    InkIcon.close:
        '<path d="M6.8 6.8l10.4 10.4M17.2 6.8L6.8 17.2"/>',
    InkIcon.language:
        '<circle cx="12" cy="12" r="7.5"/>'
        '<path d="M4.8 12h14.4M12 4.5c2.4 2.1 3.7 4.7 3.7 7.5s-1.3 5.4-3.7 7.5c-2.4-2.1-3.7-4.7-3.7-7.5s1.3-5.4 3.7-7.5Z"/>',
    InkIcon.pause:
        '<path d="M9.2 6.6v10.8M14.8 6.6v10.8"/>',
    InkIcon.skipPrev:
        '<path d="M7.2 6.8v10.4"/>'
        '<path d="M16.8 6.8c-2.7 1.7-5.3 3.4-7.9 5.2 2.6 1.8 5.2 3.5 7.9 5.2V6.8Z"/>',
    InkIcon.skipNext:
        '<path d="M16.8 6.8v10.4"/>'
        '<path d="M7.2 6.8c2.7 1.7 5.3 3.4 7.9 5.2-2.6 1.8-5.2 3.5-7.9 5.2V6.8Z"/>',
    InkIcon.dualPage:
        '<path d="M4.2 5.6c2.6-.2 5.2-.1 7.8.6v12.2c-2.6-.7-5.2-.8-7.8-.6V5.6Z"/>'
        '<path d="M19.8 5.6c-2.6-.2-5.2-.1-7.8.6v12.2c2.6-.7 5.2-.8 7.8-.6V5.6Z"/>',
    InkIcon.brightness:
        '<circle cx="12" cy="12" r="3.4"/>'
        '<path d="M12 4.6v1.6M12 17.8v1.6M4.6 12h1.6M17.8 12h1.6"/>',
    InkIcon.info:
        '<circle cx="12" cy="12" r="7.6"/>'
        '<path d="M12 11.2v4.8"/>'
        '<circle cx="12" cy="8.1" r=".7" fill="{ink}"/>',
  };
}

