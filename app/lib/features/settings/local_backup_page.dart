import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/l10n/l10n_helpers.dart';
import '../../core/layout/responsive_layout.dart';
import '../../data/platform/platform_bridge.dart';
import '../../data/providers/app_providers.dart';
import 'local_backup_service.dart';

class LocalBackupPage extends ConsumerStatefulWidget {
  const LocalBackupPage({super.key});

  @override
  ConsumerState<LocalBackupPage> createState() => _LocalBackupPageState();
}

class _LocalBackupPageState extends ConsumerState<LocalBackupPage> {
  bool _busy = false;

  Future<void> _transfer({required bool export}) async {
    if (_busy) return;
    setState(() => _busy = true);
    final storage = ref.read(libraryStorageProvider);
    final service = LocalBackupService(
      ref.read(appDatabaseProvider),
      storage: storage,
    );
    final l10n = context.l10n;
    Directory? staging;
    try {
      if (!export && !await storage.ensureWorkingDirectory()) return;
      staging = await (await getTemporaryDirectory()).createTemp(
        'inkbox-backup-',
      );
      final stamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      final file = File(p.join(staging.path, 'InkBox_$stamp.zip'));
      if (export) await service.exportTo(file);
      final transferred = await MethodChannelPlatformBridge.transferLocalBackup(
        file.path,
        export: export,
      );
      if (!transferred) return;
      if (export) {
        _showMessage(l10n.localBackupExported);
      } else {
        final result = await service.importFrom(file);
        _showMessage(
          l10n.localBackupImported(result.books, result.comics, result.skipped),
        );
      }
    } catch (error) {
      _showMessage(l10n.localBackupFailed(localizeError(l10n, error)));
    } finally {
      if (mounted) {
        ref.invalidate(workingDirectoryProvider);
        setState(() => _busy = false);
      }
      try {
        await staging?.delete(recursive: true);
      } on FileSystemException {
        // The system may have already cleared the temporary directory.
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.localBackupTitle)),
        body: ResponsiveConstrainedBody(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(l10n.localBackupDescription),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _busy ? null : () => _transfer(export: true),
                icon: const Icon(Icons.save_alt),
                label: Text(l10n.localBackupExport),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _transfer(export: false),
                icon: const Icon(Icons.file_open_outlined),
                label: Text(l10n.localBackupImport),
              ),
              if (_busy) ...[
                const SizedBox(height: 16),
                const LinearProgressIndicator(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
