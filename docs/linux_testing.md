# Linux 0.4.0 test build

Download **Mimic-x86_64.AppImage** from Releases. This is the whole application: Flutter, the Python tracking worker, libraries, pose model and GLB. No separate Python/MediaPipe install, extracted folder or server is needed.

```sh
chmod +x Mimic-x86_64.AppImage
./Mimic-x86_64.AppImage
```

Baseline: Linux x86_64, glibc 2.35+ (Ubuntu 22.04+), a working desktop session and webcam device permissions. Other distributions and ARM are not yet validated. If a host lacks FUSE support, the same single file can run with `./Mimic-x86_64.AppImage --appimage-extract-and-run`; this performs temporary extraction automatically rather than requiring installation.

1. Open camera tracking. Select a webcam and press Start camera. Multiple `/dev/video*` entries can belong to one webcam; metadata-only nodes cannot produce images, so select another entry if opening fails.
2. Stand in view. The preview and skeleton use the same captured frame. Toggle Mirror preview deliberately. Refresh webcams after connecting a USB camera.
3. Stop camera, leave the screen, or background the app. Verify the camera indicator turns off. Reopen and start explicitly.
4. Open Rig control proof. The bundled GLB is loaded and skinned in Dart; drag to rotate its mesh and move each shoulder/elbow independently. Restore T-pose. This CPU mesh renderer is scoped to the small development asset, not arbitrary textured GLB imports.
5. Disconnect/reconnect the webcam, deny device access, try an occupied camera, and repeat start/stop 20 times. Report the error message and distribution/kernel/camera model.

The camera skeleton does not yet drive the avatar. Calibration and retargeting remain future phases. No camera recordings are saved or uploaded.

CI validates the frozen worker with a blank synthetic image through the real bundled MediaPipe model, parses/skins the GLB with fixtures, and launches the packaged AppImage under Xvfb. A blank-image inference test is not a real webcam or pose-accuracy benchmark.

Diagnostics from the same AppImage:

```sh
./Mimic-x86_64.AppImage --tracker-list-devices
./Mimic-x86_64.AppImage --tracker-self-test
```

Development builds can set `MIMIC_TRACKER_EXECUTABLE` to a frozen helper built by tools/linux/build_appimage.sh. End users should use the AppImage. Build dependencies are pinned in tools/linux/requirements.txt; packaging tools have pinned versions and SHA-256 checks.
