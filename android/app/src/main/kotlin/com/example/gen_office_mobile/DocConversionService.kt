package com.example.gen_office_mobile

import android.app.Service
import android.content.Intent
import android.os.*
import java.io.File
import java.util.concurrent.Executors
import org.libreoffice.kit.LibreOfficeKit
import org.libreoffice.kit.Office

/** LibreOffice runs outside Flutter's process; malformed documents cannot kill the editor. */
class DocConversionService : Service() {
    companion object {
        private val worker = Executors.newSingleThreadExecutor()
        private var office: Office? = null
    }
    private val messenger = Messenger(Handler(Looper.getMainLooper()) { request ->
        val reply = request.replyTo
        val args = request.data
        val callerUid = request.sendingUid
        worker.execute {
            val response = Message.obtain(null, 1)
            response.data = Bundle().apply {
                try {
                    require(callerUid == applicationInfo.uid) { "Invalid caller" }
                    convert(args.getString("job")!!, args.getString("source") ?: if(args.getString("target") == "docx") "doc" else "docx", args.getString("target")!!)
                    putBoolean("ok", true)
                } catch (error: Throwable) {
                    android.util.Log.e("GenOfficeConversion", "Offline conversion failed", error)
                    putString("error", "Không chuyển đổi được tài liệu Office. File có thể hỏng, có mật khẩu hoặc không được hỗ trợ.")
                }
            }
            try { reply.send(response) } catch (_: RemoteException) { }
        }
        true
    })

    override fun onBind(intent: Intent): IBinder = messenger.binder

    private fun copyAssets(path: String, output: File) {
        val children = assets.list(path) ?: emptyArray()
        if (children.isEmpty()) {
            output.parentFile!!.mkdirs()
            assets.open(path).use { input -> output.outputStream().use { input.copyTo(it) } }
        } else {
            output.mkdirs()
            children.forEach { copyAssets("$path/$it", File(output, it)) }
        }
    }

    private fun engine(): Office {
        office?.let { return it }
        val marker = File(filesDir, "lo-unpacked-26.2.6.3")
        if (!marker.exists()) {
            copyAssets("unpack", File(applicationInfo.dataDir))
            marker.writeText("ready")
        }
        val fontConfig = File(applicationInfo.dataDir, "etc/fonts/fonts.conf")
        val fontCache = File(cacheDir, "fontconfig").apply { mkdirs() }
        val config = fontConfig.readText().replace(Regex("<cachedir>.*?</cachedir>"), "<cachedir>${fontCache.absolutePath}</cachedir>")
        fontConfig.writeText(config)
        File(applicationInfo.dataDir, "user/registrymodifications.xcu").writeText("""
            <?xml version="1.0" encoding="UTF-8"?>
            <oor:items xmlns:oor="http://openoffice.org/2001/registry">
              <item oor:path="/org.openoffice.Office.Common/Security/Scripting">
                <prop oor:name="DisableMacrosExecution" oor:op="fuse"><value>true</value></prop>
                <prop oor:name="DisableActiveContent" oor:op="fuse"><value>true</value></prop>
                <prop oor:name="BlockUntrustedRefererLinks" oor:op="fuse"><value>true</value></prop>
              </item>
            </oor:items>
        """.trimIndent())
        LibreOfficeKit.init(this)
        return Office(requireNotNull(LibreOfficeKit.getLibreOfficeKitHandle())).also {
            it.setOptionalFeatures(0)
            office = it
        }
    }

    private fun convert(jobId: String, source: String, target: String) {
        require(jobId.matches(Regex("[a-f0-9-]{36}")) && "$source:$target" in listOf("doc:docx", "docx:doc", "xls:xlsx", "xlsx:xls", "ppt:pptx", "pptx:ppt"))
        val root = File(cacheDir, "doc-conversion")
        val job = File(root, jobId).canonicalFile
        require(job.parentFile == root.canonicalFile)
        val input = File(job, "input.$source")
        val output = File(job, "output.$target")
        require(input.isFile && input.length() in 1..(32L * 1024 * 1024))
        val document = requireNotNull(engine().documentLoad(input.toURI().toASCIIString()))
        try {
            val expectedType = when (source) {
                "xls", "xlsx" -> 1
                "ppt", "pptx" -> 2
                else -> 0
            }
            require(document.documentType == expectedType) { "Sai loại tài liệu Office" }
            document.saveAs(output.toURI().toASCIIString(), target, "")
            require(output.isFile && output.length() in 1..(32L * 1024 * 1024))
        } finally { document.destroy() }
    }

}
