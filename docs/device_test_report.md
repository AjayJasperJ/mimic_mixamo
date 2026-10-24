# Device test report

CI baseline: run 40067758051 (commit 05bfbd03) passed Linux analysis/tests/build/launch and Android APK compilation. This is build evidence only.

Physical Android phone: not available in the agent environment. These gates are NOT RUN:

- Install APK and open Rig control proof; confirm actual GLB is visible.
- Move all four controls independently; correct limb follows with no corrupt mesh.
- Restore T-pose after every movement; rest pose must match initial load.
- Run bone demo, background/resume, navigate back, reopen 10 times.
- Confirm a new renderer is created after surface recreation; no black surface or crash.
- Check no persistent GPU/memory growth across repeated open/close cycles.
- Repeat launch in airplane mode. No camera should be requested at this phase.

Linux CI launch and Python/Dart checks cannot substitute for these tests. Provide phone model, Android version and observed results when executing.
