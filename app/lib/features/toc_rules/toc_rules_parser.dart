import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Parsed TXT TOC rule payload compatible with Legado (`txtTocRule.json`) and custom regexes.
@immutable
class ParsedTocRule {
  const ParsedTocRule({
    required this.name,
    required this.rule,
    this.example = '',
    this.enabled = true,
    this.serialNumber = 0,
    this.isBuiltin = false,
  });

  final String name;
  final String rule;
  final String example;
  final bool enabled;
  final int serialNumber;
  final bool isBuiltin;

  Map<String, dynamic> toLegadoJson({int? id}) => {
        'id': ?id,
        'enable': enabled,
        'name': name,
        'rule': rule,
        'example': example,
        'serialNumber': serialNumber,
      };
}

/// Built-in GitHub Legado-compatible default TXT TOC rules (mirrored in assets/txt_toc_rules.json).
class TocRulesCatalog {
  static const List<ParsedTocRule> builtinRules = [
    ParsedTocRule(
      name: '目录(去空白 · 标准中文章节)',
      rule:
          r'^[ \t\u3000]{0,8}(?:(?:序章|楔子|引子|前言|终章|后记|尾声|番外|外传|大结局|完本感言|上架感言)(?:$|[\s\u3000:：、.\-—·(（\[【].{0,35}$)|第[\s\u3000]{0,4}[\d０-９〇零一二两三四五六七八九十百千万壹贰叁肆伍陆柒捌玖拾佰仟]+?[\s\u3000]{0,4}(?:章|节(?!课)|卷|集(?![合和])|部(?![分赛游])|篇(?!张)|回).{0,40}$)',
      example: '第一章 黑暗森林 / 第 一 节 启程 / 楔子 / 番外',
      enabled: true,
      serialNumber: 1,
      isBuiltin: true,
    ),
    ParsedTocRule(
      name: '卷 + 章复合标题',
      rule:
          r'^[ \t\u3000]{0,8}(?:第[\d〇零一二两三四五六七八九十百千万]+(?:卷|部|集|篇)|卷[\d〇零一二两三四五六七八九十百千]+|正文)[\s\u3000·:：\-]{1,4}.{0,20}?第[\s\u3000]{0,3}[\d０-９〇零一二两三四五六七八九十百千万]+[\s\u3000]{0,3}(?:章|节|回).{0,35}$',
      example: '第一卷 崛起 第一章 初出茅庐',
      enabled: true,
      serialNumber: 2,
      isBuiltin: true,
    ),
    ParsedTocRule(
      name: '无「第」字章节(卷/章/节/回)',
      rule:
          r'^[ \t\u3000]{0,8}(?:卷|章|节|回|集|部|篇)[\s\u3000]{0,2}[\d０-９〇零一二两三四五六七八九十百千万]+(?:[\s\u3000.、:：\-].{0,35})?$',
      example: '卷一 尘封往事 / 章十二 暗夜',
      enabled: true,
      serialNumber: 3,
      isBuiltin: true,
    ),
    ParsedTocRule(
      name: '中文数字序号标题',
      rule:
          r'^[ \t\u3000]{0,8}[〇零一二两三四五六七八九十百千万]{1,7}[、.．:：\s\u3000]+[^\s。，；！？?!]{1,30}$',
      example: '一、初入江湖 / 十二、夜访',
      enabled: true,
      serialNumber: 4,
      isBuiltin: true,
    ),
    ParsedTocRule(
      name: '阿拉伯数字分隔符标题',
      rule:
          r'^[ \t\u3000]{0,8}\d{1,5}[、.．:：\-—\s\u3000]+[^\d\s。，；]{1,35}$',
      example: '1、序幕 / 001. 黎明之前 / 12 - 归途',
      enabled: true,
      serialNumber: 5,
      isBuiltin: true,
    ),
    ParsedTocRule(
      name: '纯数字章节号',
      rule: r'^[ \t\u3000]{0,8}\d{1,5}[ \t\u3000]{0,4}$',
      example: '1 / 002 / 128',
      enabled: true,
      serialNumber: 6,
      isBuiltin: true,
    ),
    ParsedTocRule(
      name: '英文 Chapter / Part / Section',
      rule:
          r'(?i)^[ \t\u3000]{0,8}(?:chapter|part|section|volume|vol\.?|book|act|prologue|epilogue)(?:[\s\u3000\-:#.]+[0-9ivxlcdm]+)?(?:[\s\u3000:.\-—].{0,45})?$',
      example: 'Chapter 1 The Beginning / PART II / Prologue',
      enabled: true,
      serialNumber: 7,
      isBuiltin: true,
    ),
    ParsedTocRule(
      name: '括号序号标题',
      rule:
          r'^[ \t\u3000]{0,8}[(（\[【][ \t]{0,2}(?:第?[\d〇零一二两三四五六七八九十百千万]+[章节回卷话]?|序章|楔子|番外|尾声)[ \t]{0,2}[)）\]】].{0,35}$',
      example: '（一）夜雨 / 【第一章】破晓 / [01] 启程',
      enabled: true,
      serialNumber: 8,
      isBuiltin: true,
    ),
    ParsedTocRule(
      name: '书名括号序号',
      rule:
          r'^[ \t\u3000]{0,8}[^\s。，；]{1,16}[(（][0-9〇零一二两三四五六七八九十百千万]{1,6}[)）][ \t\u3000]{0,4}$',
      example: '凡人修仙传(12) / 雪中悍刀行（三）',
      enabled: true,
      serialNumber: 9,
      isBuiltin: true,
    ),
    ParsedTocRule(
      name: '特殊符号标记标题(晋江/论坛体)',
      rule:
          r'^[ \t\u3000]{0,8}(?:[☆★✦✧◆◇●○■□※§]+[ \t、.．\-]{0,3}.{1,35}|={2,}[ \t]*.{1,30}[ \t]*={2,}|-{3,}[ \t]*.{1,30}[ \t]*-{3,})$',
      example: '☆、第1章 初遇 / ✦ 序幕 / === 第一章 ===',
      enabled: true,
      serialNumber: 10,
      isBuiltin: true,
    ),
    ParsedTocRule(
      name: '轻小说 / 话 / 幕 / 日系章节',
      rule:
          r'^[ \t\u3000]{0,8}(?:第[\s\u3000]{0,3}[\d０-９〇零一二两三四五六七八九十百千万]+[\s\u3000]{0,3}(?:话|話|幕|场|場|折|讲|講)|プロローグ|エピローグ|間章|幕間).{0,35}$',
      example: '第一话 异世界 / 第03話 / 幕间',
      enabled: true,
      serialNumber: 11,
      isBuiltin: true,
    ),
    ParsedTocRule(
      name: '正文前缀序号',
      rule:
          r'^[ \t\u3000]{0,8}正文[\s\u3000:：\-·]+(?:[\d〇零一二两三四五六七八九十百千万]+|第[\d〇零一二两三四五六七八九十百千万]+[章节回]).{0,35}$',
      example: '正文 001 重生 / 正文 第十章 风云',
      enabled: true,
      serialNumber: 12,
      isBuiltin: true,
    ),
    ParsedTocRule(
      name: 'Markdown 井号标题',
      rule: r'^[ \t]{0,3}#{1,4}[ \t]+.{1,50}$',
      example: '# 第一章 / ## 02 暗涌',
      enabled: true,
      serialNumber: 13,
      isBuiltin: true,
    ),
    ParsedTocRule(
      name: '宽松数字+标题(无分隔符)',
      rule: r'^[ \t\u3000]{0,8}\d{1,4}[\u4e00-\u9fa5][^\r\n。；]{0,26}$',
      example: '001开端 / 12风起云涌',
      enabled: false,
      serialNumber: 14,
      isBuiltin: true,
    ),
  ];

