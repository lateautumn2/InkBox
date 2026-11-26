import 'dart:io';

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
import '../../data/ffi/rust_core_bridge.dart';
import '../../data/providers/app_providers.dart';
import 'import_service.dart';

class ImportHubPage extends ConsumerStatefulWidget {
  const ImportHubPage({super.key});

  @override
  ConsumerState<ImportHubPage> createState() => _ImportHubPageState();
}

class _ImportHubPageState extends ConsumerState<ImportHubPage> {
  bool _autoClassify = true;
  bool _overwriteExisting = false;
  bool _busy = false;
  bool _foldersExpanded = false;
  String _selectedFormat = 'all';
  String _historyFilter = 'all'; // 'all' | 'archived' | 'on_shelf'
  List<ImportCandidate> _candidates = [];
  ImportBatchResult? _lastResult;

  static const _formats = ['all', 'EPUB', 'TXT', 'PDF', 'MOBI', 'comic'];

  Future<void> _pickLocalFiles() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final res = await ref.read(importServiceProvider).pickAndImportDocuments(
            autoClassify: _autoClassify,
            overwriteExisting: _overwriteExisting,
            targetBookShelfId: ref.read(activeBookShelfIdProvider),
            targetMangaShelfId: ref.read(activeMangaShelfIdProvider),
          );
      if (!mounted) return;
      if (!res.isEmpty) {
        setState(() => _lastResult = res);
        _showResultSnack(res);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addAndScanDirectory() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final svc = ref.read(importServiceProvider);
      await svc.addWatchedDirectory();
      final scanned = await svc.scanWatchedFolders();
      if (!mounted) return;
      setState(() {
        _candidates = scanned;
        _foldersExpanded = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.folderScanDoneToast(scanned.length)),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rescanWatched() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final scanned =
          await ref.read(importServiceProvider).scanWatchedFolders();
      if (!mounted) return;
      setState(() => _candidates = scanned);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.folderScanDoneToast(scanned.length)),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importSelected() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final res =
          await ref.read(importServiceProvider).importSelectedCandidates(
                _candidates,
                autoClassify: _autoClassify,
                overwriteExisting: _overwriteExisting,
                targetBookShelfId: ref.read(activeBookShelfIdProvider),
                targetMangaShelfId: ref.read(activeMangaShelfIdProvider),
              );
      if (!mounted) return;
      setState(() {
        _candidates = _candidates.where((c) => !c.selected).toList();
        _lastResult = res;
      });
      _showResultSnack(res);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forceReimportDuplicate(ImportFileOutcome dup) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final outcome =
          await ref.read(importServiceProvider).importLocalPathDetailed(
                dup.localPath,
                forceKind: dup.kind,
                overwriteExisting: true,
              );
      if (!mounted) return;
      setState(() {
        if (_lastResult != null) {
          _lastResult = ImportBatchResult(
            booksImported:
                _lastResult!.booksImported + (outcome.status == 'book' ? 1 : 0),
            mangasImported: _lastResult!.mangasImported +
                (outcome.status == 'manga' ? 1 : 0),
            skippedDuplicates:
                (_lastResult!.skippedDuplicates - 1).clamp(0, 9999),
            errors: _lastResult!.errors,
            importedItems: [..._lastResult!.importedItems, outcome],
            duplicateItems: _lastResult!.duplicateItems
                .where((d) => d.localPath != dup.localPath || d.id != dup.id)
                .toList(),
          );
        }
      });
      final l10n = context.l10n;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(l10n.overwriteSuccessToast(outcome.title)),
            action: outcome.id != null
                ? SnackBarAction(
                    label: l10n.readNow,
                    onPressed: () => _openOutcome(outcome),
                  )
                : null,
          ),
        );
    } catch (e) {
      if (!mounted) return;
      final l10n = context.l10n;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.overwriteFailedToast(localizeError(l10n, e))),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmPermanentDelete({
    required String title,
    required bool isComic,
    required int id,
  }) async {
    final l10n = context.l10n;
    final confirmed = await showInkModal<bool>(
      context: context,
      title: l10n.permanentDeleteTitle,
      subtitle: l10n.permanentDeleteConfirm(title),
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
          child: Text(ctx.l10n.removePermanentOption),
        ),
      ],
    );
    if (confirmed != true) return;
    final svc = ref.read(importServiceProvider);
    if (isComic) {
      await svc.permanentlyDeleteMangas([id]);
    } else {
      await svc.permanentlyDeleteBooks([id]);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(context.l10n.deletedForeverToast(title))),
      );
  }

  Future<void> _showSupportedFormatsModal(CoreHealthInfo health) async {
    final l10n = context.l10n;
    final booksStr =
        health.supportedBookFormats.map((e) => e.toUpperCase()).join(' · ');
    final mangaStr = health.supportedComicFormats
        .map((e) =>
            e == 'folder' ? l10n.supportedFormatsImageFolder : e.toUpperCase())
        .join(' · ');
    await showInkModal<void>(
      context: context,
      title: l10n.supportedFormats,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.supportedFormatsBooks(booksStr),
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: InkBoxTokens.of(ctx).inkPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.supportedFormatsManga(mangaStr),
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: InkBoxTokens.of(ctx).inkPrimary,
            ),
          ),
        ],
      ),
      actionsBuilder: (ctx) => [
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(ctx.l10n.close),
        ),
      ],
    );
  }

  void _openOutcome(ImportFileOutcome item) {
    if (item.id == null) {
      context.go(item.kind == 'comic' ? '/manga' : '/bookshelf');
      return;
    }
    if (item.kind == 'comic') {
      context.push('/manga/${item.id}');
    } else {
      context.push('/reader/book/${item.id}');
    }
  }

  void _showResultSnack(ImportBatchResult res) {
    final l10n = context.l10n;
    final buf = StringBuffer(
      l10n.importResultSummary(res.booksImported, res.mangasImported),
    );
    if (res.skippedDuplicates > 0) {
      buf.write(l10n.importResultSkipped(res.skippedDuplicates));
    }
    if (res.errors.isNotEmpty) {
      buf.write(l10n.importResultFailed(res.errors.length));
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(buf.toString()),
          duration: const Duration(seconds: 4),
          action: (res.booksImported > 0 || res.mangasImported > 0)
              ? SnackBarAction(
                  label: res.booksImported > 0
                      ? l10n.viewBookshelf
                      : l10n.viewMangaShelf,
                  onPressed: () => context.go(
                    res.booksImported > 0 ? '/bookshelf' : '/manga',
                  ),
                )
              : null,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = InkBoxTokens.of(context);
    final l10n = context.l10n;
    final health = ref.watch(coreHealthProvider);
    final foldersAsync = ref.watch(watchedFoldersStreamProvider);
    final bookHistory =
        ref.watch(bookHistoryStreamProvider).valueOrNull ?? const <Book>[];
    final mangaHistory =
        ref.watch(mangaHistoryStreamProvider).valueOrNull ?? const <Manga>[];
    final wide = isWideLayout(context);
    final expanded = isExpandedLayout(context);
    final bottomPad = wide
        ? 88.0
        : (tokens.isFloatingCard ? 156.0 : 84.0);

    final visibleCandidates = _candidates.where((c) {
      if (_selectedFormat == 'all') return true;
      if (_selectedFormat == 'comic') return c.targetKind == 'comic';
      return c.ext == _selectedFormat;
    }).toList();

    final selectedCount = _candidates.where((c) => c.selected).length;

    final historyEntries = <_HistoryEntry>[
      ...bookHistory.map(
        (b) => _HistoryEntry(
          id: b.id,
          title: b.title,
          format: b.format,
          isComic: false,
          isArchived: b.isArchived,
          addedAtMs: b.addedAtMs,
          localPath: b.filePath,
          fileExists: File(b.filePath).existsSync(),
          subtitle: l10n.historyBookSubtitle(
            localizedAuthor(l10n, b.author),
            (b.progressRatio * 100).round(),
          ),
        ),
      ),
      ...mangaHistory.map(
        (m) => _HistoryEntry(
          id: m.id,
          title: m.title,
          format: m.format,
          isComic: true,
          isArchived: m.isArchived,
          addedAtMs: m.addedAtMs,
          localPath: m.rootPath,
          fileExists: FileSystemEntity.typeSync(m.rootPath) !=
              FileSystemEntityType.notFound,
          subtitle: l10n.historyMangaSubtitle(
            localizedAuthor(l10n, m.author),
            m.totalChapters,
          ),
        ),
      ),
    ]..sort((a, b) => b.addedAtMs.compareTo(a.addedAtMs));

    final filteredHistory = historyEntries.where((h) {
      if (_historyFilter == 'archived') return h.isArchived;
      if (_historyFilter == 'on_shelf') return !h.isArchived;
      return true;
    }).toList();

    final actionWidgets = _buildActionsColumn(
      tokens: tokens,
      l10n: l10n,
      foldersAsync: foldersAsync,
    );
    final listWidgets = _buildListsColumn(
      tokens: tokens,
      l10n: l10n,
      visibleCandidates: visibleCandidates,
      historyEntries: historyEntries,
      filteredHistory: filteredHistory,
    );

    return SafeArea(
      bottom: false,
      child: Stack(
        children: [
          Column(
            children: [
              ResponsiveConstrainedBody(
                maxWidth: expanded ? 1040 : kMaxContentWidth,
                child: FloatingHeaderBar(
                  title: l10n.importHubTitle,
                  actions: [
                    InkCircleButton(
                      icon: InkIconWidget(
                        InkIcon.info,
                        size: 17,
                        color: tokens.inkPrimary,
                      ),
                      tooltip: l10n.supportedFormats,
                      onPressed: () => _showSupportedFormatsModal(health),
                    ),
                    const SizedBox(width: 8),
                    InkCircleButton(
                      icon: InkIconWidget(
                        InkIcon.refresh,
                        size: 17,
                        color: tokens.inkPrimary,
                      ),
                      tooltip: l10n.rescanFolders,
                      onPressed: _rescanWatched,
                    ),
                  ],
                ),
              ),
              if (_busy)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: LinearProgressIndicator(
                    minHeight: 2.5,
                    color: tokens.accentPrimary,
                  ),
                ),
              Expanded(
                child: expanded
                    ? Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1040),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 380,
                                child: ListView(
                                  padding: EdgeInsets.fromLTRB(
                                      14, 6, 8, bottomPad),
                                  children: actionWidgets,
                                ),
                              ),
                              Expanded(
                                child: ListView(
                                  padding: EdgeInsets.fromLTRB(
                                      8, 6, 14, bottomPad),
                                  children: listWidgets,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ResponsiveConstrainedBody(
                        child: ListView(
                          padding: EdgeInsets.fromLTRB(14, 6, 14, bottomPad),
                          children: [
                            ...actionWidgets,
                            const SizedBox(height: 14),
                            ...listWidgets,
                          ],
                        ),
                      ),
              ),
            ],
          ),
          if (selectedCount > 0)
            Positioned(
              left: 14,
              right: 14,
              bottom: (!wide && tokens.isFloatingCard) ? 84 : 14,
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: wide ? 460 : double.infinity,
                  ),
                  child: FloatingCard(
                    frosted: true,
                    radius: 22,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.selectedCandidatesCount(selectedCount),
                          style: TextStyle(fontSize: 12.5, color: tokens.inkMuted),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: tokens.accentPrimary,
                            shape: const StadiumBorder(),
                          ),
                          onPressed: _busy ? null : _importSelected,
                          child: Text(l10n.importToShelfCount(selectedCount)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildActionsColumn({
    required InkBoxTokens tokens,
    required dynamic l10n,
    required AsyncValue<List<WatchedFolder>> foldersAsync,
  }) {
    final loc = context.l10n;
    return [
      Row(
        children: [
          Expanded(
            child: FloatingCard(
              onTap: _pickLocalFiles,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  InkIconWidget(
                    InkIcon.file,
                    size: 20,
                    color: tokens.inkPrimary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      loc.pickLocalFiles,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
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
              backgroundColor: tokens.accentSoft,
              borderColor: Colors.transparent,
              onTap: _addAndScanDirectory,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  InkIconWidget(
                    InkIcon.folder,
                    size: 20,
                    color: tokens.accentPrimary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      loc.addAndScanFolder,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: tokens.accentPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      FloatingCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          children: [
            Row(
              children: [
                InkIconWidget(
                  InkIcon.spark,
                  size: 18,
                  color: tokens.accentPrimary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    loc.smartAutoClassify,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: tokens.inkPrimary,
                    ),
                  ),
                ),
                InkSwitch(
                  value: _autoClassify,
                  onChanged: (v) => setState(() => _autoClassify = v),
                ),
              ],
            ),
            Divider(height: 16, color: tokens.subtleBorder),
            Row(
              children: [
                InkIconWidget(
                  InkIcon.refresh,
                  size: 17,
                  color: tokens.inkMuted,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    loc.overwriteDuplicates,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: tokens.inkPrimary,
                    ),
                  ),
                ),
                InkSwitch(
                  value: _overwriteExisting,
                  onChanged: (v) => setState(() => _overwriteExisting = v),
                ),
              ],
            ),
          ],
        ),
      ),
      foldersAsync.when(
        loading: () => const SizedBox.shrink(),
        error: (_, _) => const SizedBox.shrink(),
        data: (folders) {
          if (folders.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: 10),
            child: FloatingCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () =>
                        setState(() => _foldersExpanded = !_foldersExpanded),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          InkIconWidget(
                            InkIcon.folder,
                            size: 15,
                            color: tokens.accentPrimary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              loc.watchedFoldersTitle(folders.length),
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: tokens.inkPrimary,
                              ),
                            ),
                          ),
                          InkIconWidget(
                            _foldersExpanded
                                ? InkIcon.chevronDown
                                : InkIcon.chevronRight,
                            size: 14,
                            color: tokens.inkMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_foldersExpanded) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: folders.map((f) {
                        return InkPillChip(
                          label: f.displayName,
                          leadingIcon: InkIcon.folder,
                          onDelete: () => ref
                              .read(appDatabaseProvider)
                              .deleteWatchedFolder(f.id),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
      if (_lastResult != null && !_lastResult!.isEmpty) ...[
        const SizedBox(height: 10),
        _buildLastResultCard(tokens, _lastResult!),
      ],
    ];
  }

  List<Widget> _buildListsColumn({
    required InkBoxTokens tokens,
    required dynamic l10n,
    required List<ImportCandidate> visibleCandidates,
    required List<_HistoryEntry> historyEntries,
    required List<_HistoryEntry> filteredHistory,
  }) {
    final loc = context.l10n;
    return [
      if (_candidates.isNotEmpty) ...[
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _formats.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, idx) {
              final fmt = _formats[idx];
              final label = fmt == 'all'
                  ? loc.formatAll
                  : (fmt == 'comic' ? loc.formatComicArchive : fmt);
              return InkPillChip(
                label: label,
                selected: _selectedFormat == fmt,
                elevated: true,
                onTap: () => setState(() => _selectedFormat = fmt),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        ...visibleCandidates.map((c) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: FloatingCard(
              onTap: () => setState(() => c.selected = !c.selected),
              borderColor: c.selected ? tokens.accentPrimary : null,
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              child: Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: c.selected
                          ? tokens.accentPrimary
                          : tokens.surfaceVariant,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: c.selected
                        ? const Center(
                            child: InkIconWidget(
                              InkIcon.check,
                              size: 13,
                              color: Colors.white,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: tokens.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      c.ext,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: tokens.inkPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: tokens.inkPrimary,
                          ),
                        ),
                        Text(
                          '${c.formattedSize} · ${c.targetKind == "comic" ? loc.classifiedAsComic : loc.classifiedAsBook}',
                          style: TextStyle(
                            fontSize: 11,
                            color: tokens.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      c.targetKind =
                          c.targetKind == 'comic' ? 'book' : 'comic';
                    }),
                    child: Text(
                      c.targetKind == 'comic'
                          ? loc.switchToBook
                          : loc.switchToComic,
                      style: TextStyle(
                        fontSize: 11,
                        color: tokens.accentPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 12),
      ],
      Row(
        children: [
          InkIconWidget(
            InkIcon.history,
            size: 16,
            color: tokens.inkPrimary,
          ),
          const SizedBox(width: 6),
          Text(
            loc.importHistoryTitle(historyEntries.length),
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: tokens.inkPrimary,
            ),
          ),
          const Spacer(),
          ...[
            ('all', loc.historyAll),
            ('archived', loc.historyArchived),
            ('on_shelf', loc.historyOnShelf),
          ].map((pair) {
            final active = _historyFilter == pair.$1;
            return Padding(
              padding: const EdgeInsets.only(left: 8),
              child: GestureDetector(
                onTap: () => setState(() => _historyFilter = pair.$1),
                child: Text(
                  pair.$2,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: active ? tokens.accentPrimary : tokens.inkMuted,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
      const SizedBox(height: 8),
      if (filteredHistory.isEmpty)
        FloatingCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
          child: Center(
            child: Text(
              historyEntries.isEmpty
                  ? loc.noImportHistory
                  : loc.noMatchingHistory,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: tokens.inkMuted),
            ),
          ),
        )
      else
        ...filteredHistory.map((item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: FloatingCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: item.isArchived
                          ? tokens.surfaceVariant
                          : tokens.accentSoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      item.format,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: item.isArchived
                            ? tokens.inkMuted
                            : tokens.accentPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: tokens.inkPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              !item.fileExists
                                  ? loc.fileMissingBadge
                                  : (item.isArchived
                                      ? loc.archivedBadge
                                      : loc.onShelfBadge),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: (!item.fileExists || item.isArchived)
                                    ? tokens.accentWarm
                                    : tokens.statusOk,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: tokens.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (item.isArchived)
                    TextButton(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () async {
                        if (!item.fileExists) {
                          ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                              SnackBar(
                                content: Text(
                                  loc.fileMissingReimportToast(item.title),
                                ),
                              ),
                            );
                          return;
                        }
                        final db = ref.read(appDatabaseProvider);
                        if (item.isComic) {
                          await db.restoreMangaToShelf(item.id);
                        } else {
                          await db.restoreBookToShelf(item.id);
                        }
                        if (!mounted) return;
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            SnackBar(
                              content:
                                  Text(loc.restoredToShelfToast(item.title)),
                            ),
                          );
                      },
                      child: Text(
                        loc.restoreToShelf,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: tokens.accentPrimary,
                        ),
                      ),
                    )
                  else
                    TextButton(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () => context.push(
                        item.isComic
                            ? '/manga/${item.id}'
                            : '/reader/book/${item.id}',
                      ),
                      child: Text(
                        loc.readNow,
                        style: TextStyle(
                          fontSize: 12,
                          color: tokens.accentPrimary,
                        ),
                      ),
                    ),
                  IconButton(
                    tooltip: loc.removePermanentOption,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _confirmPermanentDelete(
                      title: item.title,
                      isComic: item.isComic,
                      id: item.id,
                    ),
                    icon: InkIconWidget(
                      InkIcon.trash,
                      size: 16,
                      color: tokens.accentWarm,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
    ];
  }

  Widget _buildLastResultCard(InkBoxTokens tokens, ImportBatchResult res) {
    final l10n = context.l10n;
    return FloatingCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkIconWidget(
                res.errors.isNotEmpty ? InkIcon.spark : InkIcon.check,
                size: 16,
                color:
                    res.errors.isNotEmpty ? tokens.accentWarm : tokens.statusOk,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  l10n.lastImportResultTitle,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: tokens.inkPrimary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _lastResult = null),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                child: Text(
                  l10n.collapseLabel,
                  style: TextStyle(fontSize: 11.5, color: tokens.inkMuted),
                ),
              ),
            ],
          ),
          if (res.importedItems.isNotEmpty) ...[
            const SizedBox(height: 6),
            ...res.importedItems.map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.repaired
                            ? l10n.repairedStatus(item.title)
                            : l10n.importedStatus(item.title),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: tokens.inkPrimary,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _openOutcome(item),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                      child: Text(
                        l10n.readNow,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: tokens.accentPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
          if (res.duplicateItems.isNotEmpty) ...[
            const SizedBox(height: 4),
            ...res.duplicateItems.map((dup) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.duplicateStatus(dup.title),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: tokens.inkMuted,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _openOutcome(dup),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                      child: Text(
                        l10n.open,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: tokens.accentPrimary,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed:
                          _busy ? null : () => _forceReimportDuplicate(dup),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                      child: Text(
                        l10n.overwriteReimport,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: tokens.accentWarm,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
          if (res.errors.isNotEmpty) ...[
            const SizedBox(height: 4),
            ...res.errors.map((err) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  localizeError(l10n, err),
                  style: TextStyle(
                    fontSize: 11.5,
                    color: tokens.accentWarm,
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _HistoryEntry {
  const _HistoryEntry({
    required this.id,
    required this.title,
    required this.format,
    required this.isComic,
    required this.isArchived,
    required this.addedAtMs,
    required this.localPath,
    required this.fileExists,
    required this.subtitle,
  });

  final int id;
  final String title;
  final String format;
  final bool isComic;
  final bool isArchived;
  final int addedAtMs;
  final String localPath;
  final bool fileExists;
  final String subtitle;
}
