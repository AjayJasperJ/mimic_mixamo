# Development rig coordinates

Right-handed space, metres, +Y up, +Z toward the character's front. +X is the character's anatomical left. The viewer looks toward the front: anatomical left appears on the viewer's right.

The development asset has identity rest rotations and scales. Root Hips is at (0, .9, 0); Chest is at local (0, .35, 0); shoulder local translations are (+/-.20, .20, 0), elbows (+/-.40, 0, 0). Bone controls rotate about local +Z in degrees. These diagnostic controls are not anatomical joint-limit estimates or a retargeting solver.

Native transforms use column-major matrices and parent-first active composition: local = restLocal * rotateZ(angle). Rest translations and scales are preserved. Filament Animator.updateBoneMatrices() runs after direct local transform writes and before render(); no animation clip runs. Neutral restore writes every saved rest-local transform (zero diagnostic angle), rather than resetting skin matrices to identity.

The Linux diagram projects the same parent/child hierarchy into 2D. It verifies forward kinematics only. MediaPipe adapters, mirror policy and calibrated Mixamo bind-axis corrections remain TODO and must not inherit these simplified asset assumptions silently.

0.5.0 live solver details are centralized in docs/retargeting.md. Tracked quaternion maps override manual Z-angle controls per joint; world = parentWorld * (restLocal * trackedLocalRotation). The original Hips translation receives only the explicit bounded vertical grounding offset, and no scale changes. Source world-to-solver rotation is (x,-y,-z); frame session/sequence/time checks precede the solve.
