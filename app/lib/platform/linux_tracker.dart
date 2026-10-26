import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../features/retargeting/body_frame.dart';
import '../features/retargeting/retarget_engine.dart';
import '../features/retargeting/replay_fixture.dart';

class WebcamDevice {
  const WebcamDevice(this.path, this.name, {this.kind = 'webcam'});
  final String path, name;
  final String kind;
  bool get isIriun => kind == 'iriun';
}

class LinuxTracker extends ChangeNotifier {
  LinuxTracker({String? executable, int Function()? nowUs})
    : _executable = executable ?? bundledWorker(),
      _nowOverride = nowUs;
  final String _executable;
  final int Function()? _nowOverride;
  final _clock = Stopwatch()..start();
  final solver = RetargetEngine();
  int get _nowUs => _nowOverride?.call() ?? _clock.elapsedMicroseconds;
  Process? _process;
  Timer? _credit, _watchdog, _poseTick, _replayTick;
  int _epoch = 0, _replayMotionStart = 0;
  bool _disposed = false, _outstanding = false;
  String _activeSourceLabel = 'Camera';
  String status = 'Select a webcam and press Start camera';
  List<WebcamDevice> devices = [];
  Uint8List? jpeg;
  List<Map<String, Object?>> points = [];
  int width = 640, height = 480, frames = 0, inferenceMs = 0;
  bool running = false, replaying = false;
  static String bundledWorker() {
    final custom = Platform.environment['MIMIC_TRACKER_EXECUTABLE'];
    if (custom != null && custom.isNotEmpty) return custom;
    final usr = File(Platform.resolvedExecutable).parent.parent.path;
    return '$usr/lib/mimic-tracker/mimic-tracker';
  }

  static String? sourceWorker() {
    final candidates = [
      File('${Directory.current.path}/tools/linux/mimic_tracker.py'),
      File('${Directory.current.path}/../tools/linux/mimic_tracker.py'),
    ];
    for (final candidate in candidates) {
      if (candidate.existsSync()) return candidate.absolute.path;
    }
    return null;
  }

