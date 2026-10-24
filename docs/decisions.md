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
