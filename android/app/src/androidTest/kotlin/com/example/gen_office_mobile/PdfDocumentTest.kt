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
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.regex.Pattern

class PdfDocumentTest {
    @Test fun pdfPickerPersistsReadOnlyAccessAndNeverChangesSource() {
        org.junit.Assume.assumeTrue(android.os.Build.VERSION.SDK_INT >= 31)
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val context = instrumentation.targetContext
        val device = UiDevice.getInstance(instrumentation)
        val filename = "genoffice-pdf-picker-test.pdf"
        fun shell(command: String) = instrumentation.uiAutomation.executeShellCommand(command).use {
            ParcelFileDescriptor.AutoCloseInputStream(it).readBytes()
        }
        val original = context.assets.open("flutter_assets/assets/samples/pdf-viewer-test.pdf").use { it.readBytes() }
        val pipes = instrumentation.uiAutomation.executeShellCommandRw("tee /sdcard/Download/$filename")
        ParcelFileDescriptor.AutoCloseOutputStream(pipes[1]).use { it.write(original) }
        ParcelFileDescriptor.AutoCloseInputStream(pipes[0]).use { it.readBytes() }
        shell("am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d file:///sdcard/Download/$filename")
        val activity = instrumentation.startActivitySync(Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) as MainActivity
        class Reply : MethodChannel.Result {
            val done = CountDownLatch(1)
            var value: Any? = null
            var error: String? = null
            override fun success(result: Any?) { value = result; done.countDown() }
            override fun error(code: String, message: String?, details: Any?) { error = message; done.countDown() }
            override fun notImplemented() { error = "not implemented"; done.countDown() }
            fun await(): Any? { check(done.await(45, TimeUnit.SECONDS)); check(error == null) { error!! }; return value }
        }
        fun call(method: String, args: Map<String, Any>): Reply {
            val reply = Reply()
            instrumentation.runOnMainSync { activity.handleDocumentCall(MethodCall(method, args), reply) }
            return reply
        }
        try {
            val initial = DocumentsContract.buildDocumentUri("com.android.externalstorage.documents", "primary:Download")
            val reply = call("open", mapOf("format" to "all", "initialUri" to initial.toString()))
            var file = device.wait(Until.findObject(By.text(filename)), 10000)
            if (file == null) {
                requireNotNull(device.wait(Until.findObject(By.desc("Search")), 10000)).click()
                requireNotNull(device.wait(Until.findObject(By.res(Pattern.compile(".*:id/search_src_text"))), 10000)).text = filename
                val search = device.wait(Until.findObject(By.pkg("com.google.android.inputmethod.latin").desc("Search")), 5000)
                if (search != null) search.click() else device.pressEnter()
                file = device.wait(Until.findObject(By.res("android:id/title").text(filename)), 10000)
            }
            requireNotNull(file) { "PDF fixture missing in system picker" }.click()
            @Suppress("UNCHECKED_CAST")
            val selected = reply.await() as Map<String, Any>
            val uri = Uri.parse(selected["uri"] as String)
            assertArrayEquals(original, selected["bytes"] as ByteArray)
            assertTrue(context.contentResolver.persistedUriPermissions.any { it.uri == uri && it.isReadPermission && !it.isWritePermission })
            assertArrayEquals(original, call("read", mapOf("uri" to uri.toString())).await() as ByteArray)
            val denied = call("write", mapOf("uri" to uri.toString(), "bytes" to "changed".toByteArray()))
            assertTrue(denied.done.await(15, TimeUnit.SECONDS))
            assertNotNull(denied.error)
            assertArrayEquals(original, shell("cat /sdcard/Download/$filename"))
            context.contentResolver.releasePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
            val revoked = call("read", mapOf("uri" to uri.toString()))
            assertTrue(revoked.done.await(15, TimeUnit.SECONDS))
            assertNotNull(revoked.error)
        } finally {
            instrumentation.runOnMainSync { activity.finish() }
            shell("rm -f /sdcard/Download/$filename")
        }
    }
}
