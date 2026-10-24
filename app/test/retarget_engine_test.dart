import 'dart:io';
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:mimic_mixamo/features/retargeting/body_frame.dart';
import 'package:mimic_mixamo/features/retargeting/pose_math.dart';
import 'package:mimic_mixamo/features/retargeting/retarget_engine.dart';
import 'package:mimic_mixamo/features/retargeting/replay_fixture.dart';
import 'package:mimic_mixamo/features/rig/glb_mesh.dart';
import 'package:mimic_mixamo/features/rig/rig_pose.dart';

RetargetEngine calibrated({bool full = false, bool mirror = false}) {
  final engine = RetargetEngine()
    ..attach('test')
    ..configure(body: full, mirror: mirror)
    ..beginCalibration();
  for (var i = 1; i <= 30; i++) {
    engine.receive(ReplayFixture.frame('test', i, i * 70000), i * 70000);
  }
  expect(engine.calibrated, isTrue, reason: engine.guidance);
  return engine;
}

void move(
  RetargetEngine engine, {
  double elbow = 0,
  double shoulder = 0,
  double right = 0,
  double lean = 0,
  double crouch = 0,
  int first = 31,
  int last = 45,
}) {
  for (var i = first; i <= last; i++) {
    engine.receive(
      ReplayFixture.frame(
        'test',
        i,
        i * 70000,
        leftElbow: elbow,
        leftShoulder: shoulder,
        rightElbow: right,
        torsoLean: lean,
        crouch: crouch,
      ),
      i * 70000,
    );
  }
}

