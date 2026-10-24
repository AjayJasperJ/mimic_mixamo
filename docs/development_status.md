# Development status — 2026-10-24

Current task: M00/M01 foundation and Linux CI preview.

Implemented: Flutter session UI, synthetic skeleton with manual bend and animation, pause/reset, background pause, widget regression check, Linux and Android build workflow.

Environment: git and Java available; Flutter/Dart, Android SDK and physical device unavailable locally. Local Flutter formatting/analysis/tests/builds NOT RUN. CI is the execution environment and must pass before claiming build success.

PENDING: verify first CI result and download artifact. M01 installation on target phone is NOT RUN.
BLOCKED: M02/M03 need an approved rigged GLB; actual renderer and direct skinned bone proof not implemented. Synthetic painter is not that proof.
M04–M14: TODO. Camera tracking, calibration, retargeting, full body and device benchmarks are unimplemented.

Next: verify CI, commit platform runners with initial native integration, inspect approved GLB and prove direct elbow control. Target Android phone details and physical testing remain required.
