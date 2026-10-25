import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimic_mixamo/features/rig/custom_character_store.dart';
import 'package:mimic_mixamo/features/rig/desktop_glb_view.dart';
import 'package:mimic_mixamo/features/rig/glb_mesh.dart';
import 'package:mimic_mixamo/features/rig/rig_pose.dart';

Uint8List _withTestTexture(Uint8List original) {
  final source = ByteData.sublistView(original);
  final jsonLength = source.getUint32(12, Endian.little);
  final json =
      jsonDecode(utf8.decode(original.sublist(20, 20 + jsonLength)))
          as Map<String, dynamic>;
  final binaryChunk = 20 + jsonLength;
  final binaryLength = source.getUint32(binaryChunk, Endian.little);
  final binary = original
      .sublist(binaryChunk + 8, binaryChunk + 8 + binaryLength)
      .toList();
  final primitive = (json['meshes'] as List).first['primitives'].first;
  final attributes = primitive['attributes'] as Map<String, dynamic>;
  final positionAccessor =
      (json['accessors'] as List)[attributes['POSITION'] as int];
  final vertexCount = positionAccessor['count'] as int;
  final uvOffset = binary.length;
  final uvBytes = Uint8List(vertexCount * 8);
  final uvData = ByteData.sublistView(uvBytes);
  for (var i = 0; i < vertexCount; i++) {
    uvData.setFloat32(i * 8, .5, Endian.little);
    uvData.setFloat32(i * 8 + 4, .5, Endian.little);
  }
  binary.addAll(uvBytes);
  while (binary.length % 4 != 0) {
    binary.add(0);
  }
  final views = json['bufferViews'] as List<dynamic>;
  final uvView = views.length;
  views.add({
    'buffer': 0,
    'byteOffset': uvOffset,
    'byteLength': uvBytes.length,
  });
  final accessors = json['accessors'] as List<dynamic>;
  attributes['TEXCOORD_0'] = accessors.length;
  accessors.add({
    'bufferView': uvView,
    'componentType': 5126,
    'count': vertexCount,
    'type': 'VEC2',
  });

  const pngBase64 =
      'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0kAAAAEUlEQVR4nGN4JiL3H4QZYAwASqQIXaazuckAAAAASUVORK5CYII=';
  final png = base64.decode(pngBase64);
  while (binary.length % 4 != 0) {
    binary.add(0);
  }
  final imageOffset = binary.length;
  binary.addAll(png);
  final imageView = views.length;
  views.add({'buffer': 0, 'byteOffset': imageOffset, 'byteLength': png.length});
  json['images'] = [
    {'bufferView': imageView, 'mimeType': 'image/png'},
  ];
  json['textures'] = [
    {'source': 0},
  ];
  json['materials'] = [
    {
      'pbrMetallicRoughness': {
        'baseColorTexture': {'index': 0},
      },
    },
  ];
  primitive['material'] = 0;
  (json['buffers'] as List).first['byteLength'] = binary.length;

  final encoded = utf8.encode(jsonEncode(json));
  final paddedJson = (encoded.length + 3) & ~3;
  final paddedBinary = (binary.length + 3) & ~3;
  final result = Uint8List(12 + 8 + paddedJson + 8 + paddedBinary);
  final out = ByteData.sublistView(result);
  out.setUint32(0, 0x46546c67, Endian.little);
  out.setUint32(4, 2, Endian.little);
  out.setUint32(8, result.length, Endian.little);
  out.setUint32(12, paddedJson, Endian.little);
  out.setUint32(16, 0x4e4f534a, Endian.little);
  result.setRange(20, 20 + encoded.length, encoded);
  result.fillRange(20 + encoded.length, 20 + paddedJson, 0x20);
  final binaryHeader = 20 + paddedJson;
  out.setUint32(binaryHeader, paddedBinary, Endian.little);
  out.setUint32(binaryHeader + 4, 0x004e4942, Endian.little);
  result.setRange(binaryHeader + 8, binaryHeader + 8 + binary.length, binary);
  return result;
}

