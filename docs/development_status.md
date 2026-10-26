# Direct Mixamo tracking update — 26 October 2026

Owner-requested implementation removes mandatory Linux T-pose calibration. The solver starts on a usable torso frame and tracks bent arms immediately; optional manual neutral reset remains available. Mixamo rendering now accounts for bind-world axes, actual parent hierarchy, duplicated chest aliases and prefixed finger names. Synthetic tests added for direct startup, partial confidence, rotated imported arm axes and intermediate spine/shoulder nodes. Replay smoke now exercises direct startup.

Local validation: Dart formatter completed; Python asset/worker tests 7/7 passed. Flutter analyze/test require the pinned Flutter tool dependencies; local SDK bootstrap could not complete its dependency fetch. CI run 40373601503 passed Flutter analysis, all 41 Flutter tests and the Linux release build for code commit 9e0699bc546cad48faffd9967a5d763d4db4755f. AppImage packaging/smoke checks are still pending. Physical webcam, imported Mixamo alignment and physical acceptance gates remain NOT RUN for this change. Android remains paused. No release is claimed from these edits.

---

# Development status — Linux 0.5.0 / 24 October 2026

Owner instruction: continue the proposed development steps on Linux and disable Android runners until Linux is validated. Android job is explicitly skipped; release depends on Linux only and publishes no APK. Android implementation remains in source, not automatically re-enabled by a passing Linux job.

Prior evidence: test-build-14 passed eight Flutter tests, frozen and packaged real-model inference on a blank fixture, Linux AppImage GUI launch, Android compile and release publication. Those checks did not establish physical webcam behavior.

0.5.0 implementation:
- M06: typed world/image frame protocol, monotonic ordering/session rejection, one coordinate adapter, central mapping for the original rig.
- M07/M08: stable T-pose calibration, independent shoulder/elbow rotations, chest/hip orientation, normalized parent-local quaternions, shortest-path time-based smoothing, confidence hold/fallback and filtered recovery.
- Combined Linux camera and actual skinned GLB view. Preview mirroring and avatar mirroring are separate. Changing camera/body mode/mirroring resets calibration.
- Clearly labelled synthetic replay can calibrate and drive the model without opening a webcam. AppImage replay smoke tests the packaged UI/solver/mesh path.
- M10 experimental: thigh/shin tracking, bounded bends and vertical-only approximate grounding without mesh scaling. No precise foot IK or room-scale travel.
- Linux hand tracking extension: checksum-pinned MediaPipe Hand Landmarker, schema v3 hand landmarks, and palm plus 30 finger joints on the generated development rig. Synthetic replay exercises finger skinning. This is software-path coverage only; physical webcam hand visibility, latency and articulation remain NOT RUN. Imported-rig hand remapping is not yet verified.
- Linux custom-character preview/import extension: user-selected skinned GLB/FBX files or ZIP bundles with one model and relative-path textures are loaded into the same weighted-mesh preview and camera avatar; FBX files are converted by the AppImage-bundled Assimp executable. Mixamo bone-name aliases feed the existing retargeter. The loader normalizes partial weights, keeps the strongest four influences and draws embedded base-color textures in the Linux preview. The supplied Sketchfab ZIP converted, parsed (8,053 vertices, 42 joints), decoded its texture and produced textured raster pixels in a software test. This does not establish camera-driven pose alignment. Per-rig rest-pose calibration, multiple skins, and broader FBX compatibility remain unverified. The generated development rig remains the tested reference.
- Linux iPhone webcam source: Iriun-named V4L2 devices are identified in the camera picker, show an iPhone-specific live status, and use an OpenCV backend fallback if direct V4L2 opening fails. Setup instructions require the Iriun Linux desktop client plus the iPhone app. Worker unit tests verify device identification and backend fallback. Physical iPhone-to-Iriun-to-Mimic streaming is NOT RUN; Iriun is not bundled and the app does not connect to Iriun over the network directly.
- Calibration responsiveness fix: root cause in software was that every single invalid/low-confidence frame reset all accumulated T-pose samples and elapsed time. Real camera detections can intermittently miss a joint, so progress could repeatedly fall back to zero. Calibration now keeps valid samples through dropouts of up to 700 ms, requires 10 good frames across at least 1.2 seconds, and reports both progress/frame count and the latest rejection reason. Regression test covers brief low-confidence frames. This does not establish physical-camera calibration success; verify with the Iriun/iPhone source and record that device result separately.
- Diagnostics and synthetic CPU profiling; no camera images or landmarks exported by diagnostic copy.

Validation for the prior finger tracking work: Python asset/hand-association tests 5/5 passed; `dart format`, `flutter analyze` and `flutter test` passed (30 tests). Python syntax, shell syntax and `git diff --check` passed. Frozen worker/AppImage model self-test, GUI launch and synthetic replay smoke passed in [GitHub Actions run 40118826113](https://github.com/AjayJasperJ/mimic_mixamo/actions/runs/40118826113). Those synthetic checks do not validate physical camera hand visibility or articulation. Physical camera, subjective alignment, thermal, memory, motion delay and 10/30-minute acceptance remain NOT RUN.

Custom character import awaits CI and visual review of the supplied Sketchfab character. No physical webcam or arbitrary imported-rig behavior is claimed as verified.

M09/M10 exit gates are not VERIFIED merely because the solver is implemented or synthetic tests pass. User explicitly authorized continued implementation while physical checks remain open. General foot-contact IK, production rig approval, broader Linux compatibility and physical performance acceptance remain future work. Android port/re-enable waits for Linux acceptance and owner direction.

Next: resolve software CI failures, publish a Linux-only AppImage after all software checks, then use docs/linux_testing.md and docs/retargeting.md for a real webcam validation session. Record failures honestly and keep the previous successful release if a build fails.
