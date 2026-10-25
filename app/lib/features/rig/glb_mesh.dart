import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:vector_math/vector_math_64.dart' as v;
import 'rig_pose.dart';

Map<String, Object?> _object(Object? value) =>
    Map<String, Object?>.from(value as Map<Object?, Object?>);
List<Object?> _array(Object? value) => value as List<Object?>;
List<double> _numbers(Object? value) =>
    _array(value).map((x) => (x as num).toDouble()).toList();

class SkinVertex {
  SkinVertex(this.position, this.joints, this.weights, this.texCoord);
  final v.Vector3 position;
  final List<int> joints;
  final List<double> weights;
  final v.Vector2 texCoord;
}

/// Reads embedded glTF base-color textures and weighted triangle geometry.
class GlbMesh {
  GlbMesh._(
    this.vertices,
    this.indices,
    this.nodes,
    this.parents,
    this.skinJoints,
    this.inverseBinds,
    this.triangleTextureIds,
    this.textureBytes,
  );
  final List<SkinVertex> vertices;
  final List<int> indices;
  final List<Map<String, Object?>> nodes;
  final List<int> parents, skinJoints;
  final List<v.Matrix4> inverseBinds;
  final List<int?> triangleTextureIds;
  final Map<int, Uint8List> textureBytes;
  final Map<int, ui.Image> decodedTextures = {};

  Future<void> decodeTextures() async {
    for (final entry in textureBytes.entries) {
      try {
        final codec = await ui.instantiateImageCodec(entry.value);
        final frame = await codec.getNextFrame();
        decodedTextures[entry.key] = frame.image;
        codec.dispose();
      } on Object {
        // Keep the weighted mesh usable if an unsupported image is present.
      }
    }
  }

  void disposeTextures() {
    for (final image in decodedTextures.values) {
      image.dispose();
    }
    decodedTextures.clear();
  }

