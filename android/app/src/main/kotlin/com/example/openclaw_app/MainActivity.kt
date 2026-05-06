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
    private val CHANNEL_ACCESSIBILITY = "com.example.openclaw_app/accessibility"
    private val CHANNEL_LOCAL_MODEL = "com.example.openclaw_app/local_model"
    private val PICK_FILE_REQUEST_CODE = 1001
    private var filePickerResult: MethodChannel.Result? = null
    
    // 语音识别管理器
    private var speechManager: SpeechRecognizerManager? = null
    
    // 本地模型管理器
    private var localModelManager: LocalModelManager? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 初始化语音识别管理器
        speechManager = SpeechRecognizerManager(this)
        
        // 初始化本地模型管理器
        localModelManager = LocalModelManager(this)

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
        
        // 无障碍服务 Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_ACCESSIBILITY).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkEnabled" -> {
                    result.success(LittleZiXiaAccessibilityService.isRunning())
                }
                "openSettings" -> {
                    val intent = Intent(android.provider.Settings.ACTION_ACCESSIBILITY_SETTINGS)
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(intent)
                    result.success(true)
                }
                "getRootNode" -> {
                    val rootNode = LittleZiXiaAccessibilityService.instance?.getRootNode()
                    result.success(rootNode)
                }
                "click" -> {
                    val nodeId = call.argument<String>("nodeId")
                    val success = LittleZiXiaAccessibilityService.instance?.clickNode(nodeId ?: "") ?: false
                    result.success(success)
                }
                "clickAt" -> {
                    val x = call.argument<Double>("x")?.toFloat() ?: 0f
                    val y = call.argument<Double>("y")?.toFloat() ?: 0f
                    val success = LittleZiXiaAccessibilityService.instance?.clickAt(x, y) ?: false
                    result.success(success)
                }
                "inputText" -> {
                    val nodeId = call.argument<String>("nodeId")
                    val text = call.argument<String>("text") ?: ""
                    val success = LittleZiXiaAccessibilityService.instance?.inputText(nodeId ?: "", text) ?: false
                    result.success(success)
                }
                "scroll" -> {
                    val nodeId = call.argument<String>("nodeId")
                    val direction = call.argument<String>("direction") ?: "down"
                    val success = LittleZiXiaAccessibilityService.instance?.scrollNode(nodeId ?: "", direction) ?: false
                    result.success(success)
                }
                "goBack" -> {
                    val success = LittleZiXiaAccessibilityService.instance?.goBack() ?: false
                    result.success(success)
                }
                "goHome" -> {
                    val success = LittleZiXiaAccessibilityService.instance?.goHome() ?: false
                    result.success(success)
                }
                "launchApp" -> {
                    val packageName = call.argument<String>("packageName") ?: ""
                    val success = LittleZiXiaAccessibilityService.instance?.launchApp(packageName) ?: false
                    result.success(success)
                }
                "getCurrentPackage" -> {
                    val package = LittleZiXiaAccessibilityService.instance?.getCurrentPackage()
                    result.success(package)
                }
                else -> result.notImplemented()
            }
        }
        
        // 本地模型 Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_LOCAL_MODEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getModels" -> {
                    val models = localModelManager?.getModels() ?: emptyList()
                    val modelList = models.map { mapOf(
                        "id" to it.id,
                        "name" to it.name,
                        "sizeMB" to it.sizeMB,
                        "contextLength" to it.contextLength
                    )}
                    result.success(modelList)
                }
                "loadModel" -> {
                    val modelId = call.argument<String>("modelId") ?: ""
                    localModelManager?.loadModel(modelId) { success, error ->
                        if (success) {
                            result.success(true)
                        } else {
                            result.error("LOAD_FAILED", error, null)
                        }
                    }
                }
                "generate" -> {
                    val prompt = call.argument<String>("prompt") ?: ""
                    val maxTokens = call.argument<Int>("maxTokens") ?: 256
                    val temperature = call.argument<Double>("temperature")?.toFloat() ?: 0.7f
                    
                    val response = StringBuffer()
                    localModelManager?.generate(prompt, maxTokens, temperature) { token, done ->
                        response.append(token)
                        if (done) {
                            result.success(response.toString())
                        }
                    }
                }
                "unload" -> {
                    localModelManager?.unloadModel()
                    result.success(true)
                }
                "isLoaded" -> {
                    result.success(localModelManager?.isLoaded() ?: false)
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
