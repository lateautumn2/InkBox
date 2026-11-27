import 'dart:convert';
import 'dart:io';

import 'package:material_ui/material_ui.dart';

import '../../data/db/app_database.dart';
import '../../data/ffi/rust_core_bridge.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/app_localizations_en.dart';
import '../toc_rules/toc_rules_parser.dart';
import 'book_reader_settings.dart';

class BookPageSlice {
  const BookPageSlice({
    required this.pageIndex,
    required this.startOffset,
    required this.endOffset,
    required this.text,
    this.isPlaceholder = false,
  });

  final int pageIndex;
  final int startOffset;
  final int endOffset;
  final String text;
  final bool isPlaceholder;
}

class LoadedBookChapter {
  const LoadedBookChapter({
    required this.index,
    required this.title,
    required this.text,
    this.footnotes = const [],
    this.inlineImageHrefs = const [],
  });

  final int index;
  final String title;
  final String text;
  final List<String> footnotes;
  final List<String> inlineImageHrefs;
}

class LoadedTocResult {
  const LoadedTocResult({
    required this.chapters,
    this.matchedRuleId,
    this.matchedRuleName,
    this.detectedEncoding,
    this.fileMissing = false,
  });

  final List<BookChapterRef> chapters;
  final int? matchedRuleId;
  final String? matchedRuleName;
  final String? detectedEncoding;
  final bool fileMissing;
}

/// Paginates chapter plain text accurately to viewport bounds using TextPainter,
/// preserving exact character offsets so resizing fonts never loses reading place.
class BookPaginator {
  static Set<int> spacerNewlineIndices(String text) {
    final indices = <int>{};
    var idx = text.indexOf('\n\n');
    while (idx != -1) {
      indices.add(idx + 1);
      idx = text.indexOf('\n\n', idx + 2);
    }
    return indices;
  }

  /// Builds a rich [TextSpan] where each paragraph break (`\n\n`) renders its
  /// second `\n` at exact height `paragraphSpacing` while keeping every UTF-16
  /// character offset 1:1 with [text].
  static TextSpan buildStyledSpan(
    String text,
    TextStyle style, {
    double paragraphSpacing = 12.0,
  }) {
    if (text.isEmpty || !text.contains('\n\n')) {
      return TextSpan(text: text, style: style);
    }
    final spacerHeight = paragraphSpacing.clamp(0.5, 48.0);
    final spacerStyle = style.copyWith(
      fontSize: spacerHeight,
      height: 1.0,
      letterSpacing: 0.0,
    );
    final children = <InlineSpan>[];
    var cursor = 0;
    var matchIdx = text.indexOf('\n\n');
    while (matchIdx != -1) {
      final spacerIdx = matchIdx + 1;
      if (spacerIdx > cursor) {
        children.add(TextSpan(text: text.substring(cursor, spacerIdx)));
      }
      children.add(TextSpan(text: '\n', style: spacerStyle));
      cursor = spacerIdx + 1;
      matchIdx = text.indexOf('\n\n', cursor);
    }
    if (cursor < text.length) {
      children.add(TextSpan(text: text.substring(cursor)));
    }
    return TextSpan(style: style, children: children);
  }

