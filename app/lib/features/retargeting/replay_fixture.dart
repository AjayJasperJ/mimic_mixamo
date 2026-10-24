import 'dart:math' as math;
import 'body_frame.dart';
import 'pose_math.dart';

/// Explicitly synthetic test input. Never described as webcam or accuracy evidence.
class ReplayFixture {
  static BodyFrame frame(
    String session,
    int sequence,
    int timeUs, {
    double leftShoulder = 0,
    double leftElbow = 0,
    double rightShoulder = 0,
    double rightElbow = 0,
    double torsoLean = 0,
    double crouch = 0,
    double fingerCurl = 0,
  }) {
    final a = crouch.clamp(0.0, .8).toDouble();
    final b = math.asin(.42 / .43 * math.sin(a));
    final hipHeight = .05 + .42 * math.cos(a) + .43 * math.cos(b);
    final positions = List<V3>.filled(33, V3(0, hipHeight + .75, 0));
    final hip = V3(0, hipHeight, 0),
        torso = Rotation.axis(const V3(0, 0, 1), torsoLean);
    V3 upper(V3 p) =>
        hip - const V3(0, .05, 0) + torso.rotate(p + const V3(0, .05, 0));
    positions[11] = upper(const V3(.2, .55, 0));
    positions[12] = upper(const V3(-.2, .55, 0));
    for (final left in [true, false]) {
      final side = left ? 1.0 : -1.0;
      final shoulder = positions[left ? 11 : 12];
      final arm = Rotation.axis(
        const V3(0, 0, 1),
        left ? leftShoulder : rightShoulder,
      );
      final fore = Rotation.axis(
        const V3(0, 0, 1),
        (left ? leftShoulder : rightShoulder) + (left ? leftElbow : rightElbow),
      );
      final elbow = shoulder + torso.rotate(arm.rotate(V3(side * .4, 0, 0)));
      positions[left ? 13 : 14] = elbow;
      positions[left ? 15 : 16] =
          elbow + torso.rotate(fore.rotate(V3(side * .36, 0, 0)));
      final h = V3(side * .12, hipHeight - .05, 0);
      final knee = h + Rotation.axis(V3.right, -a).rotate(const V3(0, -.42, 0));
      final ankle =
          knee + Rotation.axis(V3.right, b).rotate(const V3(0, -.43, 0));
      positions[left ? 23 : 24] = h;
      positions[left ? 25 : 26] = knee;
      positions[left ? 27 : 28] = ankle;
      positions[left ? 29 : 30] = ankle + const V3(0, 0, -.05);
      positions[left ? 31 : 32] = ankle + const V3(0, 0, .12);
    }
    final world = positions
        .map(
          (p) => BodyPoint(
            V3(p.x, -(p.y - hipHeight), -p.z),
            visibility: 1,
            presence: 1,
          ),
        )
        .toList();
    final image = positions
        .map(
          (p) => BodyPoint(
            V3(.5 + p.x * .45, .95 - p.y * .4, 0),
            visibility: 1,
            presence: 1,
          ),
        )
        .toList();
    List<BodyPoint?> hand(bool left) {
      final side = left ? 1.0 : -1.0;
      final points = List<V3>.filled(21, V3.zero);
      void finger(List<int> indices, double y, double length) {
        var x = 0.0;
        var rise = 0.0;
        points[indices.first] = V3(0, y, 0);
        for (var i = 1; i < indices.length; i++) {
          final angle = fingerCurl * i * .75;
          x += side * length * math.cos(angle);
          rise += length * math.sin(angle);
          points[indices[i]] = V3(x, y + (left ? rise : -rise), 0);
        }
      }

      points[1] = V3(side * .025, -.035, 0);
      points[2] = V3(side * .06, -.06, 0);
      points[3] = V3(side * .095, -.075, 0);
      points[4] = V3(side * .125, -.085, 0);
      finger([5, 6, 7, 8], .05, .055);
      finger([9, 10, 11, 12], .015, .065);
      finger([13, 14, 15, 16], -.02, .058);
      finger([17, 18, 19, 20], -.055, .047);
      return points
          .map(
            (p) => BodyPoint(V3(p.x, -p.y, -p.z), visibility: 1, presence: 1),
          )
          .toList();
    }

    return BodyFrame(
      sessionId: session,
      sequence: sequence,
      capturedAtUs: timeUs,
      world: world,
      image: image,
      leftHandWorld: hand(true),
      rightHandWorld: hand(false),
    );
  }

  static BodyFrame animated(
    String session,
    int sequence,
    int timeUs,
    double seconds, {
    required bool fullBody,
  }) => frame(
    session,
    sequence,
    timeUs,
    leftShoulder: .4 * math.sin(seconds * 1.2),
    leftElbow: .9 * (.5 + .5 * math.sin(seconds * 1.7)),
    rightShoulder: -.2 * math.sin(seconds * .8),
    rightElbow: -.6 * (.5 + .5 * math.sin(seconds * .9)),
    torsoLean: .12 * math.sin(seconds * .6),
    crouch: fullBody ? .6 * (.5 + .5 * math.sin(seconds * .7)) : 0,
    fingerCurl: .8 * (.5 + .5 * math.sin(seconds * 1.8)),
  );
}
