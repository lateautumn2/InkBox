import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/icons/ink_icons.dart';
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
  String _statusText = '尚未配置 WebDAV 服务器（点击下方预设快速接入）';
  List<WebDavEntry> _backups = const [];

  late final WebDavSyncService _svc;

  static const _presets = <String, String>{
    '坚果云': 'https://dav.jianguoyun.com/dav',
    'Alist': 'http://192.168.1.2:5244/dav',
    'Nextcloud': 'https://cloud.example.com/remote.php/dav/files/user',
    '群晖 NAS': 'https://nas.example.com:5006',
  };

  @override
  void initState() {
    super.initState();
    _svc = WebDavSyncService(
      db: ref.read(appDatabaseProvider),
      rustCore: ref.read(rustCoreProvider),
    );
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final loaded = await _svc.loadConfig();
    if (!mounted) return;
    setState(() {
      _cfg = loaded;
      if (loaded.isConfigured) {
        _statusText =
            '${loaded.presetName} · ${loaded.serverUrl}${loaded.remoteRoot}';
      }
    });
  }

  Future<void> _saveCfg(WebDavConfig next) async {
    setState(() => _cfg = next);
    await _svc.saveConfig(next);
  }

  Future<void> _openConfigDialog({
    String? presetName,
    String? presetUrl,
  }) async {
    final urlCtrl = TextEditingController(
      text: presetUrl ??
          (_cfg.serverUrl.isNotEmpty ? _cfg.serverUrl : _presets['坚果云']!),
    );
    final userCtrl = TextEditingController(text: _cfg.username);
    final passCtrl = TextEditingController(text: _cfg.password);
    final rootCtrl = TextEditingController(text: _cfg.remoteRoot);

    final result =
        await showInkModal<({String url, String user, String pass, String root})>(
      context: context,
      title: '配置 WebDAV (${presetName ?? _cfg.presetName})',
      disposables: [urlCtrl, userCtrl, passCtrl, rootCtrl],
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkTextField(
            controller: urlCtrl,
            label: '服务器地址 (HTTPS / HTTP)',
            hintText: 'https://dav.jianguoyun.com/dav',
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 10),
          InkTextField(
            controller: userCtrl,
            label: '账号 / 邮箱',
            hintText: 'name@example.com',
          ),
          const SizedBox(height: 10),
          InkTextField(
            controller: passCtrl,
            obscureText: true,
            label: '应用专用密码',
            hintText: '输入 WebDAV 应用密码',
          ),
          const SizedBox(height: 10),
          InkTextField(
            controller: rootCtrl,
            label: '同步根目录',
            hintText: '/InkBox',
          ),
        ],
      ),
      actionsBuilder: (ctx) => [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop((
            url: urlCtrl.text.trim(),
            user: userCtrl.text.trim(),
            pass: passCtrl.text,
            root: rootCtrl.text.trim(),
          )),
          child: const Text('保存并测试连接'),
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
    );
    await _saveCfg(next);
    await _testConnection();
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
      setState(() {
        _connected = true;
        _backups = snaps;
        _statusText = '${_cfg.presetName} · 连接正常 (${snaps.length} 份云端快照)';
      });
      _toast('WebDAV 连接测试通过');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _connected = false;
        _statusText = '连接失败：$e';
      });
      _toast('WebDAV 连接失败：$e');
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
      );
      if (!mounted) return;
      setState(() {
        _connected = true;
        _statusText =
            '刚刚同步：拉取 ${report.progressAdopted} / 上传 ${report.progressUploaded} / 笔记 ${report.annotationsMerged} / 文件 ${report.filesUploaded}';
      });
      if (report.conflicts.isNotEmpty) {
        for (final c in report.conflicts) {
          if (!mounted) break;
          await _showConflictDialog(c);
        }
      } else {
        _toast('WebDAV 双层增量同步完成');
      }
    } catch (e) {
      if (mounted) _toast('同步失败：$e');
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
      final name =
          await _svc.createBackupSnapshot(_cfg, preferences: prefsSnap);
      final list = await _svc.listBackupSnapshots(_cfg);
      if (!mounted) return;
      setState(() => _backups = list);
      _toast('已生成并上传备份快照：$name');
    } catch (e) {
      if (mounted) _toast('备份失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restoreBackup(String fileName) async {
    setState(() => _busy = true);
    try {
      final count = await _svc.restoreBackupSnapshot(_cfg, fileName);
      if (mounted) _toast('已从 $fileName 恢复 $count 条阅读进度');
    } catch (e) {
      if (mounted) _toast('恢复失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showConflictDialog(ProgressConflict conflict) async {
    final tokens = InkBoxTokens.of(context);
    final adoptRemote = await showInkModal<bool>(
      context: context,
      title: '发现多端阅读进度冲突',
      subtitle: '《${conflict.title}》两端均产生离线阅读记录，请选择要保留的进度：',
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
                  '云端（${conflict.remoteDeviceName}）',
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
                  '本机（${conflict.localDeviceName}）',
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
          child: const Text('保留本地'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: tokens.accentPrimary,
            shape: const StadiumBorder(),
          ),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('采用云端'),
        ),
      ],
    );
    if (adoptRemote != null) {
      await _svc.resolveConflict(_cfg, conflict, adoptRemote: adoptRemote);
      _toast(adoptRemote ? '已采用云端进度' : '已保留本地进度并同步');
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
                        'WebDAV 多端同步',
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
                      tooltip: '配置 WebDAV 服务器',
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
                                borderRadius: BorderRadius.circular(14),
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
                                        'WebDAV 双层同步中心',
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
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          _connected ? '在线' : '待连接',
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
                                    _statusText,
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
                                  color:
                                      Theme.of(context).colorScheme.onPrimary,
                                ),
                                label: Text(_busy ? '同步中...' : '立即同步'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  shape: const StadiumBorder(),
                                  side: BorderSide(color: tokens.subtleBorder),
                                ),
                                onPressed: _busy ? null : _createBackup,
                                child: Text(
                                  '创建备份快照',
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
                          '分层同步范围',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: tokens.inkMuted,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _SyncToggleRow(
                          title: '阅读进度与书签',
                          subtitle: 'Layer 1 · 增量合并与坚果云 429 指数退避',
                          value: _cfg.syncProgress,
                          onChanged: (v) =>
                              _saveCfg(_cfg.copyWith(syncProgress: v)),
                        ),
                        Divider(height: 16, color: tokens.subtleBorder),
                        _SyncToggleRow(
                          title: '书架分组与划线笔记',
                          subtitle: 'Layer 1 · UUID 三向 LWW 合并',
                          value: _cfg.syncMeta,
                          onChanged: (v) =>
                              _saveCfg(_cfg.copyWith(syncMeta: v)),
                        ),
                        Divider(height: 16, color: tokens.subtleBorder),
                        _SyncToggleRow(
                          title: '阅读器排版与主题配置',
                          subtitle: 'Layer 1 · 纸张主题、字体与九宫格点击区',
                          value: _cfg.syncPrefs,
                          onChanged: (v) =>
                              _saveCfg(_cfg.copyWith(syncPrefs: v)),
                        ),
                        Divider(height: 16, color: tokens.subtleBorder),
                        _SyncToggleRow(
                          title: '书籍与漫画源文件',
                          subtitle:
                              'Layer 2 · 按需流式上传/下载 + 去重（上限 ${_cfg.maxFileMb}MB）',
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
                          '一键预设接入 WebDAV',
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
                              selected: _cfg.isConfigured &&
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
                            '云端备份快照 (${_backups.length})',
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
                                child: const Text('一键恢复'),
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
