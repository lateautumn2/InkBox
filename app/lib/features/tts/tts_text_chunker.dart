class TtsSentenceChunk {
  const TtsSentenceChunk({
    required this.index,
    required this.startOffset,
    required this.endOffset,
    required this.text,
  });

  final int index;
  final int startOffset;
  final int endOffset;
  final String text;
}

/// Splits displayed text into natural spoken sentences (~20..140 chars) while
/// retaining exact global `[startOffset, endOffset]` coordinates for live
/// sentence-level highlighting in [ReaderHighlightCanvas].
class TtsTextChunker {
  static final RegExp _boundaryChars = RegExp(r'[。！？；.!?\n]');

  static List<TtsSentenceChunk> split(
    String rawText, {
    int baseOffset = 0,
    int minLen = 18,
    int maxLen = 140,
  }) {
    if (rawText.trim().isEmpty) return const [];

    final chunks = <TtsSentenceChunk>[];
    var cursor = 0;
    final total = rawText.length;

    while (cursor < total) {
      while (cursor < total && _isSkippable(rawText.codeUnitAt(cursor))) {
        cursor++;
      }
      if (cursor >= total) break;

      var end = cursor;
      var foundEnd = -1;
      final hardLimit = (cursor + maxLen).clamp(cursor, total);

      for (var i = cursor; i < hardLimit; i++) {
        final ch = rawText[i];
        if (_boundaryChars.hasMatch(ch)) {
          final currentLen = i - cursor + 1;
          if (currentLen >= minLen || ch == '\n') {
            foundEnd = i + 1;
            break;
          }
          foundEnd = i + 1;
        }
      }

      if (foundEnd > cursor) {
        end = foundEnd;
      } else if (hardLimit < total) {
        // Look backward inside [cursor + minLen, hardLimit] for comma or space
        var softBreak = -1;
        for (var i = hardLimit - 1; i >= cursor + minLen && i > cursor; i--) {
          final c = rawText[i];
          if (c == '，' || c == ',' || c == ' ' || c == '、') {
            softBreak = i + 1;
            break;
          }
        }
        end = softBreak > cursor ? softBreak : hardLimit;
      } else {
        end = total;
      }

      var trimStart = cursor;
      var trimEnd = end;
      while (trimStart < trimEnd &&
          _isSkippable(rawText.codeUnitAt(trimStart))) {
        trimStart++;
      }
      while (trimEnd > trimStart &&
          _isSkippable(rawText.codeUnitAt(trimEnd - 1))) {
        trimEnd--;
      }

      if (trimEnd > trimStart) {
        final slice = rawText.substring(trimStart, trimEnd);
        final speakable = slice.replaceAll(RegExp(r'\s+'), ' ').trim();
        if (speakable.isNotEmpty) {
          chunks.add(
            TtsSentenceChunk(
              index: chunks.length,
              startOffset: baseOffset + trimStart,
              endOffset: baseOffset + trimEnd,
              text: speakable,
            ),
          );
        }
      }
      cursor = end;
    }

    return chunks;
  }

  static bool _isSkippable(int code) {
    return code == 0x20 ||
        code == 0x09 ||
        code == 0x0A ||
        code == 0x0D ||
        code == 0x3000;
  }
}
