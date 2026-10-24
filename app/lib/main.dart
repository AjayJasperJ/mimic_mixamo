import 'dart:math' as math;
import 'features/rig/rig_lab.dart';
import 'features/camera/camera_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

void main() {
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(['Filament 1.56.0', 'CameraX 1.3.4', 'MediaPipe Tasks 0.10.14'],
      await rootBundle.loadString('assets/notices/FILAMENT_APACHE_2_0.txt'));
  });
  runApp(const MimicApp());
}

class MimicApp extends StatelessWidget {
  const MimicApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Mimic', debugShowCheckedModeBanner: false,
    theme: ThemeData.dark(useMaterial3: true).copyWith(
      scaffoldBackgroundColor: const Color(0xff10151f),
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff69dfbf), brightness: Brightness.dark)),
    home: const SessionScreen(),
  );
}

class SessionScreen extends StatefulWidget {
  const SessionScreen({super.key});
  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _clock;
  bool _playing = false;
  double _bend = 0.5;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _clock = AnimationController(vsync: this, duration: const Duration(seconds: 3));
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _playing) {
      _clock.stop();
      setState(() => _playing = false);
    }
  }
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clock.dispose();
    super.dispose();
  }
  void _toggle() {
    setState(() => _playing = !_playing);
    if (_playing) { _clock.repeat(reverse: true); } else { _clock.stop(); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('MIMIC / motion lab · 0.4.0')),
    body: SafeArea(child: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1000),
      child: ListView(padding: const EdgeInsets.all(24), children: [
        const Text('Your movement. A new character.', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        const Text('Android + Linux camera tracking • GLB rig lab', style: TextStyle(color: Color(0xff69dfbf))),
        const SizedBox(height: 16),
        FilledButton.icon(onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const CameraScreen())), icon: const Icon(Icons.videocam), label: const Text('Open camera tracking')),
        const SizedBox(height: 16),
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Synthetic simulator below. Open camera tracking for the live camera skeleton, or rig control proof for the 3D model.'),
          const SizedBox(height: 8),
          Text(_playing ? 'Simulator running' : 'Simulator paused', key: const Key('session-status')),
          SizedBox(height: 320, width: double.infinity, child: AnimatedBuilder(animation: _clock,
            builder: (context, child) => CustomPaint(painter: PosePainter(
              bend: _playing ? _clock.value : _bend)))),
        ]))),
        const SizedBox(height: 16),
        FilledButton.icon(onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const RigLab())), icon: const Icon(Icons.view_in_ar), label: const Text('Open rig control proof')),
        const SizedBox(height: 16),
        Wrap(spacing: 12, runSpacing: 12, children: [
          FilledButton.icon(onPressed: _toggle, icon: Icon(_playing ? Icons.pause : Icons.play_arrow), label: Text(_playing ? 'Pause simulation' : 'Start simulation')),
          OutlinedButton.icon(onPressed: () { _clock.stop(); _clock.reset(); setState(() { _playing = false; _bend = 0.5; }); }, icon: const Icon(Icons.restart_alt), label: const Text('Reset pose')),
        ]),
        const SizedBox(height: 24),
        const Text('Manual elbow bend'),
        Slider(value: _bend, onChanged: _playing ? null : (value) => setState(() => _bend = value)),
        const Text('Linux and Android have separate camera skeleton and 3D rig screens. The synthetic simulator does not capture camera frames.'),
        const SizedBox(height: 24),
        const Text('Next gate: verify camera landmarks and GLB rendering on your Android phone before calibrated retargeting.', style: TextStyle(color: Colors.white70)),
      ]),
    ))),
  );
}

class PosePainter extends CustomPainter {
  PosePainter({required this.bend});
  final double bend;
  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, size.height / 2);
    final scale = math.min(size.width / 280, size.height / 290);
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.scale(scale);
    final grid = Paint()..color = Colors.white.withValues(alpha: 0.06)..strokeWidth = 1;
    for (var x = -140; x <= 140; x += 20) { canvas.drawLine(Offset(x.toDouble(), -140), Offset(x.toDouble(), 140), grid); }
    for (var y = -140; y <= 140; y += 20) { canvas.drawLine(Offset(-140, y.toDouble()), Offset(140, y.toDouble()), grid); }
    final bone = Paint()..color = const Color(0xff69dfbf)..strokeWidth = 8..strokeCap = StrokeCap.round;
    void segment(Offset a, Offset b) => canvas.drawLine(a, b, bone);
    canvas.drawCircle(const Offset(0, -99), 18, bone..style = PaintingStyle.stroke);
    bone.style = PaintingStyle.fill;
    segment(const Offset(0, -80), const Offset(0, 25));
    segment(const Offset(-42, -60), const Offset(42, -60));
    for (final side in [-1.0, 1.0]) {
      final shoulder = Offset(side * 42, -60);
      final elbow = Offset(side * 68, -10);
      final angle = bend * math.pi * 0.85;
      final wrist = elbow + Offset(side * 48 * math.sin(angle), 48 * math.cos(angle));
      segment(shoulder, elbow); segment(elbow, wrist);
      segment(const Offset(0, 25), Offset(side * 25, 72));
      segment(Offset(side * 25, 72), Offset(side * 30, 125));
      canvas.drawCircle(elbow, 5, Paint()..color = Colors.white);
    }
    canvas.restore();
  }
  @override
  bool shouldRepaint(covariant PosePainter oldDelegate) => oldDelegate.bend != bend;
}
