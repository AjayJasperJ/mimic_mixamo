"""Acquire the versioned Google Pose Landmarker Lite bundle at build time only."""
import hashlib
import json
import os
from pathlib import Path
from urllib.request import urlopen

ROOT = Path(__file__).resolve().parents[2]
URL = 'https://storage.googleapis.com/mediapipe-models/pose_landmarker/pose_landmarker_lite/float16/1/pose_landmarker_lite.task'
# Verified against the versioned upstream bundle acquired in successful CI run 40070114705.
EXPECTED_SHA256 = '59929e1d1ee95287735ddd833b19cf4ac46d29bc7afddbbf6753c459690d574a'


def fetch():
    directory = ROOT / 'app/packages/mimic_native/android/src/main/assets'
    directory.mkdir(parents=True, exist_ok=True)
    target = directory / 'pose_landmarker_lite.task'
    if target.exists():
        payload = target.read_bytes()
    else:
        with urlopen(URL, timeout=60) as response:
            payload = response.read(16 * 1024 * 1024 + 1)
    if not 1_000_000 < len(payload) <= 16*1024*1024:
        raise ValueError('Unexpected model bundle size')
    digest = hashlib.sha256(payload).hexdigest()
    if EXPECTED_SHA256 and digest != EXPECTED_SHA256:
        raise ValueError('Pose model checksum mismatch')
    temp = target.with_suffix('.tmp')
    temp.write_bytes(payload)
    os.replace(temp, target)
    (directory/'pose_model_manifest.json').write_text(json.dumps({
        'name':'Pose Landmarker Lite', 'url':URL, 'version':'float16/1',
        'sha256':digest, 'bytes':len(payload), 'sdk':'tasks-vision:0.10.14'
    }, indent=2)+'\n')
    print(f'POSE_MODEL_SHA256={digest}')


if __name__ == '__main__':
    fetch()
