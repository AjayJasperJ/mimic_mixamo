import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../platform/linux_tracker.dart';
import '../rig/desktop_glb_view.dart';

class LinuxCameraView extends StatefulWidget {
  const LinuxCameraView({super.key, this.tracker, this.autoReplay = false});
  final LinuxTracker? tracker;
  final bool autoReplay;
  @override
  State<LinuxCameraView> createState() => _LinuxCameraViewState();
}

class _LinuxCameraViewState extends State<LinuxCameraView>
    with WidgetsBindingObserver {
  late final LinuxTracker _tracker;
  String? _selected;
  bool _mirror = true, _meshReady = false, _smokeReported = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tracker = widget.tracker ?? LinuxTracker();
    if (widget.autoReplay) {
      _tracker.configure(fullBody: true);
      _tracker.startReplay(calibrate: true);
    } else {
      unawaited(_tracker.refreshDevices());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (widget.autoReplay)
      return; // Synthetic CI replay opens no camera and is focus independent.
    if (state != AppLifecycleState.resumed) _tracker.stop();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tracker.dispose();
    super.dispose();
  }

  Widget _camera() => ColoredBox(
    color: const Color(0xff10151f),
    child: _tracker.jpeg == null && !_tracker.replaying
        ? const Center(
            child: Text(
              'Start the webcam or labelled replay, then calibrate your T-pose.',
            ),
          )
        : LayoutBuilder(
            builder: (context, constraints) {
              final scale = math.min(
                constraints.maxWidth / _tracker.width,
                constraints.maxHeight / _tracker.height,
              );
              return Center(
                child: SizedBox(
                  width: _tracker.width * scale,
                  height: _tracker.height * scale,
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.diagonal3Values(_mirror ? -1 : 1, 1, 1),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (_tracker.jpeg != null)
                          Image.memory(
                            _tracker.jpeg!,
                            fit: BoxFit.fill,
                            gaplessPlayback: true,
                          ),
                        CustomPaint(
                          painter: LinuxSkeletonPainter(_tracker.points),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
  );
  Widget _avatar() => Stack(
    children: [
      Positioned.fill(
        child: DesktopGlbView(
          pose: _tracker.solver.pose,
          onMeshReady: () => _meshReady = true,
        ),
      ),
      Positioned(
        left: 8,
        top: 8,
        child: Text('Avatar • ${_tracker.solver.state}'),
      ),
    ],
  );
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _tracker,
    builder: (context, _) {
      final solver = _tracker.solver;
      final selected = _tracker.devices.any((d) => d.path == _selected)
          ? _selected
          : _tracker.devices.firstOrNull?.path;
      if (widget.autoReplay &&
          !_smokeReported &&
          _meshReady &&
          solver.calibrated &&
          solver.validBones == 42 &&
          _tracker.frames > 38) {
        _smokeReported = true;
        debugPrint('MIMIC_REPLAY_READY source=synthetic bones=42 mesh=true');
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text('Linux webcam'),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: selected,
                  hint: const Text('No camera selected'),
                  items: _tracker.devices
                      .map(
                        (d) => DropdownMenuItem(
                          value: d.path,
                          child: Text(d.name, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    _tracker.stop();
                    setState(() => _selected = value);
                  },
                ),
              ),
              IconButton(
                tooltip: 'Refresh webcams',
                onPressed: () => _tracker.refreshDevices(),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              FilledButton(
                onPressed: selected == null
                    ? null
                    : () => _tracker.start(selected),
                child: const Text('Start camera'),
              ),
              OutlinedButton(
                onPressed: () => _tracker.startReplay(),
                child: const Text('Replay test poses'),
              ),
              OutlinedButton(
                onPressed: () => _tracker.stop(),
                child: const Text('Stop camera'),
              ),
              FilledButton.tonal(
                onPressed: _tracker.running
                    ? () => _tracker.beginCalibration()
                    : null,
                child: Text(
                  solver.calibrated ? 'Recalibrate T-pose' : 'Calibrate T-pose',
                ),
              ),
              FilterChip(
                label: const Text('Mirror preview'),
                selected: _mirror,
                onSelected: (value) => setState(() => _mirror = value),
              ),
              FilterChip(
                label: const Text('Mirror avatar'),
                selected: solver.mirrorMovement,
                onSelected: (value) => _tracker.configure(mirror: value),
              ),
            ],
          ),
          Row(
            children: [
              DropdownButton<bool>(
                value: solver.fullBody,
                items: const [
                  DropdownMenuItem(value: false, child: Text('Upper body')),
                  DropdownMenuItem(
                    value: true,
                    child: Text('Full body • beta'),
                  ),
                ],
                onChanged: (value) => _tracker.configure(fullBody: value),
              ),
              const SizedBox(width: 16),
              const Text('Smoothing'),
              Expanded(
                child: Slider(
                  value: solver.smoothing,
                  onChanged: _tracker.setSmoothing,
                ),
              ),
              IconButton(
                tooltip: 'Copy diagnostics without camera data',
                onPressed: () => Clipboard.setData(
                  ClipboardData(
                    text: const JsonEncoder.withIndent(
                      '  ',
                    ).convert(_tracker.diagnostics()),
                  ),
                ),
                icon: const Icon(Icons.copy),
              ),
            ],
          ),
          if (_tracker.replaying)
            Container(
              padding: const EdgeInsets.all(8),
              color: const Color(0xff654400),
              child: const Text(
                'REPLAY • synthetic test input • no camera is open',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          Text(_tracker.status, maxLines: 2, overflow: TextOverflow.ellipsis),
          Text(solver.guidance, maxLines: 2, overflow: TextOverflow.ellipsis),
          if (!_tracker.replaying &&
              _tracker.running &&
              !solver.calibrated &&
              !solver.calibrating)
            const Text(
              'Landmarks are detected, but the avatar stays neutral until you select Calibrate T-pose and hold the pose steady.',
            ),
          if (!solver.calibrated)
            Text(
              solver.fullBody
                  ? 'Calibration needs shoulders, elbows, wrists, hips, knees and ankles.'
                  : 'Calibration needs shoulders, elbows, wrists and hips.',
            ),
          if (solver.calibrating)
            LinearProgressIndicator(value: solver.progress),
          const SizedBox(height: 8),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => constraints.maxWidth >= 760
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: _camera()),
                        const SizedBox(width: 12),
                        Expanded(child: _avatar()),
                      ],
                    )
                  : Column(
                      children: [
                        Expanded(child: _camera()),
                        const SizedBox(height: 8),
                        Expanded(child: _avatar()),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${solver.poseRate.toStringAsFixed(1)} input frames/s • ${solver.validBones}/${solver.fullBody ? 42 : 38} valid bones • solver ${(solver.solverUs / 1000).toStringAsFixed(2)} ms'
            '${_tracker.replaying ? ' • replay' : ' • inference ${_tracker.inferenceMs} ms'}',
          ),
        ],
      );
    },
  );
}

class LinuxSkeletonPainter extends CustomPainter {
  LinuxSkeletonPainter(this.points);
  final List<Map<String, Object?>> points;
  bool valid(Map<String, Object?> p) {
    final x = p['x'] as num?, y = p['y'] as num?;
    final v = p['visibility'] as num?, presence = p['presence'] as num?;
    return x != null &&
        y != null &&
        x.isFinite &&
        y.isFinite &&
        (v == null || v >= .5) &&
        (presence == null || presence >= .5);
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    Offset point(Map<String, Object?> p) => Offset(
      (p['x'] as num).toDouble() * size.width,
      (p['y'] as num).toDouble() * size.height,
    );
    final paint = Paint()
      ..color = const Color(0xff4bffb9)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (final pair in connections) {
      if (pair.$1 < points.length &&
          pair.$2 < points.length &&
          valid(points[pair.$1]) &&
          valid(points[pair.$2]))
        canvas.drawLine(point(points[pair.$1]), point(points[pair.$2]), paint);
    }
    // MediaPipe has no neck landmark. Use the ear midpoint when available,
    // then fall back toward the nose so low ear confidence cannot remove the
    // chest-to-head bridge from the live skeleton. This is display-only.
    if (points.length > 12 && [11, 12].every((i) => valid(points[i]))) {
      final leftShoulder = point(points[11]), rightShoulder = point(points[12]);
      final shoulderCenter = Offset(
        (leftShoulder.dx + rightShoulder.dx) / 2,
        (leftShoulder.dy + rightShoulder.dy) / 2,
      );
      final headBase = points.length > 8 && valid(points[7]) && valid(points[8])
          ? Offset(
              (point(points[7]).dx + point(points[8]).dx) / 2,
              (point(points[7]).dy + point(points[8]).dy) / 2,
            )
          : valid(points[0])
          ? shoulderCenter + (point(points[0]) - shoulderCenter) * .72
          : null;
      if (headBase != null) {
        canvas.drawLine(shoulderCenter, headBase, paint..strokeWidth = 4);
        canvas.drawCircle(shoulderCenter, 4, paint);
        canvas.drawCircle(headBase, 4, paint);
      }
    }
    // Make the pose model's wrist-to-palm/finger-root links stand out from the
    // arm segments. These endpoints are approximate pose landmarks, not a
    // hand-tracking model or articulated avatar fingers.
    final handPaint = Paint()
      ..color = const Color(0xff4bffb9)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    for (final pair in handConnections) {
      if (pair.$2 < points.length &&
          valid(points[pair.$1]) &&
          valid(points[pair.$2])) {
        canvas.drawLine(
          point(points[pair.$1]),
          point(points[pair.$2]),
          handPaint,
        );
      }
    }
    for (final base in [33, 54]) {
      for (final pair in articulatedHandConnections) {
        final a = base + pair.$1, b = base + pair.$2;
        if (b < points.length && valid(points[a]) && valid(points[b])) {
          canvas.drawLine(point(points[a]), point(points[b]), handPaint);
        }
      }
    }
    paint.color = Colors.white;
    for (final p in points) {
      if (valid(p)) canvas.drawCircle(point(p), 3, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant LinuxSkeletonPainter oldDelegate) =>
      oldDelegate.points != points;
  static const handConnections = [
    (15, 17),
    (15, 19),
    (15, 21),
    (17, 19),
    (16, 18),
    (16, 20),
    (16, 22),
    (18, 20),
  ];
  static const articulatedHandConnections = [
    (0, 1),
    (1, 2),
    (2, 3),
    (3, 4),
    (0, 5),
    (5, 6),
    (6, 7),
    (7, 8),
    (0, 9),
    (9, 10),
    (10, 11),
    (11, 12),
    (0, 13),
    (13, 14),
    (14, 15),
    (15, 16),
    (0, 17),
    (17, 18),
    (18, 19),
    (19, 20),
  ];
  static const connections = [
    (0, 1),
    (1, 2),
    (2, 3),
    (3, 7),
    (0, 4),
    (4, 5),
    (5, 6),
    (6, 8),
    (9, 10),
    (11, 12),
    (11, 13),
    (13, 15),
    (12, 14),
    (14, 16),
    (11, 23),
    (12, 24),
    (23, 24),
    (23, 25),
    (25, 27),
    (24, 26),
    (26, 28),
    (27, 29),
    (29, 31),
    (27, 31),
    (28, 30),
    (30, 32),
    (28, 32),
  ];
}
