# Linux 0.5.0 test build

Download **Mimic-x86_64.AppImage** from Releases. This is the whole application: Flutter, the Python tracking worker, libraries, pose and hand models, and GLB. No separate Python/MediaPipe install, extracted folder or server is needed.

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

After calibrating, the camera pose and hand landmarks drive the skinned development avatar. Finger tracking works when a hand is visible to the camera; it may degrade when hands are small, turned away or occluded. The included hand model is experimental and physical camera validation is still required. No camera recordings are saved or uploaded.

CI validates the frozen worker with a blank synthetic image through the real bundled MediaPipe model, parses/skins the GLB with fixtures, and launches the packaged AppImage under Xvfb. A blank-image inference test is not a real webcam or pose-accuracy benchmark.

Diagnostics from the same AppImage:

```sh
./Mimic-x86_64.AppImage --tracker-list-devices
./Mimic-x86_64.AppImage --tracker-self-test
```

In `flutter run -d linux` debug mode, the app falls back to `tools/linux/mimic_tracker.py` to enumerate `/dev/video*` devices. Starting inference also needs the pinned Python dependencies and both fetched task files; run `python3 tools/python/fetch_pose_model.py` and `python3 tools/python/fetch_hand_model.py`, then install `tools/linux/requirements.txt` in the development Python 3.10 environment. A frozen helper can instead be selected with `MIMIC_TRACKER_EXECUTABLE`. This source fallback is debug-only; end users should use the AppImage, which bundles Python, dependencies and both models. Packaging tools have pinned versions and SHA-256 checks.

### iPhone as a live camera with Iriun Webcam

Install the [Iriun Webcam Linux client](https://www.iriun.com/) on the computer and Iriun Webcam from the iPhone App Store. Open the desktop client and phone app, connect them using Iriun's pairing instructions, and wait for its virtual webcam to appear. In Mimic, press Refresh webcams and select **iPhone via Iriun Webcam**. If more than one Iriun `/dev/video*` entry appears, try each capture entry; then press Start camera and calibrate. The tracker reads the local Linux video device through OpenCV/V4L2; it does not ingest an iPhone network stream directly. Keep the Iriun client open while tracking. This path is implemented but still needs physical iPhone/Iriun validation on the target Linux machine.

## 0.5.0 live retargeting

Show shoulders, elbows, wrists and hips, start Upper body, then Calibrate T-pose. Hold still until progress completes (at least 1.5 seconds and 15 valid frames). Bent/occluded arms and small framing must prevent calibration. Verify the left/right arms independently, hand pose and finger curl where the hands are visible, torso lean and neutral return.

Change smoothing and compare jitter/delay. Preview mirror must not change avatar mapping; Mirror avatar deliberately swaps movement sides and requires recalibration. Switching camera/body mode must invalidate the old calibration. Hide a wrist or leave frame: hold briefly, blend to neutral and recover smoothly; do not silently freeze forever.

For Full body • beta, show knees/ankles and stand upright during calibration. Verify crouching bends joints and changes only display height, never character scale; stepping should lift the correct leg. Approximate foot contact may slide/pitch because the development rig has no independent ankle bones. Root X/Z remain anchored. No accurate walking-through-room claim is made.

Use labelled Replay test poses for a reproducible no-camera demonstration. It follows the same calibration, solve, filtering and actual GLB skinning path. Copy diagnostics exports source mode and software counters only, not camera images or landmarks.

Run 20 start/stop/background cycles and 10/30-minute real sessions before calling these gates accepted. Record distribution/hardware, build tag, observed defects and timing method. Android builds remain disabled until Linux acceptance and owner direction.
