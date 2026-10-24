# Development status — 2026-10-24

Current task: M02/M03 development rig and native skinning proof implementation.

M00: local Java 17 and git present. Flutter/Dart, Android SDK, adb, GPU and physical device unavailable locally. CI provides Flutter 3.35.7 and Android build tools.
M01: previous commit 9449339 passed Linux analysis/tests/build/smoke launch and Android debug APK build. Installation on target phone remains NOT RUN.
M02: original development humanoid generated reproducibly with 10 joints, one skin, inverse bind matrices, 156 triangles and no clips. Asset manifest and rig conventions recorded. This is a placeholder, not an owner-approved Mixamo rig.
M03: Android Filament 1.56.0 platform view and direct local shoulder/elbow control implemented; skin matrices updated explicitly. T-pose restore, procedural demo, per-view channel and detach/background handling added. Linux hierarchy preview has independent joint controls. CI run 40067758051 passed Linux build/smoke launch and Android debug APK compilation for commit 05bfbd03. Physical device acceptance remains NOT RUN.

Local validation: four Python asset contract tests PASS (weights/indices, bind hierarchy, geometry bounds, deterministic skin). Bootstrap Bash syntax PASS. Flutter checks NOT RUN locally. CI run 40067758051 passed analysis and four Flutter tests (three joint math tests plus existing session regression), Linux compilation/launch and Android compilation. Follow-up adds a Linux rig-control widget test, CI-generated pubspec.lock and corrects the diagram projection to +X right; CI revalidates these changes.

M03 exit gate remains IN_PROGRESS, not VERIFIED: actual skinning, mesh appearance and 10 load/unload cycles need a physical Android test. Do not begin tracked pose mapping before resolving rendering failures.
M04–M14: TODO. Camera, MediaPipe, calibration, live retargeting, full-body motion and measured performance are not implemented.

Next exact action: use the latest successful test release; install APK, open Rig control proof and execute docs/device_test_report.md. Inspect subsequent CI for the follow-up widget test. Replace development asset with an approved rig only after inspection/mapping. Physical target phone details still needed.
