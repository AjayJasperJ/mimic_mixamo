import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:vector_math/vector_math_64.dart' as v;
import 'rig_pose.dart';

Map<String, Object?> _object(Object? value) => Map<String, Object?>.from(value as Map<Object?, Object?>);
List<Object?> _array(Object? value) => value as List<Object?>;
List<double> _numbers(Object? value) => _array(value).map((x) => (x as num).toDouble()).toList();

class SkinVertex {
  SkinVertex(this.position, this.joints, this.weights);
  final v.Vector3 position;
  final List<int> joints;
  final List<double> weights;
}

/// Deliberately scoped to the bundled, untextured single-skin development GLB.
/// Actual GLB geometry and inverse bind matrices are used; this is not a stick diagram.
class GlbMesh {
  GlbMesh._(this.vertices, this.indices, this.nodes, this.parents, this.skinJoints, this.inverseBinds);
  final List<SkinVertex> vertices;
  final List<int> indices;
  final List<Map<String, Object?>> nodes;
  final List<int> parents, skinJoints;
  final List<v.Matrix4> inverseBinds;
  static GlbMesh parse(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    if (bytes.length < 28 || data.getUint32(0, Endian.little) != 0x46546c67 || data.getUint32(4, Endian.little) != 2 || data.getUint32(8, Endian.little) != bytes.length) throw const FormatException('Invalid GLB v2 header');
    Map<String, Object?>? document;
    Uint8List? binary;
    for (var offset = 12; offset < bytes.length;) {
      if (offset+8 > bytes.length) throw const FormatException('Truncated GLB chunk');
      final size = data.getUint32(offset, Endian.little), kind = data.getUint32(offset+4, Endian.little);
      offset += 8;
      if (size%4 != 0 || offset+size > bytes.length) throw const FormatException('Invalid GLB chunk size');
      if (kind == 0x4e4f534a) document = _object(jsonDecode(utf8.decode(bytes.sublist(offset, offset+size))));
      if (kind == 0x004e4942) binary = Uint8List.sublistView(bytes, offset, offset+size);
      offset += size;
    }
    if (document == null || binary == null) throw const FormatException('GLB needs JSON and embedded binary data');
    final gltf = document;
    final blob = ByteData.sublistView(binary);
    final accessors = _array(gltf['accessors']).map(_object).toList();
    final views = _array(gltf['bufferViews']).map(_object).toList();
    List<List<double>> read(int index) {
      final a = accessors[index], view = views[(accessors[index]['bufferView'] as num).toInt()];
      final component = (a['componentType'] as num).toInt();
      final size = switch (component) { 5121 => 1, 5123 => 2, 5125 || 5126 => 4, _ => throw const FormatException('Unsupported component type') };
      final width = switch (a['type']) { 'SCALAR' => 1, 'VEC3' => 3, 'VEC4' => 4, 'MAT4' => 16, _ => throw const FormatException('Unsupported accessor shape') };
      final count = (a['count'] as num).toInt();
      final offset = ((view['byteOffset'] as num?)?.toInt() ?? 0) + ((a['byteOffset'] as num?)?.toInt() ?? 0);
      final stride = (view['byteStride'] as num?)?.toInt() ?? width*size;
      if (count <= 0 || offset < 0 || stride < width*size || offset+(count-1)*stride+width*size > blob.lengthInBytes) throw const FormatException('Accessor exceeds GLB binary bounds');
      return List<List<double>>.generate(count, (row) => List<double>.generate(width, (column) {
        final at = offset + row*stride + column*size;
        final number = switch (component) { 5121 => blob.getUint8(at).toDouble(), 5123 => blob.getUint16(at,Endian.little).toDouble(), 5125 => blob.getUint32(at,Endian.little).toDouble(), _ => blob.getFloat32(at,Endian.little) };
        if (!number.isFinite) throw const FormatException('Nonfinite geometry');
        return number;
      }));
    }
    final meshes = _array(gltf['meshes']);
    final skins = _array(gltf['skins']);
    if (meshes.length != 1 || skins.length != 1) throw const FormatException('Desktop proof supports the bundled single-mesh, single-skin rig');
    final primitives = _array(_object(meshes.single)['primitives']);
    if (primitives.length != 1) throw const FormatException('Only one development mesh primitive is supported');
    final primitive = _object(primitives.single), attributes = _object(_object(primitives.single)['attributes']);
    final positions = read((attributes['POSITION'] as num).toInt());
    final joints = read((attributes['JOINTS_0'] as num).toInt());
    final weights = read((attributes['WEIGHTS_0'] as num).toInt());
    if (joints.length != positions.length || weights.length != positions.length) throw const FormatException('Skin attribute counts differ');
    final indices = read((primitive['indices'] as num).toInt()).map((x) => x.single.toInt()).toList();
    if (indices.length%3 != 0 || indices.any((x) => x<0 || x>=positions.length)) throw const FormatException('Invalid triangle indices');
    final nodes = _array(gltf['nodes']).map(_object).toList();
    final parents = List<int>.filled(nodes.length,-1);
    for (var i=0; i<nodes.length; i++) {
      for (final child in (nodes[i]['children'] as List<Object?>? ?? const [])) {
        final c = (child as num).toInt();
        if (c<0 || c>=nodes.length || parents[c] != -1) throw const FormatException('Invalid rig hierarchy');
        parents[c] = i;
      }
    }
    final skin = _object(skins.single);
    final skinJoints = _array(skin['joints']).map((x)=>(x as num).toInt()).toList();
    if (skinJoints.any((x)=>x<0 || x>=nodes.length)) throw const FormatException('Unknown skin node');
    final inverse = read((skin['inverseBindMatrices'] as num).toInt()).map(v.Matrix4.fromList).toList();
    if (inverse.length != skinJoints.length) throw const FormatException('Missing inverse bind matrices');
    final vertices = List<SkinVertex>.generate(positions.length, (i) {
      final w = weights[i], j = joints[i].map((x)=>x.toInt()).toList();
      if (j.length != 4 || w.length != 4 || j.any((x)=>x<0 || x>=skinJoints.length) || w.any((x)=>x<0) || (w.reduce((a,b)=>a+b)-1).abs() > .001) throw const FormatException('Invalid skin weights or joints');
      return SkinVertex(v.Vector3.array(positions[i]),j,w);
    });
    final mesh = GlbMesh._(vertices,indices,nodes,parents,skinJoints,inverse);
    mesh.posedVertices(const RigPose()); // Detect cycles before returning a usable asset.
    return mesh;
  }
  List<v.Vector3> posedVertices(RigPose pose) {
    final world = List<v.Matrix4?>.filled(nodes.length,null);
    final visiting = List<bool>.filled(nodes.length,false);
    final angles = Map<String,double>.fromIterables(['LeftUpperArm','LeftForeArm','RightUpperArm','RightForeArm'],pose.angles);
    v.Matrix4 global(int index) {
      if (world[index] != null) return world[index]!;
      if (visiting[index]) throw const FormatException('Cyclic rig hierarchy');
      visiting[index] = true;
      final node = nodes[index];
      final t = node['translation'] == null ? [0.0,0.0,0.0] : _numbers(node['translation']);
      if (node['name'] == 'Hips') t[1] += pose.rootYOffset;
      final q = node['rotation'] == null ? [0.0,0.0,0.0,1.0] : _numbers(node['rotation']);
      final s = node['scale'] == null ? [1.0,1.0,1.0] : _numbers(node['scale']);
      final local = node['matrix'] != null ? v.Matrix4.fromList(_numbers(node['matrix'])) : v.Matrix4.compose(v.Vector3.array(t),v.Quaternion(q[0],q[1],q[2],q[3]),v.Vector3.array(s));
      final angle = angles[node['name']] ?? 0;
      final tracked = pose.localRotations[node['name']];
      local.multiply(tracked == null ? v.Matrix4.rotationZ(angle*math.pi/180) : v.Matrix4.compose(
        v.Vector3.zero(),v.Quaternion(tracked.x,tracked.y,tracked.z,tracked.w),v.Vector3.all(1)));
      final result = parents[index] == -1 ? local : (global(parents[index]).clone()..multiply(local));
      visiting[index] = false; world[index] = result; return result;
    }
    final matrices = List<v.Matrix4>.generate(skinJoints.length, (i)=>global(skinJoints[i]).clone()..multiply(inverseBinds[i]));
    return vertices.map((vertex) {
      final result = v.Vector3.zero();
      for (var i=0;i<4;i++) {
        if (vertex.weights[i] == 0) continue;
        final transformed = vertex.position.clone();
        matrices[vertex.joints[i]].transform3(transformed);
        result.add(transformed..scale(vertex.weights[i]));
      }
      return result;
    }).toList();
  }
}
