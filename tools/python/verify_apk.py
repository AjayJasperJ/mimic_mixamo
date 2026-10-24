"""Verify the actual packaged APK contains the GLB, model and camera declaration."""
import hashlib
import json
import struct
import sys
import zipfile
from pathlib import Path


def verify(path):
    with zipfile.ZipFile(path) as apk:
        glb=apk.read('assets/flutter_assets/assets/characters/development_humanoid.glb')
        assert struct.unpack_from('<4sII',glb)==(b'glTF',2,len(glb)), 'Invalid packaged GLB'
        assert apk.getinfo('assets/pose_landmarker_lite.task').compress_type == zipfile.ZIP_STORED, 'Pose task must be uncompressed for native asset loading'
        model=apk.read('assets/pose_landmarker_lite.task')
        manifest=json.loads(apk.read('assets/pose_model_manifest.json'))
        assert hashlib.sha256(model).hexdigest()==manifest['sha256'], 'Packaged model checksum mismatch'
        android_manifest=apk.read('AndroidManifest.xml')
        permission='android.permission.CAMERA'
        assert permission.encode() in android_manifest or permission.encode('utf-16le') in android_manifest, 'Camera permission missing'
    print(f'APK assets verified: {len(glb)} GLB bytes, {len(model)} model bytes, camera permission declared')


if __name__=='__main__':
    verify(Path(sys.argv[1]))
