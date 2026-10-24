import 'dart:math' as math;
import '../rig/rig_pose.dart';
import 'body_frame.dart';
import 'pose_math.dart';
import 'rig_definition.dart';

class RetargetEngine {
  String? sessionId;
  bool fullBody = false, mirrorMovement = false;
  double smoothing = .35;
  bool calibrated = false, calibrating = false;
  double progress = 0;
  String state = 'idle',
      guidance = 'Start tracking, then hold a T-pose and calibrate';
  int rejectedFrames = 0, validBones = 0, solverUs = 0;
  int _observedBones = 0;
  double poseRate = 0;
  RigPose pose = const RigPose();
  int _sequence = 0,
      _captured = 0,
      _lastTick = 0,
      _lastBody = -10000000,
      _rateStart = 0,
      _rateFrames = 0;
  int _calibrationStart = 0, _samples = 0;
  Rotation _reference = Rotation.identity;
  V3 _sumX = V3.zero, _sumUp = V3.zero;
  final Map<String, Rotation> _correction = {}, _lastGood = {}, _smoothed = {};
  final Map<String, int> _lastGoodAt = {};
  double _root = 0;

  void attach(String id) {
    sessionId = id;
    _sequence = 0;
    _captured = 0;
    _lastTick = 0;
    _lastBody = -10000000;
    rejectedFrames = 0;
    poseRate = 0;
    _rateStart = 0;
    _rateFrames = 0;
    _clearCalibration();
    state = 'ready';
    guidance = 'Hold a T-pose and select Calibrate';
  }

  void stop() {
    sessionId = null;
    _clearCalibration();
    state = 'idle';
    guidance = 'Camera stopped';
  }

  void configure({bool? body, bool? mirror}) {
    if (body != null) fullBody = body;
    if (mirror != null) mirrorMovement = mirror;
    _clearCalibration();
    state = 'ready';
    guidance = 'Configuration changed. Hold a T-pose and recalibrate.';
  }

  void _clearCalibration() {
    calibrated = false;
    calibrating = false;
    progress = 0;
    _samples = 0;
    _calibrationStart = 0;
    _sumX = V3.zero;
    _sumUp = V3.zero;
    _correction.clear();
    _lastGood.clear();
    _lastGoodAt.clear();
    _smoothed.clear();
    _root = 0;
    pose = const RigPose();
    validBones = 0;
    _observedBones = 0;
  }

  void beginCalibration() {
    if (sessionId == null) {
      guidance = 'Start the webcam or labelled replay first';
      return;
    }
    _clearCalibration();
    calibrating = true;
    state = 'calibrating';
    guidance = 'Face the camera. Hold both arms straight out in a T-pose.';
  }

  V3? _point(BodyFrame frame, int i) =>
      frame.solverPoint(i, mirror: mirrorMovement)?.position;
  Rotation? _basis(BodyFrame frame) {
    final left = _point(frame, 11),
        right = _point(frame, 12),
        lh = _point(frame, 23),
        rh = _point(frame, 24);
    if (left == null || right == null || lh == null || rh == null) return null;
    try {
      final x = (left - right).unit(), rawUp = (left + right - lh - rh) * .5;
      final y = (rawUp - x * rawUp.dot(x)).unit();
      return Rotation.basis(x, y, x.cross(y).unit());
    } on FormatException {
      return null;
    }
  }

  bool receive(BodyFrame frame, int arrivalUs) {
    if (frame.sessionId != sessionId ||
        frame.sequence <= _sequence ||
        frame.capturedAtUs <= _captured) {
      rejectedFrames++;
      return false;
    }
    _sequence = frame.sequence;
    _captured = frame.capturedAtUs;
    if (_rateFrames == 0) _rateStart = arrivalUs;
    _rateFrames++;
    if (arrivalUs - _rateStart >= 1000000) {
      poseRate = _rateFrames * 1000000 / (arrivalUs - _rateStart);
      _rateStart = arrivalUs;
      _rateFrames = 0;
    }
    final watch = Stopwatch()..start();
    if (calibrating)
      _calibrate(frame, arrivalUs);
    else if (calibrated)
      _solve(frame, arrivalUs);
    solverUs = watch.elapsedMicroseconds;
    advance(arrivalUs);
    return true;
  }

