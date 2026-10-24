import 'dart:math' as math;
import 'dart:ui';
import '../retargeting/pose_math.dart';

/// Development rig convention: +Y up, +X anatomical left, angles about +Z.
class RigPose {
  const RigPose({this.leftShoulder = 0, this.leftElbow = 0,
    this.rightShoulder = 0, this.rightElbow = 0,
    this.localRotations = const {}, this.rootYOffset = 0});
  final double leftShoulder, leftElbow, rightShoulder, rightElbow;
  final Map<String,Rotation> localRotations;
  final double rootYOffset;
  List<double> get angles => [leftShoulder, leftElbow, rightShoulder, rightElbow];
  RigPose withAngle(int index, double value) {
    if (!value.isFinite) throw ArgumentError.value(value, 'value');
    final updated = angles;
    updated[index] = value.clamp(-120, 120).toDouble();
    return RigPose(leftShoulder: updated[0], leftElbow: updated[1],
      rightShoulder: updated[2], rightElbow: updated[3]);
  }
  List<Offset> arm({required bool left}) {
    final sign = left ? 1.0 : -1.0;
    final a = (left ? leftShoulder : rightShoulder) * math.pi / 180;
    final b = (left ? leftElbow : rightElbow) * math.pi / 180;
    final shoulder = Offset(sign * .20, 1.45);
    final elbow = shoulder + Offset(sign * .40 * math.cos(a), sign * .40 * math.sin(a));
    final wrist = elbow + Offset(sign * .36 * math.cos(a+b), sign * .36 * math.sin(a+b));
    return [shoulder, elbow, wrist];
  }
}
