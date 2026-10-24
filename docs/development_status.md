# Development status — Linux 0.5.0 / 24 October 2026

Owner instruction: continue the proposed development steps on Linux and disable Android runners until Linux is validated. Android job is explicitly skipped; release depends on Linux only and publishes no APK. Android implementation remains in source, not automatically re-enabled by a passing Linux job.

Prior evidence: test-build-14 passed eight Flutter tests, frozen and packaged real-model inference on a blank fixture, Linux AppImage GUI launch, Android compile and release publication. Those checks did not establish physical webcam behavior.

0.5.0 implementation:
- M06: typed world/image frame protocol, monotonic ordering/session rejection, one coordinate adapter, central mapping for the original rig.
- M07/M08: stable T-pose calibration, independent shoulder/elbow rotations, chest/hip orientation, normalized parent-local quaternions, shortest-path time-based smoothing, confidence hold/fallback and filtered recovery.
- Combined Linux camera and actual skinned GLB view. Preview mirroring and avatar mirroring are separate. Changing camera/body mode/mirroring resets calibration.
- Clearly labelled synthetic replay can calibrate and drive the model without opening a webcam. AppImage replay smoke tests the packaged UI/solver/mesh path.
- M10 experimental: thigh/shin tracking, bounded bends and vertical-only approximate grounding without mesh scaling. No precise foot IK or room-scale travel.
- Diagnostics and synthetic CPU profiling; no camera images or landmarks exported by diagnostic copy.

Validation: Python asset contracts and shell/YAML checks available locally. Flutter/Android tooling and physical camera are unavailable in the agent environment. New unit/integration tests and AppImage replay/model/GUI checks must pass CI. Physical camera, subjective alignment, thermal, memory, motion delay and 10/30-minute acceptance remain NOT RUN.

M09/M10 exit gates are not VERIFIED merely because the solver is implemented or synthetic tests pass. User explicitly authorized continued implementation while physical checks remain open. General foot-contact IK, production rig approval, broader Linux compatibility and physical performance acceptance remain future work. Android port/re-enable waits for Linux acceptance and owner direction.

Next: resolve software CI failures, publish a Linux-only AppImage after all software checks, then use docs/linux_testing.md and docs/retargeting.md for a real webcam validation session. Record failures honestly and keep the previous successful release if a build fails.
