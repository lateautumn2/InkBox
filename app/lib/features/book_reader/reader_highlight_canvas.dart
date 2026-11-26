import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/db/app_database.dart';

const List<String> kReaderHighlightColors = [
  '#EED29A', // 暖琥珀
  '#F2A6A6', // 淡朱砂
  '#A8D5BA', // 竹青绿
  '#A2C8EC', // 晴空蓝
  '#C9B6E4', // 暮山紫
];

Color parseHexColor(String hex, {Color fallback = const Color(0xFFEED29A)}) {
  final cleaned = hex.trim().replaceFirst('#', '');
  if (cleaned.length == 6) {
    final val = int.tryParse('FF$cleaned', radix: 16);
    if (val != null) return Color(val);
  } else if (cleaned.length == 8) {
    final val = int.tryParse(cleaned, radix: 16);
    if (val != null) return Color(val);
  }
  return fallback;
}

class ParsedAnnotationLocator {
  const ParsedAnnotationLocator({required this.startOffset, this.endOffset});
  final int startOffset;
  final int? endOffset;

  static ParsedAnnotationLocator parse(String locator) {
    final startMatch = RegExp(r'off:(\d+)').firstMatch(locator);
    final endMatch = RegExp(r'end:(\d+)').firstMatch(locator);
    return ParsedAnnotationLocator(
      startOffset: int.tryParse(startMatch?.group(1) ?? '') ?? 0,
      endOffset: int.tryParse(endMatch?.group(1) ?? ''),
    );
  }
}

class ResolvedHighlightSpan {
  const ResolvedHighlightSpan({
    required this.localStart,
    required this.localEnd,
    required this.annotation,
  });

  final int localStart;
  final int localEnd;
  final Annotation annotation;
}

/// Interactive book text canvas supporting:
/// - Rich underline + background highlight rendering for saved `highlight` & `note` annotations
/// - Long-press character-accurate text selection + live drag extension
/// - Draggable start/end selection handles for fine-tuning selected range
/// - Tap hit-testing on existing highlights without interfering with 9-grid tap zones or page curl
class ReaderHighlightCanvas extends StatefulWidget {
  const ReaderHighlightCanvas({
    super.key,
    required this.text,
    required this.baseOffset,
    required this.style,
    required this.isDarkPaper,
    required this.accentColor,
    required this.chapterHighlights,
    this.selectedColorHex,
    this.activeSelectionGlobal,
    this.interactive = true,
    this.onSelectionChanged,
    this.onHighlightTapped,
    this.onDismissSelection,
  });

  final String text;
  final int baseOffset;
  final TextStyle style;
  final bool isDarkPaper;
  final Color accentColor;
  final List<Annotation> chapterHighlights;
  final String? selectedColorHex;
  final ({int start, int end})? activeSelectionGlobal;
  final bool interactive;
  final void Function(int globalStart, int globalEnd, String selectedText)?
      onSelectionChanged;
  final ValueChanged<Annotation>? onHighlightTapped;
  final VoidCallback? onDismissSelection;

  /// Picks a natural initial clause/sentence at the beginning of [text] (used when
  /// entering highlight selection via the top toolbar button).
  static ({int localStart, int localEnd}) selectInitialClause(String text) {
    if (text.isEmpty) return (localStart: 0, localEnd: 0);
    var s = 0;
    while (s < text.length && _isWhitespaceOrBreak(text.codeUnitAt(s))) {
      s++;
    }
    if (s >= text.length) return (localStart: 0, localEnd: text.length);
    return selectClauseAround(text, s);
  }

  /// Selects the natural clause / phrase surrounding [charIndex] inside [text].
  static ({int localStart, int localEnd}) selectClauseAround(
    String text,
    int charIndex,
  ) {
    if (text.isEmpty) return (localStart: 0, localEnd: 0);
    final idx = charIndex.clamp(0, text.length - 1);
    var start = idx;
    var end = idx + 1;

    while (start > 0 &&
        idx - start < 22 &&
        !_isClauseStop(text.codeUnitAt(start - 1))) {
      start--;
    }
    while (end < text.length &&
        end - start < 36 &&
        !_isClauseStop(text.codeUnitAt(end))) {
      end++;
    }

    // Trim leading full-width indent or spaces inside the selected clause
    while (start < end - 1 && _isWhitespaceOrBreak(text.codeUnitAt(start))) {
      start++;
    }
    while (end > start + 1 && _isWhitespaceOrBreak(text.codeUnitAt(end - 1))) {
      end--;
    }

    if (end <= start) {
      final safeS = idx.clamp(0, text.length - 1);
      final safeE = (safeS + 1).clamp(1, text.length);
      return (localStart: safeS, localEnd: safeE);
    }
    return (localStart: start, localEnd: end);
  }

