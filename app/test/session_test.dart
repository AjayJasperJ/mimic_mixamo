import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimic_mixamo/main.dart';

void main() {
  testWidgets('simulation starts, pauses and resets without camera claims', (tester) async {
    await tester.pumpWidget(const MimicApp());
    expect(find.text('Simulator paused'), findsOneWidget);
    await tester.tap(find.text('Start simulation'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Simulator running'), findsOneWidget);
    await tester.tap(find.text('Pause simulation'));
    await tester.pump();
    expect(find.text('Simulator paused'), findsOneWidget);
    await tester.tap(find.text('Reset pose'));
    await tester.pump();
    expect(tester.widget<Slider>(find.byType(Slider)).value, 0.5);
  });
}
