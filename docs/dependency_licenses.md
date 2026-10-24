# Dependency and asset register

| Component | Pinned version | Source | License / status |
| --- | --- | --- | --- |
| Flutter and Dart SDK | Flutter 3.35.7 | https://github.com/flutter/flutter/tree/3.35.7 | BSD-3-Clause; Flutter generated notices apply |
| filament-android | 1.56.0 | https://github.com/google/filament/tree/v1.56.0 | Apache-2.0; license bundled in app/assets/notices |
| gltfio-android | 1.56.0 | Same Filament tag | Apache-2.0 |
| filament-utils-android | 1.56.0 | Same Filament tag | Apache-2.0; use library, no copied implementation source |
| Original block humanoid | mimic-block-humanoid-v1 | tools/python/generate_dev_rig.py | Original generated development asset dedicated under CC0-1.0; not Mixamo |
| MediaPipe model/code | Not acquired | Pending phase 2 | No weights or tracker shipped |
| Owner Mixamo rig | Not supplied | Pending | Must verify source and redistribution rights before adding |

Generated development model geometry and rig may be reused under CC0-1.0 (https://creativecommons.org/publicdomain/zero/1.0/). This statement applies to the generated placeholder asset, not an unseen owner asset or the entire application.

Transitive native dependency notices and final distribution audit remain pending before a production release. The current APK is a development test build.


0.3.0 additions: CameraX camera-core/camera-camera2/camera-lifecycle **1.3.4**, AndroidX lifecycle-runtime-ktx **2.7.0** (Apache-2.0), MediaPipe Tasks Vision **0.10.14** (Apache-2.0 code), and Google's versioned Pose Landmarker Lite **float16/1** bundle. Model source and actual checksum are embedded as pose_model_manifest.json in the APK. The model bundle is distinct from the code license; retain upstream terms and complete the model redistribution audit before a production release. No claim that every model inherits the SDK code license is made.

Linux 0.4.0 adds pinned Python MediaPipe/OpenCV/NumPy/Matplotlib and their dependencies (tools/linux/requirements.txt), with PyInstaller 6.10.0 for build-time freezing. Installed dependency license/notice files and the resolved Python environment are copied into the image. PyInstaller's bootloader distribution exception is applicable to bundled applications; preserve its notices. The original generated GLB and existing pose model are unchanged. linuxdeploy and appimagetool are build tools, checksum-pinned in the packaging script. Flutter's generated notices remain in its asset bundle. Hardware-driver and model redistribution review is still required before a production claim.

Linux 0.5.0 adds Google's versioned Hand Landmarker float16/1 task bundle (SHA-256 is recorded by `tools/python/fetch_hand_model.py`) for development-time and AppImage use. The model is a separate asset from the MediaPipe Python package; preserve upstream terms and complete redistribution review before production use. Android remains paused and does not bundle or run this model.