  static bool _isWhitespaceOrBreak(int code) {
    return code == 0x20 ||
        code == 0x09 ||
        code == 0x0A ||
        code == 0x0D ||
        code == 0x3000;
  }

  static bool _isClauseStop(int code) {
    // Common Chinese & ASCII clause/sentence boundaries
    const stops = '，。！？；：、“”‘’（）《》【】\n\r,.!?;:';
    return stops.codeUnits.contains(code);
  }

  static bool _isCjkIdeograph(int code) {
    return (code >= 0x4E00 && code <= 0x9FFF) ||
        (code >= 0x3400 && code <= 0x4DBF) ||
        (code >= 0xF900 && code <= 0xFAFF);
  }

  /// Checks whether [sub] matches [excerpt] at [offsetInExcerpt] across
  /// Simplified ↔ Traditional Chinese 1-to-1 character conversion while
  /// preserving exact punctuation, whitespace, ASCII, and length structure.
  static bool _isScriptConvertedMatch(
    String sub,
    String excerpt, {
    required int offsetInExcerpt,
  }) {
    if (sub.isEmpty || excerpt.isEmpty) return false;
    if (offsetInExcerpt < 0 || offsetInExcerpt + sub.length > excerpt.length) {
      return false;
    }
    for (var i = 0; i < sub.length; i++) {
      final a = sub.codeUnitAt(i);
      final b = excerpt.codeUnitAt(offsetInExcerpt + i);
      if (a == b) continue;
      if (_isCjkIdeograph(a) && _isCjkIdeograph(b)) continue;
      return false;
    }
    return true;
  }

  /// Finds [target] inside [text] ignoring whitespace/indent differences (e.g. when
  /// `indentFirstLine` is toggled across multi-paragraph highlights).
  static ({int start, int end})? _findIgnoringWhitespace(
    String text,
    String target,
    int expectedLocal,
  ) {
    final compactTargetBuf = StringBuffer();
    for (var i = 0; i < target.length; i++) {
      final c = target.codeUnitAt(i);
      if (!_isWhitespaceOrBreak(c)) compactTargetBuf.writeCharCode(c);
    }
    final compactTarget = compactTargetBuf.toString();
    if (compactTarget.isEmpty) return null;

    final compactTextBuf = StringBuffer();
    final rawIndices = <int>[];
    for (var i = 0; i < text.length; i++) {
      final c = text.codeUnitAt(i);
      if (!_isWhitespaceOrBreak(c)) {
        compactTextBuf.writeCharCode(c);
        rawIndices.add(i);
      }
    }
    final compactText = compactTextBuf.toString();
    if (compactText.length < compactTarget.length) return null;

    int bestRawStart = -1;
    int bestRawEnd = -1;
    int bestDist = 1 << 30;
    var searchFrom = 0;
    while (searchFrom <= compactText.length - compactTarget.length) {
      final hit = compactText.indexOf(compactTarget, searchFrom);
      if (hit < 0) break;
      final rawS = rawIndices[hit];
      final rawE = rawIndices[hit + compactTarget.length - 1] + 1;
      final dist = (rawS - expectedLocal).abs();
      if (dist < bestDist) {
        bestDist = dist;
        bestRawStart = rawS;
        bestRawEnd = rawE;
      }
      searchFrom = hit + 1;
    }
    if (bestRawStart >= 0 && bestRawEnd > bestRawStart) {
      return (start: bestRawStart, end: bestRawEnd);
    }
    return null;
  }

