import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/config/app_config.dart';

void main() {
  test('admin API base URL has no duplicated /admin segment', () {
    expect(AppConfig.adminApiBaseUrl.endsWith('/api'), isTrue);
    expect(AppConfig.adminApiBaseUrl.endsWith('/api/admin'), isFalse);
  });

  test('admin access comes from the server, not a build-time email', () {
    final service =
        File('lib/services/admin_center_service.dart').readAsStringSync();
    final screen =
        File('lib/screens/admin/admin_center_screen.dart').readAsStringSync();
    final backend = File('services/api-backend/routes/admin.js').readAsStringSync();

    expect(service, contains("'/admin/me'"));
    expect(service, isNot(contains('/admin/auth/roles')));
    expect(screen, contains('checkAdminAccess()'));
    expect(screen, isNot(contains('PISTISAI_ADMIN_EMAIL')));
    expect(backend, contains("router.get('/me', authenticateJWT"));
    expect(backend, contains('const isAdmin = roles.includes(\'admin\')'));
  });
}
