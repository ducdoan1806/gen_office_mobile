package com.example.gen_office_mobile

import android.content.Intent
import android.net.Uri
import android.os.ParcelFileDescriptor
import android.provider.DocumentsContract
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.By
import androidx.test.uiautomator.UiDevice
import androidx.test.uiautomator.Until
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.junit.Assert.*
import org.junit.Test
import java.io.File
import java.util.regex.Pattern
import java.util.UUID
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/** Two instrumentation processes verify real DOC bytes and persisted SAF grants. */
class DocSourcePersistenceTest {
    @Test fun docSourceSurvivesProcessRestart() {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val context = instrumentation.targetContext
        val device = UiDevice.getInstance(instrumentation)
        val phase = InstrumentationRegistry.getArguments().getString("phase")
        org.junit.Assume.assumeTrue("Run explicitly with phase=prepare or verify", phase == "prepare" || phase == "verify")
        val probe = File(context.cacheDir, "doc-saf-phone-qa")
        fun shell(command: String) = instrumentation.uiAutomation.executeShellCommand(command).use {
            ParcelFileDescriptor.AutoCloseInputStream(it).readBytes()
        }
        if (phase == "verify") {
            val uri = Uri.parse(File(probe, "uri").readText())
            val filename = File(probe, "filename").readText()
            try {
                assertTrue(context.contentResolver.persistedUriPermissions.any {
                    it.uri == uri && it.isReadPermission && it.isWritePermission
                })
                val expected = File(probe, "expected.doc").readBytes()
                assertArrayEquals(expected, context.contentResolver.openInputStream(uri)!!.use { it.readBytes() })
                assertArrayEquals(expected, shell("cat /sdcard/Download/$filename"))
                context.contentResolver.openOutputStream(uri, "wt")!!.use { it.write(expected) }
                assertArrayEquals(expected, shell("cat /sdcard/Download/$filename"))
            } finally {
                context.contentResolver.releasePersistableUriPermission(uri,
                    Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                shell("rm -f /sdcard/Download/$filename")
                probe.deleteRecursively()
            }
            return
        }
        require(phase == "prepare" && !probe.exists())
        probe.mkdirs()
        val filename = "genoffice-qa-${UUID.randomUUID()}.doc"
        File(probe, "filename").writeText(filename)
        val converter = DocConversionClient(context)
        val docx = context.assets.open("flutter_assets/assets/samples/legacy-conversion.docx").use { it.readBytes() }
        val original = converter.convert(docx, "doc")
        val editedDocx = context.assets.open("flutter_assets/assets/samples/factory-demo.docx").use { it.readBytes() }
        val edited = converter.convert(editedDocx, "doc")
        assertFalse(original.contentEquals(edited))
        val pipes = instrumentation.uiAutomation.executeShellCommandRw("tee /sdcard/Download/$filename")
        ParcelFileDescriptor.AutoCloseOutputStream(pipes[1]).use { it.write(original) }
        ParcelFileDescriptor.AutoCloseInputStream(pipes[0]).use { it.readBytes() }
        shell("am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d file:///sdcard/Download/$filename")
        val activity = instrumentation.startActivitySync(Intent(context, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) as MainActivity
        class Reply : MethodChannel.Result {
            val done = CountDownLatch(1)
            var value: Any? = null
            var failure: String? = null
            override fun success(result: Any?) { value = result; done.countDown() }
            override fun error(code: String, message: String?, details: Any?) { failure = "$code: $message"; done.countDown() }
            override fun notImplemented() { failure = "not implemented"; done.countDown() }
            fun await(): Any? { check(done.await(45, TimeUnit.SECONDS)); check(failure == null) { failure!! }; return value }
        }
        fun call(method: String, args: Map<String, Any>): Reply {
            val reply = Reply()
            instrumentation.runOnMainSync { activity.handleDocumentCall(MethodCall(method, args), reply) }
            return reply
        }
        var keepForVerify = false
        try {
            val initial = DocumentsContract.buildDocumentUri("com.android.externalstorage.documents", "primary:Download")
            val reply = call("open", mapOf("format" to "all", "initialUri" to initial.toString()))
            var file = device.wait(Until.findObject(By.text(filename)), 3000)
            if (file == null) {
                requireNotNull(device.wait(Until.findObject(By.desc(Pattern.compile("Search|Tìm kiếm"))), 10000)).click()
                requireNotNull(device.wait(Until.findObject(By.res(Pattern.compile(".*:id/search_src_text"))), 10000)).text = filename
                device.pressEnter()
                device.waitForIdle()
                device.wait(Until.hasObject(By.res(Pattern.compile(".*:id/dir_list"))), 10000)
                file = device.wait(Until.findObject(By.res("android:id/title").text(filename)), 30000)
            }
            requireNotNull(file) {
                "Dedicated DOC fixture missing in picker"
            }.click()
            @Suppress("UNCHECKED_CAST")
            val selected = reply.await() as Map<String, Any>
            assertArrayEquals(original, selected["bytes"] as ByteArray)
            val uri = selected["uri"] as String
            call("write", mapOf("uri" to uri, "bytes" to edited)).await()
            assertArrayEquals(edited, shell("cat /sdcard/Download/$filename"))
            File(probe, "uri").writeText(uri)
            File(probe, "expected.doc").writeBytes(edited)
            keepForVerify = true
        } finally {
            instrumentation.runOnMainSync { activity.finish() }
            if (!keepForVerify) {
                shell("rm -f /sdcard/Download/$filename")
                probe.deleteRecursively()
            }
        }
    }
}