  /// Resolves chapter-level `highlight`/`note` annotations into local `[0, text.length]` spans.
  static List<ResolvedHighlightSpan> resolveHighlights({
    required String text,
    required int baseOffset,
    required List<Annotation> chapterHighlights,
  }) {
    if (text.isEmpty || chapterHighlights.isEmpty) return const [];
    final sliceEnd = baseOffset + text.length;
    final resolved = <ResolvedHighlightSpan>[];

    for (final ann in chapterHighlights) {
      if (ann.isDeleted || (ann.kind != 'highlight' && ann.kind != 'note')) {
        continue;
      }
      final loc = ParsedAnnotationLocator.parse(ann.locator);
      int? foundStart;
      int? foundEnd;

      if (loc.endOffset != null && loc.endOffset! > loc.startOffset) {
        final overlapStart = math.max(loc.startOffset, baseOffset);
        final overlapEnd = math.min(loc.endOffset!, sliceEnd);
        if (overlapEnd > overlapStart) {
          final ls = overlapStart - baseOffset;
          final le = overlapEnd - baseOffset;
          final sub = text.substring(ls, le);
          if (ann.excerpt.isEmpty ||
              ann.excerpt.contains(sub) ||
              sub.contains(ann.excerpt) ||
              _isScriptConvertedMatch(
                sub,
                ann.excerpt,
                offsetInExcerpt: overlapStart - loc.startOffset,
              )) {
            foundStart = ls;
            foundEnd = le;
          }
        }
      }

      if (foundStart == null && ann.excerpt.trim().isNotEmpty) {
        final target = ann.excerpt.trim();
        final expectedLocal = loc.startOffset - baseOffset;
        int bestPos = -1;
        int bestDist = 1 << 30;
        var searchFrom = 0;
        while (searchFrom <= text.length - target.length) {
          final hit = text.indexOf(target, searchFrom);
          if (hit < 0) break;
          final dist = (hit - expectedLocal).abs();
          if (dist < bestDist) {
            bestDist = dist;
            bestPos = hit;
          }
          searchFrom = hit + 1;
        }
        if (bestPos >= 0) {
          foundStart = bestPos;
          foundEnd = (bestPos + target.length).clamp(bestPos + 1, text.length);
        } else {
          final wsMatch = _findIgnoringWhitespace(text, target, expectedLocal);
          if (wsMatch != null) {
            foundStart = wsMatch.start;
            foundEnd = wsMatch.end;
          }
        }
      }

      if (foundStart != null &&
          foundEnd != null &&
          foundEnd > foundStart &&
          foundStart < text.length) {
        resolved.add(
          ResolvedHighlightSpan(
            localStart: foundStart.clamp(0, text.length),
            localEnd: foundEnd.clamp(0, text.length),
            annotation: ann,
          ),
        );
      }
    }

    resolved.sort((a, b) => a.localStart.compareTo(b.localStart));
    return resolved;
  }

  @override
  State<ReaderHighlightCanvas> createState() => ReaderHighlightCanvasState();
}

class ReaderHighlightCanvasState extends State<ReaderHighlightCanvas> {
  double _lastMaxWidth = 300.0;
  int _longPressAnchorLocal = 0;
  int _handleDragFixedLocal = 0;

  ({int start, int end})? get _localSelection {
    final g = widget.activeSelectionGlobal;
    if (g == null || widget.text.isEmpty) return null;
    final sliceEnd = widget.baseOffset + widget.text.length;
    if (g.end <= widget.baseOffset || g.start >= sliceEnd) return null;
    final ls = (g.start - widget.baseOffset).clamp(0, widget.text.length);
    final le = (g.end - widget.baseOffset).clamp(0, widget.text.length);
    if (le <= ls) return null;
    return (start: ls, end: le);
  }