  static GlbMesh parse(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    if (bytes.length < 28 ||
        data.getUint32(0, Endian.little) != 0x46546c67 ||
        data.getUint32(4, Endian.little) != 2 ||
        data.getUint32(8, Endian.little) != bytes.length)
      throw const FormatException('Invalid GLB v2 header');
    Map<String, Object?>? document;
    Uint8List? binary;
    for (var offset = 12; offset < bytes.length;) {
      if (offset + 8 > bytes.length)
        throw const FormatException('Truncated GLB chunk');
      final size = data.getUint32(offset, Endian.little),
          kind = data.getUint32(offset + 4, Endian.little);
      offset += 8;
      if (size % 4 != 0 || offset + size > bytes.length)
        throw const FormatException('Invalid GLB chunk size');
      if (kind == 0x4e4f534a)
        document = _object(
          jsonDecode(utf8.decode(bytes.sublist(offset, offset + size))),
        );
      if (kind == 0x004e4942)
        binary = Uint8List.sublistView(bytes, offset, offset + size);
      offset += size;
    }
    if (document == null || binary == null)
      throw const FormatException('GLB needs JSON and embedded binary data');
    final gltf = document;
    final blob = ByteData.sublistView(binary);
    final accessors = _array(gltf['accessors']).map(_object).toList();
    final views = _array(gltf['bufferViews']).map(_object).toList();
    final imageNodes = _array(gltf['images'] ?? const []).map(_object).toList();
    final textureBytes = <int, Uint8List>{};
    for (var imageIndex = 0; imageIndex < imageNodes.length; imageIndex++) {
      final image = imageNodes[imageIndex];
      if (image['bufferView'] != null) {
        final view = views[(image['bufferView'] as num).toInt()];
        final start = (view['byteOffset'] as num?)?.toInt() ?? 0;
        final length = (view['byteLength'] as num).toInt();
        if (start < 0 || length <= 0 || start + length > binary.length) {
          throw const FormatException('Embedded texture exceeds GLB bounds');
        }
        textureBytes[imageIndex] = Uint8List.fromList(
          binary.sublist(start, start + length),
        );
      } else if (image['uri'] is String &&
          (image['uri'] as String).startsWith('data:') &&
          (image['uri'] as String).contains(';base64,')) {
        final uri = image['uri'] as String;
        textureBytes[imageIndex] = Uint8List.fromList(
          base64.decode(uri.substring(uri.indexOf(',') + 1)),
        );
      }
    }
    final textures = _array(gltf['textures'] ?? const []).map(_object).toList();
    final materials = _array(
      gltf['materials'] ?? const [],
    ).map(_object).toList();
    (int?, int?) textureFor(Object? materialRef) {
      if (materialRef is! num) return (null, null);
      final material = materials[materialRef.toInt()];
      final pbr = material['pbrMetallicRoughness'];
      if (pbr is! Map<Object?, Object?>) return (null, null);
      final info = _object(pbr)['baseColorTexture'];
      if (info is! Map<Object?, Object?>) return (null, null);
      final textureInfo = _object(info);
      final textureIndex = (textureInfo['index'] as num).toInt();
      final imageIndex = (textures[textureIndex]['source'] as num?)?.toInt();
      final texCoord = (textureInfo['texCoord'] as num?)?.toInt() ?? 0;
      if (imageIndex == null || !textureBytes.containsKey(imageIndex)) {
        return (null, texCoord);
      }
      return (imageIndex, texCoord);
    }

    List<List<double>> read(int index) {
      final a = accessors[index],
          view = views[(accessors[index]['bufferView'] as num).toInt()];
      final component = (a['componentType'] as num).toInt();
      final size = switch (component) {
        5120 || 5121 => 1,
        5122 || 5123 => 2,
        5125 || 5126 => 4,
        _ => throw const FormatException('Unsupported component type'),
      };
      final width = switch (a['type']) {
        'SCALAR' => 1,
        'VEC2' => 2,
        'VEC3' => 3,
        'VEC4' => 4,
        'MAT4' => 16,
        _ => throw const FormatException('Unsupported accessor shape'),
      };
      final count = (a['count'] as num).toInt();
      final offset =
          ((view['byteOffset'] as num?)?.toInt() ?? 0) +
          ((a['byteOffset'] as num?)?.toInt() ?? 0);
      final stride = (view['byteStride'] as num?)?.toInt() ?? width * size;
      if (count <= 0 ||
          offset < 0 ||
          stride < width * size ||
          offset + (count - 1) * stride + width * size > blob.lengthInBytes)
        throw const FormatException('Accessor exceeds GLB binary bounds');
      return List<List<double>>.generate(
        count,
        (row) => List<double>.generate(width, (column) {
          final at = offset + row * stride + column * size;
          var number = switch (component) {
            5120 => blob.getInt8(at).toDouble(),
            5121 => blob.getUint8(at).toDouble(),
            5122 => blob.getInt16(at, Endian.little).toDouble(),
            5123 => blob.getUint16(at, Endian.little).toDouble(),
            5125 => blob.getUint32(at, Endian.little).toDouble(),
            _ => blob.getFloat32(at, Endian.little),
          };
          if (a['normalized'] == true) {
            number = switch (component) {
              5120 => math.max(number / 127, -1),
              5121 => number / 255,
              5122 => math.max(number / 32767, -1),
              5123 => number / 65535,
              _ => throw const FormatException(
                'Unsupported normalized accessor component type',
              ),
            };
          }
          if (!number.isFinite)
            throw const FormatException('Nonfinite geometry');
          return number;
        }),
      );
    }

    final meshes = _array(gltf['meshes']);
    final skins = _array(gltf['skins']);
    if (meshes.isEmpty || skins.length != 1)
      throw const FormatException(
        'Character must contain mesh geometry and exactly one skin',
      );
    final positions = <List<double>>[],
        joints = <List<double>>[],
        weights = <List<double>>[],
        texCoords = <List<double>>[],
        indices = <int>[];
    final triangleTextureIds = <int?>[];
    for (final meshValue in meshes) {
      for (final primitiveValue in _array(_object(meshValue)['primitives'])) {
        final primitive = _object(primitiveValue),
            attributes = _object(primitive['attributes']);
        if (primitive['mode'] != null &&
            (primitive['mode'] as num).toInt() != 4)
          continue;
        if (attributes['POSITION'] == null || primitive['indices'] == null)
          continue;
        final p = read((attributes['POSITION'] as num).toInt());
        final (textureId, texCoordSet) = textureFor(primitive['material']);
        final uvAccessor = texCoordSet == null
            ? null
            : attributes['TEXCOORD_$texCoordSet'];
        final uv = uvAccessor == null
            ? List<List<double>>.generate(p.length, (_) => [0, 0])
            : read((uvAccessor as num).toInt());
        if (uv.length != p.length || uv.any((row) => row.length != 2)) {
          throw const FormatException('Texture coordinate counts differ');
        }
        final jointKeys =
            attributes.keys
                .where((key) => RegExp(r'^JOINTS_\d+$').hasMatch(key))
                .toList()
              ..sort(
                (a, b) => int.parse(
                  a.split('_').last,
                ).compareTo(int.parse(b.split('_').last)),
              );
        if (jointKeys.isEmpty) continue;
        final influenceSets = <(List<List<double>>, List<List<double>>)>[];
        for (final key in jointKeys) {
          final suffix = key.split('_').last;
          final weightKey = 'WEIGHTS_$suffix';
          if (attributes[weightKey] == null) {
            throw FormatException('Skinned primitive is missing $weightKey.');
          }
          final setJoints = read((attributes[key] as num).toInt());
          final setWeights = read((attributes[weightKey] as num).toInt());
          if (setJoints.length != p.length ||
              setWeights.length != p.length ||
              setJoints.any((row) => row.length != 4) ||
              setWeights.any((row) => row.length != 4)) {
            throw const FormatException('Skin attribute counts differ');
          }
          influenceSets.add((setJoints, setWeights));
        }
        final vertexJoints = <List<double>>[];
        final vertexWeights = <List<double>>[];
        for (var vertex = 0; vertex < p.length; vertex++) {
          final influences = <(int, double)>[];
          for (final (setJoints, setWeights) in influenceSets) {
            for (var i = 0; i < 4; i++) {
              influences.add((
                setJoints[vertex][i].toInt(),
                setWeights[vertex][i],
              ));
            }
          }
          influences.sort((a, b) => b.$2.compareTo(a.$2));
          final strongest = influences.take(4).toList();
          final sum = strongest.fold<double>(
            0,
            (total, item) => total + item.$2,
          );
          if (!sum.isFinite || sum < 1e-8) {
            throw const FormatException(
              'A skinned vertex has no positive bone weight.',
            );
          }
          vertexJoints.add(
            strongest.map((influence) => influence.$1.toDouble()).toList(),
          );
          vertexWeights.add(
            strongest.map((influence) => influence.$2 / sum).toList(),
          );
        }
        final base = positions.length;
        final ix = read(
          (primitive['indices'] as num).toInt(),
        ).map((x) => x.single.toInt()).toList();
        if (ix.length % 3 != 0 || ix.any((x) => x < 0 || x >= p.length))
          throw const FormatException('Invalid triangle indices');
        positions.addAll(p);
        texCoords.addAll(uv);
        joints.addAll(vertexJoints);
        weights.addAll(vertexWeights);
        indices.addAll(ix.map((x) => x + base));
        triangleTextureIds.addAll(List<int?>.filled(ix.length ~/ 3, textureId));
      }
    }
    if (positions.isEmpty)
      throw const FormatException(
        'No triangle mesh with skin weights was found',
      );
    final nodes = _array(gltf['nodes']).map(_object).toList();
    final parents = List<int>.filled(nodes.length, -1);
    for (var i = 0; i < nodes.length; i++) {
      for (final child
          in (nodes[i]['children'] as List<Object?>? ?? const [])) {
        final c = (child as num).toInt();
        if (c < 0 || c >= nodes.length || parents[c] != -1)
          throw const FormatException('Invalid rig hierarchy');
        parents[c] = i;
      }
    }
    final skin = _object(skins.single);
    final skinJoints = _array(
      skin['joints'],
    ).map((x) => (x as num).toInt()).toList();
    if (skinJoints.any((x) => x < 0 || x >= nodes.length))
      throw const FormatException('Unknown skin node');
    final inverse = read(
      (skin['inverseBindMatrices'] as num).toInt(),
    ).map(v.Matrix4.fromList).toList();
    if (inverse.length != skinJoints.length)
      throw const FormatException('Missing inverse bind matrices');
    final vertices = List<SkinVertex>.generate(positions.length, (i) {
      final w = weights[i], j = joints[i].map((x) => x.toInt()).toList();
      if (j.length != 4 ||
          w.length != 4 ||
          j.any((x) => x < 0 || x >= skinJoints.length) ||
          w.any((x) => x < 0) ||
          (w.reduce((a, b) => a + b) - 1).abs() > .001)
        throw const FormatException('Invalid skin weights or joints');
      return SkinVertex(
        v.Vector3.array(positions[i]),
        j,
        w,
        v.Vector2(texCoords[i][0], texCoords[i][1]),
      );
    });
    final mesh = GlbMesh._(
      vertices,
      indices,
      nodes,
      parents,
      skinJoints,
      inverse,
      triangleTextureIds,
      textureBytes,
    );
    mesh.posedVertices(
      const RigPose(),
    ); // Detect cycles before returning a usable asset.
    return mesh;
  }

