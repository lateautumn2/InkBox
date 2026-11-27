import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/icons/ink_icons.dart';
import '../../core/l10n/l10n_helpers.dart';
import '../../core/layout/responsive_layout.dart';
import '../../core/theme/inkbox_theme.dart';
import '../../core/widgets/floating_surface.dart';
import '../../core/widgets/ink_controls.dart';
import '../../data/providers/app_providers.dart';
import '../book_reader/book_reader_settings.dart';
import '../manga_reader/manga_reader_settings.dart';
import 'webdav_client.dart';
import 'webdav_sync_service.dart';

class WebDavSyncPage extends ConsumerStatefulWidget {
  const WebDavSyncPage({super.key});

  @override
  ConsumerState<WebDavSyncPage> createState() => _WebDavSyncPageState();
}

class _WebDavSyncPageState extends ConsumerState<WebDavSyncPage> {
  WebDavConfig _cfg = const WebDavConfig();
  bool _busy = false;
  bool _connected = false;
  String? _statusOverride;
  List<WebDavEntry> _backups = const [];

  late final WebDavSyncService _svc;

  static const _presets = <String, String>{
    '坚果云': 'https://dav.jianguoyun.com/dav',
    'Alist': 'http://192.168.1.2:5244/dav',
    'Nextcloud': 'https://cloud.example.com/remote.php/dav/files/user',
    'NAS': 'https://nas.example.com:5006',
  };

  @override
  void initState() {
    super.initState();
    _svc = WebDavSyncService(
      db: ref.read(appDatabaseProvider),
      rustCore: ref.read(rustCoreProvider),
      platform: ref.read(platformBridgeProvider),
    );
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    try {
      final loaded = await _svc.loadConfig();
      if (!mounted) return;
      setState(() {
        _cfg = loaded;
        if (loaded.isConfigured) {
          _statusOverride =
              '${loaded.presetName} · ${loaded.serverUrl}${loaded.remoteRoot}';
        }
      });
    } catch (error) {
      if (mounted) _toast(context.l10n.webdavTestFailed('$error'));
    }
  }

  Future<bool> _saveCfg(WebDavConfig next) async {
    try {
      await _svc.saveConfig(next);
      if (!mounted) return false;
      setState(() => _cfg = next);
      return true;
    } catch (error) {
      if (mounted) _toast(context.l10n.webdavTestFailed('$error'));
      return false;
    }
  }

