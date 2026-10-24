import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimic_mixamo/main.dart';

void main() {
  testWidgets(
    'synthetic sample starts in a T-pose and manual bend can be reset',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MimicApp());
      expect(find.textContaining('starts in a T-pose'), findsOneWidget);
      expect(find.text('Simulator paused'), findsOneWidget);
      await tester.tap(find.text('Start simulation'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Simulator running'), findsOneWidget);
      await tester.tap(find.text('Pause simulation'));
      await tester.pump();
      expect(find.text('Simulator paused'), findsOneWidget);
      await tester.tap(find.text('Reset pose'));
      await tester.pump();
      expect(tester.widget<Slider>(find.byType(Slider)).value, 0);
    },
  );
}
