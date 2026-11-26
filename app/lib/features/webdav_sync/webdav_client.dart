import 'dart:convert';
import 'dart:io';

class WebDavEntry {
  const WebDavEntry({
    required this.href,
    required this.name,
    required this.isDirectory,
    this.contentLength = 0,
    this.etag,
  });

  final String href;
  final String name;
  final bool isDirectory;
  final int contentLength;
  final String? etag;
}

class WebDavException implements Exception {
  const WebDavException(this.statusCode, this.message);
  final int statusCode;
  final String message;

  @override
  String toString() => 'WebDavException($statusCode): $message';
}

/// RFC 4918 WebDAV client with Nutstore/NAS 429/503 exponential backoff retry
/// and streaming binary file upload/download for Layer 2 large comics/books.
class WebDavClient {
  WebDavClient({
    required String baseUrl,
    required this.username,
    required this.password,
    this.maxRetries = 3,
  }) : baseUrl = baseUrl.endsWith('/')
            ? baseUrl.substring(0, baseUrl.length - 1)
            : baseUrl;

  final String baseUrl;
  final String username;
  final String password;
  final int maxRetries;

  final HttpClient _http = HttpClient()
    ..connectionTimeout = const Duration(seconds: 15);

  String get _authHeader {
    final token = base64Encode(utf8.encode('$username:$password'));
    return 'Basic $token';
  }

  Uri _resolveUri(String relativePath) {
    final clean = relativePath.startsWith('/') ? relativePath : '/$relativePath';
    return Uri.parse('$baseUrl$clean');
  }

  Future<HttpClientResponse> _sendWithRetry(
    String method,
    String relativePath, {
    Map<String, String> headers = const {},
    List<int>? bodyBytes,
    Stream<List<int>>? bodyStream,
    int? contentLength,
  }) async {
    var attempt = 0;
    while (true) {
      attempt++;
      final uri = _resolveUri(relativePath);
      final req = await _http.openUrl(method, uri);
      req.headers.set(HttpHeaders.authorizationHeader, _authHeader);
      req.headers.set(HttpHeaders.userAgentHeader, 'InkBox/1.0 (WebDAV)');
      headers.forEach((k, v) => req.headers.set(k, v));

      if (bodyBytes != null) {
        req.contentLength = bodyBytes.length;
        req.add(bodyBytes);
      } else if (bodyStream != null) {
        if (contentLength != null) req.contentLength = contentLength;
        await req.addStream(bodyStream);
      }

      final resp = await req.close();
      // Nutstore rate-limit (429) or transient 503 backoff
      if ((resp.statusCode == 429 || resp.statusCode == 503) &&
          attempt < maxRetries &&
          bodyStream == null) {
        await resp.drain<void>();
        await Future<void>.delayed(Duration(milliseconds: 500 * attempt * attempt));
        continue;
      }
      return resp;
    }
  }

  /// Ensures a nested directory path exists via idempotent MKCOL calls.
  Future<void> ensureDirectory(String relativePath) async {
    final segments = relativePath
        .split('/')
        .where((s) => s.trim().isNotEmpty)
        .toList();
    var cur = '';
    for (final seg in segments) {
      cur = '$cur/$seg';
      final resp = await _sendWithRetry('MKCOL', '$cur/');
      final code = resp.statusCode;
      await resp.drain<void>();
      // 201 Created, 405 Method Not Allowed (already exists), 301/200 OK
      if (code != 201 && code != 405 && code != 200 && code != 301) {
        throw WebDavException(code, 'MKCOL $cur failed');
      }
    }
  }

  /// Checks whether a remote resource exists using lightweight HEAD.
  Future<bool> exists(String relativePath) async {
    final resp = await _sendWithRetry('HEAD', relativePath);
    final code = resp.statusCode;
    await resp.drain<void>();
    return code >= 200 && code < 300;
  }

  /// Tests connection and authentication using Depth: 0 PROPFIND.
  Future<void> ping(String rootPath) async {
    final resp = await _sendWithRetry(
      'PROPFIND',
      rootPath.isEmpty ? '/' : rootPath,
      headers: const {
        'Depth': '0',
        HttpHeaders.contentTypeHeader: 'application/xml; charset=utf-8',
      },
      bodyBytes: utf8.encode(
        '<?xml version="1.0" encoding="utf-8"?>'
        '<d:propfind xmlns:d="DAV:"><d:prop><d:resourcetype/></d:prop></d:propfind>',
      ),
    );
    final code = resp.statusCode;
    await resp.drain<void>();
    if (code == 404 && rootPath.isNotEmpty) {
      await ensureDirectory(rootPath);
      return;
    }
    if (code < 200 || code >= 300) {
      throw WebDavException(code, 'WebDAV connection check failed ($code)');
    }
  }