  Future<void> _openConfigDialog({
    String? presetName,
    String? presetUrl,
  }) async {
    final l10n = context.l10n;
    final urlCtrl = TextEditingController(
      text:
          presetUrl ??
          (_cfg.serverUrl.isNotEmpty ? _cfg.serverUrl : _presets['坚果云']!),
    );
    final userCtrl = TextEditingController(text: _cfg.username);
    final passCtrl = TextEditingController(text: _cfg.password);
    final rootCtrl = TextEditingController(text: _cfg.remoteRoot);
    final deviceCtrl = TextEditingController(text: _cfg.deviceName);

    final result =
        await showInkModal<
          ({String url, String user, String pass, String root, String device})
        >(
          context: context,
          title: l10n.webdavConfigTitle(presetName ?? _cfg.presetName),
          disposables: [urlCtrl, userCtrl, passCtrl, rootCtrl, deviceCtrl],
          builder: (ctx) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkTextField(
                controller: urlCtrl,
                label: ctx.l10n.webdavServerUrlLabel,
                hintText: 'https://dav.jianguoyun.com/dav',
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 10),
              InkTextField(
                controller: userCtrl,
                label: ctx.l10n.webdavUserLabel,
                hintText: 'name@example.com',
              ),
              const SizedBox(height: 10),
              InkTextField(
                controller: passCtrl,
                obscureText: true,
                label: ctx.l10n.webdavPassLabel,
              ),
              const SizedBox(height: 10),
              InkTextField(
                controller: rootCtrl,
                label: ctx.l10n.webdavRootLabel,
                hintText: '/InkBox',
              ),
              const SizedBox(height: 10),
              InkTextField(
                controller: deviceCtrl,
                label: ctx.l10n.webdavDeviceNameLabel,
              ),
            ],
          ),
          actionsBuilder: (ctx) => [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(ctx.l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop((
                url: urlCtrl.text.trim(),
                user: userCtrl.text.trim(),
                pass: passCtrl.text,
                root: rootCtrl.text.trim(),
                device: deviceCtrl.text.trim(),
              )),
              child: Text(ctx.l10n.webdavSaveAndTest),
            ),
          ],
        );

    if (result == null) return;
    final next = _cfg.copyWith(
      serverUrl: result.url,
      username: result.user,
      password: result.pass,
      remoteRoot: result.root.isEmpty ? '/InkBox' : result.root,
      presetName: presetName ?? _cfg.presetName,
      deviceName: result.device.isEmpty ? _cfg.deviceName : result.device,
    );
    if (await _saveCfg(next)) await _testConnection();
  }

  Future<void> _testConnection() async {
    if (!_cfg.isConfigured) {
      await _openConfigDialog();
      return;
    }
    setState(() => _busy = true);
    try {
      await _svc.testConnection(_cfg);
      final snaps = await _svc.listBackupSnapshots(_cfg);
      if (!mounted) return;
      final l10n = context.l10n;
      setState(() {
        _connected = true;
        _backups = snaps;
        _statusOverride = l10n.webdavSnapSummary(_cfg.presetName, snaps.length);
      });
      _toast(l10n.webdavTestPassed);
    } catch (e) {
      if (!mounted) return;
      final l10n = context.l10n;
      setState(() {
        _connected = false;
        _statusOverride = l10n.webdavTestFailed('$e');
      });
      _toast(l10n.webdavTestFailed('$e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runFullSync() async {
    if (!_cfg.isConfigured) {
      await _openConfigDialog();
      return;
    }
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final prefsSnap = {
        'book_reader': ref.read(bookReaderSettingsProvider).toJson(),
        'manga_reader': ref.read(mangaReaderSettingsProvider).toJson(),
      };
      final report = await _svc.syncAll(
        _cfg,
        localPreferencesSnapshot: prefsSnap,
        applyPreferences: _applyPreferences,
      );
      if (!mounted) return;
      final l10n = context.l10n;
      setState(() {
        _connected = true;
        _statusOverride =
            '↓${report.progressAdopted} ↑${report.progressUploaded} · ★${report.annotationsMerged}';
      });
      if (report.conflicts.isNotEmpty) {
        for (final c in report.conflicts) {
          if (!mounted) break;
          await _showConflictDialog(c);
        }
      } else {
        _toast(l10n.webdavSyncDone);
      }
    } catch (e) {
      if (mounted) _toast(context.l10n.webdavTestFailed('$e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createBackup() async {
    if (!_cfg.isConfigured) {
      await _openConfigDialog();
      return;
    }
    setState(() => _busy = true);
    try {
      final prefsSnap = {
        'book_reader': ref.read(bookReaderSettingsProvider).toJson(),
        'manga_reader': ref.read(mangaReaderSettingsProvider).toJson(),
      };
      final name = await _svc.createBackupSnapshot(
        _cfg,
        preferences: prefsSnap,
      );
      final list = await _svc.listBackupSnapshots(_cfg);
      if (!mounted) return;
      setState(() => _backups = list);
      _toast(name);
    } catch (e) {
      if (mounted) _toast(context.l10n.webdavTestFailed('$e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restoreBackup(String fileName) async {
    setState(() => _busy = true);
    try {
      await _svc.restoreBackupSnapshot(
        _cfg,
        fileName,
        applyPreferences: _applyPreferences,
      );
      if (mounted) _toast(context.l10n.webdavSyncDone);
    } catch (e) {
      if (mounted) _toast(context.l10n.webdavTestFailed('$e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _applyPreferences(Map<String, dynamic> snapshot) async {
    if (!mounted) return;
    final book = snapshot['book_reader'];
    final manga = snapshot['manga_reader'];
    if (book is Map<String, dynamic>) {
      await ref
          .read(bookReaderSettingsProvider.notifier)
          .applySnapshotJson(book);
    }
    if (mounted && manga is Map<String, dynamic>) {
      await ref
          .read(mangaReaderSettingsProvider.notifier)
          .applySnapshotJson(manga);
    }
  }

  Future<void> _showConflictDialog(ProgressConflict conflict) async {
    final tokens = InkBoxTokens.of(context);
    final l10n = context.l10n;
    final adoptRemote = await showInkModal<bool>(
      context: context,
      title: l10n.webdavConflictTitle,
      subtitle: l10n.webdavConflictSubtitle(conflict.title),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: tokens.accentSoft,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: tokens.accentPrimary),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ctx.l10n.webdavRemoteLabel(conflict.remoteDeviceName),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: tokens.accentPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${(conflict.remoteProgress * 100).toStringAsFixed(1)}% · ${conflict.remoteLocator}',
                  style: TextStyle(fontSize: 12, color: tokens.inkPrimary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: tokens.surfaceVariant,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ctx.l10n.webdavLocalLabel(conflict.localDeviceName),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: tokens.inkPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${(conflict.localProgress * 100).toStringAsFixed(1)}% · ${conflict.localLocator}',
                  style: TextStyle(fontSize: 12, color: tokens.inkMuted),
                ),
              ],
            ),
          ),
        ],
      ),
      actionsBuilder: (ctx) => [
        OutlinedButton(
          style: OutlinedButton.styleFrom(shape: const StadiumBorder()),
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(ctx.l10n.webdavKeepLocal),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: tokens.accentPrimary,
            shape: const StadiumBorder(),
          ),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(ctx.l10n.webdavAdoptRemote),
        ),
      ],
    );
    if (adoptRemote != null) {
      await _svc.resolveConflict(_cfg, conflict, adoptRemote: adoptRemote);
      if (mounted) _toast(l10n.webdavSyncDone);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
      );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = InkBoxTokens.of(context);
    final l10n = context.l10n;
    final statusText = _statusOverride ?? l10n.webdavUnconfigured;

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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
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
                          l10n.webdavTitle,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: tokens.inkPrimary,
                          ),
                        ),
                      ),
                      InkCircleButton(
                        icon: InkIconWidget(
                          InkIcon.gear,
                          size: 17,
                          color: tokens.inkPrimary,
                        ),
                        tooltip: l10n.webdavConfigureTooltip,
                        onPressed: () => _openConfigDialog(),
                      ),
                    ],
                  ),
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
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 28),
                  children: [
                    FloatingCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: tokens.surfaceVariant,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: InkIconWidget(
                                    InkIcon.syncCloud,
                                    size: 22,
                                    color: _connected
                                        ? tokens.statusOk
                                        : tokens.accentPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          l10n.webdavCenterTitle,
                                          style: TextStyle(
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w700,
                                            color: tokens.inkPrimary,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 7,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _connected
                                                ? tokens.statusOk
                                                : tokens.surfaceVariant,
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: Text(
                                            _connected
                                                ? l10n.webdavOnline
                                                : l10n.webdavOffline,
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w700,
                                              color: _connected
                                                  ? Colors.white
                                                  : tokens.inkMuted,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      statusText,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: tokens.inkMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: tokens.accentPrimary,
                                    shape: const StadiumBorder(),
                                  ),
                                  onPressed: _busy ? null : _runFullSync,
                                  icon: InkIconWidget(
                                    InkIcon.refresh,
                                    size: 15,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimary,
                                  ),
                                  label: Text(
                                    _busy
                                        ? l10n.webdavSyncing
                                        : l10n.webdavSyncNow,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    shape: const StadiumBorder(),
                                    side: BorderSide(
                                      color: tokens.subtleBorder,
                                    ),
                                  ),
                                  onPressed: _busy ? null : _createBackup,
                                  child: Text(
                                    l10n.webdavCreateBackup,
                                    style: TextStyle(color: tokens.inkPrimary),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    FloatingCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.webdavSyncScope,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: tokens.inkMuted,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _SyncToggleRow(
                            title: l10n.webdavScopeProgress,
                            subtitle: l10n.webdavScopeProgressDesc,
                            value: _cfg.syncProgress,
                            onChanged: (v) =>
                                _saveCfg(_cfg.copyWith(syncProgress: v)),
                          ),
                          Divider(height: 16, color: tokens.subtleBorder),
                          _SyncToggleRow(
                            title: l10n.webdavScopeMeta,
                            subtitle: l10n.webdavScopeMetaDesc,
                            value: _cfg.syncMeta,
                            onChanged: (v) =>
                                _saveCfg(_cfg.copyWith(syncMeta: v)),
                          ),
                          Divider(height: 16, color: tokens.subtleBorder),
                          _SyncToggleRow(
                            title: l10n.webdavScopePrefs,
                            subtitle: l10n.webdavScopePrefsDesc,
                            value: _cfg.syncPrefs,
                            onChanged: (v) =>
                                _saveCfg(_cfg.copyWith(syncPrefs: v)),
                          ),
                          Divider(height: 16, color: tokens.subtleBorder),
                          _SyncToggleRow(
                            title: l10n.webdavScopeSourceFiles,
                            subtitle: l10n.webdavScopeSourceFilesDesc,
                            value: _cfg.syncFiles,
                            onChanged: (v) =>
                                _saveCfg(_cfg.copyWith(syncFiles: v)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    FloatingCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.webdavPresetsTitle,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: tokens.inkPrimary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _presets.entries.map((e) {
                              return InkPillChip(
                                label: e.key,
                                selected:
                                    _cfg.isConfigured &&
                                    _cfg.presetName == e.key,
                                onTap: () => _openConfigDialog(
                                  presetName: e.key,
                                  presetUrl: e.value,
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    if (_backups.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      FloatingCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${l10n.webdavBackupsTitle} (${_backups.length})',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: tokens.inkPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ..._backups.map((b) {
                              return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  b.name,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                subtitle: Text(
                                  '${(b.contentLength / 1024).toStringAsFixed(1)} KB',
                                  style: const TextStyle(fontSize: 10.5),
                                ),
                                trailing: TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _restoreBackup(b.name),
                                  child: Text(l10n.webdavRestoreBtn),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SyncToggleRow extends StatelessWidget {
  const _SyncToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = InkBoxTokens.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: tokens.inkPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(fontSize: 11, color: tokens.inkMuted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        InkSwitch(value: value, onChanged: onChanged),
      ],
    );
  }
}
