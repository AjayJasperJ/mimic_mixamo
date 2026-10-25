import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'glb_mesh.dart';

/// Stores the imported, converted GLB outside the app bundle so the user's
/// character remains available to the rig preview and camera avatar.
class CustomCharacterStore {
  CustomCharacterStore._();

  static const _maxInputBytes = 200 * 1024 * 1024;
  static const _maxExpandedBytes = 500 * 1024 * 1024;
  static const _maxArchiveEntries = 1000;
  static const _imageExtensions = {
    'bmp',
    'dds',
    'jpeg',
    'jpg',
    'png',
    'tga',
    'tif',
    'tiff',
    'webp',
  };

  static final ValueNotifier<String?> selectedPath = ValueNotifier(null);
  static String get displayName => selectedPath.value == null
      ? 'Original development character'
      : File(selectedPath.value!).uri.pathSegments.last
            .replaceFirst(RegExp(r'^custom-character-'), '')
            .replaceFirst(RegExp(r'-\d+\.glb$'), '')
            .replaceAll('-', ' ');

  static Future<Directory> _directory({Directory? override}) async {
    if (override != null) {
      await override.create(recursive: true);
      return override;
    }
    final env = Platform.environment;
    final base =
        env['XDG_DATA_HOME'] ??
        '${env['HOME'] ?? Directory.systemTemp.path}/.local/share';
    final directory = Directory('$base/mimic_mixamo/characters');
    await directory.create(recursive: true);
    return directory;
  }

  static Future<void> restore() async {
    if (!Platform.isLinux) return;
    try {
      final directory = await _directory();
      final marker = File('${directory.path}/selected.path');
      if (!await marker.exists()) return;
      final path = (await marker.readAsString()).trim();
      final file = File(path);
      if (!await file.exists()) return;
      GlbMesh.parse(await file.readAsBytes());
      selectedPath.value = file.path;
    } on Object {
      selectedPath.value = null;
    }
  }

  static Future<String> importFile(
    String sourcePath, {
    Directory? storageDirectory,
  }) async {
    if (!Platform.isLinux) {
      throw UnsupportedError(
        'Custom character import is currently Linux only.',
      );
    }
    final source = File(sourcePath);
    if (!await source.exists())
      throw const FileSystemException('Selected file was not found');
    final size = await source.length();
    if (size <= 0 || size > _maxInputBytes) {
      throw const FormatException(
        'Choose a character file smaller than 200 MB.',
      );
    }
    final extension = source.uri.pathSegments.last
        .toLowerCase()
        .split('.')
        .last;
    if (extension != 'fbx' && extension != 'glb' && extension != 'zip') {
      throw const FormatException(
        'Choose a Mixamo .fbx, .glb, or a .zip bundle containing one character and its textures.',
      );
    }

    final directory = await _directory(override: storageDirectory);
    final previousPath = selectedPath.value;
    final sourceName = source.uri.pathSegments.last.replaceFirst(
      RegExp(r'\.[^.]+$'),
      '',
    );
    final namePart = sourceName
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    final output = File(
      '${directory.path}/custom-character-${namePart.isEmpty ? 'imported' : namePart}-${DateTime.now().microsecondsSinceEpoch}.glb',
    );
    final temporary = File('${directory.path}/custom-character.tmp.glb');
    Directory? extracted;
    File? characterFile;
    var characterExtension = extension;
    try {
      if (extension == 'zip') {
        extracted = await Directory.systemTemp.createTemp('mimic-character-');
        final bundle = await _extractBundle(source, extracted);
        characterFile = bundle.file;
        characterExtension = bundle.extension;
      } else {
        characterFile = source;
      }

      if (characterExtension == 'glb') {
        await characterFile.copy(temporary.path);
      } else {
        late final ProcessResult result;
        try {
          result = await Process.run(_converterPath(), [
            'export',
            characterFile.path,
            temporary.path,
            '-fglb2',
          ], runInShell: false);
        } on ProcessException catch (error) {
          throw FormatException(
            'FBX conversion could not start ($error). Debug runs need Assimp installed; the AppImage includes it. Import a GLB directly if Assimp is unavailable.',
          );
        }
        if (result.exitCode != 0) {
          final detail = '${result.stderr}'.trim();
          throw FormatException(
            detail.isEmpty
                ? 'FBX conversion failed (${result.exitCode}).'
                : detail,
          );
        }
      }
      final bytes = await temporary.readAsBytes();
      final mesh = GlbMesh.parse(bytes);
      if (mesh.skinJoints.isEmpty) {
        throw const FormatException(
          'The selected character has no skinned rig.',
        );
      }
      await temporary.rename(output.path);
      final marker = File('${directory.path}/selected.path');
      await marker.writeAsString(output.path, flush: true);
      selectedPath.value = output.path;
      if (previousPath != null && previousPath != output.path) {
        final previous = File(previousPath);
        if (await previous.parent.resolveSymbolicLinks() ==
                await directory.resolveSymbolicLinks() &&
            previous.uri.pathSegments.last.startsWith('custom-character-') &&
            await previous.exists()) {
          await previous.delete();
        }
      }
      return '${displayName} • ${mesh.skinJoints.length} joints • ${mesh.textureBytes.length} embedded textures';
    } finally {
      if (await temporary.exists()) await temporary.delete();
      if (extracted != null && await extracted.exists()) {
        await extracted.delete(recursive: true);
      }
    }
  }

