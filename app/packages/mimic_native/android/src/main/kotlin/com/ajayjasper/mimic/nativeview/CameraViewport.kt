package com.ajayjasper.mimic.nativeview

import kotlin.math.min

internal class CameraViewport(val frameWidth: Int, val frameHeight: Int, val viewWidth: Int, val viewHeight: Int, val mirrored: Boolean) {
    init { require(frameWidth > 0 && frameHeight > 0 && viewWidth > 0 && viewHeight > 0) }
    val scale = min(viewWidth.toFloat()/frameWidth, viewHeight.toFloat()/frameHeight)
    val left = (viewWidth-frameWidth*scale)/2f
    val top = (viewHeight-frameHeight*scale)/2f
    fun project(x: Float, y: Float): Pair<Float, Float> =
        Pair(left+(if (mirrored) 1f-x else x)*frameWidth*scale, top+y*frameHeight*scale)
}
