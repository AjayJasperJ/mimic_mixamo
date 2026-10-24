# AppImage packaging experiments — 0.4.0

Two distinct first-packaging failures are recorded rather than changing the tracking dependency stack without evidence.

1. Run 40106210791: `pyinstaller --specpath build/appimage --add-data app/.../model:.` resolves the data path relative to the spec directory and cannot find it. Minimal reproduction is that command with a relative data source. Corrected to an absolute source path. The subsequent freeze completed and its own real blank-image model inference passed.
2. Run 40106564693: the frozen helper passed model inference, but `linuxdeploy --appdir AppDir` walked the helper under usr/lib and failed resolving `libGLdispatch-dcc1ca97.so.0.0.0` within MediaPipe's private dependency tree. This isolates the failure to repackaging, not the model or initial freeze. Hypothesis: linuxdeploy's normal shared-library scan/deployment does not preserve PyInstaller's nested hashed dependency layout.

Bounded next experiment: run linuxdeploy on the Flutter-only AppDir, then copy the already-tested frozen helper unchanged into usr/lib/mimic-tracker. Build the AppImage and require its own `--tracker-self-test` to pass with PYTHONHOME/PYTHONPATH/host Python LD_LIBRARY_PATH removed, followed by the packaged GUI smoke launch. Preserve the pinned SDK and model. If this fails, record the exact final-image loader error and inspect only that dependency path.

No physical webcam evidence is claimed by these build experiments.