  String? _calibrationIssue(BodyFrame frame) {
    final required = [
      11,
      12,
      13,
      14,
      15,
      16,
      23,
      24,
      if (fullBody) ...[25, 26, 27, 28],
    ];
    if (required.any((i) => _point(frame, i) == null))
      return 'Keep the required joints visible and confidently tracked';
    if (frame.image.length != 33)
      return 'Keep the required joints clearly visible in the camera image';
    if (required.any((i) => frame.image[i]?.usable != true))
      return 'Keep the required joints clearly visible in the camera image';
    if (frame.image[11] == null ||
        frame.image[12] == null ||
        (frame.image[11]!.position.x - frame.image[12]!.position.x).abs() < .10)
      return 'Move closer: shoulders are too small in the image';
    final basis = _basis(frame);
    if (basis == null) return 'Face the camera with shoulders and hips visible';
    for (final left in [true, false]) {
      // Calibration acceptance follows the same 2D landmarks shown in the
      // camera overlay. World-space arm direction can lean toward/away from
      // the camera even when the user is visibly holding a T-pose.
      final shoulder = frame.image[left ? 11 : 12]!.position,
          elbow = frame.image[left ? 13 : 14]!.position,
          wrist = frame.image[left ? 15 : 16]!.position;
      try {
        final upper = (elbow - shoulder).unit(),
            forearm = (wrist - elbow).unit(),
            arm = wrist - shoulder;
        if (upper.dot(forearm) < .70 ||
            arm.x.abs() < .08 ||
            arm.y.abs() > arm.x.abs() * .70)
          return 'Extend both arms sideways; keep elbows straight and wrists visible';
      } on FormatException {
        return 'Arm landmarks overlap. Reframe and try again';
      }
    }
    if (fullBody) {
      for (final left in [true, false]) {
        final h = _point(frame, left ? 23 : 24)!,
            k = _point(frame, left ? 25 : 26)!,
            a = _point(frame, left ? 27 : 28)!;
        try {
          if ((k - h).unit().dot((a - k).unit()) < .85)
            return 'Stand upright with straight legs for calibration';
        } on FormatException {
          return 'Show both knees and ankles';
        }
      }
    }
    return null;
  }

  void _calibrate(BodyFrame frame, int now) {
    final issue = _calibrationIssue(frame);
    if (issue != null) {
      _samples = 0;
      progress = 0;
      _calibrationStart = 0;
      _sumX = V3.zero;
      _sumUp = V3.zero;
      guidance = issue;
      return;
    }
    final basis = _basis(frame)!;
    if (_samples == 0) _calibrationStart = now;
    _samples++;
    _sumX = _sumX + basis.rotate(V3.right);
    _sumUp = _sumUp + basis.rotate(V3.up);
    progress = math
        .min((now - _calibrationStart) / 1500000, _samples / 15)
        .clamp(0.0, 1.0)
        .toDouble();
    guidance =
        'Hold the T-pose steady • ${(progress * 100).round()}% calibration';
    if (progress < 1) return;
    final x = _sumX.unit(), y = (_sumUp - x * _sumUp.dot(x)).unit();
    _reference = Rotation.basis(x, y, x.cross(y).unit());
    final raw = _globals(frame);
    if (raw.length < DevelopmentRig.bones(fullBody).length) {
      _samples = 0;
      progress = 0;
      _sumX = V3.zero;
      _sumUp = V3.zero;
      guidance = 'Required joints were lost; hold the T-pose again';
      return;
    }
    _correction.clear();
    for (final entry in raw.entries) {
      _correction[entry.key] = entry.value.inverse;
    }
    calibrated = true;
    calibrating = false;
    state = 'tracking';
    progress = 1;
    _smoothed.clear();
    _lastGood.clear();
    _lastGoodAt.clear();
    _lastTick = now;
    _solve(frame, now);
    guidance = 'Calibrated. Move naturally; root position stays anchored.';
  }

  Map<String, Rotation> _globals(BodyFrame frame) {
    final basis = _basis(frame);
    if (basis == null) return {};
    final result = <String, Rotation>{};
    V3 framed(V3 p) => _reference.inverse.rotate(p);
    final lh = _point(frame, 23)!, rh = _point(frame, 24)!;
    try {
      final side = framed(lh - rh);
      final horizontal = V3(side.x, 0, side.z).unit();
      result['Hips'] = Rotation.basis(
        horizontal,
        V3.up,
        horizontal.cross(V3.up).unit(),
      );
      result['Chest'] = _reference.inverse * basis;
      final directions = <String, V3>{};
      for (final entry in DevelopmentRig.segments.entries) {
        if (!fullBody &&
            (entry.key.contains('Thigh') || entry.key.contains('Shin')))
          continue;
        final parent = DevelopmentRig.parents[entry.key];
        if (parent != null && !result.containsKey(parent)) continue;
        final (a, b, rest) = entry.value;
        final start = _point(frame, a), end = _point(frame, b);
        if (start == null || end == null) continue;
        V3 direction;
        try {
          direction = framed(end - start).unit();
        } on FormatException {
          continue;
        }
        if (entry.key.contains('ForeArm') || entry.key.contains('Shin')) {
          final previous = directions[parent];
          if (previous == null) continue;
          final bend = math.acos(previous.dot(direction).clamp(-1.0, 1.0));
          final maxBend =
              (entry.key.contains('Shin') ? 145 : 155) * math.pi / 180;
          if (bend > maxBend)
            direction = Rotation.identity
                .slerp(Rotation.fromTo(previous, direction), maxBend / bend)
                .rotate(previous)
                .unit();
        }
        directions[entry.key] = direction;
        result[entry.key] = Rotation.fromTo(rest, direction);
      }
    } on FormatException {
      return {};
    }
    return result;
  }

