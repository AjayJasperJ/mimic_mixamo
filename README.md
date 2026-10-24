# Mimic

**Linux 0.5.0 development build:** webcam landmarks can now drive the bundled skinned character after T-pose calibration. Upper-body tracking, smoothing and loss recovery are implemented; full-body tracking/grounding is experimental. Physical webcam accuracy and performance acceptance remain pending.

**Android runners are paused at the owner's request.** Current automatic releases are Linux-only. Android source is preserved, and re-enabling/porting waits for Linux validation and owner direction.

## Download and run

Download **Mimic-x86_64.AppImage** from [Releases](https://github.com/AjayJasperJ/mimic_mixamo/releases). It contains Flutter, Python, tracking libraries, the pose model and GLB—no Python installation or sidecar folder is required.

```sh
chmod +x Mimic-x86_64.AppImage
./Mimic-x86_64.AppImage
```

Initial baseline: Ubuntu 22.04+ x86_64 (glibc 2.35+). Other distributions/hardware remain unvalidated. Without FUSE, the same file supports `--appimage-extract-and-run` for automatic temporary extraction.

## Live character tracking

1. Open camera tracking, select a webcam and Start camera.
2. Choose Upper body first. Show shoulders, elbows, wrists and hips. Hold straight horizontal arms and press Calibrate T-pose until progress completes.
3. Move: the GLB follows your arms and torso in the same view. Adjust Smoothing; lower values reduce filtering delay.
4. Mirror preview changes only the displayed camera. Mirror avatar changes anatomical movement mapping and requires recalibration.
5. Full body • beta additionally needs knees/ankles visible and upright legs during calibration. Root X/Z stay anchored; crouches lower the character without scaling it. Grounding is approximate, with no guaranteed foot locking.
6. Stop/back/background stops capture and invalidates calibration.

No webcam? Select **Replay test poses**, then Calibrate T-pose. A persistent REPLAY banner identifies synthetic input; no camera is open and no accuracy is demonstrated. After calibration the replay exercises arms, torso and (in full-body mode) crouching.

[Retargeting conventions and limitations](docs/retargeting.md) · [Linux test checklist](docs/linux_testing.md) · [Development status](docs/development_status.md) · [Performance evidence](docs/performance_report.md).

## CI and releases

Every push/PR runs Linux tests and AppImage packaging. Main publishes a tagged Linux-only test release after successful unit, real-model blank-image, packaged GUI and synthetic replay checks. It deletes old automatic test releases/tags only after publishing the replacement. Manual releases are preserved; failures leave the previous download available. Android's job has a literal false condition and receives no runner.

## Develop

Flutter **3.35.7** and Python 3 are used for development:

```sh
bash tools/bootstrap.sh
cd app
dart format lib test
flutter analyze
flutter test
flutter run -d linux
```

For a complete AppImage, build Flutter Linux, install `tools/linux/requirements.txt` in a Python 3.10 environment and run `bash tools/linux/build_appimage.sh`. All runtime tracking dependencies are bundled. AppImage diagnostics:

```sh
./Mimic-x86_64.AppImage --tracker-list-devices
./Mimic-x86_64.AppImage --tracker-self-test
./Mimic-x86_64.AppImage --smoke-replay
```

The last command is explicitly synthetic replay, not a camera benchmark. Manual Rig control proof remains available for checking joint/skinning behavior independently.

The original CC0 development humanoid has 10 joints, one skin and 156 triangles. It is not the owner's Mixamo character. This prototype is scoped to that small untextured rig; arbitrary GLB import, exact twist, hand/face animation, professional motion capture, precise room movement and production performance claims are not included.
