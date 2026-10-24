package com.ajayjasper.mimic.nativeview

import org.junit.Assert.*
import org.junit.Test
import java.nio.ByteBuffer
import java.nio.ByteOrder

class NativeContractsTest {
    private fun glb(): ByteArray = ByteBuffer.allocate(24).order(ByteOrder.LITTLE_ENDIAN)
        .putInt(0x46546c67).putInt(2).putInt(24).putInt(4).putInt(0x4e4f534a).put("{}  ".toByteArray()).array()
    @Test fun validGlbHeaderAccepted() { GlbContract.validateHeader(glb()) }
    @Test(expected = IllegalArgumentException::class) fun truncatedGlbRejected() { GlbContract.validateHeader(glb().copyOf(22)) }
    @Test(expected = IllegalArgumentException::class) fun textFileCannotReachNativeParser() { GlbContract.validateHeader(ByteArray(24)) }
    @Test(expected = IllegalArgumentException::class) fun overflowingChunkRejected() {
        val data=glb(); ByteBuffer.wrap(data).order(ByteOrder.LITTLE_ENDIAN).putInt(12, 64); GlbContract.validateHeader(data)
    }
    @Test fun previewAndLandmarksShareLetterboxAndMirrorMapping() {
        val back=CameraViewport(640,480,360,640,false)
        val front=CameraViewport(640,480,360,640,true)
        assertEquals(185f,back.top,0.001f)
        assertEquals(0f,back.project(0f,0f).first,0.001f)
        assertEquals(360f,front.project(0f,0f).first,0.001f)
        assertEquals(0f,front.project(1f,0f).first,0.001f)
        assertEquals(back.project(.5f,.5f),front.project(.5f,.5f))
    }
    @Test fun portraitRotationFrameUsesItsUprightDimensions() {
        val view=CameraViewport(480,640,360,640,false)
        assertEquals(0f,view.left,0.001f)
        assertEquals(80f,view.top,0.001f)
        assertEquals(560f,view.project(1f,1f).second,0.001f)
    }
}
