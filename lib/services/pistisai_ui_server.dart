import 'dart:io';

import 'package:pistisai/config/app_config.dart';
import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_static/shelf_static.dart';

final Logger _log = Logger('PistisaiUiServer');

/// Serves the PistisAI app UI over HTTP for the Hermes Desktop tab.
class PistisaiUiServer {
  final int port;
  final String documentRoot;

  PistisaiUiServer({
    this.port = AppConfig.pistisaiUiPort,
    String? documentRoot,
  })  : documentRoot = documentRoot ?? AppConfig.getPistisaiUiDocumentRoot();

  /// Start the server.
  /// Returns true if the server started successfully.
  Future<bool> start() async {
    if (_isRunning) {
      _log.info('Pistisai UI server is already running');
      return true;
    }

    try {
      // Validate document root exists
      final dir = Directory(documentRoot);
      if (!await dir.exists()) {
        _log.warning('Pistisai UI document root does not exist: $documentRoot');
        // Create it? Or just fail? For now, we'll let shelf_static handle 404s.
        // But we should at least warn.
      }

      final handler = const Pipeline()
          .addMiddleware(logRequests())
          .addHandler(createStaticHandler(documentRoot,
              defaultDocument: 'index.html',
              // We want to allow listing? Probably not for security.
              // But for dev, it might be useful. Let's not allow listing.
              // We can make this configurable later.
              ));
      _server = await io.serve(handler, '127.0.0.1', port);
      _isRunning = true;
      _log.info('Pistisai UI server started on http://127.0.0.1:$port');
      return true;
    } catch (e, st) {
      _log.severe('Failed to start Pistisai UI server', e, st);
      return false;
    }
  }

  /// Stop the server.
  /// Returns true if the server was stopped successfully.
  Future<bool> stop() async {
    if (!_isRunning) {
      _log.info('Pistisai UI server is not running');
      return true;
    }

    try {
      await _server?.close(force: true);
      _isRunning = false;
      _log.info('Pistisai UI server stopped');
      return true;
    } catch (e, st) {
      _log.severe('Failed to stop Pistisai UI server', e, st);
      return false;
    }
  }

  /// Check if the server is running.
  bool get isRunning => _isRunning;

  /// Get server status information.
  Map<String, dynamic> getStatus() {
    return {
      'service': 'pistisai-ui-server',
      'running': _isRunning,
      'port': port,
      'documentRoot': documentRoot,
    };
  }

  HttpServer? _server;
  bool _isRunning = false;
}