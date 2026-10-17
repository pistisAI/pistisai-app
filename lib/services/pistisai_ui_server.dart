import 'dart:io';

import 'package:pistisai/config/app_config.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

/// Serves the Flutter web build on loopback so a browser can open the app UI.
///
/// The document root defaults to `build/web` and can be replaced in tests.
/// This server does not share the router port (1337) or the admin port (8080).
class PistisaiUiServer {
  PistisaiUiServer({
    this.port = AppConfig.pistisaiUiPort,
    String? documentRoot,
    InternetAddress? address,
  })  : documentRoot = documentRoot ?? defaultDocumentRoot(),
        address = address ?? InternetAddress.loopbackIPv4;

  final int port;
  final String documentRoot;
  final InternetAddress address;

  HttpServer? _server;

  int get boundPort => _server?.port ?? port;

  InternetAddress? get boundAddress => _server?.address;

  bool get isRunning => _server != null;

  static String defaultDocumentRoot() {
    return <String>[
      Directory.current.path,
      'build',
      'web',
    ].join(Platform.pathSeparator);
  }

  /// True when [documentRoot] has an `index.html` that can be served.
  bool get hasDocumentRoot {
    return File(_join(documentRoot, 'index.html')).existsSync();
  }

  Future<void> start() async {
    if (_server != null) {
      return;
    }
    if (!hasDocumentRoot) {
      return;
    }
    _server = await shelf_io.serve(_handle, address, port);
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    await server?.close(force: true);
  }

  Future<Response> _handle(Request request) async {
    if (request.method != 'GET' && request.method != 'HEAD') {
      return Response(405);
    }
    final relative = request.url.path;
    if (relative.contains('..')) {
      return Response.notFound('Not found');
    }
    final filePath = _resolve(relative.isEmpty ? 'index.html' : relative);
    if (filePath == null) {
      return Response.notFound('Not found');
    }
    final file = File(filePath);
    if (await file.exists()) {
      return _fileResponse(file);
    }
    final index = File(_join(documentRoot, 'index.html'));
    if (relative.isEmpty || !relative.contains('.')) {
      if (await index.exists()) {
        return _fileResponse(index);
      }
    }
    return Response.notFound('Not found');
  }

  Response _fileResponse(File file) {
    return Response.ok(
      file.openRead(),
      headers: <String, String>{
        HttpHeaders.contentTypeHeader: _contentType(file.path),
      },
    );
  }

  String? _resolve(String relative) {
    final normalized = relative.replaceAll('/', Platform.pathSeparator);
    if (normalized.split(Platform.pathSeparator).contains('..')) {
      return null;
    }
    final root = Directory(documentRoot).absolute.path;
    final resolved = File(_join(root, normalized)).absolute.path;
    final prefix = root.endsWith(Platform.pathSeparator)
        ? root
        : '$root${Platform.pathSeparator}';
    if (resolved != root && !resolved.startsWith(prefix)) {
      return null;
    }
    return resolved;
  }

  static String _join(String root, String relative) {
    if (relative.isEmpty) {
      return root;
    }
    return '$root${Platform.pathSeparator}$relative';
  }

  static String _contentType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.html')) return 'text/html; charset=utf-8';
    if (lower.endsWith('.js')) return 'text/javascript; charset=utf-8';
    if (lower.endsWith('.css')) return 'text/css; charset=utf-8';
    if (lower.endsWith('.json')) return 'application/json; charset=utf-8';
    if (lower.endsWith('.wasm')) return 'application/wasm';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.svg')) return 'image/svg+xml';
    if (lower.endsWith('.ico')) return 'image/x-icon';
    if (lower.endsWith('.map')) return 'application/json';
    if (lower.endsWith('.woff2')) return 'font/woff2';
    if (lower.endsWith('.woff')) return 'font/woff';
    if (lower.endsWith('.ttf')) return 'font/ttf';
    return 'application/octet-stream';
  }
}
