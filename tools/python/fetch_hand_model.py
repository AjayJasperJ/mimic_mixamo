"""Acquire the versioned Google MediaPipe Hand Landmarker task at build time."""
import hashlib
import json
import os
from pathlib import Path
from urllib.request import urlopen

ROOT = Path(__file__).resolve().parents[2]
URL = 'https://storage.googleapis.com/mediapipe-models/hand_landmarker/hand_landmarker/float16/1/hand_landmarker.task'
EXPECTED_SHA256 = 'fbc2a30080c3c557093b5ddfc334698132eb341044ccee322ccf8bcf3607cde1'


def fetch():
    directory = ROOT / 'app/packages/mimic_native/android/src/main/assets'
    directory.mkdir(parents=True, exist_ok=True)
    target = directory / 'hand_landmarker.task'
    if target.exists():
        payload = target.read_bytes()
    else:
        with urlopen(URL, timeout=60) as response:
            payload = response.read(16 * 1024 * 1024 + 1)
    if not 1_000_000 < len(payload) <= 16 * 1024 * 1024:
        raise ValueError('Unexpected hand model bundle size')
    digest = hashlib.sha256(payload).hexdigest()
    if digest != EXPECTED_SHA256:
        raise ValueError('Hand model checksum mismatch')
    temp = target.with_suffix('.tmp')
    temp.write_bytes(payload)
    os.replace(temp, target)
    (directory/'hand_model_manifest.json').write_text(json.dumps({
        'name':'Hand Landmarker', 'url':URL, 'version':'float16/1',
        'sha256':digest, 'bytes':len(payload), 'sdk':'mediapipe 0.10.14'
    }, indent=2)+'\n')
    print(f'HAND_MODEL_SHA256={digest}')


if __name__ == '__main__':
    fetch()
