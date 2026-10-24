Read docs/development_plan.md, docs/development_status.md and docs/decisions.md before changes.
Follow the ordered M00–M14 gates. Preserve honest tested/untested labels.
Do not claim synthetic drawing proves skinning or pose tracking.
Keep frames and per-frame joint updates native on Android.
Never commit camera footage, credentials or signing keys.
Use Flutter 3.35.7. CI generates platform scaffolding using tools/bootstrap.sh;
custom Android code lives in the committed local plugin app/packages/mimic_native/. Do not place custom code in uncommitted generated runners.
Run dart format, flutter analyze and flutter test for Dart changes.

The app Gradle config app/android/app/build.gradle.kts is committed to keep bundled MediaPipe task files uncompressed. Bootstrap fills missing runner files without replacing this config.

Linux 0.4.0 is explicitly in scope: bundled webcam tracking helper under tools/linux/ and AppImage packaging. Do not require end-user Python installation or a sidecar directory. Linux frames may cross Dart via the bounded local worker protocol; Android frames remain native. Run AppImage's frozen/packaged self-test and GUI smoke check before publishing it. No physical webcam results may be inferred from synthetic CI tests.
