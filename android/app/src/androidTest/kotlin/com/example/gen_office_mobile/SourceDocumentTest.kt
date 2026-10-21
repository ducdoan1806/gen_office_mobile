package com.example.gen_office_mobile

import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.By
import androidx.test.uiautomator.UiDevice
import androidx.test.uiautomator.Until
import androidx.test.uiautomator.UiSelector
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.junit.Assert.*
import org.junit.Test
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.regex.Pattern

/** Exercises the real system picker and Downloads provider, without storage permissions. */
class SourceDocumentTest {
    private val instrumentation = InstrumentationRegistry.getInstrumentation()
    private val device = UiDevice.getInstance(instrumentation)
    private val filename = "genoffice-source-save-test.docx"

    private class Reply : MethodChannel.Result {
        val done = CountDownLatch(1)
        var value: Any? = null
        var error: String? = null
        override fun success(result: Any?) { value = result; done.countDown() }
        override fun error(code: String, message: String?, details: Any?) { error = "$code: $message"; done.countDown() }
        override fun notImplemented() { error = "not implemented"; done.countDown() }
        fun await(): Any? { check(done.await(45, TimeUnit.SECONDS)) { "Native file operation timed out" }; check(error == null) { error!! }; return value }
    }

    private fun shell(command: String): ByteArray = instrumentation.uiAutomation.executeShellCommand(command).use {
        android.os.ParcelFileDescriptor.AutoCloseInputStream(it).readBytes()
    }

    private fun call(activity: MainActivity, method: String, args: Map<String, Any>? = null): Reply {
        val reply = Reply()
        instrumentation.runOnMainSync { activity.handleDocumentCall(MethodCall(method, args), reply) }
        return reply
    }

    @Test fun selectedDownloadsFileIsOverwrittenAndRevokedPermissionFails() {
        org.junit.Assume.assumeTrue(android.os.Build.VERSION.SDK_INT >= 31)
        val context = instrumentation.targetContext
        val original = context.assets.open("flutter_assets/assets/samples/factory-demo.docx").use { it.readBytes() }
        val pipes = instrumentation.uiAutomation.executeShellCommandRw("tee /sdcard/Download/$filename")
        android.os.ParcelFileDescriptor.AutoCloseOutputStream(pipes[1]).use { it.write(original) }
        android.os.ParcelFileDescriptor.AutoCloseInputStream(pipes[0]).use { it.readBytes() }
        assertArrayEquals("Fixture must exist before opening the picker", original, shell("cat /sdcard/Download/$filename"))
        shell("am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d file:///sdcard/Download/$filename")
        val activity = instrumentation.startActivitySync(Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) as MainActivity
        try {
            val initial = DocumentsContract.buildDocumentUri("com.android.externalstorage.documents", "primary:Download")
            val selected = call(activity, "open", mapOf("initialUri" to initial.toString()))
            var file = device.wait(Until.findObject(By.text(filename)), 3000)
            if (file == null) {
                val roots = device.findObject(UiSelector().description("Show roots"))
                if (roots.waitForExists(5000)) {
                    roots.click()
                    val downloads = device.findObject(UiSelector().text("Downloads"))
                    check(downloads.waitForExists(10000)) { "Downloads root missing" }
                    downloads.click()
                }
                file = device.wait(Until.findObject(By.text(filename)), 5000)
            }
            if (file == null) {
                val search = device.wait(Until.findObject(By.desc("Search")), 10000)
                assertNotNull("Search in picker", search)
                requireNotNull(search).click()
                val input = device.wait(Until.findObject(By.res(Pattern.compile(".*:id/search_src_text"))), 10000)
                requireNotNull(input) { "Search input missing" }.text = filename
                val imeSearch = device.wait(Until.findObject(By.pkg("com.google.android.inputmethod.latin").desc("Search")), 5000)
                if (imeSearch != null) imeSearch.click() else device.pressEnter()
                device.waitForIdle()
                device.wait(Until.hasObject(By.res(Pattern.compile(".*:id/dir_list"))), 10000)
                file = device.wait(Until.findObject(By.res("android:id/title").text(filename)), 10000)
            }
            assertNotNull("Dedicated DOCX fixture in Downloads", file)
            device.findObject(UiSelector().resourceId("android:id/title").text(filename)).click()
            @Suppress("UNCHECKED_CAST")
            val source = selected.await() as Map<String, Any>
            val uri = source["uri"] as String
            assertArrayEquals(original, source["bytes"] as ByteArray)
            assertTrue(context.contentResolver.persistedUriPermissions.any { it.uri == Uri.parse(uri) && it.isReadPermission && it.isWritePermission })
            val edited = "PK-edited".toByteArray()
            call(activity, "write", mapOf("uri" to uri, "bytes" to edited)).await()
            assertArrayEquals(edited, shell("cat /sdcard/Download/$filename"))
            assertArrayEquals(edited, call(activity, "read", mapOf("uri" to uri)).await() as ByteArray)
            context.contentResolver.releasePersistableUriPermission(Uri.parse(uri), Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            val failure = call(activity, "write", mapOf("uri" to uri, "bytes" to "PK-no-access".toByteArray()))
            assertTrue(failure.done.await(15, TimeUnit.SECONDS))
            assertNotNull("Revoked permission must fail", failure.error)
            assertArrayEquals(edited, shell("cat /sdcard/Download/$filename"))
        } catch (error: Throwable) {
            device.dumpWindowHierarchy(java.io.File(context.cacheDir, "source-picker-test.xml"))
            throw error
        } finally {
            instrumentation.runOnMainSync { activity.finish() }
            shell("rm -f /sdcard/Download/$filename")
        }
    }
}
