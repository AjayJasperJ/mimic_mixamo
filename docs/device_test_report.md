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


## 0.3.0 user regression checklist (NOT RUN by agent)

- Confirm the app home title shows 0.3.0, so an older APK is not being tested.
- Open camera tracking. Grant permission. Camera image should appear with body landmarks when a person is visible.
- Deny permission, retry, then enable it in Android Settings; no crash or stuck permission loop.
- Switch front/back. Check preview mirroring and overlay remain aligned.
- Turn phone portrait/landscape, background/resume, leave and reopen 20 times. Camera indicator must turn off on Stop/back/background.
- Leave/re-enter frame: skeleton must disappear/recover without an old frozen overlay.
- Launch offline; bundled model must initialize.
- Open Rig control proof. Test visibility with TextureView; if blank, copy the displayed load-stage/error text. Reload model and restore pose; repeat 10 times.
- This release does not yet use landmarks to animate the GLB.
