#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
MIMIC_STAGE="$PWD/build/appimage"
mkdir -p "$MIMIC_STAGE/tooling" dist
python3 tools/python/fetch_pose_model.py
python3 -m PyInstaller --noconfirm --clean --onedir --name mimic-tracker \
  --distpath "$MIMIC_STAGE/frozen" --workpath "$MIMIC_STAGE/pyinstaller" --specpath "$MIMIC_STAGE" \
  --collect-all mediapipe --collect-all cv2 \
  --exclude-module jax --exclude-module jaxlib --exclude-module tensorflow --exclude-module torch \
  --add-data "$PWD/app/packages/mimic_native/android/src/main/assets/pose_landmarker_lite.task:." \
  tools/linux/mimic_tracker.py
"$MIMIC_STAGE/frozen/mimic-tracker/mimic-tracker" --self-test
MIMIC_APPDIR="$MIMIC_STAGE/AppDir"
mkdir -p "$MIMIC_APPDIR/usr/bin" "$MIMIC_APPDIR/usr/lib" "$MIMIC_APPDIR/usr/share/doc/mimic"
cp -a app/build/linux/x64/release/bundle/. "$MIMIC_APPDIR/usr/bin/"
cp -a "$MIMIC_STAGE/frozen/mimic-tracker" "$MIMIC_APPDIR/usr/lib/"
cp README.md "$MIMIC_APPDIR/usr/share/doc/mimic/"
python3 -m pip freeze > "$MIMIC_APPDIR/usr/share/doc/mimic/python-environment.txt"
python3 tools/linux/collect_licenses.py "$MIMIC_APPDIR/usr/share/doc/mimic/python-licenses"
curl --fail --location --retry 3 -o "$MIMIC_STAGE/tooling/linuxdeploy.AppImage" \
  https://github.com/linuxdeploy/linuxdeploy/releases/download/1-alpha-20251107-1/linuxdeploy-x86_64.AppImage
printf '%s  %s\n' c20cd71e3a4e3b80c3483cef793cda3f4e990aca14014d23c544ca3ce1270b4d "$MIMIC_STAGE/tooling/linuxdeploy.AppImage" | sha256sum -c -
chmod +x "$MIMIC_STAGE/tooling/linuxdeploy.AppImage"
NO_STRIP=1 APPIMAGE_EXTRACT_AND_RUN=1 "$MIMIC_STAGE/tooling/linuxdeploy.AppImage" \
  --appdir "$MIMIC_APPDIR" --executable "$MIMIC_APPDIR/usr/bin/mimic_mixamo" \
  --desktop-file tools/linux/mimic.desktop --icon-file tools/linux/mimic.svg
# The custom entrypoint starts either Flutter or the bundled tracker diagnostics.
rm -f "$MIMIC_APPDIR/AppRun"
cp tools/linux/AppRun "$MIMIC_APPDIR/AppRun"
chmod +x "$MIMIC_APPDIR/AppRun"
curl --fail --location --retry 3 -o "$MIMIC_STAGE/tooling/appimagetool.AppImage" \
  https://github.com/AppImage/appimagetool/releases/download/1.9.1/appimagetool-x86_64.AppImage
printf '%s  %s\n' ed4ce84f0d9caff66f50bcca6ff6f35aae54ce8135408b3fa33abfc3cb384eb0 "$MIMIC_STAGE/tooling/appimagetool.AppImage" | sha256sum -c -
chmod +x "$MIMIC_STAGE/tooling/appimagetool.AppImage"
# Reuse this pinned tool's embedded runtime instead of downloading a floating runtime.
MIMIC_OFFSET=$("$MIMIC_STAGE/tooling/appimagetool.AppImage" --appimage-offset)
head -c "$MIMIC_OFFSET" "$MIMIC_STAGE/tooling/appimagetool.AppImage" > "$MIMIC_STAGE/tooling/runtime-x86_64"
ARCH=x86_64 APPIMAGE_EXTRACT_AND_RUN=1 "$MIMIC_STAGE/tooling/appimagetool.AppImage" \
  --runtime-file "$MIMIC_STAGE/tooling/runtime-x86_64" --no-appstream --mksquashfs-opt=-processors --mksquashfs-opt=2 "$MIMIC_APPDIR" dist/Mimic-x86_64.AppImage
chmod +x dist/Mimic-x86_64.AppImage
