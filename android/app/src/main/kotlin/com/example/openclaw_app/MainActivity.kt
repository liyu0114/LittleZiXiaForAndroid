package com.example.openclaw_app

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.util.Log
import io.flutter.plugin.common.MethodChannel
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    private val CHANNEL_SPEECH = "com.example.openclaw_app/speech"
    private val CHANNEL_FILE = "com.example.openclaw_app/file"
    private val PICK_FILE_REQUEST_CODE = 1001
    private var filePickerResult: MethodChannel.Result? = null
    
    // 语音识别管理器
    private var speechManager: SpeechRecognizerManager? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 初始化语音识别管理器
        speechManager = SpeechRecognizerManager(this)

        // 语音识别 Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_SPEECH).setMethodCallHandler { call, result ->
            when (call.method) {
                "initialize" -> {
                    val success = speechManager?.initialize() ?: false
                    result.success(success)
                }
                "listen" -> {
                    speechManager?.startListening(result)
                }
                "stop" -> {
                    speechManager?.stopListening()
                    result.success(true)
                }
                "destroy" -> {
                    speechManager?.destroy()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // 文件选择 Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_FILE).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickFile" -> {
                    filePickerResult = result
                    pickFile()
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun pickFile() {
        try {
            val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
                type = "*/*"  // 所有文件类型
                addCategory(Intent.CATEGORY_OPENABLE)
                
                // 允许的文件类型
                putExtra(
                    Intent.EXTRA_MIME_TYPES, arrayOf(
                        "application/pdf",           // PDF
                        "application/msword",        // DOC
                        "application/vnd.openxmlformats-officedocument.wordprocessingml.document",  // DOCX
                        "application/vnd.ms-excel",  // XLS
                        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",  // XLSX
                        "application/vnd.ms-powerpoint",  // PPT
                        "application/vnd.openxmlformats-officedocument.presentationml.presentation",  // PPTX
                        "text/plain",                // TXT
                        "text/csv",                  // CSV
                    )
                )
            }
            startActivityForResult(intent, PICK_FILE_REQUEST_CODE)
            Log.d("FilePicker", "启动文件选择器")
        } catch (e: Exception) {
            Log.e("FilePicker", "启动文件选择器失败: $e")
            filePickerResult?.error("ERROR", "启动文件选择器失败: $e", null)
            filePickerResult = null
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        
        if (requestCode == PICK_FILE_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK && data != null) {
                val uri: Uri? = data.data
                if (uri != null) {
                    // 获取文件信息
                    val fileName = getFileName(uri)
                    val fileSize = getFileSize(uri)
                    val mimeType = contentResolver.getType(uri) ?: "application/octet-stream"
                    
                    // 返回文件信息
                    val result = mapOf(
                        "path" to uri.toString(),
                        "name" to fileName,
                        "size" to fileSize,
                        "type" to mimeType
                    )
                    
                    filePickerResult?.success(result)
                    Log.d("FilePicker", "文件选择成功: $fileName ($fileSize bytes)")
                } else {
                    filePickerResult?.error("ERROR", "未选择文件", null)
                }
            } else {
                filePickerResult?.error("CANCELLED", "用户取消选择", null)
            }
            filePickerResult = null
        }
    }

    private fun getFileName(uri: Uri): String {
        var name = "unknown"
        val cursor = contentResolver.query(uri, null, null, null, null)
        cursor?.use {
            if (it.moveToFirst()) {
                val nameIndex = it.getColumnIndex(android.provider.OpenableColumns.DISPLAY_NAME)
                if (nameIndex >= 0) {
                    name = it.getString(nameIndex)
                }
            }
        }
        return name
    }

    private fun getFileSize(uri: Uri): Long {
        var size = 0L
        val cursor = contentResolver.query(uri, null, null, null, null)
        cursor?.use {
            if (it.moveToFirst()) {
                val sizeIndex = it.getColumnIndex(android.provider.OpenableColumns.SIZE)
                if (sizeIndex >= 0 && !it.isNull(sizeIndex)) {
                    size = it.getLong(sizeIndex)
                }
            }
        }
        return size
    }

    override fun onDestroy() {
        speechManager?.destroy()
        super.onDestroy()
    }
}
