# Development status — 2026-10-24 / 0.3.0

Current tasks: reported GLB loader failure (M03) and Android camera/skeleton proof (M04/M05).

Baseline test-build-8 compiled both platforms and passed five Flutter tests plus four Python asset checks. User has installed Android and reports no camera/skeleton and a broken GLB loader. Camera was absent from that build; its absence was not a permission/configuration issue.

Changes: Android camera permission/Activity lifecycle host, CameraX analysis, bundled MediaPipe Pose Landmarker Lite, native camera frame + matching skeleton Canvas, front/back switching, permission recovery and bounded newest-frame delivery. No camera recording/upload. Independent camera screen opens from home. Model is packaged at build time.

GLB corrections: TextureView composition, Flutter asset-path resolution, binary header validation, phase/error diagnostics, Reload model control and native library failure reporting. These are proposed fixes for the reported runtime failure; physical visual verification is NOT RUN.

Validation: Python asset checks locally PASS. Flutter/Android tools unavailable locally. CI must run Flutter analysis/tests, native GLB and overlay geometry unit tests, both builds, Linux smoke launch, and actual APK model/GLB/permission packaging verification. No device results are claimed.

M03 visual gate: IN_PROGRESS / user-reported failure pending retest.
M04/M05: IMPLEMENTED, CI and physical-device acceptance pending. Overlay alignment, permission deny/regrant, front/back, rotation, background/resume and offline launch still need phone tests.
M06–M14: TODO. Camera skeleton does not drive the avatar yet. Calibration/retargeting/full-body performance are not implemented.

Next: resolve CI failures; pin acquired model SHA-256; install the newest 0.3.0 APK, verify camera overlay and GLB separately, and record phone model and observed load-stage errors if rendering fails. Do not mark M03 complete until the phone shows the skinned character and passes neutral restore/reload cycles.