  void _solve(BodyFrame frame, int now) {
    final raw = _globals(frame);
    final desired = <String, Rotation>{};
    for (final entry in raw.entries) {
      desired[entry.key] =
          entry.value * (_correction[entry.key] ?? Rotation.identity);
    }
    validBones = 0;
    for (final name in DevelopmentRig.bones(fullBody)) {
      final global = desired[name], parent = DevelopmentRig.parents[name];
      if (global == null || (parent != null && !desired.containsKey(parent)))
        continue;
      final local = parent == null ? global : desired[parent]!.inverse * global;
      _lastGood[name] = local.normalized();
      _lastGoodAt[name] = now;
      validBones++;
    }
    _observedBones = validBones;
    if (desired.containsKey('Chest')) _lastBody = now;
  }

  RigPose advance(int now) {
    if (!calibrated) return pose;
    final delta = _lastTick == 0
        ? 1 / 30
        : ((now - _lastTick) / 1000000).clamp(0.0, .2).toDouble();
    _lastTick = now;
    final alpha =
        1 - math.exp(-delta / (.025 + .30 * smoothing.clamp(0.0, 1.0)));
    for (final name in DevelopmentRig.bones(fullBody)) {
      final good = _lastGood[name] ?? Rotation.identity;
      final age = now - (_lastGoodAt[name] ?? -10000000);
      final fallback = ((age - 200000) / 500000).clamp(0.0, 1.0).toDouble();
      final target = good.slerp(Rotation.identity, fallback);
      _smoothed[name] = (_smoothed[name] ?? Rotation.identity).slerp(
        target,
        alpha,
      );
    }
    validBones = math.min(
      _observedBones,
      DevelopmentRig.bones(fullBody)
          .where((name) => now - (_lastGoodAt[name] ?? -10000000) <= 200000)
          .length,
    );
    var rootTarget = 0.0;
    final freshLegs = [
      'LeftThigh',
      'LeftShin',
      'RightThigh',
      'RightShin',
    ].every((b) => now - (_lastGoodAt[b] ?? -10000000) < 200000);
    if (fullBody && freshLegs)
      rootTarget = _groundOffset(_smoothed).clamp(-.55, .15).toDouble();
    _root += (rootTarget - _root) * alpha;
    pose = RigPose(
      localRotations: Map.unmodifiable(_smoothed),
      rootYOffset: _root,
    );
    if (now - _lastBody > 1000000) {
      state = 'lost';
      guidance = 'Tracking lost. Hold position and face the camera to recover.';
    } else if (now - _lastBody > 200000 ||
        validBones < DevelopmentRig.bones(fullBody).length) {
      state = 'partial';
      guidance =
          'Partial tracking: missing joints briefly hold, then return to neutral.';
    } else {
      state = 'tracking';
      guidance = fullBody
          ? 'Full-body beta • approximate ground height, no room-scale travel'
          : 'Upper-body tracking • anatomical sides preserved';
    }
    return pose;
  }

  double _groundOffset(Map<String, Rotation> locals) {
    final hip = locals['Hips'] ?? Rotation.identity;
    var lowest = double.infinity;
    for (final left in [true, false]) {
      final prefix = left ? 'Left' : 'Right';
      final thigh = hip * (locals['${prefix}Thigh'] ?? Rotation.identity);
      final shin = thigh * (locals['${prefix}Shin'] ?? Rotation.identity);
      final origin =
          const V3(0, .9, 0) +
          hip.rotate(V3(left ? .12 : -.12, -.05, 0)) +
          thigh.rotate(const V3(0, -.42, 0));
      // Actual foot-box bounds relative to each development shin joint.
      for (final x in [-.075, .075]) {
        for (final y in [-.43, -.36]) {
          for (final z in [-.075, .195]) {
            lowest = math.min(lowest, (origin + shin.rotate(V3(x, y, z))).y);
          }
        }
      }
    }
    return -lowest;
  }
}
