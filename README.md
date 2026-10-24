# Mimic

Flutter + native Android character motion tracking project. **Foundation preview, not a working motion capture app yet.** See [development plan](docs/development_plan.md) and [current status](docs/development_status.md).

## Download a test build

Download the newest tagged build from [Releases](https://github.com/AjayJasperJ/mimic_mixamo/releases). After both main-branch builds succeed, CI publishes a prerelease named `test-build-<run number>` with the Linux archive, debug APK and checksums. Only after publication, it deletes older automatic test releases and their tags. Manual/versioned releases are preserved. Failed builds leave the previous test release available.\n\nAlternatively, open [GitHub Actions](https://github.com/AjayJasperJ/mimic_mixamo/actions/workflows/build.yml), select the latest successful run, and download its artifact (GitHub sign-in required). Every push and pull request builds Linux x86_64 and an Android debug APK; manual runs are also enabled. Artifacts expire after 30 days.

Linux: unzip the artifact, verify `sha256sum -c SHA256SUMS`, extract the `.tar.gz`, then run `./mimic_mixamo` inside the extracted bundle. Keep `lib/` and `data/` alongside the executable. Baseline Ubuntu 22.04+ x86_64 with GTK3 runtime: `sudo apt-get install libgtk-3-0 libstdc++6`. Other distributions have not been validated.

Android: install the debug APK and open Rig control proof to test the Filament development humanoid. Camera tracking is not implemented. Visual skinning and lifecycle verification on a physical phone are pending. This is not a distribution-signed release.

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

## Rig control milestone (0.2)

Open **Rig control proof** from the preview. Android loads an original skinned block humanoid through Filament and exposes four independent shoulder/elbow sliders, a native bone demo and T-pose restore. Linux shows the same hierarchy as a 2D joint preview. Camera tracking is still pending. Actual Android skinning and lifecycle acceptance require a physical device; see [device checklist](docs/device_test_report.md).

The placeholder GLB is generated before every build using Python 3 (standard library only). It has 10 joints and no clips, demonstrating why pre-recorded clips are not required for live bone control. See [asset manifest](docs/asset_manifest.json). It is not a Mixamo character.

## Initial synthetic preview

Manual elbow slider, animated synthetic skeleton, start/pause/reset controls and lifecycle pause. This validates UI wiring only. Live camera tracking, Mixamo GLB skinning, calibration, smoothing and native session channels are pending. Supply an approved rigged GLB (skin/joints/weights required; animation clips optional) for the next rendering gate.

The Linux preview provides interface testing while Android-only tracking is developed. Full desktop tracking is not currently promised.
