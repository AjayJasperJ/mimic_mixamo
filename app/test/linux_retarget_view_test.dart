import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimic_mixamo/features/camera/linux_camera_view.dart';
import 'package:mimic_mixamo/platform/linux_tracker.dart';
import 'package:mimic_mixamo/features/retargeting/pose_math.dart';

void main() {
  testWidgets('labelled replay calibrates and drives the avatar without a camera process', (tester) async {
    debugDefaultTargetPlatformOverride=TargetPlatform.linux;
    var now=1;
    final tracker=LinuxTracker(executable:'/missing-helper-not-used-in-replay',nowUs:()=>now);
    try {
      tester.view.physicalSize=const Size(1280,1000);tester.view.devicePixelRatio=1;
      await tester.pumpWidget(MaterialApp(home:Scaffold(body:SizedBox(height:800,child:LinuxCameraView(tracker:tracker,autoReplay:true)))));
      for(var i=0;i<55;i++) { now+=66000;await tester.pump(const Duration(milliseconds:66)); }
      expect(find.text('REPLAY • synthetic test input • no camera is open'),findsOneWidget);
      expect(tracker.replaying,isTrue);expect(tracker.jpeg,isNull);
      expect(tracker.solver.calibrated,isTrue);expect(tracker.solver.validBones,10);
      expect(tracker.solver.pose.localRotations['LeftForeArm']!.angleTo(Rotation.identity),greaterThan(.1));
      await tester.tap(find.text('Stop camera'));await tester.pump();
      expect(tracker.running,isFalse);expect(tracker.solver.calibrated,isFalse);
      expect(tracker.solver.pose.localRotations,isEmpty);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      tester.view.resetPhysicalSize();tester.view.resetDevicePixelRatio();
      debugDefaultTargetPlatformOverride=null;
    }
  });
}
