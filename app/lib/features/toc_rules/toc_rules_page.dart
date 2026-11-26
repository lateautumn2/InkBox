import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/icons/ink_icons.dart';
import '../../core/theme/inkbox_theme.dart';
import '../../core/widgets/floating_surface.dart';
import '../../core/widgets/ink_controls.dart';
import '../../data/db/app_database.dart';
import '../../data/providers/app_providers.dart';
import '../importer/import_service.dart';
import 'toc_rules_parser.dart';

/// TXT TOC Rule Manager supporting GitHub Legado `txtTocRule.json` import,
/// custom rule creation/editing, live regex testing via Rust `fancy-regex`,
/// enabling/disabling, and JSON export.
class TocRulesPage extends ConsumerStatefulWidget {
  const TocRulesPage({super.key});

  @override
  ConsumerState<TocRulesPage> createState() => _TocRulesPageState();
}

class _TocRulesPageState extends ConsumerState<TocRulesPage> {
  static const _defaultSample =
      '楔子 雪夜\n漫天风雪。\n第一章 黑暗森林\n罗辑抬头望向星空。\n第 2 章 面壁者\n计划正式开始。\n1、序幕\n雨夜降临。\nChapter 1 Awakening\nA quiet valley.\n☆、番外 旧梦\n微风轻拂。';

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
      );
  }

  Future<void> _importFromFile() async {
    final picked =
        await ref.read(platformBridgeProvider).pickDocumentsDetailed();
    if (picked.paths.isEmpty) {
      if (picked.errors.isNotEmpty) {
        _toast('读取规则文件失败：${picked.errors.first}');
      }
      return;
    }
    var importedTotal = 0;
    for (final path in picked.paths) {
      try {
        final bytes = await File(path).readAsBytes();
        final raw = utf8.decode(bytes, allowMalformed: true);
        final parsed = TocRulesCatalog.parseImportedContent(raw);
        if (parsed.isNotEmpty) {
          importedTotal +=
              await ref.read(appDatabaseProvider).importTocRules(parsed);
        }
      } catch (e) {
        _toast('解析文件失败：$e');
      } finally {
        // Delete temporary SAF staged JSON copy so it doesn't pollute library_imports/
        ImportService.cleanupManagedFileIfOwned(path);
      }
    }
    if (importedTotal > 0) {
      _toast('成功导入 $importedTotal 条目录规则');
    } else {
      _toast('未在所选文件中识别到有效目录规则（支持 Legado txtTocRule.json）');
    }
  }

  Future<void> _showPasteImportModal() async {
    final ctrl = TextEditingController();
    final pastedText = await showInkModal<String>(
      context: context,
      title: '粘贴导入目录规则',
      subtitle: '支持 Legado (阅读) txtTocRule.json 数组/单条对象，或每行一条「名称::正则」',
      disposables: [ctrl],
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkTextField(
            controller: ctrl,
            label: '规则 JSON 或正则表达式',
            hintText: r'[{"name":"目录","rule":"^第.+章.*$","enable":true}]',
            maxLines: 6,
            minLines: 4,
            monospace: true,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: InkPillChip(
              label: '从剪贴板粘贴',
              onTap: () async {
                final data = await Clipboard.getData(Clipboard.kTextPlain);
                if (data?.text != null && data!.text!.isNotEmpty) {
                  ctrl.text = data.text!;
                }
              },
            ),
          ),
        ],
      ),
      actionsBuilder: (ctx) => [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(ctrl.text),
          child: const Text('导入规则'),
        ),
      ],
    );
    if (pastedText == null) return;
    final parsed = TocRulesCatalog.parseImportedContent(pastedText);
    if (parsed.isEmpty) {
      _toast('未解析到有效规则，请检查 JSON 或正则格式');
      return;
    }
    final count = await ref.read(appDatabaseProvider).importTocRules(parsed);
    _toast('已导入 $count 条目录规则');
  }

  String? _validateRulePattern(String pat) {
    final rust = ref.read(rustCoreProvider);
    if (rust != null) {
      try {
        final res = rust.testTocRule(
          pattern: pat,
          sampleText: '第一章 测试\n正文',
          maxPreview: 1,
        );
        if (res['valid'] != true) {
          return res['error']?.toString() ?? '正则表达式语法无效';
        }
        return null;
      } catch (_) {}
    }
    try {
      RegExp(
        pat.replaceAll('(?i)', '').replaceAll('(?m)', ''),
        multiLine: true,
        caseSensitive: !pat.contains('(?i)'),
      );
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> _showEditRuleModal({TocRule? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final ruleCtrl = TextEditingController(text: existing?.rule ?? '');
    final exampleCtrl = TextEditingController(text: existing?.example ?? '');
    final sampleCtrl = TextEditingController(
      text: existing != null && existing.example.isNotEmpty
          ? '${existing.example.replaceAll(' / ', '\n')}\n$_defaultSample'
          : _defaultSample,
    );
    String? testSummary;
    bool testError = false;

    final result = await showInkModal<({String name, String pat, String example})>(
      context: context,
      title: existing == null ? '新建目录识别规则' : '编辑目录识别规则',
      subtitle: '支持标准正则与 Legado 零宽断言（如 (?!完|结)）',
      disposables: [nameCtrl, ruleCtrl, exampleCtrl, sampleCtrl],
      builder: (ctx) {
        final tokens = InkBoxTokens.of(ctx);
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            void runTest() {
              final pat = ruleCtrl.text.trim();
              if (pat.isEmpty) {
                setModalState(() {
                  testError = true;
                  testSummary = '请先输入正则表达式';
                });
                return;
              }
              final rust = ref.read(rustCoreProvider);
              if (rust != null) {
                try {
                  final res = rust.testTocRule(
                    pattern: pat,
                    sampleText: sampleCtrl.text,
                    maxPreview: 6,
                  );
                  if (res['valid'] == true) {
                    final count = (res['match_count'] as num?)?.toInt() ?? 0;
                    final titles =
                        (res['preview_titles'] as List<dynamic>? ?? const [])
                            .cast<String>();
                    setModalState(() {
                      testError = false;
                      testSummary = count == 0
                          ? '正则合法，但在测试文本中未匹配到章节'
                          : '匹配到 $count 章：${titles.join(' / ')}';
                    });
                  } else {
                    setModalState(() {
                      testError = true;
                      testSummary = '正则错误：${res['error']}';
                    });
                  }
                  return;
                } catch (_) {}
              }
              // Pure-Dart fallback test
              try {
                final re = RegExp(
                  pat.replaceAll('(?i)', ''),
                  multiLine: true,
                  caseSensitive: !pat.contains('(?i)'),
                );
                final hits = re
                    .allMatches(sampleCtrl.text)
                    .map((m) => (m.group(0) ?? '').trim())
                    .where((s) => s.isNotEmpty)
                    .toList();
                setModalState(() {
                  testError = false;
                  testSummary = hits.isEmpty
                      ? '正则合法，但未匹配到测试章节'
                      : '匹配到 ${hits.length} 章：${hits.take(6).join(' / ')}';
                });
              } catch (e) {
                setModalState(() {
                  testError = true;
                  testSummary = '正则语法有误：$e';
                });
              }
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkTextField(
                  controller: nameCtrl,
                  label: '规则名称',
                  hintText: '例如：标准中文章节',
                ),
                const SizedBox(height: 10),
                InkTextField(
                  controller: ruleCtrl,
                  label: '正则表达式',
                  hintText: r'^[ \t]{0,4}第[\d一二三四五六七八九十百千万]+章.{0,30}$',
                  maxLines: 4,
                  minLines: 2,
                  monospace: true,
                ),
                const SizedBox(height: 10),
                InkTextField(
                  controller: exampleCtrl,
                  label: '示例标题（选填）',
                  hintText: '第一章 启程',
                ),
                const SizedBox(height: 10),
                InkTextField(
                  controller: sampleCtrl,
                  label: '测试样例文本',
                  maxLines: 3,
                  minLines: 2,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    InkPillChip(
                      label: '实时测试规则',
                      leadingIcon: InkIcon.spark,
                      onTap: runTest,
                    ),
                  ],
                ),
                if (testSummary != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: testError
                          ? tokens.accentWarm.withValues(alpha: 0.14)
                          : tokens.accentSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      testSummary!,
                      style: TextStyle(
                        fontSize: 11.5,
                        color:
                            testError ? tokens.accentWarm : tokens.inkPrimary,
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        );
      },
      actionsBuilder: (ctx) => [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop((
            name: nameCtrl.text.trim(),
            pat: ruleCtrl.text.replaceAll(RegExp(r'^[\r\n]+|[\r\n]+$'), ''),
            example: exampleCtrl.text.trim(),
          )),
          child: const Text('保存'),
        ),
      ],
    );

    if (result == null) return;
    final name = result.name;
    final pat = result.pat;
    final example = result.example;
    if (name.isEmpty || pat.trim().isEmpty) {
      _toast('规则名称与正则表达式不能为空');
      return;
    }
    final regexErr = _validateRulePattern(pat);
    if (regexErr != null) {
      _toast('正则语法错误，无法保存：$regexErr');
      return;
    }
    await ref.read(appDatabaseProvider).saveTocRule(
          id: existing?.id,
          name: name,
          rule: pat,
          example: example,
          enabled: existing?.enabled ?? true,
        );
    _toast(existing == null ? '已新增目录规则' : '已更新目录规则');
  }

  Future<void> _confirmDeleteRule(TocRule rule) async {
    final confirmed = await showInkModal<bool>(
      context: context,
      title: '删除目录规则',
      subtitle: '确定要删除规则「${rule.name}」吗？使用该规则的书籍将自动恢复为智能自动识别。',
      builder: (_) => const SizedBox.shrink(),
      actionsBuilder: (ctx) => [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: InkBoxTokens.of(ctx).accentWarm,
          ),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('删除'),
        ),
      ],
    );
    if (confirmed != true) return;
    await ref.read(appDatabaseProvider).deleteTocRule(rule.id);
    _toast('已删除规则「${rule.name}」');
  }

  Future<void> _showMoreActions(List<TocRule> rules) async {
    final action = await showInkOptionSheet<String>(
      context: context,
      title: '目录规则操作',
      options: const [
        InkOptionItem(
          value: 'import_file',
          label: '从本地文件导入规则',
          subtitle: '支持 GitHub Legado txtTocRule.json 或 .txt 正则文件',
          icon: InkIcon.file,
        ),
        InkOptionItem(
          value: 'import_paste',
          label: '粘贴 JSON / 正则导入',
          subtitle: '直接粘贴 Legado 规则 JSON 或正则表达式',
          icon: InkIcon.note,
        ),
        InkOptionItem(
          value: 'export_json',
          label: '导出全部规则到剪贴板',
          subtitle: '以标准 Legado txtTocRule.json 格式导出',
          icon: InkIcon.importTray,
        ),
        InkOptionItem(
          value: 'restore_builtin',
          label: '恢复内置 GitHub 默认规则',
          subtitle: '补全或还原默认 14 条中英文目录识别规则（保留自定义规则）',
          icon: InkIcon.refresh,
        ),
      ],
    );
    if (action == null) return;
    switch (action) {
      case 'import_file':
        await _importFromFile();
      case 'import_paste':
        await _showPasteImportModal();
      case 'export_json':
        final jsonStr = TocRulesCatalog.exportToLegadoJson(
          rules
              .map(
                (r) => ParsedTocRule(
                  name: r.name,
                  rule: r.rule,
                  example: r.example,
                  enabled: r.enabled,
                  serialNumber: r.serialNumber,
                  isBuiltin: r.isBuiltin,
                ),
              )
              .toList(),
        );
        await Clipboard.setData(ClipboardData(text: jsonStr));
        _toast('已复制 ${rules.length} 条目录规则 JSON 到剪贴板');
      case 'restore_builtin':
        final n =
            await ref.read(appDatabaseProvider).restoreDefaultTocRules();
        _toast('已恢复 $n 条内置默认目录规则');
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = InkBoxTokens.of(context);
    final rulesAsync = ref.watch(tocRulesStreamProvider);
    final db = ref.read(appDatabaseProvider);

    return Scaffold(
      backgroundColor: tokens.canvasBg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              child: FloatingCard(
                radius: 22,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    InkCircleButton(
                      icon: InkIconWidget(
                        InkIcon.back,
                        size: 18,
                        color: tokens.inkPrimary,
                      ),
                      onPressed: () => context.pop(),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'TXT 目录识别规则',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: tokens.inkPrimary,
                        ),
                      ),
                    ),
                    InkCircleButton(
                      icon: InkIconWidget(
                        InkIcon.plus,
                        size: 18,
                        color: tokens.inkPrimary,
                      ),
                      tooltip: '新建规则',
                      onPressed: () => _showEditRuleModal(),
                    ),
                    const SizedBox(width: 8),
                    InkCircleButton(
                      icon: InkIconWidget(
                        InkIcon.more,
                        size: 18,
                        color: tokens.inkPrimary,
                      ),
                      tooltip: '导入与管理',
                      onPressed: () =>
                          _showMoreActions(rulesAsync.valueOrNull ?? const []),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 2, 14, 10),
              child: Row(
                children: [
                  Expanded(
                    child: FloatingCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      onTap: _importFromFile,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          InkIconWidget(
                            InkIcon.file,
                            size: 16,
                            color: tokens.accentPrimary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '导入规则文件',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: tokens.inkPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FloatingCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      onTap: _showPasteImportModal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          InkIconWidget(
                            InkIcon.note,
                            size: 16,
                            color: tokens.accentPrimary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '粘贴 JSON 导入',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: tokens.inkPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: rulesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('加载规则失败：$e')),
                data: (rules) {
                  if (rules.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkIconWidget(
                            InkIcon.toc,
                            size: 38,
                            color: tokens.inkMuted,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '暂无目录规则',
                            style: TextStyle(color: tokens.inkMuted),
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: () => db.restoreDefaultTocRules(),
                            child: const Text('恢复内置默认规则'),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
                    itemCount: rules.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final r = rules[i];
                      return FloatingCard(
                        padding: const EdgeInsets.all(13),
                        onTap: () => _showEditRuleModal(existing: r),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          r.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w700,
                                            color: tokens.inkPrimary,
                                          ),
                                        ),
                                      ),
                                      if (!r.isBuiltin) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: tokens.accentSoft,
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            '自定义',
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w600,
                                              color: tokens.accentPrimary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                InkSwitch(
                                  value: r.enabled,
                                  onChanged: (v) => db.toggleTocRule(r.id, v),
                                ),
                              ],
                            ),
                            if (r.example.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                '示例：${r.example}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: tokens.inkMuted,
                                ),
                              ),
                            ],
                            const SizedBox(height: 6),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: tokens.surfaceVariant,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                r.rule,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontFamily: 'monospace',
                                  color: tokens.inkMuted,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                GestureDetector(
                                  onTap: () => _showEditRuleModal(existing: r),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    child: Text(
                                      '编辑 / 测试',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: tokens.accentPrimary,
                                      ),
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => _confirmDeleteRule(r),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    child: Text(
                                      '删除',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: tokens.accentWarm,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
