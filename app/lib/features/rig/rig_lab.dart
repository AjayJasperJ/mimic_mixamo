import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'rig_pose.dart';

class RigLab extends StatefulWidget {
  const RigLab({super.key});
  @override
  State<RigLab> createState() => _RigLabState();
}

class _RigLabState extends State<RigLab> with WidgetsBindingObserver {
  RigPose _pose = const RigPose();
  MethodChannel? _native;
  Timer? _poll;
  String _status = 'Preparing native renderer';
  bool _playing = false;
  bool _polling = false;
  bool _loadError = false;
  var _openedAt = DateTime.now();
  bool get _android => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  @override
  void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); }
  Future<void> _command(String name, [Map<String, Object?>? args]) async {
    try { await _native?.invokeMethod<void>(name, args); }
    on PlatformException catch (error) { if (mounted) setState(() => _status = error.message ?? error.code); }
    on MissingPluginException { if (mounted) setState(() => _status = 'Native plugin unavailable in this build'); }
  }
  void _created(int id) {
    _native = MethodChannel('mimic/rig/$id');
    _command('setPose', {'angles': _pose.angles});
    _poll = Timer.periodic(const Duration(seconds: 1), (_) => _readStatus());
    _readStatus();
  }
  Future<void> _readStatus() async {
    if (_polling || !mounted) return;
    _polling = true;
    try {
      final value = await _native?.invokeMapMethod<String, Object?>('status');
      if (mounted && value != null) setState(() {
        _loadError = value['error'] != null;
        _status = value['error']?.toString() ?? (value['ready'] == true
          ? 'GLB loaded • ${value['jointCount']} controllable joints • ${value['renderedFrames']} frame callbacks'
          : DateTime.now().difference(_openedAt).inSeconds > 10
            ? 'Renderer waiting at ${value['stage']}. Tap Reload model to retry.'
            : 'Loading development rig: ${value['stage']}');
      });
    } on PlatformException catch (error) { if (mounted) setState(() => _status = error.message ?? error.code); }
    on MissingPluginException { if (mounted) setState(() => _status = 'Native plugin unavailable in this build'); }
    finally { _polling = false; }
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final resumed = state == AppLifecycleState.resumed;
    _command('setActive', {'enabled': resumed});
    if (!resumed) { _command('play', {'enabled': false}); if (mounted) setState(() => _playing = false); }
  }
  @override
  void dispose() {
    _poll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _command('setActive', {'enabled': false});
    super.dispose();
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Rig control proof'), actions: [IconButton(tooltip: 'Open-source licenses', onPressed: () => showLicensePage(context: context, applicationName: 'Mimic'), icon: const Icon(Icons.info_outline))]),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      const Text('Original development humanoid', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
      const Text('T-pose • 10 skin joints • no animation clips • not a Mixamo character'),
      const SizedBox(height: 12),
      SizedBox(height: 350, child: _android
        ? AndroidView(viewType: 'mimic/rig', onPlatformViewCreated: _created)
        : CustomPaint(painter: RigDiagram(_pose))),
      const SizedBox(height: 12),
      SelectableText(_android ? _status : 'Linux: joint hierarchy preview. Native Filament skinning is Android-only.', style: TextStyle(color: _loadError ? Colors.redAccent : null)),
      const SizedBox(height: 12),
      Wrap(spacing: 12, runSpacing: 8, children: [
        if (_android) OutlinedButton(onPressed: () {
          setState(() { _loadError = false; _playing = false; _status = 'Reloading GLB'; _openedAt = DateTime.now(); });
          _command('reload');
        }, child: const Text('Reload model')),
        OutlinedButton(onPressed: () {
          setState(() { _pose = const RigPose(); _playing = false; });
          _command('reset');
        }, child: const Text('Restore T-pose')),
        if (_android) FilledButton(onPressed: () {
          setState(() => _playing = !_playing);
          _command('play', {'enabled': _playing});
        }, child: Text(_playing ? 'Stop bone demo' : 'Run bone demo')),
      ]),
      for (var i = 0; i < 4; i++) ...[
        Text('${const ['Left shoulder', 'Left elbow', 'Right shoulder', 'Right elbow'][i]}: ${_pose.angles[i].round()}°'),
        Slider(key: ValueKey('joint-$i'), min: -120, max: 120, value: _pose.angles[i], onChanged: (value) {
          setState(() { _pose = _pose.withAngle(i, value); _playing = false; });
          _command('setPose', {'angles': _pose.angles});
        }),
      ],
      const Text('Live camera skeleton is on the separate camera screen; avatar retargeting is pending. Check each arm independently, restore the T-pose, then leave and reopen this screen 10 times. Report blank frames, mesh distortion or crashes.'),
    ]),
  );
}

class RigDiagram extends CustomPainter {
  RigDiagram(this.pose);
  final RigPose pose;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xff171f2b));
    final scale = size.height / 2.1;
    Offset project(Offset p) => Offset(size.width/2 + p.dx*scale, size.height - 20 - p.dy*scale);
    final paint = Paint()..color = const Color(0xff69dfbf)..strokeWidth = 12..strokeCap = StrokeCap.round;
    void line(Offset a, Offset b) => canvas.drawLine(project(a), project(b), paint);
    line(const Offset(0,.88), const Offset(0,1.45));
    canvas.drawCircle(project(const Offset(0,1.67)), scale*.12, paint);
    for (final left in [true, false]) {
      final arm = pose.arm(left: left);
      line(Offset(0,1.45), arm[0]); line(arm[0], arm[1]); line(arm[1], arm[2]);
      for (final p in arm) { canvas.drawCircle(project(p), 5, Paint()..color = Colors.white); }
      final x = left ? .12 : -.12;
      line(const Offset(0,.88), Offset(x,.85));
      line(Offset(x,.85), Offset(x,.43)); line(Offset(x,.43), Offset(x,.03));
    }
  }
  @override
  bool shouldRepaint(covariant RigDiagram oldDelegate) => oldDelegate.pose != pose;
}