  List<v.Vector3> posedVertices(RigPose pose) {
    final world = List<v.Matrix4?>.filled(nodes.length, null);
    final visiting = List<bool>.filled(nodes.length, false);
    final angles = Map<String, double>.fromIterables([
      'LeftUpperArm',
      'LeftForeArm',
      'RightUpperArm',
      'RightForeArm',
    ], pose.angles);
    v.Matrix4 global(int index) {
      if (world[index] != null) return world[index]!;
      if (visiting[index]) throw const FormatException('Cyclic rig hierarchy');
      visiting[index] = true;
      final node = nodes[index];
      final t = node['translation'] == null
          ? [0.0, 0.0, 0.0]
          : _numbers(node['translation']);
      if (node['name'] == 'Hips') t[1] += pose.rootYOffset;
      final q = node['rotation'] == null
          ? [0.0, 0.0, 0.0, 1.0]
          : _numbers(node['rotation']);
      final s = node['scale'] == null
          ? [1.0, 1.0, 1.0]
          : _numbers(node['scale']);
      final local = node['matrix'] != null
          ? v.Matrix4.fromList(_numbers(node['matrix']))
          : v.Matrix4.compose(
              v.Vector3.array(t),
              v.Quaternion(q[0], q[1], q[2], q[3]),
              v.Vector3.array(s),
            );
      final angle = angles[node['name']] ?? 0;
      final tracked =
          pose.localRotations[_canonicalBone(node['name']?.toString() ?? '')] ??
          pose.localRotations[node['name']];
      local.multiply(
        tracked == null
            ? v.Matrix4.rotationZ(angle * math.pi / 180)
            : v.Matrix4.compose(
                v.Vector3.zero(),
                v.Quaternion(tracked.x, tracked.y, tracked.z, tracked.w),
                v.Vector3.all(1),
              ),
      );
      final result = parents[index] == -1
          ? local
          : (global(parents[index]).clone()..multiply(local));
      visiting[index] = false;
      world[index] = result;
      return result;
    }

    final matrices = List<v.Matrix4>.generate(
      skinJoints.length,
      (i) => global(skinJoints[i]).clone()..multiply(inverseBinds[i]),
    );
    return vertices.map((vertex) {
      final result = v.Vector3.zero();
      for (var i = 0; i < 4; i++) {
        if (vertex.weights[i] == 0) continue;
        final transformed = vertex.position.clone();
        matrices[vertex.joints[i]].transform3(transformed);
        result.add(transformed..scale(vertex.weights[i]));
      }
      return result;
    }).toList();
  }

