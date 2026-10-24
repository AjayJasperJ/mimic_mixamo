# Decisions

- 2026-10-24: Flutter 3.35.7 pinned for reproducible scaffold generation; not a claim that it is the latest SDK.
- Linux initially supports UI and synthetic pose playback only. CameraX and Android Filament code cannot run unchanged on Linux. Desktop camera/3D tracking is separate future work.
- CI bootstraps absent platform runners from the pinned Flutter template. Custom native runners must be committed when native work begins. App code and pubspec already exist, so flutter create does not replace them.
- Linux packaging includes the whole Flutter bundle, not just the executable. Ubuntu 22.04 x86_64 is the initial CI baseline; other distributions require testing.
- No approved character or tracking model is included. No third-party model distribution rights are assumed.

- Rendering work lives in a committed local Flutter Android plugin, rather than generated app runners. The pinned runner template remains reproducible and does not overwrite custom native implementation.
- A generated original CC0 block humanoid unblocks development while waiting for the owner asset. Its simple identity bind axes are not assumed to hold for Mixamo.
- Filament 1.56.0 Android ModelViewer/FilamentAsset/Animator APIs checked against exact tagged source. Direct TransformManager writes precede updateBoneMatrices; clip playback is disabled.

- app/pubspec.lock recovered directly from the successful CI dependency resolution and committed with all hosted package checksums; no hand-invented dependency hashes.

- 0.3.0: User confirmed that the Android build had no camera and reported the GLB loader was not fixed. Camera was previously unimplemented, not a device configuration issue. Add independent M04/M05 camera proof while M03 visual acceptance remains open.
- GLB composition fix: use Filament's supported TextureView constructor, keep native library initialization scoped to the rig, resolve Flutter asset paths through FlutterAssets, validate GLB framing and provide reload/error stages. Root cause on the user's device is not proven until retested.
- Camera proof uses MediaPipe VIDEO mode on a dedicated synchronous analysis worker, rather than LIVE_STREAM callbacks. CameraX KEEP_ONLY_LATEST and bounded UI handoff avoid inference backlog and simplify image ownership. No camera data crosses Dart.
- MPImage.close() in MediaPipe 0.10.14 recycles its Bitmap. The displayed native camera frame therefore owns a separate copy; its matching landmarks use the same upright image coordinates. Display mirroring does not change anatomical landmark identities.
- The model is acquired at build time from Google's versioned float16/1 endpoint and bundled in the APK with its SHA-256 manifest. CI checks packaging and runtime code does not fetch models. Pin the observed checksum after first acquisition.