void main() {
  test(
    'bundled GLB bind matrices preserve rest mesh and drive only the selected arm',
    () async {
      final mesh = GlbMesh.parse(
        await File('assets/characters/development_humanoid.glb').readAsBytes(),
      );
      expect(mesh.vertices.length, 360);
      expect(mesh.indices.length ~/ 3, 540);
      expect(mesh.skinJoints.length, 42);
      final rest = mesh.posedVertices(const RigPose());
      for (var i = 0; i < rest.length; i++) {
        expect((rest[i] - mesh.vertices[i].position).length, lessThan(1e-5));
      }
      final posed = mesh.posedVertices(const RigPose(leftElbow: 90));
      final left = mesh.vertices.indexWhere((v) => v.joints.first == 3);
      final right = mesh.vertices.indexWhere((v) => v.joints.first == 5);
      expect((posed[left] - rest[left]).length, greaterThan(.01));
      expect((posed[right] - rest[right]).length, lessThan(1e-5));
    },
  );
  test('combines material-split skinned primitives in one character', () async {
    final original = await File(
      'assets/characters/development_humanoid.glb',
    ).readAsBytes();
    final source = ByteData.sublistView(original);
    final jsonLength = source.getUint32(12, Endian.little);
    final json =
        jsonDecode(utf8.decode(original.sublist(20, 20 + jsonLength)))
            as Map<String, dynamic>;
    final meshes = json['meshes'] as List<dynamic>;
    final primitives = meshes.first['primitives'] as List<dynamic>;
    primitives.add(Map<String, dynamic>.from(primitives.first as Map));
    final encoded = utf8.encode(jsonEncode(json));
    final paddedLength = (encoded.length + 3) & ~3;
    final binaryStart = 20 + jsonLength;
    final binaryLength = source.getUint32(binaryStart, Endian.little);
    final rebuilt = Uint8List(12 + 8 + paddedLength + 8 + binaryLength);
    final out = ByteData.sublistView(rebuilt);
    out.setUint32(0, 0x46546c67, Endian.little);
    out.setUint32(4, 2, Endian.little);
    out.setUint32(8, rebuilt.length, Endian.little);
    out.setUint32(12, paddedLength, Endian.little);
    out.setUint32(16, 0x4e4f534a, Endian.little);
    rebuilt.setRange(20, 20 + encoded.length, encoded);
    rebuilt.fillRange(20 + encoded.length, 20 + paddedLength, 0x20);
    final binaryHeader = 20 + paddedLength;
    out.setUint32(binaryHeader, binaryLength, Endian.little);
    out.setUint32(binaryHeader + 4, 0x004e4942, Endian.little);
    rebuilt.setRange(
      binaryHeader + 8,
      rebuilt.length,
      original.sublist(binaryStart + 8),
    );

    final mesh = GlbMesh.parse(rebuilt);
    expect(mesh.vertices.length, 720);
    expect(mesh.indices.length, 3240);
  });
  test(
    'renormalizes partial skin weights emitted by an FBX converter',
    () async {
      final bytes = await File(
        'assets/characters/development_humanoid.glb',
      ).readAsBytes();
      final data = ByteData.sublistView(bytes);
      final jsonLength = data.getUint32(12, Endian.little);
      final json =
          jsonDecode(utf8.decode(bytes.sublist(20, 20 + jsonLength)))
              as Map<String, dynamic>;
      final primitive = (json['meshes'] as List).first['primitives'].first;
      final weightAccessorIndex = primitive['attributes']['WEIGHTS_0'] as int;
      final accessor = (json['accessors'] as List)[weightAccessorIndex];
      expect(accessor['componentType'], 5126);
      final view = (json['bufferViews'] as List)[accessor['bufferView'] as int];
      final binaryOffset = 20 + jsonLength + 8;
      final weightOffset =
          binaryOffset +
          (view['byteOffset'] as int? ?? 0) +
          (accessor['byteOffset'] as int? ?? 0);
      final stride = view['byteStride'] as int? ?? 16;
      final count = accessor['count'] as int;
      for (var vertex = 0; vertex < count; vertex++) {
        for (var influence = 0; influence < 4; influence++) {
          final offset = weightOffset + vertex * stride + influence * 4;
          data.setFloat32(
            offset,
            data.getFloat32(offset, Endian.little) * .25,
            Endian.little,
          );
        }
      }

      final mesh = GlbMesh.parse(bytes);
      for (final vertex in mesh.vertices) {
        expect(vertex.weights.reduce((a, b) => a + b), closeTo(1, 1e-6));
      }
    },
  );
  test('decodes and rasterizes an embedded base-color texture', () async {
    final original = await File(
      'assets/characters/development_humanoid.glb',
    ).readAsBytes();
    final mesh = GlbMesh.parse(_withTestTexture(original));
    expect(mesh.textureBytes, hasLength(1));
    expect(mesh.triangleTextureIds.whereType<int>(), isNotEmpty);
    await mesh.decodeTextures();
    expect(mesh.decodedTextures, hasLength(1));

    final recorder = ui.PictureRecorder();
    SkinnedGlbPainter(
      mesh,
      const RigPose(),
      .3,
    ).paint(ui.Canvas(recorder), const ui.Size(350, 350));
    final rendered = await recorder.endRecording().toImage(350, 350);
    final pixels = (await rendered.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    ))!.buffer.asUint8List();
    var redPixels = 0;
    for (var i = 0; i < pixels.length; i += 4) {
      if (pixels[i] > 180 && pixels[i + 1] < 80 && pixels[i + 2] < 80) {
        redPixels++;
      }
    }
    expect(redPixels, greaterThan(100));
    rendered.dispose();
    mesh.disposeTextures();
  });
  test('desktop GLB loader rejects text or truncated files before parsing', () {
    expect(() => GlbMesh.parse(Uint8List(20)), throwsFormatException);
  });
  test(
    'imports a ZIP bundle containing a GLB and companion texture files',
    () async {
      final fixture = await File(
        'assets/characters/development_humanoid.glb',
      ).readAsBytes();
      final bundle = Archive()
        ..addFile(ArchiveFile.bytes('Mixamo/Hero.glb', fixture))
        ..addFile(
          ArchiveFile.bytes('Mixamo/Textures/albedo.png', [137, 80, 78, 71]),
        );
      final zipBytes = ZipEncoder().encode(bundle);
      final temp = await Directory.systemTemp.createTemp('mimic-zip-test-');
      final zip = File('${temp.path}/character.zip')
        ..writeAsBytesSync(zipBytes);
      final storage = Directory('${temp.path}/selected');
      addTearDown(() async {
        CustomCharacterStore.selectedPath.value = null;
        if (await temp.exists()) await temp.delete(recursive: true);
      });

      final result = await CustomCharacterStore.importFile(
        zip.path,
        storageDirectory: storage,
      );
      expect(result, contains('42 joints'));
      final firstSelection = CustomCharacterStore.selectedPath.value!;
      expect(
        GlbMesh.parse(await File(firstSelection).readAsBytes()).skinJoints,
        hasLength(42),
      );
      await CustomCharacterStore.importFile(
        zip.path,
        storageDirectory: storage,
      );
      final secondSelection = CustomCharacterStore.selectedPath.value!;
      expect(secondSelection, isNot(firstSelection));
      expect(await File(firstSelection).exists(), isFalse);
      expect(await File(secondSelection).exists(), isTrue);
    },
  );
  test(
    'rejects ZIP entries that try to escape the extraction directory',
    () async {
      final fixture = await File(
        'assets/characters/development_humanoid.glb',
      ).readAsBytes();
      final bundle = Archive()
        ..addFile(ArchiveFile.bytes('../escape.glb', fixture));
      final temp = await Directory.systemTemp.createTemp(
        'mimic-zip-path-test-',
      );
      final zip = File('${temp.path}/unsafe.zip')
        ..writeAsBytesSync(ZipEncoder().encode(bundle));
      addTearDown(() async {
        if (await temp.exists()) await temp.delete(recursive: true);
      });

      await expectLater(
        CustomCharacterStore.importFile(
          zip.path,
          storageDirectory: Directory('${temp.path}/selected'),
        ),
        throwsFormatException,
      );
      expect(await File('${temp.parent.path}/escape.glb').exists(), isFalse);
    },
  );
}