  static String _canonicalBone(String source) {
    final name = source
        .split(':')
        .last
        .replaceAll(RegExp(r'^mixamorig\d*'), '');
    final finger = name.replaceFirst(
      RegExp(r'^(Left|Right)Hand(Thumb|Index|Middle|Ring|Pinky)'),
      r'$1$2',
    );
    const aliases = <String, String>{
      'LeftArm': 'LeftUpperArm',
      'RightArm': 'RightUpperArm',
      'LeftForeArm': 'LeftForeArm',
      'RightForeArm': 'RightForeArm',
      'LeftHand': 'LeftHand',
      'RightHand': 'RightHand',
      'LeftUpLeg': 'LeftThigh',
      'RightUpLeg': 'RightThigh',
      'LeftLeg': 'LeftShin',
      'RightLeg': 'RightShin',
      'LeftFoot': 'LeftFoot',
      'RightFoot': 'RightFoot',
      'Neck': 'Neck',
      'Head': 'Head',
      'Hips': 'Hips',
      'Spine': 'Spine',
      'Spine1': 'Chest',
      'Spine2': 'Chest',
      'LeftShoulder': 'LeftShoulder',
      'RightShoulder': 'RightShoulder',
    };
    return aliases[name] ?? aliases[finger] ?? finger;
  }
}
