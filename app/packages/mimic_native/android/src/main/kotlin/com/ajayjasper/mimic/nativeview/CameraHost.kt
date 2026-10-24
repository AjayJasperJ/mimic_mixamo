package com.ajayjasper.mimic.nativeview

import android.Manifest
import android.app.Activity
import android.app.Application
import android.content.pm.PackageManager
import android.os.Bundle
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.PluginRegistry

/** Owns Activity attachment, permission callbacks and foreground notifications. Main thread only. */
internal class CameraHost : PluginRegistry.RequestPermissionsResultListener, Application.ActivityLifecycleCallbacks {
    var activity: Activity? = null
        private set
    var resumed = false
        private set
    private var binding: ActivityPluginBinding? = null
    private var permissionCode = 43000
    private val permissionRequests = mutableMapOf<Int, (Boolean) -> Unit>()
    val sessions = mutableSetOf<CameraSessionView>()

    fun attach(next: ActivityPluginBinding) {
        binding = next
        activity = next.activity
        resumed = true
        next.addRequestPermissionsResultListener(this)
        next.activity.application.registerActivityLifecycleCallbacks(this)
        sessions.toList().forEach { it.reconcile() }
    }
    fun detach() {
        resumed = false
        sessions.toList().forEach { it.reconcile() }
        binding?.removeRequestPermissionsResultListener(this)
        activity?.application?.unregisterActivityLifecycleCallbacks(this)
        binding = null
        activity = null
        val pending = permissionRequests.values.toList()
        permissionRequests.clear()
        pending.forEach { it(false) }
    }
    fun hasPermission(): Boolean = activity?.let {
        ContextCompat.checkSelfPermission(it, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED
    } ?: false
    fun requestPermission(callback: (Boolean) -> Unit) {
        val current = activity ?: run { callback(false); return }
        if (hasPermission()) { callback(true); return }
        val code = permissionCode++
        permissionRequests[code] = callback
        ActivityCompat.requestPermissions(current, arrayOf(Manifest.permission.CAMERA), code)
    }
    override fun onRequestPermissionsResult(code: Int, permissions: Array<out String>, results: IntArray): Boolean {
        val callback = permissionRequests.remove(code) ?: return false
        callback(results.isNotEmpty() && results[0] == PackageManager.PERMISSION_GRANTED)
        return true
    }
    override fun onActivityResumed(value: Activity) {
        if (value == activity) { resumed = true; sessions.toList().forEach { it.reconcile() } }
    }
    override fun onActivityPaused(value: Activity) {
        if (value == activity) { resumed = false; sessions.toList().forEach { it.reconcile() } }
    }
    override fun onActivityCreated(value: Activity, state: Bundle?) {}
    override fun onActivityStarted(value: Activity) {}
    override fun onActivityStopped(value: Activity) {}
    override fun onActivitySaveInstanceState(value: Activity, state: Bundle) {}
    override fun onActivityDestroyed(value: Activity) {
        if (value == activity) { resumed = false; sessions.toList().forEach { it.reconcile() } }
    }
}
