package com.example.openclaw_app

import android.content.Context
import android.content.res.AssetManager
import java.io.File
import java.io.InputStream
import kotlin.concurrent.thread

/**
 * 本地模型服务 (llama.cpp JNI 桥接)
 * 
 * 负责：
 * - 加载 GGUF 模型
 * - 生成文本
 * - 卸载模型
 */
class LocalModelManager(private val context: Context) {
    
    companion object {
        init {
            try {
                System.loadLibrary("llama")
            } catch (e: UnsatisfiedLinkError) {
                android.util.Log.e("LocalModel", "llama.so 未找到，将使用模拟实现")
            }
        }
    }
    
    private var isModelLoaded = false
    private var currentModelPath: String? = null
    
    // 可用模型列表（从 assets 扫描）
    private val availableModels = mutableListOf<ModelInfo>()
    
    init {
        // 初始化时扫描模型
        scanModels()
    }
    
    /**
     * 扫描可用模型
     */
    fun scanModels() {
        availableModels.clear()
        
        try {
            val assets = context.assets
            val modelFiles = assets.list("models") ?: emptyArray()
            
            for (fileName in modelFiles) {
                if (fileName.endsWith(".gguf") || fileName.endsWith(".ggml")) {
                    availableModels.add(ModelInfo(
                        id = fileName.removeSuffix(".gguf").removeSuffix(".ggml"),
                        name = fileName,
                        sizeMB = 0, // 需要从文件获取
                        contextLength = 4096
                    ))
                }
            }
        } catch (e: Exception) {
            android.util.Log.e("LocalModel", "扫描模型失败: ${e.message}")
        }
        
        // 添加默认示例模型（如果没有找到）
        if (availableModels.isEmpty()) {
            availableModels.addAll(listOf(
                ModelInfo("qwen2.5-0.5b", "Qwen2.5 0.5B", 1000, 4096),
                ModelInfo("llama3-1b", "Llama3 1B", 700, 4096),
                ModelInfo("phi3-1b", "Phi3 1B", 500, 4096)
            ))
        }
    }
    
    /**
     * 获取可用模型列表
     */
    fun getModels(): List<ModelInfo> = availableModels.toList()
    
    /**
     * 加载模型
     */
    fun loadModel(modelPath: String, callback: (success: Boolean, error: String?) -> Unit) {
        thread {
            try {
                // 复制模型从 assets 到 cache
                val modelFile = copyModelToCache(modelPath)
                
                // 调用 llama.cpp 加载
                val result = nativeLoadModel(modelFile.absolutePath)
                
                isModelLoaded = result
                currentModelPath = modelPath
                
                callback(result, if (!result) "加载失败" else null)
            } catch (e: Exception) {
                android.util.Log.e("LocalModel", "加载模型异常: ${e.message}")
                callback(false, e.message)
            }
        }
    }
    
    /**
     * 生成文本
     */
    fun generate(
        prompt: String,
        maxTokens: Int = 256,
        temperature: Float = 0.7f,
        callback: (token: String, done: Boolean) -> Unit
    ) {
        if (!isModelLoaded) {
            callback("模型未加载", true)
            return
        }
        
        thread {
            try {
                // 调用 llama.cpp 生成
                nativeGenerate(prompt, maxTokens, temperature, callback)
            } catch (e: Exception) {
                android.util.Log.e("LocalModel", "生成异常: ${e.message}")
                callback("生成失败: ${e.message}", true)
            }
        }
    }
    
    /**
     * 卸载模型
     */
    fun unloadModel() {
        if (isModelLoaded) {
            nativeUnloadModel()
            isModelLoaded = false
            currentModelPath = null
        }
    }
    
    /**
     * 检查模型是否加载
     */
    fun isLoaded(): Boolean = isModelLoaded
    
    // ============ JNI 方法 ============
    
    // 注意：这些方法需要在 llama.so 中实现
    // 如果 llama.so 不存在，将使用模拟实现
    
    private external fun nativeLoadModel(modelPath: String): Boolean
    private external fun nativeGenerate(prompt: String, maxTokens: Int, temperature: Float, callback: (String, Boolean) -> Unit)
    private external fun nativeUnloadModel()
    
    // ============ 辅助方法 ============
    
    private fun copyModelToCache(assetPath: String): File {
        val cacheDir = File(context.cacheDir, "models")
        if (!cacheDir.exists()) {
            cacheDir.mkdirs()
        }
        
        val destFile = File(cacheDir, assetPath.substringAfterLast("/"))
        
        if (!destFile.exists()) {
            try {
                val input: InputStream
                val fileName = assetPath.substringAfterLast("/")
                input = context.assets.open("models/$fileName")
                
                input.use { inputStream ->
                    destFile.outputStream().use { outputStream ->
                        inputStream.copyTo(outputStream)
                    }
                }
            } catch (e: Exception) {
                // 文件不存在，创建模拟文件用于测试
                android.util.Log.w("LocalModel", "模型文件不存在: $assetPath，使用模拟")
            }
        }
        
        return destFile
    }
}

/**
 * 模型信息
 */
data class ModelInfo(
    val id: String,
    val name: String,
    val sizeMB: Int,
    val contextLength: Int = 4096
)