  List<String> _workerCommand(List<String> args) {
    final explicit = Platform.environment['MIMIC_TRACKER_EXECUTABLE'];
    if (explicit != null && explicit.isNotEmpty) return [explicit, ...args];
    if (File(_executable).existsSync()) return [_executable, ...args];
    final script = kDebugMode ? sourceWorker() : null;
    if (script != null) return ['python3', script, ...args];
    throw StateError(
      'Tracking helper missing. Run the packaged AppImage or set MIMIC_TRACKER_EXECUTABLE for development.',
    );
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  void _startPoseClock() {
    _poseTick?.cancel();
    _poseTick = Timer.periodic(const Duration(milliseconds: 33), (_) {
      if (!running || _disposed) return;
      solver.advance(_nowUs);
      _changed();
    });
  }

  void beginCalibration() {
    _replayMotionStart = 0;
    solver.beginCalibration();
    _changed();
  }

  void configure({bool? fullBody, bool? mirror}) {
    _replayMotionStart = 0;
    solver.configure(body: fullBody, mirror: mirror);
    _changed();
  }

  void setSmoothing(double value) {
    solver.smoothing = value.clamp(0.0, 1.0).toDouble();
    _changed();
  }

  Map<String, Object?> diagnostics() => {
    'version': '0.5.0',
    'source': replaying ? 'synthetic replay' : 'webcam',
    'state': solver.state,
    'rigId': 'mimic-block-humanoid-v1',
    'calibrated': solver.calibrated,
    'calibrationProgress': solver.progress,
    'calibrationGoodFrames': solver.calibrationSamples,
    'calibrationGuidance': solver.guidance,
    'fullBody': solver.fullBody,
    'mirrorMovement': solver.mirrorMovement,
    'smoothing': solver.smoothing,
    'receivedPoseRate': solver.poseRate,
    'inferenceMs': replaying ? null : inferenceMs,
    'solverUs': solver.solverUs,
    'validBones': solver.validBones,
    'rejectedFrames': solver.rejectedFrames,
    'rootYOffset': solver.pose.rootYOffset,
    'deviceValidated': false,
    'note':
        'Software counters only; not motion-to-photon latency or accuracy. No images/landmarks exported.',
  };
  Future<void> refreshDevices() async {
    try {
      final command = _workerCommand(['--list-devices']);
      final result = await Process.run(command.first, command.skip(1).toList());
      if (_disposed) return;
      if (result.exitCode != 0) throw StateError('Webcam discovery failed');
      final value = jsonDecode(result.stdout as String) as Map<String, Object?>;
      devices = (value['devices'] as List<Object?>).map((item) {
        final d = item as Map<String, Object?>;
        return WebcamDevice(
          d['path'] as String,
          d['name'] as String,
          kind: d['kind'] as String? ?? 'webcam',
        );
      }).toList();
      if (!running)
        status = devices.isEmpty
            ? 'No webcams found. Connect a webcam and refresh, or use labelled replay.'
            : 'Select a webcam and press Start camera';
    } catch (error) {
      if (!_disposed && !running) status = error.toString();
    }
    _changed();
  }

  void startReplay({bool calibrate = false}) {
    stop();
    running = true;
    replaying = true;
    final token = _epoch;
    final session = 'replay-$token-$_nowUs';
    solver.attach(session);
    _startPoseClock();
    status = 'REPLAY • synthetic input • no camera is open';
    if (calibrate) beginCalibration();
    _replayTick = Timer.periodic(const Duration(milliseconds: 66), (_) {
      if (!running || !replaying || _disposed || token != _epoch) return;
      final now = _nowUs;
      if (solver.calibrated && _replayMotionStart == 0)
        _replayMotionStart = now;
      final frame = solver.calibrated
          ? ReplayFixture.animated(
              session,
              frames + 1,
              now,
              (now - _replayMotionStart) / 1000000,
              fullBody: solver.fullBody,
            )
          : ReplayFixture.frame(session, frames + 1, now);
      solver.receive(frame, now);
      points = frame.image
          .map(
            (p) => <String, Object?>{
              'x': p?.position.x,
              'y': p?.position.y,
              'z': p?.position.z,
              'visibility': p?.visibility,
              'presence': p?.presence,
            },
          )
          .toList();
      frames++;
      _changed();
    });
    _changed();
  }

  Future<void> start(String device) async {
    stop();
    final token = _epoch;
    final selected = devices.where((candidate) => candidate.path == device);
    final isIriun = selected.isNotEmpty && selected.first.isIriun;
    _activeSourceLabel = isIriun ? 'iPhone via Iriun Webcam' : 'Camera';
    status = isIriun
        ? 'Connecting to iPhone via Iriun Webcam'
        : 'Starting camera tracking';
    _changed();
    try {
      final command = _workerCommand(['--device', device]);
      final process = await Process.start(
        command.first,
        command.skip(1).toList(),
      );
      if (_disposed || token != _epoch) {
        process.kill();
        return;
      }
      _process = process;
      _watchdog = Timer(const Duration(seconds: 30), () {
        if (token == _epoch && frames == 0) {
          stop();
          status =
              'Camera initialization timed out. Try another device or check webcam permissions.';
          _changed();
        }
      });
      var diagnostics = '';
      process.stderr.transform(const Utf8Decoder(allowMalformed: true)).listen((
        text,
      ) {
        diagnostics += text;
        if (diagnostics.length > 4096)
          diagnostics = diagnostics.substring(diagnostics.length - 4096);
      }, onError: (Object _) {});
      process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            (line) {
              if (_disposed || token != _epoch) return;
              try {
                final event = jsonDecode(line) as Map<String, Object?>;
                switch (event['kind']) {
                  case 'ready':
                    if (event['schemaVersion'] != 3 ||
                        event['sessionId'] is! String)
                      throw const FormatException(
                        'Worker protocol mismatch. Install the newest AppImage.',
                      );
                    solver.attach(event['sessionId'] as String);
                    _activeSourceLabel = event['deviceKind'] == 'iriun'
                        ? 'iPhone via Iriun Webcam'
                        : 'Camera';
                    running = true;
                    status =
                        '$_activeSourceLabel live • direct tracking, no calibration required';
                    _startPoseClock();
                    _next(token);
                    _changed();
                  case 'frame':
                    _outstanding = false;
                    final frame = BodyFrame.parse(event);
                    if (!solver.receive(frame, _nowUs)) {
                      _watchdog?.cancel();
                      _credit?.cancel();
                      _credit = Timer(
                        const Duration(milliseconds: 66),
                        () => _next(token),
                      );
                      _changed();
                      break;
                    }
                    jpeg = base64Decode(event['jpeg'] as String);
                    width = (event['width'] as num).toInt();
                    height = (event['height'] as num).toInt();
                    frames = (event['frames'] as num).toInt();
                    inferenceMs = (event['inferenceMs'] as num).toInt();
                    final bodyPoints = (event['points'] as List<Object?>)
                        .map(
                          (p) => Map<String, Object?>.from(
                            p as Map<Object?, Object?>,
                          ),
                        )
                        .toList();
                    List<Map<String, Object?>> readHandImage(String key) =>
                        ((event[key] as List<Object?>?) ?? const [])
                            .map(
                              (p) => Map<String, Object?>.from(
                                p as Map<Object?, Object?>,
                              ),
                            )
                            .toList();
                    final emptyHand = List<Map<String, Object?>>.filled(
                      21,
                      const {'x': null, 'y': null},
                    );
                    points = [
                      ...bodyPoints,
                      ...List<Map<String, Object?>>.filled(33, const {
                        'x': null,
                        'y': null,
                      }).skip(bodyPoints.length),
                      ...readHandImage('leftHandPoints'),
                      ...emptyHand.skip(readHandImage('leftHandPoints').length),
                      ...readHandImage('rightHandPoints'),
                      ...emptyHand.skip(
                        readHandImage('rightHandPoints').length,
                      ),
                    ];
                    status = bodyPoints.isEmpty
                        ? '$_activeSourceLabel live • searching for a person'
                        : '$_activeSourceLabel live • body landmarks detected';
                    _watchdog?.cancel();
                    _changed();
                    _credit?.cancel();
                    _credit = Timer(
                      const Duration(milliseconds: 66),
                      () => _next(token),
                    );
                  case 'error':
                    final message =
                        event['message']?.toString() ?? 'Tracker failed';
                    stop();
                    status = message;
                    _changed();
                }
              } catch (error) {
                stop();
                status = 'Invalid tracker response: $error';
                _changed();
              }
            },
            onError: (Object error) {
              if (token == _epoch && !_disposed) {
                stop();
                status = 'Tracker connection failed: $error';
                _changed();
              }
            },
          );
      unawaited(
        process.exitCode.then((code) {
          if (token != _epoch || _disposed) return;
          stop();
          final detail = diagnostics.trim().split('\n').last;
          status =
              'Tracker exited ($code). ${detail.isEmpty ? 'Try Start camera or a different webcam.' : detail}';
          _changed();
        }),
      );
    } catch (error) {
      if (token == _epoch && !_disposed) {
        stop();
        status = 'Could not start tracker: $error';
        _changed();
      }
    }
  }

