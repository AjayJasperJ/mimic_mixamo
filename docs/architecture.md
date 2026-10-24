# Architecture at the rendering gate

- `app/lib/features/rig/`: rig control screen and development forward kinematics.
- `app/packages/mimic_native/`: local Android Flutter plugin. Its factory creates `mimic/rig` platform views; each owns `mimic/rig/<viewId>` command/status channel.
- `ModelViewer` from pinned Filament 1.56.0 owns the engine, GLB loader and skinning resources. All calls run on Android's main thread. A Choreographer callback computes procedural rotations natively; Dart sends user commands only.
- Surface detach stops callbacks and removes the SurfaceView so ModelViewer's detach handler destroys GPU resources. Reattach creates a fresh SurfaceView/viewer. Disposal is idempotent. This behavior requires device verification, particularly Flutter composition and surface recreation.
- `tools/python/generate_dev_rig.py`: reproducible original GLB generation; bootstrap generates the binary before asset bundling. No model download or runtime Python dependency.
- Linux remains a diagnostic joint hierarchy diagram. Android native plugin registration is omitted by Flutter on Linux.

No camera, pose inference, calibration or live retargeting exists yet. Follow M03 physical evidence gate before calling the rendering phase complete.
