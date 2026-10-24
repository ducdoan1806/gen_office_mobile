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
    private var openingPdf = false
    private var openingAll = false
    private var openingExtension = "docx"
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
        val chatGpt = ChatGptPlatform(applicationContext)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "vpic1/chatgpt")
            .setMethodCallHandler { call, result ->
                if (call.method == "openBrowser") {
                    try { chatGpt.openBrowser(requireNotNull(call.argument<String>("url"))); result.success(null) }
                    catch (_: Exception) { result.error("browser", "Không mở được trình duyệt để đăng nhập ChatGPT.", null) }
                } else if (call.method in listOf("read", "write", "verifyIdToken")) {
                    background(result, "Không xác thực hoặc lưu được kết nối ChatGPT. Vui lòng thử lại.") {
                        when (call.method) {
                            "read" -> chatGpt.read()
                            "write" -> { chatGpt.write(requireNotNull(call.argument<String>("value"))); null }
                            else -> chatGpt.verify(requireNotNull(call.argument<String>("token")),
                                requireNotNull(call.argument<String>("clientId")),
                                requireNotNull(call.argument<String>("nonce")))
                        }
                    }
                } else result.notImplemented()
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "genoffice/app_info")
            .setMethodCallHandler { call, result ->
                if (call.method != "getAppInfo") result.notImplemented()
                else {
                    @Suppress("DEPRECATION")
                    val info = packageManager.getPackageInfo(packageName, 0)
                    @Suppress("DEPRECATION")
                    val build = if (android.os.Build.VERSION.SDK_INT >= 28) info.longVersionCode else info.versionCode.toLong()
                    result.success(mapOf("version" to info.versionName, "buildNumber" to build.toString()))
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "genoffice/document_files")
            .setMethodCallHandler(::handleDocumentCall)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "genoffice/doc_conversion")
            .setMethodCallHandler { call, result ->
                if (call.method != "convert") result.notImplemented()
                else if (!java.io.File(applicationInfo.nativeLibraryDir, "liblo-native-code.so").isFile) {
                    result.error("unsupported_abi", "Bản chuyển đổi DOC hiện hỗ trợ Android ARM64 và x86_64.", null)
                }
                else background(result, "Không chuyển đổi được tài liệu Office. File gốc chưa được ghi thay đổi. Hãy kiểm tra file không bị hỏng hoặc có mật khẩu.") {
                    DocConversionClient(applicationContext).convert(
                        requireNotNull(call.argument<ByteArray>("bytes")),
                        requireNotNull(call.argument<String>("target")),
                        call.argument<String>("source") ?: if(call.argument<String>("target") == "docx") "doc" else "docx"
                    )
                }
            }
    }

    internal fun handleDocumentCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "open", "create" -> {
                if (pending != null) {
                    result.error("busy", "Trình chọn file đang mở.", null)
                } else {
                    creating = call.method == "create"
                    openingExtension = if(creating) (call.argument<String>("name") ?: "document.docx").substringAfterLast('.').lowercase() else call.argument<String>("format") ?: "docx"
                    require(openingExtension in listOf("docx","doc","pdf","xlsx","pptx","xls","ppt","csv","all"))
                    openingPdf = !creating && call.argument<String>("format") == "pdf"
                    openingAll = !creating && call.argument<String>("format") == "all"
                    val intent = Intent(if (creating) Intent.ACTION_CREATE_DOCUMENT else Intent.ACTION_OPEN_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = when { openingExtension=="xls" -> "application/vnd.ms-excel"; openingExtension=="ppt" -> "application/vnd.ms-powerpoint"; openingExtension=="csv" -> "text/csv"; openingExtension=="doc" -> "application/msword"; openingAll -> "*/*"; openingExtension=="pdf" -> "application/pdf"; openingExtension=="xlsx" -> "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"; openingExtension=="pptx" -> "application/vnd.openxmlformats-officedocument.presentationml.presentation"; else -> "application/vnd.openxmlformats-officedocument.wordprocessingml.document" }
                        if (openingAll) putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("application/vnd.ms-excel", "application/vnd.ms-powerpoint", "text/csv", "text/comma-separated-values", "application/csv", "text/plain", "application/pdf", "application/msword", "application/vnd.openxmlformats-officedocument.wordprocessingml.document", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", "application/vnd.openxmlformats-officedocument.presentationml.presentation"))
                        addFlags((if (openingPdf) Intent.FLAG_GRANT_READ_URI_PERMISSION else accessFlags) or Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
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
                require(output.size() + count <= maxBytes) { "Tài liệu vượt giới hạn 32 MB." }
                output.write(buffer, 0, count)
            }
            return output.toByteArray()
        }
    }

    private fun background(result: MethodChannel.Result, failureMessage: String? = null, action: () -> Any?) {
        io.execute {
            try {
                val value = action()
                main.post { result.success(value) }
            } catch (error: Exception) {
                main.post { result.error("source_file", failureMessage ?: "Không truy cập/lưu được file gốc. Nếu file đã bị di chuyển hoặc mất quyền, hãy chọn mở lại file.", null) }
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
        val isPdf = openingPdf
        val isAll = openingAll
        val expectedExtension = openingExtension
        background(result) {
            var name = "document.docx"
            contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) name = cursor.getString(0)
            }
            val extension = name.substringAfterLast('.', "").lowercase()
            require(if (isAll) extension in listOf("docx", "pdf", "doc", "xlsx", "pptx", "xls", "ppt", "csv") else extension == expectedExtension) { "Loại file không hợp lệ." }
            val granted = data.flags and accessFlags
            val required = if (extension == "pdf") Intent.FLAG_GRANT_READ_URI_PERMISSION else accessFlags
            require(granted and required == required) { "File thiếu quyền truy cập cần thiết." }
            contentResolver.takePersistableUriPermission(uri, granted and required)
            mapOf("uri" to uri.toString(), "name" to name, "bytes" to if (isNew) ByteArray(0) else read(uri))
        }
    }
}
