import 'dart:async';
import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

/// cloudflared-style login: local redirect captures the token query value.
Future<String?> openAccessLogin(Uri loginUrl) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final redirect = 'http://127.0.0.1:${server.port}/callback';
  final login = loginUrl.replace(
    queryParameters: {
      ...loginUrl.queryParameters,
      'redirect_url': redirect,
    },
  );
  try {
    final launched = await launchUrl(
      login,
      mode: LaunchMode.externalApplication,
    );
    if (!launched) return null;
    final request = await server.first.timeout(const Duration(minutes: 5));
    final token = request.uri.queryParameters['token'] ??
        request.uri.queryParameters['cf_access_token'] ??
        request.uri.queryParameters['CF_Authorization'];
    request.response.statusCode = HttpStatus.ok;
    request.response.headers.contentType = ContentType.html;
    request.response.write(
      '<p>Pistisai received the sign-in. You can close this window.</p>',
    );
    await request.response.close();
    return token;
  } on TimeoutException {
    return null;
  } finally {
    await server.close(force: true);
  }
}