  /// Lists immediate children of [relativeDir] via PROPFIND Depth: 1.
  Future<List<WebDavEntry>> listDirectory(String relativeDir) async {
    final normalized = relativeDir.endsWith('/') ? relativeDir : '$relativeDir/';
    final resp = await _sendWithRetry(
      'PROPFIND',
      normalized,
      headers: const {
        'Depth': '1',
        HttpHeaders.contentTypeHeader: 'application/xml; charset=utf-8',
      },
      bodyBytes: utf8.encode(
        '<?xml version="1.0" encoding="utf-8"?>'
        '<d:propfind xmlns:d="DAV:"><d:prop>'
        '<d:resourcetype/><d:getcontentlength/><d:getetag/>'
        '</d:prop></d:propfind>',
      ),
    );
    final body = await utf8.decodeStream(resp);
    if (resp.statusCode == 404) return const [];
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw WebDavException(resp.statusCode, 'PROPFIND $normalized failed');
    }

    final entries = <WebDavEntry>[];
    final responseRe = RegExp(
      r'<(?:\w+:)?response\b[^>]*>(.*?)</(?:\w+:)?response>',
      caseSensitive: false,
      dotAll: true,
    );
    final hrefRe = RegExp(
      r'<(?:\w+:)?href\b[^>]*>(.*?)</(?:\w+:)?href>',
      caseSensitive: false,
      dotAll: true,
    );
    final lenRe = RegExp(
      r'<(?:\w+:)?getcontentlength\b[^>]*>(\d+)</(?:\w+:)?getcontentlength>',
      caseSensitive: false,
    );
    final etagRe = RegExp(
      r'<(?:\w+:)?getetag\b[^>]*>(.*?)</(?:\w+:)?getetag>',
      caseSensitive: false,
    );
    final colRe = RegExp(r'<(?:\w+:)?collection\s*/?>', caseSensitive: false);

    final matches = responseRe.allMatches(body).toList();
    for (var i = 0; i < matches.length; i++) {
      final block = matches[i].group(1) ?? '';
      final href = Uri.decodeFull(hrefRe.firstMatch(block)?.group(1)?.trim() ?? '');
      if (href.isEmpty) continue;
      // Skip the directory itself (typically first entry).
      if (i == 0 &&
          (href.endsWith(normalized) ||
              '${href.replaceFirst(RegExp(r'/$'), '')}/' == normalized)) {
        continue;
      }
      final trimmed = href.endsWith('/') ? href.substring(0, href.length - 1) : href;
      final name = trimmed.split('/').where((s) => s.isNotEmpty).lastOrNull ?? '';
      if (name.isEmpty) continue;
      entries.add(
        WebDavEntry(
          href: href,
          name: name,
          isDirectory: colRe.hasMatch(block) || href.endsWith('/'),
          contentLength:
              int.tryParse(lenRe.firstMatch(block)?.group(1) ?? '0') ?? 0,
          etag: etagRe.firstMatch(block)?.group(1)?.trim(),
        ),
      );
    }
    return entries;
  }

  /// Downloads a UTF-8 text/JSON resource; returns null on 404.
  Future<String?> getString(String relativePath) async {
    final resp = await _sendWithRetry('GET', relativePath);
    if (resp.statusCode == 404) {
      await resp.drain<void>();
      return null;
    }
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      await resp.drain<void>();
      throw WebDavException(resp.statusCode, 'GET $relativePath failed');
    }
    return utf8.decodeStream(resp);
  }

  /// Uploads a UTF-8 text/JSON resource via PUT.
  Future<void> putString(String relativePath, String content) async {
    final resp = await _sendWithRetry(
      'PUT',
      relativePath,
      headers: const {
        HttpHeaders.contentTypeHeader: 'application/json; charset=utf-8',
      },
      bodyBytes: utf8.encode(content),
    );
    final code = resp.statusCode;
    await resp.drain<void>();
    if (code < 200 || code >= 300) {
      throw WebDavException(code, 'PUT $relativePath failed');
    }
  }

  /// Streams a local file to WebDAV (Layer 2 books/comics & backup snapshots).
  Future<void> putFile(String relativePath, File localFile) async {
    final len = await localFile.length();
    final resp = await _sendWithRetry(
      'PUT',
      relativePath,
      headers: const {
        HttpHeaders.contentTypeHeader: 'application/octet-stream',
      },
      bodyStream: localFile.openRead(),
      contentLength: len,
    );
    final code = resp.statusCode;
    await resp.drain<void>();
    if (code < 200 || code >= 300) {
      throw WebDavException(code, 'PUT file $relativePath failed');
    }
  }

  /// Streams a remote file to a local target path with zero full-file RAM buffering.
  Future<bool> downloadFile(String relativePath, File targetFile) async {
    final resp = await _sendWithRetry('GET', relativePath);
    if (resp.statusCode == 404) {
      await resp.drain<void>();
      return false;
    }
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      await resp.drain<void>();
      throw WebDavException(resp.statusCode, 'GET file $relativePath failed');
    }
    await targetFile.parent.create(recursive: true);
    final sink = targetFile.openWrite();
    try {
      await resp.pipe(sink);
    } finally {
      await sink.close();
    }
    return true;
  }

  void close() => _http.close(force: true);
}
