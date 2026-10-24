# Mimic

**0.4.0 development build:** Android and Linux webcam skeleton tracking, plus manual skinned GLB controls. Camera-to-character retargeting is not implemented yet. See the [development plan](docs/development_plan.md) and [status](docs/development_status.md).

## Downloads

Download the newest build from [Releases](https://github.com/AjayJasperJ/mimic_mixamo/releases).

**Linux:** download the single **Mimic-x86_64.AppImage** file. No Python installation or sidecar folder is required.

```sh
chmod +x Mimic-x86_64.AppImage
./Mimic-x86_64.AppImage
```

Open camera tracking, select a webcam, then Start camera. The same screen supports local skeleton tracking on Android. Linux GLB controls load the actual bundled skinned mesh; drag to rotate it. [Linux testing and compatibility](docs/linux_testing.md).

**Android:** install mimic-debug.apk. Confirm the home title says 0.4.0. Open camera tracking and grant permission. Switch front/back as needed. Open Rig control proof separately to test the GLB. Reload model and the load-stage/error text provide recovery diagnostics. An older downloaded APK does not update itself. If Android reports conflicting debug signatures, uninstall the old test APK first.

These are test builds. Physical camera, performance and broad distribution compatibility checks remain pending. Ubuntu 22.04+ x86_64 is the initial Linux baseline. On hosts without FUSE, the AppImage supports `--appimage-extract-and-run` as a temporary-extraction launch mode.

CI runs on every push/PR and can be run manually. Successful main-branch Linux and Android jobs publish a `test-build-<run number>` release. Only after publishing the replacement are older automatic test releases and tags deleted; manually created releases remain. Failed builds preserve the previous download. Actions artifacts expire after 30 days.

## Develop

Install Flutter **3.35.7**, Python 3 and the platform build tools:

```sh
bash tools/bootstrap.sh
cd app
dart format lib test
flutter analyze
flutter test
flutter run -d linux
```

For Android, first run `python3 tools/python/fetch_pose_model.py` to bundle the checksum-pinned model. For a complete Linux AppImage, build Flutter Linux, create a Python 3.10 environment with `tools/linux/requirements.txt`, then run `bash tools/linux/build_appimage.sh`. The workflow records the full environment and preserves dependency license files inside the image.

Linux prerequisites for building include clang, cmake, ninja, pkg-config, GTK3 development headers, Xvfb, patchelf and squashfs tools. AppImage users do not install these development tools.

## Implementation boundaries

- Android: CameraX 1.3.4 + MediaPipe Tasks 0.10.14; native image/landmark overlay, local processing, no recordings/uploads. Filament 1.56.0 uses a TextureView for the GLB.
- Linux: bundled Python MediaPipe/OpenCV worker using V4L2; a credit-based local stdio protocol bounds processing to one requested frame. Flutter displays matching JPEG and landmarks. No network listener is opened.
- Linux GLB proof: Dart parses the bundled geometry, joints and inverse bind matrices and skins the small development mesh. This is an actual mesh preview, not the earlier stick diagram, and is not a generic high-performance GLB engine.
- Character: original CC0 block humanoid, 10 joints, one skin, 156 triangles, no animation clips. [Asset manifest](docs/asset_manifest.json). It is not the owner's Mixamo asset.
- Pending: calibrated pose-to-avatar retargeting, owner rig integration, full-body grounding and measured device performance. See [device checklist](docs/device_test_report.md).