  TextPainter _layoutPainter(double maxWidth) {
    return TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth <= 0 ? 1.0 : maxWidth);
  }

  int _offsetForLocalPos(Offset localPos) {
    if (widget.text.isEmpty) return 0;
    final tp = _layoutPainter(_lastMaxWidth);
    return tp.getPositionForOffset(localPos).offset.clamp(0, widget.text.length);
  }

  /// Checks whether [globalPos] taps inside an existing highlighted span on this canvas.
  /// Returns `true` and triggers [onHighlightTapped] if matched; otherwise `false`.
  bool tryHandleTapAtGlobal(Offset globalPos) {
    if (!mounted || !widget.interactive || widget.text.isEmpty) return false;
    final ro = context.findRenderObject();
    if (ro is! RenderBox || !ro.hasSize) return false;
    final local = ro.globalToLocal(globalPos);
    if (local.dx < 0 ||
        local.dy < 0 ||
        local.dx > ro.size.width ||
        local.dy > ro.size.height) {
      return false;
    }

    final highlights = ReaderHighlightCanvas.resolveHighlights(
      text: widget.text,
      baseOffset: widget.baseOffset,
      chapterHighlights: widget.chapterHighlights,
    );
    if (highlights.isEmpty) return false;

    final tp = _layoutPainter(ro.size.width);
    for (final h in highlights.reversed) {
      final boxes = tp.getBoxesForSelection(
        TextSelection(baseOffset: h.localStart, extentOffset: h.localEnd),
      );
      for (final box in boxes) {
        if (box.toRect().inflate(4.0).contains(local)) {
          widget.onHighlightTapped?.call(h.annotation);
          return true;
        }
      }
    }
    return false;
  }

  void _emitLocalSelection(int a, int b) {
    if (widget.text.isEmpty || widget.onSelectionChanged == null) return;
    var s = math.min(a, b).clamp(0, widget.text.length - 1);
    var e = math.max(a, b).clamp(s + 1, widget.text.length);
    // Trim leading/trailing whitespace & full-width indent so offsets match excerpt 1:1
    while (s < e - 1 &&
        ReaderHighlightCanvas._isWhitespaceOrBreak(widget.text.codeUnitAt(s))) {
      s++;
    }
    while (e > s + 1 &&
        ReaderHighlightCanvas._isWhitespaceOrBreak(
            widget.text.codeUnitAt(e - 1))) {
      e--;
    }
    // Avoid splitting UTF-16 surrogate pairs
    if (s > 0 && (widget.text.codeUnitAt(s - 1) & 0xFC00) == 0xD800) {
      s--;
    }
    if (e < widget.text.length &&
        (widget.text.codeUnitAt(e - 1) & 0xFC00) == 0xD800) {
      e++;
    }
    final excerpt = widget.text.substring(s, e);
    if (excerpt.trim().isEmpty) return;
    widget.onSelectionChanged!(
      widget.baseOffset + s,
      widget.baseOffset + e,
      excerpt,
    );
  }

  void _onLongPressStart(LongPressStartDetails d) {
    if (widget.text.isEmpty) return;
    final idx = _offsetForLocalPos(d.localPosition);
    _longPressAnchorLocal = idx;
    final clause = ReaderHighlightCanvas.selectClauseAround(widget.text, idx);
    _emitLocalSelection(clause.localStart, clause.localEnd);
  }

  void _onLongPressMoveUpdate(LongPressMoveUpdateDetails d) {
    if (widget.text.isEmpty) return;
    final cur = _offsetForLocalPos(d.localPosition);
    if ((cur - _longPressAnchorLocal).abs() >= 2) {
      _emitLocalSelection(_longPressAnchorLocal, cur);
    }
  }

  void _onPanStart(DragStartDetails d) {
    final sel = _localSelection;
    if (sel == null) return;
    final tp = _layoutPainter(_lastMaxWidth);
    final boxes = tp.getBoxesForSelection(
      TextSelection(baseOffset: sel.start, extentOffset: sel.end),
    );
    if (boxes.isEmpty) {
      _handleDragFixedLocal = sel.start;
      return;
    }
    final startPt = Offset(
      boxes.first.left,
      (boxes.first.top + boxes.first.bottom) * 0.5,
    );
    final endPt = Offset(
      boxes.last.right,
      (boxes.last.top + boxes.last.bottom) * 0.5,
    );
    final distStart = (d.localPosition - startPt).distance;
    final distEnd = (d.localPosition - endPt).distance;
    // Pin whichever end is further from the initial touch point so the closer handle moves
    _handleDragFixedLocal = distStart <= distEnd ? sel.end : sel.start;
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_localSelection == null) return;
    final cur = _offsetForLocalPos(d.localPosition);
    if (cur != _handleDragFixedLocal) {
      _emitLocalSelection(_handleDragFixedLocal, cur);
    }
  }

  TextSpan _buildRichSpan(
    List<ResolvedHighlightSpan> highlights,
    ({int start, int end})? sel,
  ) {
    if (widget.text.isEmpty || (highlights.isEmpty && sel == null)) {
      return TextSpan(text: widget.text, style: widget.style);
    }

    // Collect all boundary cut points in [0, text.length]
    final cuts = <int>{0, widget.text.length};
    for (final h in highlights) {
      cuts.add(h.localStart);
      cuts.add(h.localEnd);
    }
    if (sel != null) {
      cuts.add(sel.start);
      cuts.add(sel.end);
    }
    final sortedCuts = cuts.toList()..sort();

    final children = <InlineSpan>[];
    for (var i = 0; i < sortedCuts.length - 1; i++) {
      final segStart = sortedCuts[i];
      final segEnd = sortedCuts[i + 1];
      if (segEnd <= segStart) continue;
      final segText = widget.text.substring(segStart, segEnd);

      final inSelection =
          sel != null && segStart >= sel.start && segEnd <= sel.end;
      ResolvedHighlightSpan? activeHl;
      for (final h in highlights) {
        if (segStart >= h.localStart && segEnd <= h.localEnd) {
          activeHl = h;
        }
      }

      if (inSelection) {
        final selColor = widget.selectedColorHex != null
            ? parseHexColor(widget.selectedColorHex!)
            : widget.accentColor;
        children.add(
          TextSpan(
            text: segText,
            style: TextStyle(
              backgroundColor: selColor.withValues(
                alpha: widget.isDarkPaper ? 0.32 : 0.42,
              ),
            ),
          ),
        );
      } else if (activeHl != null) {
        final hlColor = parseHexColor(activeHl.annotation.colorHex);
        final lineColor = Color.lerp(
          hlColor,
          widget.isDarkPaper ? Colors.white : Colors.black,
          0.22,
        )!;
        final hasNote = activeHl.annotation.noteText.trim().isNotEmpty;
        children.add(
          TextSpan(
            text: segText,
            style: TextStyle(
              backgroundColor: hlColor.withValues(
                alpha: widget.isDarkPaper ? 0.28 : 0.38,
              ),
              decoration: TextDecoration.underline,
              decorationColor: lineColor,
              decorationThickness: 2.2,
              decorationStyle:
                  hasNote ? TextDecorationStyle.wavy : TextDecorationStyle.solid,
            ),
          ),
        );
      } else {
        children.add(TextSpan(text: segText));
      }
    }

    return TextSpan(style: widget.style, children: children);
  }

  @override
  Widget build(BuildContext context) {
    final highlights = ReaderHighlightCanvas.resolveHighlights(
      text: widget.text,
      baseOffset: widget.baseOffset,
      chapterHighlights: widget.chapterHighlights,
    );
    final sel = _localSelection;
    final span = _buildRichSpan(highlights, sel);

    return LayoutBuilder(
      builder: (context, constraints) {
        _lastMaxWidth = constraints.maxWidth;
        Widget content = SizedBox(
          width: double.infinity,
          child: CustomPaint(
            foregroundPainter: sel != null
                ? _SelectionHandlesPainter(
                    text: widget.text,
                    style: widget.style,
                    selection: sel,
                    accentColor: widget.accentColor,
                  )
                : null,
            child: Text.rich(
              span,
            ),
          ),
        );

        if (!widget.interactive) return content;

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          dragStartBehavior: DragStartBehavior.down,
          onLongPressStart: _onLongPressStart,
          onLongPressMoveUpdate: _onLongPressMoveUpdate,
          onPanStart: sel != null ? _onPanStart : null,
          onPanUpdate: sel != null ? _onPanUpdate : null,
          onTapUp: sel != null ? (_) => widget.onDismissSelection?.call() : null,
          child: content,
        );
      },
    );
  }
}

