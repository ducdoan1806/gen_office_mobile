package com.example.gen_office_mobile

import android.app.Activity
import android.app.Service
import android.content.ComponentName
import android.content.Intent
import android.os.Binder
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.net.Uri
import androidx.browser.customtabs.CustomTabsCallback
import androidx.browser.customtabs.CustomTabsClient
import androidx.browser.customtabs.CustomTabsIntent
import androidx.browser.customtabs.CustomTabsServiceConnection
import io.flutter.plugin.common.MethodChannel

/**
 * Empty browser-bound service. No token, credentials, methods or data are exposed.
 * Chrome binds this only while displaying the authentication Custom Tab.
 */
class ChatGptKeepAliveService : Service() {
    private val binder = Binder()
    override fun onBind(intent: Intent?): IBinder = binder
}

/** A real bound Custom Tabs session, rather than an unrelated browser task. */
internal class ChatGptBrowser(private val activity: Activity) {
    private val context = activity.applicationContext
    private val handler = Handler(Looper.getMainLooper())
    private var connection: CustomTabsServiceConnection? = null
    private var pending: MethodChannel.Result? = null
    private var bound = false
    private val timeout = Runnable {
        fail("Không kết nối được trình duyệt đăng nhập. Vui lòng mở lại và thử lại.")
    }
    fun open(value: String, result: MethodChannel.Result) {
        val uri = Uri.parse(value)
        require(uri.scheme == "https" && uri.host == "auth.openai.com" && uri.path == "/api/accounts/authorize")
        close()
        val browserPackage = CustomTabsClient.getPackageName(context, null)
        if (browserPackage == null) {
            result.error("browser", "Cần trình duyệt hỗ trợ Custom Tabs, ví dụ Chrome, để đăng nhập ChatGPT.", null)
            return
        }
        pending = result
        val current = object : CustomTabsServiceConnection() {
            override fun onCustomTabsServiceConnected(name: ComponentName, client: CustomTabsClient) {
                if (connection !== this || pending == null) return
                try {
                    client.warmup(0)
                    val session = client.newSession(object : CustomTabsCallback() {})
                        ?: throw IllegalStateException("No browser session")
                    val intent = CustomTabsIntent.Builder(session)
                        .setShowTitle(true).build()
                    intent.intent.setPackage(browserPackage)
                    intent.intent.putExtra("android.support.customtabs.extra.KEEP_ALIVE",
                        Intent(context, ChatGptKeepAliveService::class.java))
                    intent.launchUrl(activity, uri)
                    handler.removeCallbacks(timeout)
                    val response = pending
                    pending = null
                    response?.success(null)
                } catch (_: Exception) {
                    fail("Không mở được phiên đăng nhập an toàn. Vui lòng thử lại.")
                }
            }
            override fun onServiceDisconnected(name: ComponentName) {
                if (connection === this) fail("Kết nối trình duyệt bị ngắt. Vui lòng đăng nhập lại.")
            }
        }
        connection = current
        try {
            bound = CustomTabsClient.bindCustomTabsServicePreservePriority(context, browserPackage, current)
        } catch (_: Exception) {
            fail("Không được phép kết nối trình duyệt đăng nhập."); return
        }
        if (!bound) fail("Không kết nối được trình duyệt Custom Tabs.")
        else handler.postDelayed(timeout, 10000)
    }
    private fun fail(message: String) {
        val response = pending
        pending = null
        close()
        response?.error("browser", message, null)
    }
    fun close() {
        handler.removeCallbacks(timeout)
        val old = connection
        connection = null
        if (bound && old != null) {
            try { context.unbindService(old) } catch (_: IllegalArgumentException) {}
        }
        bound = false
        val response = pending
        pending = null
        response?.error("browser", "Đã đóng phiên đăng nhập.", null)
    }
}
