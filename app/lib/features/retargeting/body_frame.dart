import 'pose_math.dart';

class BodyPoint {
  const BodyPoint(this.position, {this.visibility, this.presence});
  final V3 position;
  final double? visibility, presence;
  bool get usable =>
      position.finite &&
      position.length < 10 &&
      (visibility == null || (visibility!.isFinite && visibility! >= .5)) &&
      (presence == null || (presence!.isFinite && presence! >= .5));
  static BodyPoint? parse(Object? raw) {
    if (raw is! Map<String, Object?>) return null;
    final x = raw['x'], y = raw['y'], z = raw['z'];
    if (x is! num || y is! num || z is! num) return null;
    final p = BodyPoint(
      V3(x.toDouble(), y.toDouble(), z.toDouble()),
      visibility: (raw['visibility'] as num?)?.toDouble(),
      presence: (raw['presence'] as num?)?.toDouble(),
    );
    return p.position.finite ? p : null;
  }
}

class BodyFrame {
  BodyFrame({
    required this.sessionId,
    required this.sequence,
    required this.capturedAtUs,
    required List<BodyPoint?> world,
    required List<BodyPoint?> image,
    List<BodyPoint?> leftHandWorld = const [],
    List<BodyPoint?> rightHandWorld = const [],
  }) : world = List.unmodifiable(world),
       image = List.unmodifiable(image),
       leftHandWorld = List.unmodifiable(leftHandWorld),
       rightHandWorld = List.unmodifiable(rightHandWorld);
  final String sessionId;
  final int sequence, capturedAtUs;
  final List<BodyPoint?> world, image;
  final List<BodyPoint?> leftHandWorld, rightHandWorld;
  factory BodyFrame.parse(Map<String, Object?> event) {
    if (event['schemaVersion'] != 3 || event['sessionId'] is! String)
      throw const FormatException(
        'Tracking helper protocol mismatch. Use the newest AppImage.',
      );
    List<BodyPoint?> read(String key) {
      final raw = event[key];
      if (raw is! List<Object?> || (raw.isNotEmpty && raw.length != 33))
        throw FormatException('Invalid $key landmark count');
      return raw.map(BodyPoint.parse).toList();
    }

    List<BodyPoint?> readHand(String key) {
      final raw = event[key];
      if (raw == null) return const [];
      if (raw is! List<Object?> || (raw.isNotEmpty && raw.length != 21)) {
        throw FormatException('Invalid $key landmark count');
      }
      return raw.map(BodyPoint.parse).toList();
    }

    final sequence = (event['sequence'] as num).toInt(),
        time = (event['capturedAtUs'] as num).toInt();
    if (sequence < 1 || time < 1)
      throw const FormatException('Invalid frame ordering metadata');
    return BodyFrame(
      sessionId: event['sessionId'] as String,
      sequence: sequence,
      capturedAtUs: time,
      world: read('worldPoints'),
      image: read('points'),
      leftHandWorld: readHand('leftHandWorld'),
      rightHandWorld: readHand('rightHandWorld'),
    );
  }

  /// MediaPipe camera estimates -> right-handed solver metres: (x,-y,-z).
  /// Mirror-avatar mode reflects X AND exchanges anatomical sides before solving.
  BodyPoint? solverPoint(int index, {bool mirror = false}) {
    const opposite = {
      11: 12,
      12: 11,
      13: 14,
      14: 13,
      15: 16,
      16: 15,
      23: 24,
      24: 23,
      25: 26,
      26: 25,
      27: 28,
      28: 27,
    };
    final mapped = mirror ? (opposite[index] ?? index) : index;
    if (mapped >= world.length) return null;
    final raw = world[mapped];
    if (raw == null || !raw.usable) return null;
    final p = raw.position;
    return BodyPoint(
      V3(mirror ? -p.x : p.x, -p.y, -p.z),
      visibility: raw.visibility,
      presence: raw.presence,
    );
  }

  /// Hand Landmarker world points are wrist-origin, camera-oriented metres.
  /// Anchor them to the matching Pose wrist before applying the solver basis.
  BodyPoint? solverHandPoint(bool left, int index, {bool mirror = false}) {
    final anatomicalLeft = mirror ? !left : left;
    final hand = anatomicalLeft ? leftHandWorld : rightHandWorld;
    final rawWrist = world.length > (anatomicalLeft ? 15 : 16)
        ? world[anatomicalLeft ? 15 : 16]
        : null;
    final wrist = rawWrist == null || !rawWrist.usable
        ? null
        : BodyPoint(
            V3(
              mirror ? -rawWrist.position.x : rawWrist.position.x,
              -rawWrist.position.y,
              -rawWrist.position.z,
            ),
          );
    if (hand.length != 21 ||
        index < 0 ||
        index >= hand.length ||
        wrist == null) {
      return null;
    }
    final localWrist = hand[0];
    final local = hand[index];
    if (local == null ||
        localWrist == null ||
        !local.usable ||
        !localWrist.usable) {
      return null;
    }
    final offset = local.position - localWrist.position;
    final converted = V3(mirror ? -offset.x : offset.x, -offset.y, -offset.z);
    return BodyPoint(
      wrist.position + converted,
      visibility: local.visibility,
      presence: local.presence,
    );
  }
}