void main() {
  test(
    'quaternion antiparallel rotation and shortest-path sign interpolation are finite',
    () {
      final flip = Rotation.fromTo(V3.up, const V3(0, -1, 0));
      expect((flip.rotate(V3.up) - const V3(0, -1, 0)).length, lessThan(1e-7));
      final q = Rotation.axis(V3.up, 1.2),
          negative = Rotation(0, -math.sin(.6), 0, -math.cos(.6));
      expect(q.slerp(negative, .5).angleTo(q), lessThan(1e-7));
      expect(q.slerp(negative, .5).norm, closeTo(1, 1e-9));
      expect(() => Rotation.fromTo(V3.zero, V3.up), throwsFormatException);
    },
  );
  test(
    'global to parent-local conversion reconstructs the desired global orientation',
    () {
      final parent = Rotation.axis(V3.up, .7),
          desired = Rotation.axis(V3.right, -.6);
      final local = parent.inverse * desired;
      expect((parent * local).angleTo(desired), lessThan(1e-7));
    },
  );
  test('stable T-pose calibration maps the neutral frame to identity', () {
    final engine = calibrated();
    expect(engine.progress, 1);
    expect(engine.pose.localRotations.length, 38);
    for (final q in engine.pose.localRotations.values) {
      expect(q.angleTo(Rotation.identity), lessThan(1e-6));
    }
    expect(engine.pose.rootYOffset, 0);
  });
  test('synthetic hand landmarks drive the skinned finger joints', () async {
    final engine = calibrated();
    final before = engine.pose.localRotations['LeftIndex2']!;
    final open = ReplayFixture.frame('test', 31, 2170000);
    engine.receive(open, 2170000);
    final mesh = GlbMesh.parse(
      await File('assets/characters/development_humanoid.glb').readAsBytes(),
    );
    final openVertices = mesh.posedVertices(engine.pose);
    final curled = ReplayFixture.frame('test', 32, 2240000, fingerCurl: 1.1);
    engine.receive(curled, 2240000);
    final after = engine.pose.localRotations['LeftIndex2']!;
    final curledVertices = mesh.posedVertices(engine.pose);
    expect(after.angleTo(before), greaterThan(.05));
    expect(
      curledVertices.asMap().entries.any(
        (entry) => (entry.value - openVertices[entry.key]).length > .001,
      ),
      isTrue,
    );
  });
  test(
    'T-pose calibration tolerates bounded landmark jitter across the hold',
    () {
      final engine = RetargetEngine()
        ..attach('test')
        ..beginCalibration();
      for (var i = 1; i <= 30; i++) {
        final frame = ReplayFixture.frame('test', i, i * 70000);
        final shift = i.isEven ? 0.02 : -0.02;
        List<BodyPoint?> shifted(List<BodyPoint?> points) => points
            .map(
              (p) => p == null
                  ? null
                  : BodyPoint(
                      V3(p.position.x + shift, p.position.y, p.position.z),
                      visibility: p.visibility,
                      presence: p.presence,
                    ),
            )
            .toList();
        engine.receive(
          BodyFrame(
            sessionId: 'test',
            sequence: i,
            capturedAtUs: i * 70000,
            world: shifted(frame.world),
            image: shifted(frame.image),
          ),
          i * 70000,
        );
      }
      expect(engine.calibrated, isTrue, reason: engine.guidance);
      expect(engine.progress, 1);
    },
  );
  test(
    'visible T-pose calibrates despite depth-tilted world arm estimates',
    () {
      final engine = RetargetEngine()
        ..attach('test')
        ..beginCalibration();
      for (var i = 1; i <= 30; i++) {
        final frame = ReplayFixture.frame('test', i, i * 70000);
        final world = frame.world.toList();
        for (final left in [true, false]) {
          final shoulderIndex = left ? 11 : 12;
          final elbowIndex = left ? 13 : 14;
          final wristIndex = left ? 15 : 16;
          final shoulder = world[shoulderIndex]!.position;
          final direction = V3(left ? .28 : -.28, 0, .28);
          world[elbowIndex] = BodyPoint(
            shoulder + direction,
            visibility: .52,
            presence: .52,
          );
          world[wristIndex] = BodyPoint(
            shoulder + direction * 1.9,
            visibility: .52,
            presence: .52,
          );
        }
        final confidentWorld = world
            .map(
              (point) => point == null
                  ? null
                  : BodyPoint(point.position, visibility: .52, presence: .52),
            )
            .toList();
        engine.receive(
          BodyFrame(
            sessionId: 'test',
            sequence: i,
            capturedAtUs: i * 70000,
            world: confidentWorld,
            image: frame.image,
          ),
          i * 70000,
        );
      }
      expect(engine.calibrated, isTrue, reason: engine.guidance);
    },
  );
  test('low-confidence calibration does not silently succeed', () {
    final engine = RetargetEngine()
      ..attach('test')
      ..beginCalibration();
    for (var i = 1; i <= 40; i++) {
      final good = ReplayFixture.frame('test', i, i * 70000);
      final world = good.world.toList();
      world[15] = BodyPoint(world[15]!.position, visibility: .1, presence: 1);
      engine.receive(
        BodyFrame(
          sessionId: 'test',
          sequence: i,
          capturedAtUs: i * 70000,
          world: world,
          image: good.image,
        ),
        i * 70000,
      );
    }
    expect(engine.calibrated, isFalse);
    expect(engine.progress, 0);
    expect(engine.guidance, contains('visible'));
  });
  test('bent-arm pose is rejected for neutral calibration', () {
    final engine = RetargetEngine()
      ..attach('test')
      ..beginCalibration();
    for (var i = 1; i <= 40; i++) {
      engine.receive(
        ReplayFixture.frame('test', i, i * 70000, leftElbow: 1),
        i * 70000,
      );
    }
    expect(engine.calibrated, isFalse);
    expect(engine.guidance, contains('Extend both arms'));
  });
  test(
    'old session, duplicate sequence and nonmonotonic timestamps are rejected',
    () {
      final engine = calibrated();
      expect(
        engine.receive(ReplayFixture.frame('old', 31, 2170000), 2170000),
        isFalse,
      );
      expect(
        engine.receive(ReplayFixture.frame('test', 30, 2170000), 2170000),
        isFalse,
      );
      expect(
        engine.receive(ReplayFixture.frame('test', 31, 10), 2170000),
        isFalse,
      );
      expect(engine.rejectedFrames, 3);
      expect(engine.calibrated, isTrue);
    },
  );
  test(
    'anatomical left arm drives its skinned mesh without moving the right arm',
    () async {
      final engine = calibrated();
      move(engine, elbow: math.pi / 2);
      final mesh = GlbMesh.parse(
        await File('assets/characters/development_humanoid.glb').readAsBytes(),
      );
      final rest = mesh.posedVertices(const RigPose()),
          posed = mesh.posedVertices(engine.pose);
      final left = mesh.vertices.indexWhere((v) => v.joints.first == 3),
          right = mesh.vertices.indexWhere((v) => v.joints.first == 5);
      expect((posed[left] - rest[left]).length, greaterThan(.05));
      expect((posed[right] - rest[right]).length, lessThan(1e-5));
      expect(
        engine.pose.localRotations['LeftForeArm']!.angleTo(Rotation.identity),
        closeTo(math.pi / 2, .03),
      );
    },
  );
  test(
    'mirror-avatar policy swaps the tracked arm without reflecting quaternion handedness',
    () {
      final engine = calibrated(mirror: true);
      move(engine, elbow: 1);
      expect(
        engine.pose.localRotations['RightForeArm']!.angleTo(Rotation.identity),
        greaterThan(.9),
      );
      expect(
        engine.pose.localRotations['LeftForeArm']!.angleTo(Rotation.identity),
        lessThan(1e-6),
      );
      for (final q in engine.pose.localRotations.values) {
        expect(q.norm, closeTo(1, 1e-9));
      }
    },
  );
  test(
    'torso lean is separated from hip yaw and rotations remain normalized',
    () {
      final engine = calibrated();
      move(engine, lean: .3);
      expect(
        engine.pose.localRotations['Chest']!.angleTo(Rotation.identity),
        closeTo(.3, .02),
      );
      expect(
        engine.pose.localRotations['Hips']!.angleTo(Rotation.identity),
        lessThan(1e-6),
      );
      for (final q in engine.pose.localRotations.values) {
        expect(q.norm, closeTo(1, 1e-9));
      }
    },
  );
  test(
    'an invalid wrist falls back while the other arm continues tracking',
    () {
      final engine = calibrated();
      move(engine, elbow: 1, right: -.5);
      for (var i = 46; i <= 70; i++) {
        final frame = ReplayFixture.frame(
          'test',
          i,
          i * 70000,
          leftElbow: 1,
          rightElbow: -.5,
        );
        final world = frame.world.toList();
        world[15] = BodyPoint(world[15]!.position, visibility: 0, presence: 1);
        engine.receive(
          BodyFrame(
            sessionId: 'test',
            sequence: i,
            capturedAtUs: i * 70000,
            world: world,
            image: frame.image,
          ),
          i * 70000,
        );
      }
      expect(engine.state, 'partial');
      expect(
        engine.pose.localRotations['LeftForeArm']!.angleTo(Rotation.identity),
        lessThan(.03),
      );
      expect(
        engine.pose.localRotations['RightForeArm']!.angleTo(Rotation.identity),
        greaterThan(.45),
      );
    },
  );
  test(
    'whole-body tracking loss blends toward neutral rather than freezing',
    () {
      final engine = calibrated();
      move(engine, elbow: 1);
      for (var now = 3150000; now <= 4850000; now += 33000) {
        engine.advance(now);
      }
      expect(engine.state, 'lost');
      expect(engine.validBones, 0);
      expect(
        engine.pose.localRotations['LeftForeArm']!.angleTo(Rotation.identity),
        lessThan(.03),
      );
    },
  );
  test(
    'full-body crouch bends knees and adjusts ground height without scaling vertices',
    () async {
      final engine = calibrated(full: true);
      move(engine, crouch: .6, last: 60);
      expect(engine.pose.localRotations.length, 42);
      expect(
        engine.pose.localRotations['LeftShin']!.angleTo(Rotation.identity),
        greaterThan(.6),
      );
      expect(engine.pose.rootYOffset, lessThan(-.03));
      final mesh = GlbMesh.parse(
        await File('assets/characters/development_humanoid.glb').readAsBytes(),
      );
      final posed = mesh.posedVertices(engine.pose);
      final footIndices = List<int>.generate(mesh.vertices.length, (i) => i)
          .where(
            (i) =>
                (mesh.vertices[i].joints.first == 7 ||
                    mesh.vertices[i].joints.first == 9) &&
                mesh.vertices[i].position.y < .08,
          );
      expect(
        footIndices.map((i) => posed[i].y).reduce(math.min),
        greaterThan(-.01),
      );
      // Same rigid head vertices keep their distance: crouching never scales the mesh.
      final headA = 8, headB = 9;
      expect(
        (posed[headA] - posed[headB]).length,
        closeTo(
          (mesh.vertices[headA].position - mesh.vertices[headB].position)
              .length,
          1e-6,
        ),
      );
    },
  );
  test(
    'camera/session and configuration changes invalidate prior calibration',
    () {
      final engine = calibrated();
      engine.configure(body: true);
      expect(engine.calibrated, isFalse);
      expect(engine.pose.localRotations, isEmpty);
      engine.attach('new');
      expect(
        engine.receive(ReplayFixture.frame('test', 100, 7000000), 7000000),
        isFalse,
      );
    },
  );
  test(
    'protocol parser preserves absent confidence and rejects malformed frame versions',
    () {
      expect(
        () => BodyFrame.parse({'schemaVersion': 1}),
        throwsFormatException,
      );
      final points = List<Object?>.generate(
        33,
        (_) => <String, Object?>{'x': 0.1, 'y': 0.2, 'z': 0.3},
      );
      final hand = List<Object?>.generate(
        21,
        (i) => <String, Object?>{'x': i == 8 ? .1 : 0, 'y': 0, 'z': 0},
      );
      hand[0] = <String, Object?>{'x': 0, 'y': 0, 'z': 0};
      final frame = BodyFrame.parse({
        'schemaVersion': 3,
        'sessionId': 'test',
        'sequence': 1,
        'capturedAtUs': 1,
        'worldPoints': points,
        'points': points,
        'leftHandWorld': hand,
      });
      expect(frame.world.first!.visibility, isNull);
      final p = frame.solverPoint(11)!.position;
      expect(p.x, .1);
      expect(p.y, -.2);
      expect(p.z, -.3);
      expect(frame.leftHandWorld.length, 21);
      expect(frame.solverHandPoint(true, 8)!.position.x, .2);
    },
  );
}
