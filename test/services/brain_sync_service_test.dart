import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/services/brain_sync_service.dart';

void main() {
  group('BrainSyncService.startSync idempotency', () {
    test('calling startSync twice does not start two timers', () async {
      var syncCallCount = 0;
      final service = _TestableBrainSync(onSync: () => syncCallCount++);

      service.startSync(interval: const Duration(seconds: 60));
      service.startSync(interval: const Duration(seconds: 60));
      service.startSync(interval: const Duration(seconds: 60));

      // Only one immediate sync should have fired despite three startSync calls.
      // We allow a tiny async window for the first sync() to complete.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(syncCallCount, 1,
          reason: 'startSync must be idempotent — only one sync should run');

      service.stopSync();
    });

    test('stopSync allows startSync to run again', () async {
      var syncCallCount = 0;
      final service = _TestableBrainSync(onSync: () => syncCallCount++);

      service.startSync(interval: const Duration(seconds: 60));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      service.stopSync();

      service.startSync(interval: const Duration(seconds: 60));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      service.stopSync();

      expect(syncCallCount, 2,
          reason: 'After stopSync, startSync should work once more');
    });
  });
}

/// Minimal subclass that overrides sync() to avoid real DB/HTTP.
class _TestableBrainSync extends BrainSyncService {
  final void Function() onSync;
  _TestableBrainSync({required this.onSync}) : super.forTest();

  @override
  Future<SyncResult> sync() async {
    onSync();
    return SyncResult(
      success: true,
      uploaded: 0,
      downloaded: 0,
      failed: 0,
      duration: Duration.zero,
    );
  }
}
