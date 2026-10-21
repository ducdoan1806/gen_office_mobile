package com.example.gen_office_mobile

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import android.provider.DocumentsContract
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var pending: MethodChannel.Result? = null
    private var creating = false
    private val accessFlags = Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
    private val maxBytes = 32 * 1024 * 1024

    override fun onDestroy() {
        pending?.error("closed", "Đã đóng trình chọn file.", null)
        pending = null
        io.shutdown()
        super.onDestroy()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "genoffice/document_files")
            .setMethodCallHandler(::handleDocumentCall)
    }

    internal fun handleDocumentCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "open", "create" -> {
                if (pending != null) {
                    result.error("busy", "Trình chọn file đang mở.", null)
                } else {
                    creating = call.method == "create"
                    val intent = Intent(if (creating) Intent.ACTION_CREATE_DOCUMENT else Intent.ACTION_OPEN_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
                        addFlags(accessFlags or Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
                        if (creating) putExtra(Intent.EXTRA_TITLE, call.argument<String>("name") ?: "document.docx")
                    call.argument<String>("initialUri")?.let {
                        putExtra(DocumentsContract.EXTRA_INITIAL_URI, Uri.parse(it))
                    }
                    }
                    pending = result
                    try { startActivityForResult(intent, 7401) }
                    catch (error: Exception) { pending = null; result.error("picker", error.message, null) }
                }
            }
            "read", "write" -> background(result) {
                val uri = Uri.parse(requireNotNull(call.argument<String>("uri")))
                require(uri.scheme == "content") { "Đường dẫn file gốc không hợp lệ." }
                require(contentResolver.persistedUriPermissions.any {
                    it.uri == uri && it.isReadPermission && (call.method == "read" || it.isWritePermission)
                }) { "Quyền truy cập file gốc đã mất. Hãy mở lại file." }
                if (call.method == "read") read(uri) else {
                    val bytes = requireNotNull(call.argument<ByteArray>("bytes"))
                    require(bytes.isNotEmpty() && bytes.size <= maxBytes) { "DOCX vượt giới hạn 32 MB." }
                    contentResolver.openOutputStream(uri, "wt").use { stream ->
                        requireNotNull(stream) { "Không mở được file gốc để ghi." }
                        stream.write(bytes)
                        stream.flush()
                    }
                    check(read(uri).contentEquals(bytes)) { "Không xác minh được nội dung đã lưu vào file gốc." }
                    null
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun read(uri: Uri): ByteArray {
        contentResolver.openInputStream(uri).use { stream ->
            requireNotNull(stream) { "Không đọc được file gốc." }
            val output = ByteArrayOutputStream()
            val buffer = ByteArray(64 * 1024)
            while (true) {
                val count = stream.read(buffer)
                if (count < 0) break
                require(output.size() + count <= maxBytes) { "DOCX vượt giới hạn 32 MB." }
                output.write(buffer, 0, count)
            }
            return output.toByteArray()
        }
    }

    private fun background(result: MethodChannel.Result, action: () -> Any?) {
        io.execute {
            try {
                val value = action()
                main.post { result.success(value) }
            } catch (error: Exception) {
                main.post { result.error("source_file", "Không truy cập/lưu được file gốc. Nếu file đã bị di chuyển hoặc mất quyền, hãy mở lại bằng nút Mở DOCX. ", null) }
            }
        }
    }

    @Deprecated("Used for the Android document picker")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != 7401) return
        val result = pending ?: return
        pending = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) { result.success(null); return }
        val isNew = creating
        background(result) {
            val granted = data.flags and accessFlags
            require(granted and accessFlags == accessFlags) { "File cần quyền đọc và ghi. Hãy chọn file có thể chỉnh sửa." }
            contentResolver.takePersistableUriPermission(uri, granted)
            var name = "document.docx"
            contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) name = cursor.getString(0)
            }
            require(name.endsWith(".docx", ignoreCase = true)) { "Hãy chọn file DOCX." }
            mapOf("uri" to uri.toString(), "name" to name, "bytes" to if (isNew) ByteArray(0) else read(uri))
        }
    }
}