  static List<BookPageSlice> paginate({
    required String text,
    required double maxWidth,
    required double maxHeight,
    required TextStyle style,
    bool indentParagraphs = true,
    double paragraphSpacing = 12.0,
  }) {
    final normalized = formatParagraphs(text, indent: indentParagraphs);
    if (normalized.isEmpty || maxWidth <= 24 || maxHeight <= 24) {
      return [
        BookPageSlice(
          pageIndex: 0,
          startOffset: 0,
          endOffset: normalized.length,
          text: normalized,
          isPlaceholder: normalized.isEmpty,
        ),
      ];
    }

    final pages = <BookPageSlice>[];
    var offset = 0;
    final total = normalized.length;
    final fontSize = (style.fontSize ?? 18.0).clamp(10.0, 48.0);
    final lineHeight = (style.height ?? 1.75).clamp(1.0, 3.5);
    // Upper-bound characters that can possibly fit on a single screen (with 2.5x safety margin)
    // so TextPainter lays out O(1) text per page instead of O(N) remaining chapter text.
    final estCharsPerLine = (maxWidth / (fontSize * 0.48)).ceil();
    final estLinesPerPage = (maxHeight / (fontSize * lineHeight)).ceil() + 2;
    final baseWindow = (estCharsPerLine * estLinesPerPage * 2.5)
        .ceil()
        .clamp(1200, 6000);

    while (offset < total) {
      var windowSize = baseWindow;
      late String remaining;
      late TextPainter tp;
      while (true) {
        var windowEnd = (offset + windowSize).clamp(offset, total);
        // Never split a UTF-16 surrogate pair.
        if (windowEnd < total &&
            windowEnd > offset &&
            (normalized.codeUnitAt(windowEnd - 1) & 0xFC00) == 0xD800) {
          windowEnd--;
        }
        remaining = normalized.substring(offset, windowEnd);
        tp = TextPainter(
          text: buildStyledSpan(
            remaining,
            style,
            paragraphSpacing: paragraphSpacing,
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: maxWidth);

        if (tp.height > maxHeight || windowEnd >= total) {
          break;
        }
        windowSize *= 2;
      }

      if (tp.height <= maxHeight) {
        pages.add(
          BookPageSlice(
            pageIndex: pages.length,
            startOffset: offset,
            endOffset: offset + remaining.length,
            text: remaining.trimRight(),
          ),
        );
        break;
      }

      // Compute exact character offset at bottom-right of viewport.
      final endPos = tp.getPositionForOffset(Offset(maxWidth, maxHeight));
      var take = endPos.offset;
      if (take <= 0) {
        take = 1;
      } else {
        // Verify line fits strictly inside maxHeight so bottom line never clips.
        final probe = TextPainter(
          text: buildStyledSpan(
            remaining.substring(0, take),
            style,
            paragraphSpacing: paragraphSpacing,
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: maxWidth);
        if (probe.height > maxHeight && take > 1) {
          final lines = tp.computeLineMetrics();
          double accH = 0;
          int fittingLines = 0;
          for (final l in lines) {
            if (accH + l.height > maxHeight) break;
            accH += l.height;
            fittingLines++;
          }
          if (fittingLines > 0) {
            final safePos = tp.getPositionForOffset(
              Offset(maxWidth, (accH - 1).clamp(1, maxHeight)),
            );
            take = safePos.offset.clamp(1, remaining.length);
          }
        }
      }
      if (take < remaining.length &&
          (remaining.codeUnitAt(take - 1) & 0xFC00) == 0xD800) {
        take++;
      }

      pages.add(
        BookPageSlice(
          pageIndex: pages.length,
          startOffset: offset,
          endOffset: offset + take,
          text: remaining.substring(0, take).trimRight(),
        ),
      );
      offset += take;
      while (offset < total &&
          (normalized[offset] == '\n' || normalized[offset] == '\r')) {
        offset++;
      }
    }

    return pages;
  }

  static int findPageForOffset(List<BookPageSlice> pages, int charOffset) {
    if (pages.isEmpty) return 0;
    for (var i = 0; i < pages.length - 1; i++) {
      if (charOffset < pages[i + 1].startOffset) return i;
    }
    return pages.length - 1;
  }

  static String formatParagraphs(String raw, {required bool indent}) {
    final paras = raw
        .replaceAll('\r\n', '\n')
        .split(RegExp(r'\n+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .map((s) => indent && !s.startsWith('　　') ? '　　$s' : s)
        .toList();
    return paras.join('\n\n');
  }
}

/// Loads chapter TOC and chapter text for all V1.0 formats via RustCoreBridge
/// (with Legado-compatible TXT TOC rules and zero hardcoded demo prose).
class BookContentLoader {
  BookContentLoader({this.rustCore, AppLocalizations? l10n})
      : l10n = l10n ?? AppLocalizationsEn();

  final RustCoreBridge? rustCore;
  final AppLocalizations l10n;

  Future<List<BookChapterRef>> loadChapterList(
    Book book, {
    List<TocRule> tocRules = const [],
    TocRule? forcedRule,
  }) async {
    final res = await loadChapterToc(
      book,
      tocRules: tocRules,
      forcedRule: forcedRule,
    );
    return res.chapters;
  }

  Future<LoadedTocResult> loadChapterToc(
    Book book, {
    List<TocRule> tocRules = const [],
    TocRule? forcedRule,
  }) async {
    final file = File(book.filePath);
    if (!file.existsSync()) {
      return LoadedTocResult(
        chapters: [BookChapterRef(index: 0, title: l10n.readerLocalFileUnavailable)],
        fileMissing: true,
      );
    }

    final fmt = book.format.toUpperCase();
    if (fmt == 'PDF' && rustCore != null) {
      try {
        final meta = rustCore!.parsePdfMetadata(book.filePath);
        final raw = meta['chapters'] as List<dynamic>? ?? const [];
        return LoadedTocResult(
          chapters: raw.map((e) {
            final m = Map<String, dynamic>.from(e as Map);
            return BookChapterRef(
              index: (m['index'] as num).toInt(),
              title: m['title'] as String? ??
                  l10n.chapterLabelShort((m['index'] as num).toInt() + 1),
              href: m['href'] as String? ?? '',
            );
          }).toList(),
        );
      } catch (_) {
        return LoadedTocResult(
          chapters: [BookChapterRef(index: 0, title: l10n.readerBodyTitle)],
        );
      }
    }

    if (rustCore != null) {
      try {
        if (fmt == 'TXT') {
          final rustRules = tocRules
              .map(
                (r) => {
                  'id': r.id,
                  'name': r.name,
                  'rule': r.rule,
                  'example': r.example,
                  'enable': r.enabled,
                  'serial_number': r.serialNumber,
                },
              )
              .toList();
          final forcedMap = forcedRule == null
              ? null
              : {
                  'id': forcedRule.id,
                  'name': forcedRule.name,
                  'rule': forcedRule.rule,
                  'example': forcedRule.example,
                  'enable': true,
                  'serial_number': forcedRule.serialNumber,
                };
          final idx = rustCore!.indexTxtWithRules(
            path: book.filePath,
            rules: rustRules,
            forcedRule: forcedMap,
            forcedEncoding: book.forcedEncoding,
          );
          final raw = idx['chapters'] as List<dynamic>? ?? const [];
          return LoadedTocResult(
            chapters: raw.map((e) {
              final m = Map<String, dynamic>.from(e as Map);
              return BookChapterRef(
                index: (m['index'] as num).toInt(),
                title: m['title'] as String? ?? l10n.readerBodyTitle,
                startByte: (m['start_byte'] as num?)?.toInt() ?? 0,
                endByte: (m['end_byte'] as num?)?.toInt() ?? 0,
              );
            }).toList(),
            matchedRuleId: (idx['matched_rule_id'] as num?)?.toInt(),
            matchedRuleName: idx['matched_rule_name'] as String?,
            detectedEncoding: idx['encoding'] as String?,
          );
        } else if (fmt == 'EPUB') {
          final meta = rustCore!.parseEpubMetadata(book.filePath);
          final raw = meta['chapters'] as List<dynamic>? ?? const [];
          return LoadedTocResult(
            chapters: raw.map((e) {
              final m = Map<String, dynamic>.from(e as Map);
              return BookChapterRef(
                index: (m['index'] as num).toInt(),
                title: m['title'] as String? ?? l10n.readerBodyTitle,
                href: m['href'] as String? ?? '',
              );
            }).toList(),
          );
        } else if (fmt == 'MOBI' || fmt == 'AZW3') {
          final meta = rustCore!.parseMobiMetadata(book.filePath);
          final raw = meta['chapters'] as List<dynamic>? ?? const [];
          return LoadedTocResult(
            chapters: raw.map((e) {
              final m = Map<String, dynamic>.from(e as Map);
              return BookChapterRef(
                index: (m['index'] as num).toInt(),
                title: m['title'] as String? ?? l10n.readerBodyTitle,
                href: m['href'] as String? ?? '',
              );
            }).toList(),
          );
        } else if (fmt == 'FB2' || fmt == 'MD') {
          final meta =
              rustCore!.parseStructuredBook(book.filePath, fmt.toLowerCase());
          final raw = meta['chapters'] as List<dynamic>? ?? const [];
          return LoadedTocResult(
            chapters: raw.map((e) {
              final m = Map<String, dynamic>.from(e as Map);
              return BookChapterRef(
                index: (m['index'] as num).toInt(),
                title: m['title'] as String? ?? l10n.readerBodyTitle,
                href: m['href'] as String? ?? '',
              );
            }).toList(),
          );
        }
      } catch (_) {}
    }

    // Pure-Dart fallback for TXT/MD when native library is absent (e.g., isolated widget tests).
    if (fmt == 'TXT' || fmt == 'MD') {
      final raw = _safeDecodeTextFile(file);
      return _splitTxtDartFallback(
        raw,
        book.title,
        tocRules: tocRules,
        forcedRule: forcedRule,
      );
    }

    return LoadedTocResult(
      chapters: [BookChapterRef(index: 0, title: book.title)],
    );
  }

  static String _safeDecodeTextFile(File file) {
    final bytes = file.readAsBytesSync();
    return utf8
        .decode(bytes, allowMalformed: true)
        .replaceFirst('\uFEFF', '')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
  }

  static double _scoreDartMatches(
    List<RegExpMatch> hits,
    int totalChars,
    int serialNumber,
  ) {
    if (hits.isEmpty) return -1.0;
    final avg = totalChars / hits.length;
    final density = (avg >= 250 && avg <= 25000)
        ? 100.0
        : (avg >= 60 && totalChars < 6000)
            ? 80.0
            : (avg < 60 ? 5.0 : 40.0);
    final noisy = hits.where((m) {
      final t = (m.group(0) ?? '').trim();
      return t.length > 48 || (t.contains('。') && t.length > 16);
    }).length;
    final clean = (1.0 - (noisy / hits.length) * 1.4).clamp(0.05, 1.0);
    final prio = (20 - serialNumber.clamp(0, 20)) * 0.6;
    return density * clean + prio;
  }

  LoadedTocResult _splitTxtDartFallback(
    String raw,
    String fallbackTitle, {
    List<TocRule> tocRules = const [],
    TocRule? forcedRule,
  }) {
    final candidates = <TocRule>[
      ?forcedRule,
      if (forcedRule == null) ...tocRules.where((r) => r.enabled),
    ];

    List<RegExpMatch> bestMatches = const [];
    double bestScore = -1.0;
    TocRule? winner;

    for (final rule in candidates) {
      try {
        final re = compileTocRuleForDart(rule.rule);
        final hits = re.allMatches(raw).toList();
        if (forcedRule != null) {
          bestMatches = hits;
          winner = hits.isNotEmpty ? rule : null;
          break;
        }
        final score = _scoreDartMatches(hits, raw.length, rule.serialNumber);
        if (score > bestScore) {
          bestScore = score;
          bestMatches = hits;
          winner = rule;
        }
      } catch (_) {}
    }

    if (bestMatches.isEmpty && forcedRule == null) {
      final fallbackRe = RegExp(
        r'^[ \t\u3000]{0,4}(?:序章|楔子|尾声|番外|第[\s\u3000]{0,4}[\d〇零一二两三四五六七八九十百千万]+[\s\u3000]{0,4}[章节回卷部篇]).{0,40}$',
        multiLine: true,
      );
      bestMatches = fallbackRe.allMatches(raw).toList();
    }

    if (bestMatches.isEmpty) {
      return LoadedTocResult(
        chapters: [
          BookChapterRef(
            index: 0,
            title: fallbackTitle,
            startByte: 0,
            endByte: raw.length,
          ),
        ],
        detectedEncoding: 'UTF-8',
      );
    }

    final chapters = <BookChapterRef>[];
    if (bestMatches.first.start > 0 &&
        raw.substring(0, bestMatches.first.start).trim().isNotEmpty) {
      chapters.add(
        BookChapterRef(
          index: 0,
          title: l10n.readerPrefaceTitle,
          startByte: 0,
          endByte: bestMatches.first.start,
        ),
      );
    }
    for (var i = 0; i < bestMatches.length; i++) {
      final start = bestMatches[i].start;
      final end =
          i + 1 < bestMatches.length ? bestMatches[i + 1].start : raw.length;
      final title = (bestMatches[i].group(0) ?? '').trim();
      chapters.add(
        BookChapterRef(
          index: chapters.length,
          title: title.isEmpty ? l10n.chapterLabelShort(chapters.length + 1) : title,
          startByte: start,
          endByte: end,
        ),
      );
    }
    return LoadedTocResult(
      chapters: chapters,
      matchedRuleId: winner?.id,
      matchedRuleName: winner?.name,
      detectedEncoding: 'UTF-8',
    );
  }

  Future<LoadedBookChapter> loadChapterContent(
    Book book,
    BookChapterRef chapter,
    BookReaderSettings settings,
  ) async {
    final file = File(book.filePath);
    if (!file.existsSync()) {
      return LoadedBookChapter(
        index: chapter.index,
        title: chapter.title,
        text: l10n.readerLocalFileMissing(book.filePath),
      );
    }

    final fmt = book.format.toUpperCase();
    if (rustCore != null) {
      try {
        final res = rustCore!.readBookChapter(
          format: fmt.toLowerCase(),
          path: book.filePath,
          chapterIndex: chapter.index,
          href: chapter.href.isNotEmpty ? chapter.href : null,
          title: chapter.title,
          startByte: chapter.startByte,
          endByte: chapter.endByte,
          forcedEncoding: book.forcedEncoding,
          replaceRules: settings.replaceRules.map((r) => r.toRustMap()).toList(),
          cnMode: settings.chineseConversion,
        );
        final blocks = (res['blocks'] as List<dynamic>? ?? const []);
        final footnotes = <String>[];
        final images = <String>[];
        for (final b in blocks) {
          final m = Map<String, dynamic>.from(b as Map);
          if (m['kind'] == 'Footnote' && m['text'] != null) {
            footnotes.add(m['text'] as String);
          } else if (m['kind'] == 'Image' && m['href'] != null) {
            images.add(m['href'] as String);
          }
        }
        return LoadedBookChapter(
          index: chapter.index,
          title: res['title'] as String? ?? chapter.title,
          text: res['plain_text'] as String? ?? '',
          footnotes: footnotes,
          inlineImageHrefs: images,
        );
      } catch (_) {}
    }

    if (fmt == 'TXT' || fmt == 'MD') {
      final raw = _safeDecodeTextFile(file);
      final safeStart = chapter.startByte.clamp(0, raw.length);
      final safeEnd = chapter.endByte > safeStart
          ? chapter.endByte.clamp(safeStart, raw.length)
          : raw.length;
      return LoadedBookChapter(
        index: chapter.index,
        title: chapter.title,
        text: raw.substring(safeStart, safeEnd),
      );
    }

    return LoadedBookChapter(
      index: chapter.index,
      title: chapter.title,
      text: l10n.readerCoreUnavailable(book.format),
    );
  }
}
