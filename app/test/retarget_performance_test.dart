import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimic_mixamo/features/retargeting/retarget_engine.dart';
import 'package:mimic_mixamo/features/retargeting/replay_fixture.dart';
import 'package:mimic_mixamo/features/rig/glb_mesh.dart';

void main() {
  test('long synthetic sequence stays finite through solver and actual GLB skinning',() async {
    final mesh=GlbMesh.parse(await File('assets/characters/development_humanoid.glb').readAsBytes());
    final solver=RetargetEngine()..attach('perf')..configure(body:true)..beginCalibration();
    for(var i=1;i<=30;i++) { solver.receive(ReplayFixture.frame('perf',i,i*70000),i*70000); }
    expect(solver.calibrated,isTrue);
    final samples=<int>[];
    for(var i=31;i<=330;i++) {
      final frame=ReplayFixture.animated('perf',i,i*70000,i*.07,fullBody:true);
      final watch=Stopwatch()..start();
      solver.receive(frame,i*70000);final vertices=mesh.posedVertices(solver.pose);
      samples.add(watch.elapsedMicroseconds);
      expect(vertices.every((v)=>v.x.isFinite&&v.y.isFinite&&v.z.isFinite),isTrue);
      expect(solver.pose.rootYOffset, inInclusiveRange(-.55,.15));
      expect(solver.pose.localRotations.values.every((q)=>(q.norm-1).abs()<1e-7),isTrue);
    }
    samples.sort();
    // Measured CPU cost of synthetic solve+skin only, not webcam/render latency or device FPS.
    print('MIMIC_SYNTHETIC_CPU ${jsonEncode({'samples':samples.length,'medianUs':samples[samples.length~/2],'p95Us':samples[(samples.length*.95).floor()],'scope':'CI synthetic solve+skin; excludes camera, inference, raster and display'})}');
  });
}
