import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'linux_camera_view.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});
  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  MethodChannel? _channel;
  Timer? _timer;
  bool _polling = false;
  String _status = 'Preparing camera';
  int _frames = 0;
  int _landmarks = 0;
  int _inferenceMs = 0;
  String _camera = 'front';
  bool get _linux => !kIsWeb && defaultTargetPlatform == TargetPlatform.linux;
  bool get _android => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  Future<void> _command(String command) async {
    try { await _channel?.invokeMethod<void>(command); }
    on PlatformException catch (error) { if (mounted) setState(() => _status = error.message ?? error.code); }
    on MissingPluginException { if (mounted) setState(() => _status = 'Camera plugin unavailable. Install the current Android APK.'); }
  }
  void _created(int id) {
    _channel = MethodChannel('mimic/camera/$id');
    _command('start');
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) => _poll());
  }
  Future<void> _poll() async {
    if (_polling || !mounted) return;
    _polling = true;
    try {
      final value = await _channel?.invokeMapMethod<String, Object?>('status');
      if (mounted && value != null) setState(() {
        _status = value['state']?.toString() ?? 'Waiting for camera';
        _frames = (value['frames'] as num?)?.toInt() ?? 0;
        _landmarks = (value['landmarks'] as num?)?.toInt() ?? 0;
        _inferenceMs = (value['inferenceMs'] as num?)?.toInt() ?? 0;
        _camera = value['camera']?.toString() ?? 'front';
      });
    } on PlatformException catch (error) { if (mounted) setState(() => _status = error.message ?? error.code); }
    on MissingPluginException { if (mounted) setState(() => _status = 'Camera plugin unavailable. Install the current Android APK.'); }
    finally { _polling = false; }
  }
  @override
  void dispose() {
    _timer?.cancel();
    _command('stop');
    super.dispose();
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Camera body tracking')),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      const Text('Allow camera access, then stand where your body is visible. Frames stay on this device and are not recorded.'),
      const SizedBox(height: 12),
      SizedBox(height: _linux ? 520 : 420, child: _linux
        ? const LinuxCameraView()
        : _android
        ? AndroidView(viewType: 'mimic/camera', onPlatformViewCreated: _created)
        : const Center(child: Text('Camera tracking is currently supported on Android and Linux.'))),
      const SizedBox(height: 12),
      if (!_linux) Text(_android ? _status : 'Camera unavailable on this platform'),
      if (_android) Text('$_camera camera • $_frames processed frames • $_landmarks visible landmarks • inference $_inferenceMs ms'),
      const SizedBox(height: 12),
      if (!_linux) Wrap(spacing: 10, runSpacing: 10, children: [
        FilledButton(onPressed: _android ? () => _command('start') : null, child: const Text('Start camera')),
        OutlinedButton(onPressed: _android ? () => _command('stop') : null, child: const Text('Stop camera')),
        OutlinedButton(onPressed: _android ? () => _command('switchCamera') : null, child: const Text('Switch front/back')),
        TextButton(onPressed: _android ? () => _command('openSettings') : null, child: const Text('Camera permission settings')),
      ]),
      const SizedBox(height: 16),
      const Text('This screen verifies camera acquisition and the body skeleton overlay. It does not yet drive the 3D character. Use Rig control proof to test the GLB independently.'),
    ]),
  );
}
