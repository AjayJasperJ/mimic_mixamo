# Performance evidence — 0.5.0

No physical-device performance results are claimed.

CI runs 300 synthetic frames through full-body solve and actual GLB skinning. The test prints `MIMIC_SYNTHETIC_CPU` with sample count, median and p95 CPU microseconds. This excludes camera acquisition, MediaPipe inference, JPEG transfer/decode, Flutter raster, display and thermal behavior. It is not an FPS, accuracy or motion-to-photon benchmark. It has no arbitrary hardware-dependent time assertion; it verifies finite transforms and bounded root movement throughout.

In-app diagnostics measure processed input frame rate, MediaPipe inference time reported by the worker, and Dart solver time. Smoothed pose ticks target updates but are not labelled as measured render FPS. Diagnostic copies include source mode so synthetic replay cannot be mistaken for webcam evidence, and contain no images/landmarks.

Pending physical protocol: record distribution/kernel, CPU/GPU/RAM, webcam/resolution, build tag and mode. Run still pose, left/right arm lifts, hands forward, torso lean, crouch/step and occlusion. Measure actual render frame timings, capture-to-consumption clock conventions, external visible delay and idle angular jitter separately. Run 20 camera start/stop cycles and 10/30-minute sessions, then inspect memory, camera release and thermal behavior. Compare results against the development plan and report missed targets; do not infer accuracy from confidence.