  static Future<({File file, String extension})> _extractBundle(
    File source,
    Directory destination,
  ) async {
    final archive = ZipDecoder().decodeBytes(
      await source.readAsBytes(),
      verify: true,
    );
    if (archive.length > _maxArchiveEntries) {
      throw const FormatException('ZIP contains too many entries.');
    }
    var expandedBytes = 0;
    final models = <File>[];
    for (final entry in archive) {
      if (entry.isSymbolicLink) {
        throw const FormatException(
          'ZIP bundles cannot contain symbolic links.',
        );
      }
      var name = entry.name.replaceAll('\\', '/');
      if (entry.isDirectory && name.endsWith('/')) {
        name = name.substring(0, name.length - 1);
      }
      final segments = name.split('/');
      if (name.isEmpty ||
          name.startsWith('/') ||
          RegExp(r'^[A-Za-z]:').hasMatch(name) ||
          segments.any((part) => part == '..' || part == '.' || part.isEmpty)) {
        throw const FormatException('ZIP contains an unsafe file path.');
      }
      if (entry.isDirectory) continue;
      if (entry.size < 0 || entry.size > _maxInputBytes) {
        throw const FormatException(
          'A ZIP entry exceeds the 200 MB file limit.',
        );
      }
      expandedBytes += entry.size;
      if (expandedBytes > _maxExpandedBytes) {
        throw const FormatException('ZIP expands beyond the 500 MB limit.');
      }
      final extension = segments.last.toLowerCase().split('.').last;
      if (extension != 'fbx' &&
          extension != 'glb' &&
          !_imageExtensions.contains(extension)) {
        continue;
      }
      final target = File(
        '${destination.path}${Platform.pathSeparator}${segments.join(Platform.pathSeparator)}',
      );
      await target.parent.create(recursive: true);
      final bytes = entry.readBytes();
      if (bytes == null || bytes.length != entry.size) {
        throw const FormatException('ZIP contains an incomplete file.');
      }
      await target.writeAsBytes(bytes, flush: false);
      if (extension == 'fbx' || extension == 'glb') models.add(target);
    }
    if (models.length != 1) {
      throw const FormatException(
        'ZIP must contain exactly one .fbx or .glb character file.',
      );
    }
    final model = models.single;
    return (file: model, extension: model.path.toLowerCase().split('.').last);
  }

  static String _converterPath() {
    final configured = Platform.environment['MIMIC_ASSIMP_EXECUTABLE'];
    if (configured != null && configured.isNotEmpty) return configured;
    final executable = File(Platform.resolvedExecutable);
    final bundled = File('${executable.parent.parent.path}/bin/mimic-assimp');
    if (bundled.existsSync()) return bundled.path;
    // Development fallback. The AppImage always supplies the bundled binary.
    return 'assimp';
  }
}
