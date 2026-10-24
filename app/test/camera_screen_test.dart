import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimic_mixamo/features/camera/camera_screen.dart';

void main() {
  testWidgets('Linux explicitly explains camera support and never opens native camera', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(const MaterialApp(home: CameraScreen()));
      expect(find.byType(AndroidView), findsNothing);
      expect(find.text('Linux camera support is not implemented'), findsOneWidget);
      final start = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Start camera'));
      expect(start.onPressed, isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
