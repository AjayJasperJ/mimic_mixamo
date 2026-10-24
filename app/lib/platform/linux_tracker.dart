import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

class WebcamDevice {
  const WebcamDevice(this.path, this.name);
  final String path, name;
}

class LinuxTracker extends ChangeNotifier {
  LinuxTracker({String? executable}) : _executable = executable ?? bundledWorker();
  final String _executable;
  Process? _process;
  Timer? _credit;
  Timer? _watchdog;
  int _epoch = 0;
  bool _disposed = false;
  bool _outstanding = false;
  String status = 'Select a webcam and press Start camera';
  List<WebcamDevice> devices = [];
  Uint8List? jpeg;
  List<Map<String, Object?>> points = [];
  int width = 640, height = 480, frames = 0, inferenceMs = 0;
  bool running = false;
  static String bundledWorker() {
    final override = Platform.environment['MIMIC_TRACKER_EXECUTABLE'];
    if (override != null && override.isNotEmpty) return override;
    final usr = File(Platform.resolvedExecutable).parent.parent.path;
    return '$usr/lib/mimic-tracker/mimic-tracker';
  }
  void _changed() { if (!_disposed) notifyListeners(); }
  Future<void> refreshDevices() async {
    try {
      if (!await File(_executable).exists()) throw StateError('Tracking helper missing. Run the packaged AppImage.');
      final result = await Process.run(_executable, ['--list-devices']);
      if (_disposed) return;
      if (result.exitCode != 0) throw StateError('Webcam discovery failed');
      final value = jsonDecode(result.stdout as String) as Map<String, Object?>;
      devices = (value['devices'] as List<Object?>).map((item) {
        final d = item as Map<String, Object?>;
        return WebcamDevice(d['path'] as String, d['name'] as String);
      }).toList();
      status = devices.isEmpty ? 'No webcams found under /dev/video*. Connect a webcam and refresh.' : 'Select a webcam and press Start camera';
    } catch (error) { if (!_disposed) status = error.toString(); }
    _changed();
  }
  Future<void> start(String device) async {
    stop();
    final token = _epoch;
    status = 'Starting bundled pose tracker';
    _changed();
    try {
      final process = await Process.start(_executable, ['--device', device]);
      if (_disposed || token != _epoch) { process.kill(); return; }
      _process = process;
      _watchdog = Timer(const Duration(seconds: 30), () {
        if (token == _epoch && frames == 0) {
          stop(); status = 'Camera initialization timed out. Try another device or check webcam permissions.'; _changed();
        }
      });
      // Drain native diagnostics without allowing pipe buffers to stall inference.
      var diagnostics = '';
      process.stderr.transform(const Utf8Decoder(allowMalformed: true)).listen((text) {
        diagnostics += text;
        if (diagnostics.length > 4096) diagnostics = diagnostics.substring(diagnostics.length-4096);
      }, onError: (Object _) {});
      process.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
        if (_disposed || token != _epoch) return;
        try {
          final event = jsonDecode(line) as Map<String, Object?>;
          switch (event['kind']) {
            case 'ready':
              running = true; status = 'Camera active • searching for a person'; _next(token); _changed();
            case 'frame':
              _outstanding = false;
              jpeg = base64Decode(event['jpeg'] as String);
              width = (event['width'] as num).toInt(); height = (event['height'] as num).toInt();
              frames = (event['frames'] as num).toInt(); inferenceMs = (event['inferenceMs'] as num).toInt();
              points = (event['points'] as List<Object?>).map((p) => Map<String, Object?>.from(p as Map<Object?, Object?>)).toList();
              status = points.isEmpty ? 'Camera active • searching for a person' : 'Body landmarks detected';
              _watchdog?.cancel();
              _changed();
              _credit?.cancel(); _credit = Timer(const Duration(milliseconds: 66), () => _next(token));
            case 'error':
              final message = event['message']?.toString() ?? 'Tracker failed';
              stop(); status = message; _changed();
          }
        } catch (error) { stop(); status = 'Invalid tracker response: $error'; _changed(); }
      }, onError: (Object error) {
        if (token == _epoch && !_disposed) { stop(); status = 'Tracker connection failed: $error'; _changed(); }
      });
      unawaited(process.exitCode.then((code) {
        if (token != _epoch || _disposed) return;
        stop();
        final detail = diagnostics.trim().split('\n').last;
        status = 'Tracker exited ($code). ${detail.isEmpty ? 'Try Start camera or a different webcam.' : detail}'; _changed();
      }));
    } catch (error) { if (token == _epoch && !_disposed) { stop(); status = 'Could not start tracker: $error'; _changed(); } }
  }
  void _next(int token) {
    if (_disposed || token != _epoch || !running || _outstanding) return;
    try { _process?.stdin.writeln('next'); _outstanding = true; }
    catch (_) { stop(); status = 'Camera worker disconnected'; _changed(); }
  }
  void stop() {
    _epoch++; _credit?.cancel(); _watchdog?.cancel(); _outstanding = false;
    final previous = _process; _process = null;
    if (previous != null) {
      try { previous.stdin.writeln('stop'); unawaited(previous.stdin.close().catchError((Object _) {})); } catch (_) {}
      // A blocked V4L2 read must not keep the camera open after leaving the screen.
      var exited = false;
      unawaited(previous.exitCode.then((_) { exited = true; }));
      unawaited(Future<void>.delayed(const Duration(seconds: 1), () { if (!exited) previous.kill(ProcessSignal.sigterm); }));
      unawaited(Future<void>.delayed(const Duration(seconds: 2), () { if (!exited) previous.kill(ProcessSignal.sigkill); }));
    }
    running = false; jpeg = null; points = []; frames = 0; status = 'Camera stopped';
    _changed();
  }
  @override
  void dispose() { _disposed = true; stop(); super.dispose(); }
}
