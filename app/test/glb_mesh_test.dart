import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimic_mixamo/features/rig/glb_mesh.dart';
import 'package:mimic_mixamo/features/rig/rig_pose.dart';

void main() {
  test(
    'bundled GLB bind matrices preserve rest mesh and drive only the selected arm',
    () async {
      final mesh = GlbMesh.parse(
        await File('assets/characters/development_humanoid.glb').readAsBytes(),
      );
      expect(mesh.vertices.length, 360);
      expect(mesh.indices.length ~/ 3, 540);
      expect(mesh.skinJoints.length, 42);
      final rest = mesh.posedVertices(const RigPose());
      for (var i = 0; i < rest.length; i++) {
        expect((rest[i] - mesh.vertices[i].position).length, lessThan(1e-5));
      }
      final posed = mesh.posedVertices(const RigPose(leftElbow: 90));
      final left = mesh.vertices.indexWhere((v) => v.joints.first == 3);
      final right = mesh.vertices.indexWhere((v) => v.joints.first == 5);
      expect((posed[left] - rest[left]).length, greaterThan(.01));
      expect((posed[right] - rest[right]).length, lessThan(1e-5));
    },
  );
  test('desktop GLB loader rejects text or truncated files before parsing', () {
    expect(() => GlbMesh.parse(Uint8List(20)), throwsFormatException);
  });
}
