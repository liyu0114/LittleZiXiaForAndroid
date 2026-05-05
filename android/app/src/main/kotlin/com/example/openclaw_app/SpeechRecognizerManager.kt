package com.example.openclaw_app

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.util.Log
import io.flutter.plugin.common.MethodChannel

/**
 * 语音识别管理器
 * 使用 Android 原生 SpeechRecognizer API
 */
class SpeechRecognizerManager(private val context: Context) {
    private var speechRecognizer: SpeechRecognizer? = null
    private var resultCallback: MethodChannel.Result? = null
    private var isListening = false

    companion object {
        private const val TAG = "SpeechRecognizer"
    }

    /**
     * 初始化语音识别器
     */
    fun initialize(): Boolean {
        return try {
            if (speechRecognizer == null) {
                speechRecognizer = SpeechRecognizer.createSpeechRecognizer(context)
                speechRecognizer?.setRecognitionListener(object : RecognitionListener {
                    override fun onReadyForSpeech(params: Bundle?) {
                        Log.d(TAG, "准备好接收语音")
                    }

                    override fun onBeginningOfSpeech() {
                        Log.d(TAG, "开始说话")
                    }

                    override fun onRmsChanged(rmsdB: Float) {
                        // 音量变化，可用于 UI 反馈
                    }

                    override fun onBufferReceived(buffer: ByteArray?) {
                        // 收到音频数据
                    }

                    override fun onEndOfSpeech() {
                        Log.d(TAG, "说话结束")
                        isListening = false
                    }

                    override fun onError(error: Int) {
                        val errorMessage = getErrorMessage(error)
                        Log.e(TAG, "语音识别错误: $errorMessage (code: $error)")
                        isListening = false
                        resultCallback?.error("ERROR", errorMessage, error)
                        resultCallback = null
                    }

                    override fun onResults(results: Bundle?) {
                        val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                        val result = matches?.firstOrNull() ?: ""
                        Log.d(TAG, "识别结果: $result")
                        isListening = false
                        resultCallback?.success(result)
                        resultCallback = null
                    }

                    override fun onPartialResults(partialResults: Bundle?) {
                        // 部分结果，可用于实时显示
                        val matches = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                        val partial = matches?.firstOrNull() ?: ""
                        Log.d(TAG, "部分结果: $partial")
                    }

                    override fun onEvent(eventType: Int, params: Bundle?) {
                        Log.d(TAG, "事件: $eventType")
                    }
                })
            }
            Log.d(TAG, "语音识别器初始化成功")
            true
        } catch (e: Exception) {
            Log.e(TAG, "语音识别器初始化失败: ${e.message}")
            false
        }
    }

    /**
     * 开始语音识别
     */
    fun startListening(result: MethodChannel.Result) {
        if (isListening) {
            Log.w(TAG, "已在监听中")
            result.error("BUSY", "已在监听中", null)
            return
        }

        if (speechRecognizer == null) {
            Log.e(TAG, "语音识别器未初始化")
            result.error("NOT_INITIALIZED", "语音识别器未初始化", null)
            return
        }

        resultCallback = result
        isListening = true

        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, "zh-CN")  // 默认中文
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)  // 启用部分结果
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)  // 只返回最佳结果
            putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, context.packageName)
        }

        try {
            speechRecognizer?.startListening(intent)
            Log.d(TAG, "开始监听语音...")
        } catch (e: Exception) {
            Log.e(TAG, "启动监听失败: ${e.message}")
            isListening = false
            result.error("ERROR", "启动监听失败: ${e.message}", null)
            resultCallback = null
        }
    }

    /**
     * 停止语音识别
     */
    fun stopListening() {
        if (isListening) {
            speechRecognizer?.stopListening()
            isListening = false
            Log.d(TAG, "停止监听")
        }
    }

    /**
     * 取消语音识别
     */
    fun cancel() {
        speechRecognizer?.cancel()
        isListening = false
        resultCallback?.error("CANCELLED", "用户取消", null)
        resultCallback = null
        Log.d(TAG, "取消识别")
    }

    /**
     * 销毁语音识别器
     */
    fun destroy() {
        speechRecognizer?.destroy()
        speechRecognizer = null
        isListening = false
        resultCallback = null
        Log.d(TAG, "语音识别器已销毁")
    }

    /**
     * 获取错误信息
     */
    private fun getErrorMessage(errorCode: Int): String {
        return when (errorCode) {
            SpeechRecognizer.ERROR_AUDIO -> "音频录制错误"
            SpeechRecognizer.ERROR_CLIENT -> "客户端错误"
            SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "权限不足"
            SpeechRecognizer.ERROR_NETWORK -> "网络错误"
            SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "网络超时"
            SpeechRecognizer.ERROR_NO_MATCH -> "无法识别"
            SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "识别器忙"
            SpeechRecognizer.ERROR_SERVER -> "服务器错误"
            SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "未检测到语音"
            else -> "未知错误 ($errorCode)"
        }
    }
}
