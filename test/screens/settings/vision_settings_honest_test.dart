// "Initialize All" on the vision settings screen must show ✅ only for a
// service that really started, and ❌ with the reason otherwise
// (AGENTS.md: "Controls tell the truth").
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/di/locator.dart' as di;
import 'package:pistisai/l10n/app_localizations.dart';
import 'package:pistisai/screens/settings/vision_settings_screen.dart';
import 'package:pistisai/services/vision/camera_capture_service.dart';
import 'package:pistisai/services/vision/ocr_engine_service.dart';
import 'package:pistisai/services/vision/region_capture_service.dart';
import 'package:pistisai/services/vision/vision_service.dart';

class _FailingRegionCapture extends RegionCaptureService {
  @override
  Future<bool> initialize() async => false;

  @override
  String? get lastError => 'region channel missing';
}

class _WorkingCamera extends CameraCaptureService {
  bool _ready = false;

  @override
  Future<bool> initialize() async => _ready = true;

  @override
  bool get isInitialized => _ready;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void register<T extends Object>(T instance) {
    if (di.serviceLocator.isRegistered<T>()) {
      di.serviceLocator.unregister<T>();
    }
    di.serviceLocator.registerSingleton<T>(instance);
  }

  tearDown(() {
    for (final unregister in [
      () => di.serviceLocator.unregister<MainVisionService>(),
      () => di.serviceLocator.unregister<RegionCaptureService>(),
      () => di.serviceLocator.unregister<CameraCaptureService>(),
      () => di.serviceLocator.unregister<OcrEngineService>(),
    ]) {
      try {
        unregister();
      } catch (_) {}
    }
  });

  testWidgets('shows ✅ only for services that really started', (tester) async {
    register<MainVisionService>(MainVisionService());
    register<RegionCaptureService>(_FailingRegionCapture());
    register<CameraCaptureService>(_WorkingCamera());
    // Real OCR service: on this test host there is neither the native
    // Tesseract channel nor the Android/iOS plugin, so it must fail.
    register<OcrEngineService>(OcrEngineService());

    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: Locale('en'),
      home: VisionSettingsScreen(startLinuxCamera: false),
    ));

    await tester.tap(find.text('Initialize All Services'));
    // The OCR service calls a real (absent) platform channel, whose reply
    // arrives outside the fake clock.
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('✅ Main Vision Service initialized'), findsOneWidget);
    expect(find.text('✅ Camera Capture Service initialized'), findsOneWidget);

    expect(find.text('✅ Region Capture Service initialized'), findsNothing);
    expect(find.text('❌ Region Capture Service: region channel missing'),
        findsOneWidget);

    expect(find.text('✅ OCR Engine Service initialized'), findsNothing);
    expect(find.textContaining('❌ OCR Engine Service: OCR is not available'),
        findsOneWidget);

    expect(find.text('Initialization complete'), findsNothing);
    expect(find.text('Some services did not start. See the results below.'),
        findsOneWidget);
  });
}
