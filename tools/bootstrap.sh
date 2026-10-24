#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 tools/python/generate_dev_rig.py
cd app
# Generate only absent runners. Never overwrite future native implementation.
if [[ ! -d linux || ! -d android ]]; then
  flutter create --platforms=linux,android --org com.ajayjasper --project-name mimic_mixamo --no-pub .
  rm -f test/widget_test.dart
fi
flutter pub get
