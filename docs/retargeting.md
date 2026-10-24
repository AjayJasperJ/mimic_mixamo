# Linux retargeting — 0.5.0

This implementation targets the original `mimic-block-humanoid-v1` rig. It does not import arbitrary rigs or establish motion-capture accuracy.

## Coordinate and frame contract

Python worker protocol v2 sends a UUID session ID, increasing sequence number, monotonic capture timestamp in microseconds, normalized image landmarks and separate hip-centred world landmarks. Nullable visibility/presence remain nullable. Solver coordinates are `(x, -y, -z)`: a proper 180-degree X rotation with +Y up and +Z toward the character's front. Image coordinates are used for framing/overlay only; world coordinates are used for rotations.

Preview mirroring changes only the displayed image/overlay. Mirror-avatar mode instead reflects world X and exchanges anatomical left/right indices before reconstructing a right-handed basis; it is not treated as a quaternion reflection. Changing avatar mirroring, body mode, camera or session invalidates calibration.

MediaPipe capture timestamps are used only for ordering. Source and Dart clocks are not subtracted. Confidence fallback and filtering use elapsed Dart monotonic receipt time. Old session IDs, duplicate/out-of-order sequence numbers and timestamps are rejected. Invalid/nonfinite/degenerate geometry is never passed to the mesh.

## Calibration

Start a camera or the clearly labelled replay, then select Calibrate T-pose. Show shoulders, elbows, wrists and hips; full-body beta additionally requires knees and ankles. Hold straight horizontal arms, and straight legs in full-body mode. Calibration requires at least 15 valid samples over 1.5 seconds. Small image framing, bent arms, low confidence, coincident landmarks and unstable positions reset progress with guidance.

A mean orthonormal torso basis establishes the neutral reference. Per-bone neutral orientation corrections align this specific rig to that reference. Successful calibration clears old filters. Thresholds are initial tuning values and require real-device evaluation.

## Rotation solve

The pelvis follows hip yaw; the chest follows the shoulder/hip torso frame. Limb directions use world-space endpoint pairs. Direction-only minimal-swing rotations preserve a neutral twist; they do not recover exact axial twist. Desired global rotations include the neutral correction, then parent-local rotations are computed as `inverse(parentGlobal) * desiredGlobal`.

Translations and scales remain at bind values. The renderer multiplies each rest-local transform by the normalized tracked quaternion, computes joint world transforms and applies inverse bind matrices. There is no animation clip competing with these writes. Elbow and knee bends are bounded before solving the local chain.

Filtering uses shortest-path quaternion slerp and elapsed-time exponential smoothing. Sign-equivalent q/-q does not create a long rotation. Low-confidence chains hold for 200 ms, then blend toward neutral over 500 ms. Sustained body loss is labelled after one second; recovery is filtered. A periodic pose tick applies fallback even when inference stops delivering frames.

## Full-body beta

Legs use hip/knee/ankle directions and local thigh/shin rotations. Root X/Z and character scale stay fixed. A vertical-only display offset estimates ground contact from the original rig's foot-box bounds after posing; it is clamped to [-0.55, +0.15] metres and filtered. This lets crouches lower the character without shrinking the mesh.

This is approximate grounding, not constrained foot IK, accurate room movement, jumping estimation or reliable foot locking. The placeholder has no ankle bones: feet inherit shin orientation, so toe/heel pitch and sliding can be wrong. Do not claim full-body release acceptance until physical squat/step/occlusion tests pass. Generalized foot-contact IK and an approved production rig remain future work.

## Evidence and limitations

Unit tests cover calibration rejection, neutral restore, quaternion sign/antiparallel cases, parent/local composition, independent arms through actual GLB skinning, anatomical mirroring, torso lean, confidence fallback, stale sessions, grounded crouching and synthetic long-run finiteness. A labelled replay mode exercises the UI and asset path without opening a camera. CI's AppImage replay smoke requires completed calibration, ten valid bones and a loaded mesh. These are synthetic software checks, not webcam or accuracy evidence.

Diagnostics report processed input frames/s, model inference time, solver CPU time, valid bones and rejected frames. They exclude sensor, image decode, display and motion-to-photon latency. Copy diagnostics exports no image or landmark payload.
