package com.ajayjasper.mimic.nativeview

import android.content.Context
import android.opengl.Matrix
import android.view.Choreographer
import android.view.SurfaceView
import android.widget.FrameLayout
import com.google.android.filament.utils.ModelViewer
import com.google.android.filament.utils.Utils
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import java.nio.ByteBuffer
import kotlin.math.sin

class MimicNativePlugin : FlutterPlugin {
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        Utils.init()
        binding.platformViewRegistry.registerViewFactory("mimic/rig", RigFactory(binding.binaryMessenger))
    }
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {}
}

private class RigFactory(private val messenger: BinaryMessenger) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView = RigView(context, viewId, messenger)
}

/** All Filament calls and commands run on Android's main/render thread. */
private class RigView(context: Context, id: Int, messenger: BinaryMessenger) : PlatformView, Choreographer.FrameCallback {
    private val channel = MethodChannel(messenger, "mimic/rig/$id")
    private var viewer: ModelViewer? = null
    private var surface: SurfaceView? = null
    private var disposed = false
    private var active = true
    private var playing = false
    private var scheduled = false
    private var error: String? = null
    private var animationEpoch = 0L
    private var renderedFrames = 0L
    private val angles = floatArrayOf(0f, 0f, 0f, 0f)
    private val joints = linkedMapOf<String, Pair<Int, FloatArray>>()
    private val names = listOf("LeftUpperArm", "LeftForeArm", "RightUpperArm", "RightForeArm")
    private val container = object : FrameLayout(context) {
        override fun onAttachedToWindow() {
            super.onAttachedToWindow()
            if (!disposed) attachRenderer()
        }
        override fun onDetachedFromWindow() {
            stopFrames()
            // ModelViewer destroys its owned engine on SurfaceView detach.
            viewer = null
            joints.clear()
            removeAllViews()
            surface = null
            super.onDetachedFromWindow()
        }
    }

    init {
        channel.setMethodCallHandler { call, result ->
            if (disposed) { result.error("disposed", "Rig view was disposed", null); return@setMethodCallHandler }
            when (call.method) {
                "status" -> result.success(mapOf("ready" to (viewer != null && joints.size == 4 && error == null),
                    "error" to error, "jointCount" to joints.size, "renderedFrames" to renderedFrames,
                    "asset" to "Mimic original development humanoid", "trackingImplemented" to false))
                "setPose" -> {
                    val values = call.argument<List<Number>>("angles")
                    if (values == null || values.size != 4 || values.any { !it.toDouble().isFinite() }) {
                        result.error("invalid_pose", "Expected four finite joint angles", null)
                    } else {
                        for (i in 0..3) angles[i] = values[i].toFloat().coerceIn(-120f, 120f)
                        playing = false
                        schedule()
                        result.success(null)
                    }
                }
                "play" -> { playing = call.argument<Boolean>("enabled") == true; animationEpoch = 0L; schedule(); result.success(null) }
                "setActive" -> {
                    active = call.argument<Boolean>("enabled") == true
                    if (active) schedule() else stopFrames()
                    result.success(null)
                }
                "reset" -> { angles.fill(0f); playing = false; schedule(); result.success(null) }
                else -> result.notImplemented()
            }
        }
    }

    private fun attachRenderer() {
        if (viewer != null || disposed) return
        error = null
        try {
            val nextSurface = SurfaceView(container.context)
            container.addView(nextSurface, FrameLayout.LayoutParams(-1, -1))
            surface = nextSurface
            val next = ModelViewer(nextSurface)
            viewer = next
            val bytes = container.context.assets.open("flutter_assets/assets/characters/development_humanoid.glb").use { it.readBytes() }
            val buffer = ByteBuffer.allocateDirect(bytes.size).apply { put(bytes); flip() }
            next.loadModelGlb(buffer)
            val asset = requireNotNull(next.asset) { "GLB loader returned no asset" }
            next.transformToUnitCube()
            val tm = next.engine.transformManager
            for (name in names) {
                val entity = asset.getFirstEntityByName(name)
                require(entity != 0) { "Missing joint: $name" }
                val instance = tm.getInstance(entity)
                val rest = FloatArray(16)
                tm.getTransform(instance, rest)
                joints[name] = Pair(instance, rest)
            }
            schedule()
        } catch (failure: Exception) {
            error = failure.message ?: failure.javaClass.simpleName
            stopFrames()
            viewer = null
            joints.clear()
            container.removeAllViews()
            surface = null
        }
    }

    private fun schedule() {
        if (active && !disposed && viewer != null && !scheduled && error == null) {
            scheduled = true
            Choreographer.getInstance().postFrameCallback(this)
        }
    }
    private fun stopFrames() {
        Choreographer.getInstance().removeFrameCallback(this)
        scheduled = false
    }
    override fun doFrame(frameTimeNanos: Long) {
        scheduled = false
        val current = viewer ?: return
        if (!active || disposed || error != null) return
        try {
            if (animationEpoch == 0L) animationEpoch = frameTimeNanos
            val wave = ((sin((frameTimeNanos-animationEpoch)/1e9 * 1.5)+1.0)*0.5).toFloat()
            val tm = current.engine.transformManager
            names.forEachIndexed { i, name ->
                val (instance, rest) = joints.getValue(name)
                val degrees = if (playing) when(i) { 0 -> wave*35f; 1 -> wave*105f; 2 -> -wave*20f; else -> -wave*80f } else angles[i]
                val rotation = FloatArray(16)
                Matrix.setRotateM(rotation, 0, degrees, 0f, 0f, 1f)
                val local = FloatArray(16)
                // Bind-local * rotation preserves the bind translation and scale.
                Matrix.multiplyMM(local, 0, rest, 0, rotation, 0)
                tm.setTransform(instance, local)
            }
            // No clip playback: local bone transforms drive actual skin matrices.
            current.animator?.updateBoneMatrices()
            current.render(frameTimeNanos)
            renderedFrames++
        } catch (failure: Exception) {
            error = failure.message ?: "Render failure"
        }
        schedule()
    }
    override fun getView(): android.view.View = container
    override fun dispose() {
        if (disposed) return
        disposed = true
        stopFrames()
        channel.setMethodCallHandler(null)
        viewer = null
        joints.clear()
        container.removeAllViews()
        surface = null
    }
}
