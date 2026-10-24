# Architecture at the rendering gate

- `app/lib/features/rig/`: rig control screen and development forward kinematics.
- `app/packages/mimic_native/`: local Android Flutter plugin. Its factory creates `mimic/rig` platform views; each owns `mimic/rig/<viewId>` command/status channel.
- `ModelViewer` from pinned Filament 1.56.0 owns the engine, GLB loader and skinning resources. All calls run on Android's main thread. A Choreographer callback computes procedural rotations natively; Dart sends user commands only.
- Surface detach stops callbacks and removes the SurfaceView so ModelViewer's detach handler destroys GPU resources. Reattach creates a fresh SurfaceView/viewer. Disposal is idempotent. This behavior requires device verification, particularly Flutter composition and surface recreation.
- `tools/python/generate_dev_rig.py`: reproducible original GLB generation; bootstrap generates the binary before asset bundling. No model download or runtime Python dependency.
- Linux remains a diagnostic joint hierarchy diagram. Android native plugin registration is omitted by Flutter on Linux.

No camera, pose inference, calibration or live retargeting exists yet. Follow M03 physical evidence gate before calling the rendering phase complete.


## 0.3.0 camera proof and loader recovery

CameraHost owns Activity permission/result hooks and foreground lifecycle. CameraSessionView owns one custom LifecycleRegistry, CameraX analysis use case and serial CPU inference executor. Stop/switch/dispose advance an epoch; old callbacks are rejected. Only that view's CameraX use case is unbound. The UI handoff is one AtomicReference plus at most one pending main-thread delivery, not a queue of frames.

CameraCanvas displays the exact upright bitmap used for inference and its corresponding landmarks under one fit-center transform. Preview mirror applies to image and overlay together, without mirroring the input given to MediaPipe. MPImage input is closed after synchronous detection, and a separate display bitmap prevents SDK recycling from invalidating the preview.

GLB rendering now uses ModelViewer(TextureView), not SurfaceView. Both renderers remain separate proof screens. No camera-to-rig mapping is claimed.
