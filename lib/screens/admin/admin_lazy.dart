import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'admin_center_screen.dart';
import 'admin_data_flush_screen.dart';
import '../../config/app_config.dart';

final adminRoutes = [
  GoRoute(
    path: '/admin/data-flush',
    name: 'admin-data-flush',
    pageBuilder: (context, state) {
      AppConfig.verboseLog('[Router] Building AdminDataFlushScreen');
      return MaterialPage(
        key: state.pageKey,
        child: const AdminDataFlushScreen(),
      );
    },
  ),
  GoRoute(
    path: '/admin-center',
    name: 'admin-center',
    pageBuilder: (context, state) {
      AppConfig.verboseLog('[Router] Building AdminCenterScreen');
      return MaterialPage(
        key: state.pageKey,
        child: const AdminCenterScreen(),
      );
    },
  ),
];
