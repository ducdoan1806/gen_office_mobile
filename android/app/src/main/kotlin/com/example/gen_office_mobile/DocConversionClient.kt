package com.example.gen_office_mobile

import android.content.*
import android.os.*
import java.io.File
import java.util.UUID
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

class DocConversionClient(private val context: Context) {
    /** Call on an IO thread, never the main thread. Binder carries paths, not document bytes. */
    fun convert(bytes: ByteArray, target: String): ByteArray {
        require(target in listOf("doc", "docx") && bytes.size in 1..(32 * 1024 * 1024))
        val jobId = UUID.randomUUID().toString()
        val job = File(context.cacheDir, "doc-conversion/$jobId").apply { mkdirs() }
        File(job, if (target == "docx") "input.doc" else "input.docx").outputStream().use { it.write(bytes) }
        val done = CountDownLatch(1)
        var failure: String? = null
        var bound = false
        val main = Handler(Looper.getMainLooper())
        val reply = Messenger(Handler(Looper.getMainLooper()) { message ->
            if (!message.data.getBoolean("ok")) failure = message.data.getString("error") ?: "Chuyển đổi DOC thất bại."
            done.countDown()
            true
        })
        val connection = object : ServiceConnection {
            override fun onServiceConnected(name: ComponentName, binder: IBinder) {
                try {
                    Messenger(binder).send(Message.obtain(null, 1).apply {
                        replyTo = reply
                        data = Bundle().apply { putString("job", jobId); putString("target", target) }
                    })
                } catch (_: Exception) { failure = "Không kết nối được bộ chuyển đổi DOC."; done.countDown() }
            }
            override fun onServiceDisconnected(name: ComponentName) { failure = "Bộ chuyển đổi DOC đã dừng. File gốc chưa được lưu thay đổi."; done.countDown() }
            override fun onNullBinding(name: ComponentName) { failure = "Bộ chuyển đổi DOC chưa sẵn sàng."; done.countDown() }
        }
        try {
            main.post {
                try {
                    bound = context.bindService(Intent(context, DocConversionService::class.java), connection, Context.BIND_AUTO_CREATE)
                    if (!bound) { failure = "Không khởi động được bộ chuyển đổi DOC."; done.countDown() }
                } catch (_: Exception) { failure = "Không khởi động được bộ chuyển đổi DOC."; done.countDown() }
            }
            if (!done.await(180, TimeUnit.SECONDS)) {
                context.getSystemService(android.app.ActivityManager::class.java).runningAppProcesses
                    ?.filter { it.uid == android.os.Process.myUid() && it.processName == context.packageName + ":doc_converter" }
                    ?.forEach { android.os.Process.killProcess(it.pid) }
                throw IllegalStateException("Chuyển đổi DOC quá thời gian cho phép.")
            }
            check(failure == null) { failure!! }
            val output = File(job, "output.$target")
            require(output.length() in 1..(32L * 1024 * 1024))
            val result = output.readBytes()
            if (target == "docx") require(result.size >= 4 && result[0] == 80.toByte() && result[1] == 75.toByte())
            else require(result.size >= 8 && result.take(8) == listOf(0xd0,0xcf,0x11,0xe0,0xa1,0xb1,0x1a,0xe1).map { it.toByte() })
            return result
        } finally {
            main.post { if (bound) context.unbindService(connection) }
            job.deleteRecursively()
        }
    }
}
