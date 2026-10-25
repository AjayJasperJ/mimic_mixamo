import 'dart:async';
import 'dart:math' as math;
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vector_math/vector_math_64.dart' as v;
import 'glb_mesh.dart';
import 'rig_pose.dart';

class DesktopGlbView extends StatefulWidget {
  const DesktopGlbView({
    super.key,
    required this.pose,
    this.onMeshReady,
    this.customPath,
  });
  final RigPose pose;
  final VoidCallback? onMeshReady;
  final String? customPath;
  @override
  State<DesktopGlbView> createState() => _DesktopGlbViewState();
}

class _DesktopGlbViewState extends State<DesktopGlbView> {
  late Future<GlbMesh> _asset = _load();
  double _yaw = .3;
  Future<GlbMesh> _load() async {
    final path = widget.customPath;
    final bytes = path == null
        ? (await rootBundle.load(
            'assets/characters/development_humanoid.glb',
          )).buffer.asUint8List()
        : await File(path).readAsBytes();
    final mesh = GlbMesh.parse(bytes);
    await mesh.decodeTextures();
    if (!mounted) {
      mesh.disposeTextures();
      return mesh;
    }
    if (mounted) widget.onMeshReady?.call();
    return mesh;
  }

  @override
  void didUpdateWidget(covariant DesktopGlbView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.customPath != widget.customPath) {
      final previous = _asset;
      _asset = _load();
      unawaited(
        previous.then((mesh) => mesh.disposeTextures()).catchError((_) {}),
      );
    }
  }

  @override
  void dispose() {
    unawaited(_asset.then((mesh) => mesh.disposeTextures()).catchError((_) {}));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<GlbMesh>(
    future: _asset,
    builder: (context, snapshot) {
      if (snapshot.hasError)
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SelectableText('GLB load failed: ${snapshot.error}'),
              OutlinedButton(
                onPressed: () => setState(() => _asset = _load()),
                child: const Text('Reload model'),
              ),
            ],
          ),
        );
      if (!snapshot.hasData)
        return const Center(child: CircularProgressIndicator());
      return GestureDetector(
        onPanUpdate: (details) =>
            setState(() => _yaw += details.delta.dx * .01),
        child: CustomPaint(
          painter: SkinnedGlbPainter(snapshot.data!, widget.pose, _yaw),
          child: const SizedBox.expand(),
        ),
      );
    },
  );
}

class SkinnedGlbPainter extends CustomPainter {
  SkinnedGlbPainter(this.mesh, this.pose, this.yaw);
  final GlbMesh mesh;
  final RigPose pose;
  final double yaw;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xff171f2b),
    );
    final posed = mesh.posedVertices(pose);
    final rotated = posed
        .map(
          (p) => v.Vector3(
            p.x * math.cos(yaw) + p.z * math.sin(yaw),
            p.y,
            -p.x * math.sin(yaw) + p.z * math.cos(yaw),
          ),
        )
        .toList();
    final minX = rotated.map((p) => p.x).reduce(math.min),
        maxX = rotated.map((p) => p.x).reduce(math.max);
    final minY = rotated.map((p) => p.y).reduce(math.min),
        maxY = rotated.map((p) => p.y).reduce(math.max);
    final width = math.max(maxX - minX, .01),
        height = math.max(maxY - minY, .01);
    final scale = math.min(size.width / width, size.height / height) * .82;
    Offset project(v.Vector3 p) => Offset(
      size.width / 2 + (p.x - (minX + maxX) / 2) * scale,
      size.height / 2 - (p.y - (minY + maxY) / 2) * scale,
    );
    canvas.drawLine(
      Offset(12, project(v.Vector3(0, minY, 0)).dy),
      Offset(size.width - 12, project(v.Vector3(0, minY, 0)).dy),
      Paint()
        ..color = Colors.white24
        ..strokeWidth = 1,
    );
    final faces = List<int>.generate(mesh.indices.length ~/ 3, (i) => i * 3);
    faces.sort((a, b) {
      double depth(int i) =>
          (rotated[mesh.indices[i]].z +
              rotated[mesh.indices[i + 1]].z +
              rotated[mesh.indices[i + 2]].z) /
          3;
      return depth(a).compareTo(depth(b));
    });
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final texturePaints = <int, Paint>{};
    final batchPositions = <Offset>[], batchUvs = <Offset>[];
    final batchIndices = <int>[];
    int? batchTextureId;
    void flushTextureBatch() {
      final textureId = batchTextureId;
      if (textureId == null || batchIndices.isEmpty) return;
      final texture = mesh.decodedTextures[textureId];
      if (texture != null) {
        final vertices = ui.Vertices(
          ui.VertexMode.triangles,
          batchPositions,
          textureCoordinates: batchUvs,
          indices: batchIndices,
        );
        final paint = texturePaints.putIfAbsent(
          textureId,
          () => Paint()
            ..shader = ui.ImageShader(
              texture,
              ui.TileMode.clamp,
              ui.TileMode.clamp,
              Matrix4.identity().storage,
            )
            ..filterQuality = FilterQuality.medium,
        );
        canvas.drawVertices(vertices, BlendMode.srcOver, paint);
      }
      batchPositions.clear();
      batchUvs.clear();
      batchIndices.clear();
      batchTextureId = null;
    }

    for (final face in faces) {
      final a = rotated[mesh.indices[face]],
          b = rotated[mesh.indices[face + 1]],
          c = rotated[mesh.indices[face + 2]];
      final normal = (b - a).cross(c - a);
      final shade = normal.length < 1e-9
          ? .7
          : (.45 +
                    .55 *
                        (normal.normalized().dot(
                          v.Vector3(.2, .7, .6).normalized(),
                        )).abs())
                .clamp(.3, 1.0)
                .toDouble();
      final textureId = mesh.triangleTextureIds[face ~/ 3];
      final texture = textureId == null
          ? null
          : mesh.decodedTextures[textureId];
      if (texture != null) {
        if (batchTextureId != textureId) {
          flushTextureBatch();
          batchTextureId = textureId;
        }
        final base = batchPositions.length;
        batchPositions.addAll([project(a), project(b), project(c)]);
        final sourceUvs = [
          mesh.vertices[mesh.indices[face]].texCoord,
          mesh.vertices[mesh.indices[face + 1]].texCoord,
          mesh.vertices[mesh.indices[face + 2]].texCoord,
        ];
        batchUvs.addAll(
          sourceUvs.map(
            (uv) => Offset(uv.x * texture.width, uv.y * texture.height),
          ),
        );
        batchIndices.addAll([base, base + 1, base + 2]);
      } else {
        flushTextureBatch();
        final path = Path()
          ..moveTo(project(a).dx, project(a).dy)
          ..lineTo(project(b).dx, project(b).dy)
          ..lineTo(project(c).dx, project(c).dy)
          ..close();
        canvas.drawPath(
          path,
          Paint()
            ..color = Color.fromRGBO(
              (70 * shade).round(),
              (225 * shade).round(),
              (180 * shade).round(),
              1,
            ),
        );
      }
    }
    flushTextureBatch();
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SkinnedGlbPainter oldDelegate) =>
      oldDelegate.pose != pose ||
      oldDelegate.yaw != yaw ||
      oldDelegate.mesh != mesh;
}