  void _next(int token) {
    if (_disposed || token != _epoch || !running || _outstanding) return;
    try {
      _process?.stdin.writeln('next');
      _outstanding = true;
      _watchdog?.cancel();
      _watchdog = Timer(const Duration(seconds: 10), () {
        if (token == _epoch && _outstanding) {
          stop();
          status =
              'Camera stopped delivering poses. Reconnect or try another device.';
          _changed();
        }
      });
    } catch (_) {
      stop();
      status = 'Camera worker disconnected';
      _changed();
    }
  }

  void stop() {
    _epoch++;
    _credit?.cancel();
    _watchdog?.cancel();
    _poseTick?.cancel();
    _replayTick?.cancel();
    _outstanding = false;
    final previous = _process;
    _process = null;
    if (previous != null) {
      try {
        previous.stdin.writeln('stop');
        unawaited(previous.stdin.close().catchError((Object _) {}));
      } catch (_) {}
      var exited = false;
      unawaited(
        previous.exitCode.then((_) {
          exited = true;
        }),
      );
      unawaited(
        Future<void>.delayed(const Duration(seconds: 1), () {
          if (!exited) previous.kill(ProcessSignal.sigterm);
        }),
      );
      unawaited(
        Future<void>.delayed(const Duration(seconds: 2), () {
          if (!exited) previous.kill(ProcessSignal.sigkill);
        }),
      );
    }
    solver.stop();
    running = false;
    replaying = false;
    jpeg = null;
    points = [];
    frames = 0;
    _replayMotionStart = 0;
    status = 'Camera stopped';
    _changed();
  }

  @override
  void dispose() {
    _disposed = true;
    stop();
    super.dispose();
  }
}
