import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/icons/ink_icons.dart';
import '../../core/l10n/l10n_helpers.dart';
import '../../core/layout/responsive_layout.dart';
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
    final l10n = context.l10n;
    final picked =
        await ref.read(platformBridgeProvider).pickDocumentsDetailed();
    if (picked.paths.isEmpty) {
      if (picked.errors.isNotEmpty) {
        _toast(localizeError(l10n, picked.errors.first));
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
        _toast(localizeError(l10n, e));
      } finally {
        ImportService.cleanupManagedFileIfOwned(path);
      }
    }
    if (!mounted) return;
    if (importedTotal > 0) {
      _toast(l10n.tocReloadedCount(importedTotal));
    } else {
      _toast(l10n.noTocFound);
    }
  }

  Future<void> _showPasteImportModal() async {
    final l10n = context.l10n;
    final ctrl = TextEditingController();
    final pastedText = await showInkModal<String>(
      context: context,
      title: l10n.pasteImportTitle,
      disposables: [ctrl],
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkTextField(
            controller: ctrl,
            label: ctx.l10n.ruleJsonOrRegexLabel,
            hintText: r'[{"name":"TOC","rule":"^Chapter.*$","enable":true}]',
            maxLines: 6,
            minLines: 4,
            monospace: true,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: InkPillChip(
              label: ctx.l10n.pasteFromClipboard,
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
          child: Text(ctx.l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(ctrl.text),
          child: Text(ctx.l10n.importRulesBtn),
        ),
      ],
    );
    if (pastedText == null) return;
    final parsed = TocRulesCatalog.parseImportedContent(pastedText);
    if (parsed.isEmpty) {
      if (mounted) _toast(l10n.errInvalidAudio.isNotEmpty ? l10n.noTocFound : '');
      return;
    }
    final count = await ref.read(appDatabaseProvider).importTocRules(parsed);
    if (mounted) _toast('+$count');
  }

  String? _validateRulePattern(String pat) {
    final rust = ref.read(rustCoreProvider);
    if (rust != null) {
      try {
        final res = rust.testTocRule(
          pattern: pat,
          sampleText: 'Chapter 1\nBody',
          maxPreview: 1,
        );
        if (res['valid'] != true) {
          return res['error']?.toString() ?? 'Invalid regex';
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
    final l10n = context.l10n;
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
      title: existing == null ? l10n.newRuleTitle : l10n.editRuleTitle,
      disposables: [nameCtrl, ruleCtrl, exampleCtrl, sampleCtrl],
      builder: (ctx) {
        final tokens = InkBoxTokens.of(ctx);
        final ctxL10n = ctx.l10n;
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            void runTest() {
              final pat = ruleCtrl.text.trim();
              if (pat.isEmpty) {
                setModalState(() {
                  testError = true;
                  testSummary = 'Empty regex';
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
                          ? '0'
                          : '$count: ${titles.join(' / ')}';
                    });
                  } else {
                    setModalState(() {
                      testError = true;
                      testSummary = '${res['error']}';
                    });
                  }
                  return;
                } catch (_) {}
              }
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
                      ? '0'
                      : '${hits.length}: ${hits.take(6).join(' / ')}';
                });
              } catch (e) {
                setModalState(() {
                  testError = true;
                  testSummary = '$e';
                });
              }
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkTextField(
                  controller: nameCtrl,
                  label: ctxL10n.ruleNameLabel,
                ),
                const SizedBox(height: 10),
                InkTextField(
                  controller: ruleCtrl,
                  label: ctxL10n.regexLabel,
                  maxLines: 4,
                  minLines: 2,
                  monospace: true,
                ),
                const SizedBox(height: 10),
                InkTextField(
                  controller: exampleCtrl,
                  label: ctxL10n.examplePrefix('').replaceAll(': ', '').replaceAll('：', ''),
                ),
                const SizedBox(height: 10),
                InkTextField(
                  controller: sampleCtrl,
                  label: ctxL10n.sampleTextLabel,
                  maxLines: 3,
                  minLines: 2,
                ),
                const SizedBox(height: 8),
                InkPillChip(
                  label: ctxL10n.liveTestBtn,
                  leadingIcon: InkIcon.spark,
                  onTap: runTest,
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
          child: Text(ctx.l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop((
            name: nameCtrl.text.trim(),
            pat: ruleCtrl.text.replaceAll(RegExp(r'^[\r\n]+|[\r\n]+$'), ''),
            example: exampleCtrl.text.trim(),
          )),
          child: Text(ctx.l10n.save),
        ),
      ],
    );

    if (result == null) return;
    final name = result.name;
    final pat = result.pat;
    final example = result.example;
    if (name.isEmpty || pat.trim().isEmpty) return;
    final regexErr = _validateRulePattern(pat);
    if (regexErr != null) {
      _toast(regexErr);
      return;
    }
    await ref.read(appDatabaseProvider).saveTocRule(
          id: existing?.id,
          name: name,
          rule: pat,
          example: example,
          enabled: existing?.enabled ?? true,
        );
  }

  Future<void> _confirmDeleteRule(TocRule rule) async {
    final l10n = context.l10n;
    final confirmed = await showInkModal<bool>(
      context: context,
      title: l10n.deleteRuleTitle,
      subtitle: l10n.deleteRuleConfirm(rule.name),
      builder: (_) => const SizedBox.shrink(),
      actionsBuilder: (ctx) => [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(ctx.l10n.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: InkBoxTokens.of(ctx).accentWarm,
          ),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(ctx.l10n.delete),
        ),
      ],
    );
    if (confirmed != true) return;
    await ref.read(appDatabaseProvider).deleteTocRule(rule.id);
  }

  Future<void> _showMoreActions(List<TocRule> rules) async {
    final l10n = context.l10n;
    final action = await showInkOptionSheet<String>(
      context: context,
      title: l10n.tocActionsTitle,
      options: [
        InkOptionItem(
          value: 'import_file',
          label: l10n.importRuleFile,
          icon: InkIcon.file,
        ),
        InkOptionItem(
          value: 'import_paste',
          label: l10n.pasteJsonImport,
          icon: InkIcon.note,
        ),
        InkOptionItem(
          value: 'export_json',
          label: l10n.exportToClipboard,
          icon: InkIcon.importTray,
        ),
        InkOptionItem(
          value: 'restore_builtin',
          label: l10n.restoreBuiltinRules,
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
        if (mounted) _toast(l10n.copiedToast);
      case 'restore_builtin':
        await ref.read(appDatabaseProvider).restoreDefaultTocRules();
        if (mounted) _toast(l10n.restoreDefaultRules);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = InkBoxTokens.of(context);
    final l10n = context.l10n;
    final rulesAsync = ref.watch(tocRulesStreamProvider);
    final db = ref.read(appDatabaseProvider);

    return Scaffold(
      backgroundColor: tokens.canvasBg,
      body: SafeArea(
        child: ResponsiveConstrainedBody(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                child: FloatingCard(
                  radius: 18,
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
                          l10n.tocRulesTitle,
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
                        tooltip: l10n.newRuleTooltip,
                        onPressed: () => _showEditRuleModal(),
                      ),
                      const SizedBox(width: 8),
                      InkCircleButton(
                        icon: InkIconWidget(
                          InkIcon.more,
                          size: 18,
                          color: tokens.inkPrimary,
                        ),
                        tooltip: l10n.moreActionsTooltip,
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
                              l10n.importRuleFile,
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
                              l10n.pasteJsonImport,
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
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('$e')),
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
                              l10n.noTocRules,
                              style: TextStyle(color: tokens.inkMuted),
                            ),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: () => db.restoreDefaultTocRules(),
                              child: Text(l10n.restoreDefaultRules),
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
                                              l10n.customBadge,
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
                                  l10n.examplePrefix(r.example),
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
                                    onTap: () =>
                                        _showEditRuleModal(existing: r),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      child: Text(
                                        l10n.editTestBtn,
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
                                        l10n.delete,
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
      ),
    );
  }
}