class _SelectionHandlesPainter extends CustomPainter {
  const _SelectionHandlesPainter({
    required this.text,
    required this.style,
    required this.selection,
    required this.accentColor,
  });

  final String text;
  final TextStyle style;
  final ({int start, int end}) selection;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (text.isEmpty || size.width <= 0) return;
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width);

    final boxes = tp.getBoxesForSelection(
      TextSelection(baseOffset: selection.start, extentOffset: selection.end),
    );
    if (boxes.isEmpty) return;

    final first = boxes.first;
    final last = boxes.last;
    final stemPaint = Paint()
      ..color = accentColor
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    final knobPaint = Paint()..color = accentColor;

    final maxX = math.max(5.0, size.width - 5.0);
    final maxY = math.max(5.0, size.height - 5.0);

    // Start handle (left edge of first box, knob clamped inside canvas bounds)
    final sx = first.left.clamp(1.5, size.width - 1.5);
    canvas.drawLine(
      Offset(sx, first.top),
      Offset(sx, first.bottom),
      stemPaint,
    );
    canvas.drawCircle(
      Offset(sx.clamp(5.0, maxX), (first.top - 4).clamp(5.0, maxY)),
      4.8,
      knobPaint,
    );

    // End handle (right edge of last box, knob clamped inside canvas bounds)
    final ex = last.right.clamp(1.5, size.width - 1.5);
    canvas.drawLine(
      Offset(ex, last.top),
      Offset(ex, last.bottom),
      stemPaint,
    );
    canvas.drawCircle(
      Offset(ex.clamp(5.0, maxX), (last.bottom + 4).clamp(5.0, maxY)),
      4.8,
      knobPaint,
    );
  }

  @override
  bool shouldRepaint(_SelectionHandlesPainter old) =>
      old.selection != selection ||
      old.text != text ||
      old.accentColor != accentColor;
}
