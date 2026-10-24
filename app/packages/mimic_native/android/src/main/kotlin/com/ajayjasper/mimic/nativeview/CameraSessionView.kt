package com.ajayjasper.mimic.nativeview

import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.Paint
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.provider.Settings
import android.util.Size
import android.view.Surface
import android.view.View
import androidx.camera.core.CameraInfo
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.content.ContextCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarker
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import java.nio.ByteBuffer
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicReference
import kotlin.math.max

internal class CameraFactory(private val messenger: BinaryMessenger, private val host: CameraHost) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, id: Int, args: Any?): PlatformView = CameraSessionView(context, id, messenger, host)
}

internal data class CameraPoint(val x: Float, val y: Float, val visibility: Float?, val presence: Float?) {
    fun visible() = x.isFinite() && y.isFinite() && (visibility == null || visibility >= .5f) && (presence == null || presence >= .5f)
}
internal data class PreviewFrame(val epoch: Int, val bitmap: Bitmap, val points: List<CameraPoint>, val mirror: Boolean, val inferenceMs: Long)

/** Camera frames and landmarks stay native; only small status maps cross to Dart. */
internal class CameraSessionView(context: Context, id: Int, messenger: BinaryMessenger, private val host: CameraHost) : PlatformView, LifecycleOwner {
    private val registry = LifecycleRegistry(this)
    override val lifecycle: Lifecycle get() = registry
    private val channel = MethodChannel(messenger, "mimic/camera/$id")
    private val main = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor()
    private val latest = AtomicReference<PreviewFrame?>(null)
    private val deliveryScheduled = AtomicBoolean(false)
    @Volatile private var epoch = 0
    @Volatile private var disposed = false
    private var attached = false
    private var requested = false
    private var permissionPending = false
    private var starting = false
    private var facing = CameraSelector.LENS_FACING_FRONT
    private var provider: ProcessCameraProvider? = null
    private var analysis: ImageAnalysis? = null
    private var observedCamera: CameraInfo? = null
    // These three fields are used only by the single analysis worker.
    private var detector: PoseLandmarker? = null
    private var timestamp = -1L
    private var acceptedAt = -1L
    private var status = "Tap Start camera to allow local body tracking"
    private var frameCount = 0L
    private var jointCount = 0
    private var inferenceMs = 0L
    private val preview = object : CameraCanvas(context) {
        override fun onAttachedToWindow() { super.onAttachedToWindow(); attached = true; reconcile() }
        override fun onDetachedFromWindow() { attached = false; stopSession(); super.onDetachedFromWindow() }
        override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
            super.onSizeChanged(w, h, oldw, oldh)
            analysis?.targetRotation = display?.rotation ?: Surface.ROTATION_0
        }
    }

    init {
        registry.currentState = Lifecycle.State.CREATED
        host.sessions.add(this)
        channel.setMethodCallHandler { call, result ->
            if (disposed) { result.error("disposed", "Camera view has closed", null); return@setMethodCallHandler }
            when (call.method) {
                "start" -> {
                    requested = true
                    if (!host.hasPermission() && !permissionPending) {
                        permissionPending = true
                        status = "Camera permission required"
                        host.requestPermission { granted ->
                            permissionPending = false
                            if (disposed) return@requestPermission
                            if (granted) reconcile() else {
                                requested = false
                                status = "Camera permission denied. Enable it in Android Settings, then tap Start camera."
                            }
                        }
                    } else reconcile()
                    result.success(null)
                }
                "stop" -> { requested = false; stopSession(); status = "Camera stopped"; result.success(null) }
                "switchCamera" -> {
                    facing = if (facing == CameraSelector.LENS_FACING_FRONT) CameraSelector.LENS_FACING_BACK else CameraSelector.LENS_FACING_FRONT
                    stopSession(); reconcile(); result.success(null)
                }
                "openSettings" -> {
                    host.activity?.startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:${context.packageName}")))
                    result.success(null)
                }
                "status" -> result.success(mapOf("state" to status, "frames" to frameCount, "landmarks" to jointCount,
                    "inferenceMs" to inferenceMs, "camera" to if (facing == CameraSelector.LENS_FACING_FRONT) "front" else "back",
                    "permissionGranted" to host.hasPermission(), "avatarRetargeting" to false))
                else -> result.notImplemented()
            }
        }
    }

    fun reconcile() {
        if (disposed) return
        if (!requested || !attached || !host.resumed || !host.hasPermission()) {
            if (analysis != null || starting) stopSession()
            return
        }
        if (analysis != null || starting) return
        starting = true
        status = "Loading bundled pose model"
        val token = ++epoch
        worker.execute {
            try {
                val options = PoseLandmarker.PoseLandmarkerOptions.builder()
                    .setBaseOptions(BaseOptions.builder().setModelAssetPath("pose_landmarker_lite.task").build())
                    .setRunningMode(RunningMode.VIDEO).setNumPoses(1)
                    .setMinPoseDetectionConfidence(.5f).setMinPosePresenceConfidence(.5f).setMinTrackingConfidence(.5f)
                    .build()
                val next = PoseLandmarker.createFromOptions(preview.context, options)
                if (token != epoch || disposed) { next.close(); return@execute }
                detector = next
                timestamp = -1L; acceptedAt = -1L
                main.post { if (token == epoch && !disposed) bind(token) }
            } catch (failure: Exception) { fail(token, "Pose model could not start: ${failure.message}") }
            catch (failure: LinkageError) { fail(token, "Native pose library could not load: ${failure.message}") }
        }
    }

    private fun bind(token: Int) {
        val future = ProcessCameraProvider.getInstance(preview.context)
        future.addListener({
            if (token != epoch || disposed) return@addListener
            try {
                val cameraProvider = future.get()
                provider = cameraProvider
                var selector = CameraSelector.Builder().requireLensFacing(facing).build()
                if (!cameraProvider.hasCamera(selector)) {
                    facing = if (facing == CameraSelector.LENS_FACING_FRONT) CameraSelector.LENS_FACING_BACK else CameraSelector.LENS_FACING_FRONT
                    selector = CameraSelector.Builder().requireLensFacing(facing).build()
                    require(cameraProvider.hasCamera(selector)) { "No usable camera was found" }
                }
                val mirror = facing == CameraSelector.LENS_FACING_FRONT
                val next = ImageAnalysis.Builder()
                    .setTargetResolution(Size(640, 480))
                    .setTargetRotation(preview.display?.rotation ?: Surface.ROTATION_0)
                    .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                    .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_RGBA_8888).build()
                analysis = next
                next.setAnalyzer(worker) { image -> analyze(image, token, mirror) }
                registry.currentState = Lifecycle.State.RESUMED
                val camera = cameraProvider.bindToLifecycle(this, selector, next)
                observedCamera = camera.cameraInfo
                camera.cameraInfo.cameraState.observe(this) { state ->
                    state.error?.let { fail(token, "Camera unavailable (code ${it.code}). Close other camera apps and tap Start camera.") }
                }
                starting = false
                status = "Camera active • searching for a person"
            } catch (failure: Exception) { fail(token, "Camera could not open: ${failure.message}") }
        }, ContextCompat.getMainExecutor(preview.context))
    }

    private fun analyze(image: ImageProxy, token: Int, mirror: Boolean) {
        try {
            if (disposed || token != epoch) return
            val now = SystemClock.uptimeMillis()
            if (acceptedAt >= 0 && now - acceptedAt < 66) return
            acceptedAt = now
            val localDetector = detector ?: return
            val width = image.width; val height = image.height
            val plane = image.planes[0]
            require(plane.pixelStride == 4) { "Expected CameraX RGBA pixels" }
            val buffer = plane.buffer.duplicate()
            val bytes = ByteArray(width * height * 4)
            // Read each row explicitly: some cameras add padding to rowStride.
            val base = buffer.position()
            for (row in 0 until height) {
                buffer.position(base + row * plane.rowStride)
                buffer.get(bytes, row * width * 4, width * 4)
            }
            val raw = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            raw.copyPixelsFromBuffer(ByteBuffer.wrap(bytes))
            val matrix = Matrix().apply { postRotate(image.imageInfo.rotationDegrees.toFloat()) }
            val upright = Bitmap.createBitmap(raw, 0, 0, width, height, matrix, false)
            if (upright !== raw) raw.recycle()
            val input = BitmapImageBuilder(upright).build()
            try {
                timestamp = max(now, timestamp + 1)
                val started = SystemClock.uptimeMillis()
                val result = localDetector.detectForVideo(input, timestamp)
                if (disposed || token != epoch) return
                val points = result.landmarks().firstOrNull()?.map {
                    CameraPoint(it.x(), it.y(), it.visibility().orElse(null), it.presence().orElse(null))
                } ?: emptyList()
                // MPImage.close recycles its bitmap in this pinned SDK. Display owns a separate copy.
                val displayBitmap = requireNotNull(upright.copy(Bitmap.Config.ARGB_8888, false)) { "Camera preview copy failed" }
                val frame = PreviewFrame(token, displayBitmap, points, mirror, SystemClock.uptimeMillis() - started)
                latest.getAndSet(frame)?.bitmap?.recycle()
                scheduleDelivery()
            } finally { input.close() }
        } catch (failure: Exception) { fail(token, "Camera processing failed: ${failure.message}") }
        finally { image.close() }
    }

    private fun scheduleDelivery() {
        if (!deliveryScheduled.compareAndSet(false, true)) return
        main.post {
            val frame = latest.getAndSet(null)
            if (frame != null) {
                if (!disposed && frame.epoch == epoch) {
                    preview.show(frame)
                    frameCount++
                    jointCount = frame.points.count { it.visible() }
                    inferenceMs = frame.inferenceMs
                    status = if (frame.points.isEmpty()) "Camera active • searching for a person" else "Body landmarks detected"
                } else frame.bitmap.recycle()
            }
            deliveryScheduled.set(false)
            if (latest.get() != null && !disposed) scheduleDelivery()
        }
    }
    private fun fail(token: Int, message: String) {
        main.post {
            if (token != epoch || disposed) return@post
            requested = false
            stopSession()
            status = message
        }
    }
    private fun stopSession() {
        epoch++
        starting = false
        observedCamera?.cameraState?.removeObservers(this)
        observedCamera = null
        analysis?.let { it.clearAnalyzer(); provider?.unbind(it) }
        analysis = null
        if (registry.currentState != Lifecycle.State.DESTROYED) registry.currentState = Lifecycle.State.CREATED
        latest.getAndSet(null)?.bitmap?.recycle()
        preview.clear()
        jointCount = 0
        status = if (requested) "Camera paused" else "Camera stopped"
        if (!worker.isShutdown) worker.execute { detector?.close(); detector = null }
    }
    override fun getView(): View = preview
    override fun dispose() {
        if (disposed) return
        requested = false
        stopSession()
        disposed = true
        registry.currentState = Lifecycle.State.DESTROYED
        host.sessions.remove(this)
        channel.setMethodCallHandler(null)
        worker.shutdown()
    }
}

