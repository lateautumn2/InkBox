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
    final storage = ref.read(libraryStorageProvider);
    final db = ref.read(appDatabaseProvider);
    final picked = await ref
        .read(platformBridgeProvider)
        .pickDocumentsDetailed();
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
          importedTotal += await db.importTocRules(parsed);
        }
      } catch (e) {
        _toast(localizeError(l10n, e));
      } finally {
        await storage.releaseTemp(path);
      }
    }
    if (!mounted) return;
    if (importedTotal > 0) {
      _toast(l10n.tocRulesImported(importedTotal));
    } else {
      _toast(l10n.tocRulesNotFound);
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
                final text = data?.text;
                if (ctx.mounted && text != null && text.isNotEmpty) {
                  ctrl.text = text;
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
    if (pastedText == null || !mounted) return;
    final parsed = TocRulesCatalog.parseImportedContent(pastedText);
    if (parsed.isEmpty) {
      _toast(l10n.tocRulesNotFound);
      return;
    }
    final count = await ref.read(appDatabaseProvider).importTocRules(parsed);
    if (mounted) _toast(l10n.tocRulesImported(count));
  }

  ({int count, List<String> titles, String? error}) _testRule(
    String pattern,
    String sample, {
    int preview = 0,
  }) {
    final rust = ref.read(rustCoreProvider);
    if (rust != null) {
      try {
        final res = rust.testTocRule(
          pattern: pattern,
          sampleText: sample,
          maxPreview: preview,
        );
        return (
          count: (res['match_count'] as num?)?.toInt() ?? 0,
          titles: (res['preview_titles'] as List<dynamic>? ?? const [])
              .cast<String>(),
          error: res['valid'] == true ? null : res['error']?.toString() ?? '',
        );
      } catch (_) {
        // Use the Dart fallback if the native engine is unavailable.
      }
    }
    try {
      final regex = compileTocRuleForDart(pattern);
      final hits = regex
          .allMatches(sample)
          .map((match) => (match.group(0) ?? '').trim())
          .where((title) => title.isNotEmpty)
          .toList();
      return (
        count: hits.length,
        titles: hits.take(preview).toList(),
        error: null,
      );
    } on FormatException catch (error) {
      return (count: 0, titles: const [], error: error.message);
    }
  }

  Future<void> _showEditRuleModal({TocRule? existing}) async {
    final l10n = context.l10n;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final ruleCtrl = TextEditingController(text: existing?.rule ?? '');
    final exampleCtrl = TextEditingController(text: existing?.example ?? '');
    final defaultSample = l10n.tocRuleSampleText;
    final sampleCtrl = TextEditingController(
      text: existing != null && existing.example.isNotEmpty
          ? '${existing.example.replaceAll(' / ', '\n')}\n$defaultSample'
          : defaultSample,
    );
    final feedback = ValueNotifier<({String text, bool isError})?>(null);

    void showError(String message) {
      feedback.value = (text: message, isError: true);
    }

    void showRegexError(String detail) {
      showError(
        detail.isEmpty
            ? l10n.tocRuleInvalidRegex
            : '${l10n.tocRuleInvalidRegex}\n$detail',
      );
    }

    void runTest() {
      final pattern = ruleCtrl.text.trim();
      if (pattern.isEmpty) {
        showError(l10n.tocRuleEmptyRegex);
        return;
      }
      final tested = _testRule(pattern, sampleCtrl.text, preview: 6);
      if (tested.error case final error?) {
        showRegexError(error);
        return;
      }
      feedback.value = (
        text: [
          l10n.tocRuleTestMatches(tested.count),
          ...tested.titles,
        ].join('\n'),
        isError: false,
      );
    }

    final result =
        await showInkModal<({String name, String pat, String example})>(
          context: context,
          title: existing == null ? l10n.newRuleTitle : l10n.editRuleTitle,
          disposables: [nameCtrl, ruleCtrl, exampleCtrl, sampleCtrl, feedback],
          builder: (ctx) {
            final tokens = InkBoxTokens.of(ctx);
            final ctxL10n = ctx.l10n;
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
                  label: ctxL10n.tocRuleExampleLabel,
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
                ValueListenableBuilder(
                  valueListenable: feedback,
                  builder: (context, value, _) {
                    if (value == null) return const SizedBox.shrink();
                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: value.isError
                            ? tokens.accentWarm.withValues(alpha: 0.14)
                            : tokens.accentSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        value.text,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: value.isError
                              ? tokens.accentWarm
                              : tokens.inkPrimary,
                        ),
                      ),
                    );
                  },
                ),
              ],
            );
          },
          actionsBuilder: (ctx) => [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(ctx.l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                final pattern = ruleCtrl.text.replaceAll(
                  RegExp(r'^[\r\n]+|[\r\n]+$'),
                  '',
                );
                if (name.isEmpty) {
                  showError(l10n.tocRuleMissingName);
                  return;
                }
                if (pattern.trim().isEmpty) {
                  showError(l10n.tocRuleEmptyRegex);
                  return;
                }
                final tested = _testRule(pattern, '');
                if (tested.error case final error?) {
                  showRegexError(error);
                  return;
                }
                Navigator.of(ctx).pop((
                  name: name,
                  pat: pattern,
                  example: exampleCtrl.text.trim(),
                ));
              },
              child: Text(ctx.l10n.save),
            ),
          ],
        );

    if (result == null || !mounted) return;
    await ref
        .read(appDatabaseProvider)
        .saveTocRule(
          id: existing?.id,
          name: result.name,
          rule: result.pat,
          example: result.example,
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
    if (confirmed != true || !mounted) return;
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
    if (action == null || !mounted) return;
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
                            Flexible(
                              child: Text(
                                l10n.importRuleFile,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: tokens.inkPrimary,
                                ),
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
                            Flexible(
                              child: Text(
                                l10n.pasteJsonImport,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: tokens.inkPrimary,
                                ),
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
