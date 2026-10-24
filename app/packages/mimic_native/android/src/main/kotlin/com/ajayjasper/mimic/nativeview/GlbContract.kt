package com.ajayjasper.mimic.nativeview

import java.nio.ByteBuffer
import java.nio.ByteOrder

/** Validate container framing before handing bytes to the native GLB parser. */
internal object GlbContract {
    fun validateHeader(bytes: ByteArray) {
        require(bytes.size >= 20) { "Bundled GLB is missing or truncated" }
        val data = ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN)
        require(data.int == 0x46546c67) { "Asset is not a binary glTF file" }
        require(data.int == 2) { "Only GLB version 2 is supported" }
        require(data.int == bytes.size) { "GLB length does not match its header" }
        var first = true
        while (data.hasRemaining()) {
            require(data.remaining() >= 8) { "Truncated GLB chunk header" }
            val size = data.int
            val kind = data.int
            require(size >= 0 && size % 4 == 0 && size <= data.remaining()) { "Invalid GLB chunk length" }
            if (first) { require(kind == 0x4e4f534a) { "GLB must begin with a JSON chunk" }; first = false }
            data.position(data.position() + size)
        }
    }
}
