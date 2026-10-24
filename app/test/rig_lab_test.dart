import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimic_mixamo/features/rig/rig_lab.dart';

void main() {
  testWidgets('Linux rig controls move independently and restore neutral', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: RigLab()));
    expect(find.textContaining('Linux: joint hierarchy preview'), findsOneWidget);
    expect(find.byType(AndroidView), findsNothing);
    await tester.drag(find.byKey(const ValueKey('joint-1')), const Offset(100, 0));
    await tester.pump();
    final leftElbow = tester.widget<Slider>(find.byKey(const ValueKey('joint-1'))).value;
    expect(leftElbow, greaterThan(0));
    expect(tester.widget<Slider>(find.byKey(const ValueKey('joint-3'))).value, 0);
    await tester.tap(find.text('Restore T-pose'));
    await tester.pump();
    expect(tester.widget<Slider>(find.byKey(const ValueKey('joint-1'))).value, 0);
  });
}
