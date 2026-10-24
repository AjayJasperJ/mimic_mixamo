import 'package:flutter_test/flutter_test.dart';
import 'package:mimic_mixamo/features/rig/rig_pose.dart';

void main() {
  test('left elbow moves wrist without moving shoulder, elbow or opposite arm', () {
    const rest = RigPose();
    final bent = rest.withAngle(1, 90);
    final original = rest.arm(left: true);
    final moved = bent.arm(left: true);
    expect(moved[0], original[0]);
    expect(moved[1], original[1]);
    expect(moved[2].dx, closeTo(.60, 1e-9));
    expect(moved[2].dy, closeTo(1.81, 1e-9));
    expect(bent.arm(left: false), rest.arm(left: false));
  });
  test('parent shoulder rotation carries the forearm and preserves bone lengths', () {
    const rest = RigPose();
    final points = rest.withAngle(0, 90).withAngle(1, -90).arm(left: true);
    expect(points[1].dx, closeTo(.20, 1e-9));
    expect(points[1].dy, closeTo(1.85, 1e-9));
    expect(points[2].dx, closeTo(.56, 1e-9));
    expect((points[1]-points[0]).distance, closeTo(.40, 1e-9));
    expect((points[2]-points[1]).distance, closeTo(.36, 1e-9));
  });
  test('nonfinite angles rejected and diagnostic angles bounded', () {
    expect(() => const RigPose().withAngle(0, double.nan), throwsArgumentError);
    expect(const RigPose().withAngle(0, 999).leftShoulder, 120);
  });
}
