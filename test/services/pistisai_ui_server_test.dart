import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/config/app_config.dart';
import 'package:pistisai/services/pistisai_ui_server.dart';

// HttpClient is stubbed under the Flutter test binding, so requests go
// through a raw socket.

void main() {
  test('serves an injected document root on loopback', () async {
    final root = Directory.systemTemp.createTempSync('pistisai-ui');
    addTearDown(() {
      if (root.existsSync()) {
        root.deleteSync(recursive: true);
      }
    });
    File('${root.path}${Platform.pathSeparator}index.html')
        .writeAsStringSync('<html>pistisai-ui</html>');
    File('${root.path}${Platform.pathSeparator}app.js')
        .writeAsStringSync('console.log(1)');

    final server = PistisaiUiServer(port: 0, documentRoot: root.path);
    addTearDown(server.stop);
    await server.start();

    expect(AppConfig.pistisaiUiPort, 1338);
    expect(server.boundAddress!.address, '127.0.0.1');
    expect(server.boundPort, isNot(1337));
    expect(server.boundPort, isNot(8080));

    final index = await _get(server.boundPort, '/');
    expect(index.statusCode, 200);
    expect(index.body, contains('pistisai-ui'));

    final script = await _get(server.boundPort, '/app.js');
    expect(script.statusCode, 200);
    expect(script.body, contains('console.log'));

    final missing = await _get(server.boundPort, '/missing.html');
    expect(missing.statusCode, 404);

    final escaped = await _get(server.boundPort, '/..%2Fsecret.txt');
    expect(escaped.statusCode, 404);
  });

  test('start is a no-op when the document root has no index.html', () async {
    final root = Directory.systemTemp.createTempSync('pistisai-ui-missing');
    addTearDown(() {
      if (root.existsSync()) {
        root.deleteSync(recursive: true);
      }
    });

    final server = PistisaiUiServer(port: 0, documentRoot: root.path);
    addTearDown(server.stop);
    await server.start();

    expect(server.hasDocumentRoot, isFalse);
    expect(server.isRunning, isFalse);
  });
}

Future<_HttpBody> _get(int port, String path) async {
  final socket = await Socket.connect(InternetAddress.loopbackIPv4, port);
  try {
    socket.write(
      'GET $path HTTP/1.1\r\nHost: 127.0.0.1\r\nConnection: close\r\n\r\n',
    );
    await socket.flush();
    final bytes = await socket.fold<List<int>>(<int>[], (previous, chunk) {
      previous.addAll(chunk);
      return previous;
    });
    final raw = utf8.decode(bytes);
    final status = int.parse(raw.split(' ')[1]);
    final body = raw.split('\r\n\r\n').skip(1).join('\r\n\r\n');
    return _HttpBody(status, body);
  } finally {
    await socket.close();
  }
}

class _HttpBody {
  final int statusCode;
  final String body;

  const _HttpBody(this.statusCode, this.body);
}