/** Uses the exact processed image for preview and overlay, avoiding crop/mirror mismatches. */
internal open class CameraCanvas(context: Context) : View(context) {
    private var frame: PreviewFrame? = null
    private val bone = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.rgb(75, 255, 185); strokeCap = Paint.Cap.ROUND }
    private val point = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.WHITE }
    private val imagePaint = Paint(Paint.FILTER_BITMAP_FLAG)
    fun show(value: PreviewFrame) { frame = value; invalidate() }
    fun clear() { frame = null; invalidate() }
    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        canvas.drawColor(Color.rgb(15, 21, 30))
        val current = frame ?: return
        val bitmap = current.bitmap
        if (bitmap.isRecycled) return
        if (width <= 0 || height <= 0) return
        val viewport = CameraViewport(bitmap.width, bitmap.height, width, height, current.mirror)
        val scale = viewport.scale
        canvas.save()
        canvas.translate(viewport.left, viewport.top)
        canvas.scale(scale, scale)
        if (current.mirror) { canvas.translate(bitmap.width.toFloat(), 0f); canvas.scale(-1f, 1f) }
        canvas.clipRect(0, 0, bitmap.width, bitmap.height)
        canvas.drawBitmap(bitmap, 0f, 0f, imagePaint)
        bone.strokeWidth = 3.5f / scale
        for ((a,b) in CONNECTIONS) {
            val p = current.points.getOrNull(a); val q = current.points.getOrNull(b)
            if (p != null && q != null && p.visible() && q.visible())
                canvas.drawLine(p.x*bitmap.width, p.y*bitmap.height, q.x*bitmap.width, q.y*bitmap.height, bone)
        }
        for (p in current.points) if (p.visible()) canvas.drawCircle(p.x*bitmap.width,p.y*bitmap.height,4f/scale,point)
        canvas.restore()
    }
    companion object {
        private val CONNECTIONS = listOf(0 to 1,1 to 2,2 to 3,3 to 7,0 to 4,4 to 5,5 to 6,6 to 8,9 to 10,
            11 to 12,11 to 13,13 to 15,12 to 14,14 to 16,11 to 23,12 to 24,23 to 24,
            23 to 25,25 to 27,24 to 26,26 to 28,27 to 29,29 to 31,27 to 31,28 to 30,30 to 32,28 to 32,
            15 to 17,15 to 19,15 to 21,17 to 19,16 to 18,16 to 20,16 to 22,18 to 20)
    }
}
