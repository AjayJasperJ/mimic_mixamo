# Mimic

Flutter + native Android character motion tracking project. **Foundation preview, not a working motion capture app yet.** See [development plan](docs/development_plan.md) and [current status](docs/development_status.md).

## Download a test build

Open [GitHub Actions](https://github.com/AjayJasperJ/mimic_mixamo/actions/workflows/build.yml), select the latest successful run, and download its artifact (GitHub sign-in required). Every push and pull request builds Linux x86_64 and an Android debug APK; manual runs are also enabled. Artifacts expire after 30 days.

Linux: unzip the artifact, verify `sha256sum -c SHA256SUMS`, extract the `.tar.gz`, then run `./mimic_mixamo` inside the extracted bundle. Keep `lib/` and `data/` alongside the executable. Baseline Ubuntu 22.04+ x86_64 with GTK3 runtime: `sudo apt-get install libgtk-3-0 libstdc++6`. Other distributions have not been validated.

Android: install the debug APK for UI testing only. No camera or 3D rig support is included in this milestone. This is not a distribution-signed release.

## Develop

Install Flutter **3.35.7**, then:

```sh
bash tools/bootstrap.sh
cd app
dart format lib test
flutter analyze
flutter test
flutter run -d linux
```

Linux build prerequisites: clang, cmake, ninja-build, pkg-config, libgtk-3-dev, libstdc++-12-dev. Android uses JDK 17 and the Android SDK. The bootstrap script generates missing platform scaffolding from the pinned SDK; custom native source will be committed before native integration.

## Current preview

Manual elbow slider, animated synthetic skeleton, start/pause/reset controls and lifecycle pause. This validates UI wiring only. Live camera tracking, Mixamo GLB skinning, calibration, smoothing and native session channels are pending. Supply an approved rigged GLB (skin/joints/weights required; animation clips optional) for the next rendering gate.

The Linux preview provides interface testing while Android-only tracking is developed. Full desktop tracking is not currently promised.
