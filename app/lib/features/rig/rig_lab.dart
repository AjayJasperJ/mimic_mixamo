import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'rig_pose.dart';
import 'desktop_glb_view.dart';
import 'custom_character_store.dart';
import 'package:file_selector/file_selector.dart';

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
  String _importStatus =
      'Linux: skinned GLB preview. Import a model to replace the development character.';
  bool _playing = false;
  bool _importing = false;
  bool _polling = false;
  bool _loadError = false;
  var _openedAt = DateTime.now();
  bool get _android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> _command(String name, [Map<String, Object?>? args]) async {
    try {
      await _native?.invokeMethod<void>(name, args);
    } on PlatformException catch (error) {
      if (mounted) setState(() => _status = error.message ?? error.code);
    } on MissingPluginException {
      if (mounted)
        setState(() => _status = 'Native plugin unavailable in this build');
    }
  }

  void _created(int id) {
    _native = MethodChannel('mimic/rig/$id');
    _command('setPose', {'angles': _pose.angles});
    _poll = Timer.periodic(const Duration(seconds: 1), (_) => _readStatus());
    _readStatus();
  }

  Future<void> _importCharacter() async {
    if (_importing) return;
    setState(() {
      _importing = true;
      _importStatus = 'Opening character file picker…';
    });
    try {
      final file = await openFile();
      if (file == null) {
        if (mounted) setState(() => _importStatus = 'Import cancelled.');
        return;
      }
      if (mounted) setState(() => _importStatus = 'Importing ${file.name}…');
      final result = await CustomCharacterStore.importFile(file.path);
      if (mounted) setState(() => _importStatus = 'Loaded $result');
    } on Object catch (error) {
      if (mounted) {
        setState(() => _importStatus = 'Import failed: ${_importError(error)}');
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  String _importError(Object error) {
    if (error is FormatException) return error.message.toString();
    final message = error.toString();
    if (message.contains('assimp') || message.contains('ProcessException')) {
      return '$message. FBX conversion in Flutter debug needs Assimp installed; the AppImage bundles it. You can import a GLB without Assimp.';
    }
    return message;
  }

  Future<void> _readStatus() async {
    if (_polling || !mounted) return;
    _polling = true;
    try {
      final value = await _native?.invokeMapMethod<String, Object?>('status');
      if (mounted && value != null)
        setState(() {
          _loadError = value['error'] != null;
          _status =
              value['error']?.toString() ??
              (value['ready'] == true
                  ? 'GLB loaded • ${value['jointCount']} controllable joints • ${value['renderedFrames']} frame callbacks'
                  : DateTime.now().difference(_openedAt).inSeconds > 10
                  ? 'Renderer waiting at ${value['stage']}. Tap Reload model to retry.'
                  : 'Loading development rig: ${value['stage']}');
        });
    } on PlatformException catch (error) {
      if (mounted) setState(() => _status = error.message ?? error.code);
    } on MissingPluginException {
      if (mounted)
        setState(() => _status = 'Native plugin unavailable in this build');
    } finally {
      _polling = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final resumed = state == AppLifecycleState.resumed;
    _command('setActive', {'enabled': resumed});
    if (!resumed) {
      _command('play', {'enabled': false});
      if (mounted) setState(() => _playing = false);
    }
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
    appBar: AppBar(
      title: const Text('Rig control proof'),
      actions: [
        IconButton(
          tooltip: 'Open-source licenses',
          onPressed: () =>
              showLicensePage(context: context, applicationName: 'Mimic'),
          icon: const Icon(Icons.info_outline),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        ValueListenableBuilder<String?>(
          valueListenable: CustomCharacterStore.selectedPath,
          builder: (context, path, _) => Text(
            path == null
                ? 'Development humanoid'
                : CustomCharacterStore.displayName,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
        const Text(
          'Import a rigged Mixamo FBX or skinned GLB, directly or in a ZIP with its texture files. Embedded base-color textures appear in the Linux preview.',
        ),
        const SizedBox(height: 12),
        ValueListenableBuilder<String?>(
          valueListenable: CustomCharacterStore.selectedPath,
          builder: (context, path, _) => SizedBox(
            height: 350,
            child: _android
                ? AndroidView(
                    viewType: 'mimic/rig',
                    onPlatformViewCreated: _created,
                  )
                : DesktopGlbView(
                    key: ValueKey(path),
                    customPath: path,
                    pose: _pose,
                  ),
          ),
        ),
        if (!_android)
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: _importing ? null : _importCharacter,
              icon: const Icon(Icons.file_open),
              label: Text(
                _importing ? 'Importing…' : 'Import FBX / GLB / ZIP bundle',
              ),
            ),
          ),
        const SizedBox(height: 12),
        SelectableText(
          _android ? _status : _importStatus,
          style: TextStyle(color: _loadError ? Colors.redAccent : null),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            if (_android)
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _loadError = false;
                    _playing = false;
                    _status = 'Reloading GLB';
                    _openedAt = DateTime.now();
                  });
                  _command('reload');
                },
                child: const Text('Reload model'),
              ),
            OutlinedButton(
              onPressed: () {
                setState(() {
                  _pose = const RigPose();
                  _playing = false;
                });
                _command('reset');
              },
              child: const Text('Restore T-pose'),
            ),
            if (_android)
              FilledButton(
                onPressed: () {
                  setState(() => _playing = !_playing);
                  _command('play', {'enabled': _playing});
                },
                child: Text(_playing ? 'Stop bone demo' : 'Run bone demo'),
              ),
          ],
        ),
        for (var i = 0; i < 4; i++) ...[
          Text(
            '${const ['Left shoulder', 'Left elbow', 'Right shoulder', 'Right elbow'][i]}: ${_pose.angles[i].round()}°',
          ),
          Slider(
            key: ValueKey('joint-$i'),
            min: -120,
            max: 120,
            value: _pose.angles[i],
            onChanged: (value) {
              setState(() {
                _pose = _pose.withAngle(i, value);
                _playing = false;
              });
              _command('setPose', {'angles': _pose.angles});
            },
          ),
        ],
        const Text(
          'Live camera skeleton is on the separate camera screen; avatar retargeting is pending. Check each arm independently, restore the T-pose, then leave and reopen this screen 10 times. Report blank frames, mesh distortion or crashes.',
        ),
      ],
    ),
  );
}

class RigDiagram extends CustomPainter {
  RigDiagram(this.pose);
  final RigPose pose;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xff171f2b),
    );
    final scale = size.height / 2.1;
    Offset project(Offset p) =>
        Offset(size.width / 2 + p.dx * scale, size.height - 20 - p.dy * scale);
    final paint = Paint()
      ..color = const Color(0xff69dfbf)
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    void line(Offset a, Offset b) =>
        canvas.drawLine(project(a), project(b), paint);
    line(const Offset(0, .88), const Offset(0, 1.45));
    canvas.drawCircle(project(const Offset(0, 1.67)), scale * .12, paint);
    for (final left in [true, false]) {
      final arm = pose.arm(left: left);
      line(Offset(0, 1.45), arm[0]);
      line(arm[0], arm[1]);
      line(arm[1], arm[2]);
      for (final p in arm) {
        canvas.drawCircle(project(p), 5, Paint()..color = Colors.white);
      }
      final x = left ? .12 : -.12;
      line(const Offset(0, .88), Offset(x, .85));
      line(Offset(x, .85), Offset(x, .43));
      line(Offset(x, .43), Offset(x, .03));
    }
  }

  @override
  bool shouldRepaint(covariant RigDiagram oldDelegate) =>
      oldDelegate.pose != pose;
}
