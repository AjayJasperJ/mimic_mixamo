# Mimic

Flutter + native Android character motion tracking project. **0.3.0 test build: Android camera skeleton and manual GLB controls; calibrated character mimicry is still pending.** See [development plan](docs/development_plan.md) and [current status](docs/development_status.md).

## Download a test build

Download the newest tagged build from [Releases](https://github.com/AjayJasperJ/mimic_mixamo/releases). After both main-branch builds succeed, CI publishes a prerelease named `test-build-<run number>` with the Linux archive, debug APK and checksums. Only after publication, it deletes older automatic test releases and their tags. Manual/versioned releases are preserved. Failed builds leave the previous test release available.\n\nAlternatively, open [GitHub Actions](https://github.com/AjayJasperJ/mimic_mixamo/actions/workflows/build.yml), select the latest successful run, and download its artifact (GitHub sign-in required). Every push and pull request builds Linux x86_64 and an Android debug APK; manual runs are also enabled. Artifacts expire after 30 days.

Linux: unzip the artifact, verify `sha256sum -c SHA256SUMS`, extract the `.tar.gz`, then run `./mimic_mixamo` inside the extracted bundle. Keep `lib/` and `data/` alongside the executable. Baseline Ubuntu 22.04+ x86_64 with GTK3 runtime: `sudo apt-get install libgtk-3-0 libstdc++6`. Other distributions have not been validated.

Android: install the current debug APK. The home title must show **0.3.0**. Open **Open camera tracking**, grant Camera permission and stand in view to test the skeleton. Use **Switch front/back** if necessary. Open **Rig control proof** separately for the GLB; **Reload model** retries initialization and the status line exposes load failures. Physical phone acceptance remains pending. This is not a distribution-signed release.

## Develop

Install Flutter **3.35.7** and Python 3. For an Android build, first run `python3 tools/python/fetch_pose_model.py` to bundle the versioned model; runtime model downloads are not used. Then:

```sh
bash tools/bootstrap.sh
cd app
dart format lib test
flutter analyze
flutter test
flutter run -d linux
```

Linux build prerequisites: clang, cmake, ninja-build, pkg-config, libgtk-3-dev, libstdc++-12-dev. Android uses JDK 17 and the Android SDK. The bootstrap script generates missing platform scaffolding from the pinned SDK; custom native source will be committed before native integration.

## Rig control milestone (0.2)

Open **Rig control proof** from the preview. Android loads an original skinned block humanoid through Filament and exposes four independent shoulder/elbow sliders, a native bone demo and T-pose restore. Linux shows the same hierarchy as a 2D joint preview. The camera skeleton is available on its own Android screen; calibrated avatar retargeting is still pending. Actual Android skinning and lifecycle acceptance require a physical device; see [device checklist](docs/device_test_report.md).

The placeholder GLB is generated before every build using Python 3 (standard library only). It has 10 joints and no clips, demonstrating why pre-recorded clips are not required for live bone control. See [asset manifest](docs/asset_manifest.json). It is not a Mixamo character.

## Initial synthetic preview

Manual elbow slider, animated synthetic skeleton, start/pause/reset controls and lifecycle pause. This validates UI wiring only. Camera-to-avatar retargeting, owner Mixamo rig integration, calibration and smoothing are pending. Supply an approved rigged GLB (skin/joints/weights required; animation clips optional) for the next rendering gate.

The Linux preview provides interface testing while Android-only tracking is developed. Full desktop tracking is not currently promised.

## Camera and GLB fixes (0.3.0)

Android uses CameraX 1.3.4 and MediaPipe Tasks 0.10.14 with a bundled Pose Landmarker Lite model. Camera images and inference stay native. A single CameraX analysis worker uses keep-only-latest backpressure, at most 15 inference attempts/sec, and displays each processed frame together with its matching landmarks. Front preview mirroring is display-only. There is no recording or upload.

The GLB viewer now uses TextureView rather than SurfaceView inside Flutter, resolves the asset path through Flutter's asset API, checks binary framing before native parsing, and exposes reload/stage/error status. These are implementation fixes; a physical-device visual regression is still required.

Install `mimic-debug.apk` from the newest release; a previously downloaded APK does not update itself. If Android rejects an update because debug signing keys differ, uninstall the old debug build and install the new one. No user motion recordings exist to preserve.
