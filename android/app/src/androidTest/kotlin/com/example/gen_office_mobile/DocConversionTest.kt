package com.example.gen_office_mobile

import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.*
import org.junit.Test
import java.io.ByteArrayInputStream
import java.util.zip.ZipInputStream

class DocConversionTest {
    @Test fun convertsWordBinaryOfflineInBothDirections() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val original = context.assets.open("flutter_assets/assets/samples/legacy-conversion.docx").use { it.readBytes() }
        val client = DocConversionClient(context)
        val doc = client.convert(original, "doc")
        assertArrayEquals(byteArrayOf(0xd0.toByte(),0xcf.toByte(),0x11,0xe0.toByte(),0xa1.toByte(),0xb1.toByte(),0x1a,0xe1.toByte()), doc.copyOf(8))
        val restored = client.convert(doc, "docx")
        java.io.File(context.cacheDir, "doc-conversion-probe.doc").writeBytes(doc)
        var documentXml = ""
        ZipInputStream(ByteArrayInputStream(restored)).use { zip ->
            while (true) {
                val entry = zip.nextEntry ?: break
                if (entry.name == "word/document.xml") documentXml = zip.readBytes().toString(Charsets.UTF_8)
            }
        }
        java.io.File(context.cacheDir, "doc-conversion-probe.xml").writeText(documentXml)
        assertTrue("DOC round trip must retain Vietnamese Word text", documentXml.contains("Xin chào nhà máy"))
        assertTrue(documentXml.contains("<w:tbl"))
        val converterProcess = context.getSystemService(android.app.ActivityManager::class.java)
            .runningAppProcesses?.firstOrNull { it.processName == context.packageName + ":doc_converter" }
        assertNotNull("Converter process must exist", converterProcess)
        assertTrue("Converter uses a private process", android.os.Process.myPid() != converterProcess!!.pid)
    }
}