import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import 'platform_bridge.dart';

/// Android library records use SAF document URIs. Readers can lease a seekable
/// temporary file for native parsers that take a filesystem path.
class LibraryStorage {
  static const _channel = MethodChannel('dev.inkbox/platform');

  Future<PickedDirectory?>? _directoryPicker;

  bool get requiresWorkingDirectory => Platform.isAndroid;

  static bool isDocument(String path) => path.startsWith('content://');

  Future<PickedDirectory?> workingDirectory() => _directory('workingDirectory');

  Future<PickedDirectory?> pickWorkingDirectory() async {
    final pending = _directoryPicker;
    if (pending != null) return pending;
    final picker = _directory('pickWorkingDirectory');
    _directoryPicker = picker;
    try {
      return await picker;
    } finally {
      _directoryPicker = null;
    }
  }

  Future<bool> ensureWorkingDirectory() async {
    if (!requiresWorkingDirectory) return true;
    return (await workingDirectory() ?? await pickWorkingDirectory()) != null;
  }

  Future<PickedDirectory?> _directory(String method) async {
    if (!requiresWorkingDirectory) return null;
    final raw = await _channel.invokeMapMethod<String, String>(method);
    return raw == null
        ? null
        : PickedDirectory(uri: raw['uri']!, name: raw['name']!);
  }

  Future<void> releaseWatchedDirectory(String uri) async {
    if (!requiresWorkingDirectory || !isDocument(uri)) return;
    await _channel.invokeMethod<void>('releaseWatchedDirectory', {'uri': uri});
  }

  Future<void> pruneWorkingDirectories(
    List<String> references,
    List<String> watched,
  ) async {
    if (!requiresWorkingDirectory) return;
    await _channel.invokeMethod<void>('pruneWorkingDirectories', {
      'references': references.where(isDocument).toList(),
      'watched': watched.where(isDocument).toList(),
    });
  }

  Future<Map<String, String>> store(String localPath) async {
    final absolutePath = p.normalize(p.absolute(localPath));
    if (!requiresWorkingDirectory) return {absolutePath: localPath};
    final paths = await _channel.invokeMapMethod<String, String>(
      'storeLibraryPath',
      {'path': absolutePath},
    );
    if (paths == null || !paths.containsKey(absolutePath)) {
      throw FileSystemException('ERR_STREAM_OPEN', localPath);
    }
    return paths;
  }

  Future<ReadableMedia> open(String reference, {String? extension}) async {
    if (!isDocument(reference)) {
      return ReadableMedia._(this, reference, {reference: reference});
    }
    if (requiresWorkingDirectory) {
      try {
        final paths = await _channel.invokeMapMethod<String, String>(
          'openLibraryDocument',
          {'path': reference, 'extension': ?extension},
        );
        if (paths != null && paths.containsKey(reference)) {
          return ReadableMedia._(this, reference, paths);
        }
      } on MissingPluginException {
        // The content URI requires Android's document provider.
      }
    }
    throw FileSystemException('ERR_FILE_NOT_FOUND', reference);
  }

  Future<bool> exists(String reference) async {
    if (reference.isEmpty) return false;
    if (!isDocument(reference)) {
      final stat = await FileStat.stat(reference);
      return stat.type == FileSystemEntityType.directory || stat.size > 0;
    }
    if (!requiresWorkingDirectory) return false;
    try {
      return await _channel.invokeMethod<bool>('libraryDocumentExists', {
            'path': reference,
          }) ??
          false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<void> delete(String reference) async {
    if (!requiresWorkingDirectory || !isDocument(reference)) return;
    try {
      await _channel.invokeMethod<bool>('deleteLibraryDocument', {
        'path': reference,
      });
    } on MissingPluginException {
      // There is no Android document provider in this environment.
    }
  }

  Future<void> releaseTemp(String path) async {
    if (!requiresWorkingDirectory || isDocument(path)) return;
    try {
      await _channel.invokeMethod<void>('releaseMediaTemp', {'path': path});
    } on PlatformException {
      // Android can reclaim media in the cache directory.
    } on MissingPluginException {
      // There is no native cache in this environment.
    }
  }
}

class ReadableMedia {
  ReadableMedia._(this._storage, this.reference, this.paths);

  final LibraryStorage _storage;
  final String reference;
  final Map<String, String> paths;
  String get path => paths[reference]!;
  bool _closed = false;

  Future<void> close() async {
    if (_closed || reference == path) return;
    _closed = true;
    await _storage.releaseTemp(path);
  }
}
