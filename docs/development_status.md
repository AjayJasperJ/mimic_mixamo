# Development status — 0.4.0 / 24 October 2026

Current tasks: Linux webcam tracking and single-file AppImage distribution, explicitly requested by owner.

Prior Android baseline: 0.3.0 camera and GLB recovery build passed CI run 40070114705, including both builds, native contract tests and actual APK asset/permission checks. Physical Android GLB visual acceptance remains pending after the reported failure.

0.4.0 implementation:
- Linux V4L2 webcam discovery, local MediaPipe/OpenCV inference and matching preview/skeleton. Worker is packaged with Python and its dependencies; no runtime pip/model download.
- One-frame credit protocol over local stdio; UI epoch invalidation on restart. Stop/back/background sends stop and terminates a worker that does not exit, so no camera process should remain.
- Linux desktop loads the actual bundled skinned GLB, applies joint-local transforms and inverse bind matrices, and displays triangles with drag-to-rotate. This is scoped to the development asset and is not arbitrary GLB import support.
- CI builds Mimic-x86_64.AppImage, performs real blank-image model inference in the frozen worker and packaged AppImage, and smoke-launches the packaged GUI. Release assets now use the AppImage instead of the old tar archive.

Validation: no physical webcam or Flutter SDK in local agent environment. Standard-library worker device listing executed and found no webcams. Shell/YAML syntax checks and Python asset contracts run locally. New Dart, frozen inference and AppImage checks must pass CI before claiming build success. Blank-image inference is not webcam/accuracy acceptance.

M03: Linux GLB implementation added; Android visual gate remains pending phone retest.
M04/M05: Android implemented/compiled baseline; Linux implementation pending CI and physical webcam acceptance.
M06–M14: TODO. Camera skeleton does not drive the avatar yet. Calibration, full-body retargeting and performance targets are not verified.

Next: resolve CI failures, publish AppImage only after its packaged tracker and GUI checks pass, then execute docs/linux_testing.md with a real webcam. Preserve honest device-tested/untested labels.
