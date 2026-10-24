import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../platform/linux_tracker.dart';

class LinuxCameraView extends StatefulWidget {
  const LinuxCameraView({super.key, this.tracker});
  final LinuxTracker? tracker;
  @override
  State<LinuxCameraView> createState() => _LinuxCameraViewState();
}

class _LinuxCameraViewState extends State<LinuxCameraView> with WidgetsBindingObserver {
  late final LinuxTracker _tracker;
  String? _selected;
  bool _mirror = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tracker = widget.tracker ?? LinuxTracker();
    unawaited(_tracker.refreshDevices());
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _tracker.stop();
  }
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tracker.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: _tracker, builder: (context, _) {
    final selected = _tracker.devices.any((d) => d.path == _selected) ? _selected : _tracker.devices.firstOrNull?.path;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        const Text('Linux webcam'), const SizedBox(width: 12),
        Expanded(child: DropdownButton<String>(isExpanded: true, value: selected,
          hint: const Text('No camera selected'), items: _tracker.devices.map((d) => DropdownMenuItem(value: d.path, child: Text(d.name, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: (value) { _tracker.stop(); setState(() => _selected = value); })),
        IconButton(tooltip: 'Refresh webcams', onPressed: () => _tracker.refreshDevices(), icon: const Icon(Icons.refresh)),
      ]),
      Expanded(child: ColoredBox(color: const Color(0xff10151f), child: _tracker.jpeg == null
        ? const Center(child: Text('Press Start camera to show your webcam and body skeleton.'))
        : LayoutBuilder(builder: (context, constraints) {
            final scale = math.min(constraints.maxWidth/_tracker.width, constraints.maxHeight/_tracker.height);
            final size = Size(_tracker.width*scale, _tracker.height*scale);
            return Center(child: SizedBox.fromSize(size: size, child: Transform(
              alignment: Alignment.center, transform: Matrix4.diagonal3Values(_mirror ? -1 : 1, 1, 1),
              child: Stack(fit: StackFit.expand, children: [
                Image.memory(_tracker.jpeg!, fit: BoxFit.fill, gaplessPlayback: true),
                CustomPaint(painter: LinuxSkeletonPainter(_tracker.points)),
              ]))));
          }))),
      const SizedBox(height: 8),
      Text(_tracker.status),
      Text('${_tracker.frames} processed frames • inference ${_tracker.inferenceMs} ms'),
      Wrap(spacing: 8, children: [
        FilledButton(onPressed: selected == null ? null : () => _tracker.start(selected), child: const Text('Start camera')),
        OutlinedButton(onPressed: () => _tracker.stop(), child: const Text('Stop camera')),
        FilterChip(label: const Text('Mirror preview'), selected: _mirror, onSelected: (value) => setState(() => _mirror = value)),
      ]),
    ]);
  });
}

class LinuxSkeletonPainter extends CustomPainter {
  LinuxSkeletonPainter(this.points);
  final List<Map<String, Object?>> points;
  bool valid(Map<String, Object?> p) {
    final x = p['x'] as num?, y = p['y'] as num?;
    final v = p['visibility'] as num?, presence = p['presence'] as num?;
    return x != null && y != null && x.isFinite && y.isFinite && (v == null || v >= .5) && (presence == null || presence >= .5);
  }
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save(); canvas.clipRect(Offset.zero & size);
    Offset point(Map<String, Object?> p) => Offset((p['x'] as num).toDouble()*size.width, (p['y'] as num).toDouble()*size.height);
    final paint = Paint()..color = const Color(0xff4bffb9)..strokeWidth = 3..strokeCap = StrokeCap.round;
    for (final pair in connections) {
      if (pair.$1 < points.length && pair.$2 < points.length && valid(points[pair.$1]) && valid(points[pair.$2])) canvas.drawLine(point(points[pair.$1]), point(points[pair.$2]), paint);
    }
    paint.color = Colors.white;
    for (final p in points) { if (valid(p)) canvas.drawCircle(point(p), 3, paint); }
    canvas.restore();
  }
  @override
  bool shouldRepaint(covariant LinuxSkeletonPainter oldDelegate) => oldDelegate.points != points;
  static const connections = [(0,1),(1,2),(2,3),(3,7),(0,4),(4,5),(5,6),(6,8),(9,10),
    (11,12),(11,13),(13,15),(12,14),(14,16),(11,23),(12,24),(23,24),(23,25),(25,27),
    (24,26),(26,28),(27,29),(29,31),(27,31),(28,30),(30,32),(28,32),(15,17),(15,19),(15,21),(17,19),(16,18),(16,20),(16,22),(18,20)];
}