  /// Parses Legado `txtTocRule.json` (array, single object, or wrapped `{rules: [...]}`),
  /// or falls back to line-by-line custom regex rules (`名称::正则` or bare regex per line).
  /// Rejects malformed JSON instead of importing broken JSON syntax lines as regex rules.
  static List<ParsedTocRule> parseImportedContent(String raw) {
    final trimmed = raw.trim().replaceFirst('\uFEFF', '');
    if (trimmed.isEmpty) return const [];

    if (trimmed.startsWith('[') || trimmed.startsWith('{')) {
      final dynamic decoded;
      try {
        decoded = jsonDecode(trimmed);
      } catch (_) {
        // Looks like JSON (or truncated JSON) — never turn raw JSON syntax lines into regexes!
        return const [];
      }
      final list = <dynamic>[];
      if (decoded is List) {
        list.addAll(decoded);
      } else if (decoded is Map<String, dynamic>) {
        if (decoded['rules'] is List) {
          list.addAll(decoded['rules'] as List);
        } else if (decoded['data'] is List) {
          list.addAll(decoded['data'] as List);
        } else {
          list.add(decoded);
        }
      }
      final out = <ParsedTocRule>[];
      for (var i = 0; i < list.length; i++) {
        final item = list[i];
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final rawPat =
            (map['rule'] ?? map['pattern'] ?? map['regex'] ?? '').toString();
        final pattern = rawPat.replaceAll(RegExp(r'^[\r\n]+|[\r\n]+$'), '');
        if (pattern.trim().isEmpty) continue;
        final name =
            (map['name'] ?? map['title'] ?? '导入规则 ${out.length + 1}')
                .toString()
                .trim();
        final example = (map['example'] ?? '').toString().trim();
        final enableRaw = map.containsKey('enable')
            ? map['enable']
            : (map.containsKey('enabled') ? map['enabled'] : true);
        final enabled = enableRaw is bool
            ? enableRaw
            : enableRaw.toString().toLowerCase() != 'false';
        final serial =
            (map['serialNumber'] ?? map['serial_number'] ?? (100 + i));
        out.add(
          ParsedTocRule(
            name: name.isEmpty ? '导入规则 ${out.length + 1}' : name,
            rule: pattern,
            example: example,
            enabled: enabled,
            serialNumber: serial is num ? serial.toInt() : (100 + i),
            isBuiltin: false,
          ),
        );
      }
      return out;
    }

    // Plain-text fallback: either "Name::Regex" or one regex per non-empty line.
    final out = <ParsedTocRule>[];
    final lines = trimmed.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty || line.startsWith('//') || line.startsWith('# ')) {
        continue;
      }
      if (line.contains('::')) {
        final idx = line.indexOf('::');
        final name = line.substring(0, idx).trim();
        final pattern = line.substring(idx + 2).trim();
        if (pattern.isNotEmpty) {
          out.add(
            ParsedTocRule(
              name: name.isEmpty ? '导入规则 ${out.length + 1}' : name,
              rule: pattern,
              serialNumber: 100 + out.length,
            ),
          );
        }
      } else {
        out.add(
          ParsedTocRule(
            name: '导入规则 ${out.length + 1}',
            rule: line,
            serialNumber: 100 + out.length,
          ),
        );
      }
    }
    return out;
  }

  static String exportToLegadoJson(List<ParsedTocRule> rules) {
    final encoded = [
      for (var i = 0; i < rules.length; i++)
        rules[i].toLegadoJson(id: i + 1),
    ];
    return const JsonEncoder.withIndent('  ').convert(encoded);
  }
}
