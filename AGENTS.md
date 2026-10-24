Read docs/development_plan.md, docs/development_status.md and docs/decisions.md before changes.
Follow the ordered M00–M14 gates. Preserve honest tested/untested labels.
Do not claim synthetic drawing proves skinning or pose tracking.
Keep frames and per-frame joint updates native on Android.
Never commit camera footage, credentials or signing keys.
Use Flutter 3.35.7. CI generates platform scaffolding using tools/bootstrap.sh;
custom Android code lives in the committed local plugin app/packages/mimic_native/. Do not place custom code in uncommitted generated runners.
Run dart format, flutter analyze and flutter test for Dart changes.

The app Gradle config app/android/app/build.gradle.kts is committed to keep bundled MediaPipe task files uncompressed. Bootstrap fills missing runner files without replacing this config.
