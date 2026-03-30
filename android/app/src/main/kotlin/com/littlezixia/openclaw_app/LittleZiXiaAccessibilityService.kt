package com.littlezixia.openclaw_app

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.content.Intent
import android.graphics.Path
import android.graphics.Rect
import android.os.Bundle
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import io.flutter.plugin.common.MethodChannel

class LittleZiXiaAccessibilityService : AccessibilityService() {
    
    companion object {
        var instance: LittleZiXiaAccessibilityService? = null
        var channel: MethodChannel? = null
        
        fun isRunning(): Boolean = instance != null
    }
    
    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        channel?.invokeMethod("onServiceConnected", null)
    }
    
    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // 处理无障碍事件
        when (event?.eventType) {
            AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED -> {
                // 窗口状态改变
                val packageName = event.packageName?.toString()
                val className = event.className?.toString()
                val args = hashMapOf<String, Any?>(
                    "packageName" to packageName,
                    "className" to className
                )
                channel?.invokeMethod("onWindowChanged", args)
            }
            AccessibilityEvent.TYPE_NOTIFICATION_STATE_CHANGED -> {
                // 通知状态改变
                val text = event.text?.joinToString("\n")
                val args = hashMapOf<String, Any?>(
                    "text" to text,
                    "packageName" to event.packageName?.toString()
                )
                channel?.invokeMethod("onNotification", args)
            }
        }
    }
    
    override fun onInterrupt() {
        // 中断处理
    }
    
    override fun onDestroy() {
        super.onDestroy()
        instance = null
        channel?.invokeMethod("onServiceDisconnected", null)
    }
    
    // 获取根节点
    fun getRootNode(): Map<String, Any?>? {
        val rootNode = rootInActiveWindow ?: return null
        return nodeToMap(rootNode)
    }
    
    // 将 AccessibilityNodeInfo 转换为 Map
    private fun nodeToMap(node: AccessibilityNodeInfo): Map<String, Any?> {
        val bounds = Rect()
        node.getBoundsInScreen(bounds)
        
        val children = mutableListOf<Map<String, Any?>>()
        for (i in 0 until node.childCount) {
            node.getChild(i)?.let { child ->
                children.add(nodeToMap(child))
                child.recycle()
            }
        }
        
        return hashMapOf(
            "id" to node.viewIdResourceName,
            "text" to node.text?.toString(),
            "contentDescription" to node.contentDescription?.toString(),
            "className" to node.className?.toString(),
            "bounds" to hashMapOf(
                "left" to bounds.left,
                "top" to bounds.top,
                "width" to bounds.width(),
                "height" to bounds.height()
            ),
            "isClickable" to node.isClickable,
            "isScrollable" to node.isScrollable,
            "isEditable" to node.isEditable,
            "isChecked" to node.isChecked,
            "isEnabled" to node.isEnabled,
            "children" to children
        )
    }
    
    // 点击节点
    fun clickNode(nodeId: String): Boolean {
        val rootNode = rootInActiveWindow ?: return false
        val node = findNodeById(rootNode, nodeId) ?: return false
        val result = node.performAction(AccessibilityNodeInfo.ACTION_CLICK)
        node.recycle()
        return result
    }
    
    // 点击坐标
    fun clickAt(x: Float, y: Float): Boolean {
        val path = Path()
        path.moveTo(x, y)
        
        val gesture = GestureDescription.Builder()
            .addStroke(GestureDescription.StrokeDescription(path, 0, 100))
            .build()
        
        return dispatchGesture(gesture, null, null)
    }
    
    // 输入文本
    fun inputText(nodeId: String, text: String): Boolean {
        val rootNode = rootInActiveWindow ?: return false
        val node = findNodeById(rootNode, nodeId) ?: return false
        
        val args = Bundle()
        args.putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, text)
        val result = node.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
        
        node.recycle()
        return result
    }
    
    // 滚动
    fun scrollNode(nodeId: String, direction: String): Boolean {
        val rootNode = rootInActiveWindow ?: return false
        val node = findNodeById(rootNode, nodeId) ?: return false
        
        val action = when (direction) {
            "up" -> AccessibilityNodeInfo.ACTION_SCROLL_BACKWARD
            "down" -> AccessibilityNodeInfo.ACTION_SCROLL_FORWARD
            "left" -> AccessibilityNodeInfo.ACTION_SCROLL_BACKWARD
            "right" -> AccessibilityNodeInfo.ACTION_SCROLL_FORWARD
            else -> return false
        }
        
        val result = node.performAction(action)
        node.recycle()
        return result
    }
    
    // 返回
    fun goBack(): Boolean {
        return performGlobalAction(GLOBAL_ACTION_BACK)
    }
    
    // 回到主页
    fun goHome(): Boolean {
        return performGlobalAction(GLOBAL_ACTION_HOME)
    }
    
    // 打开最近任务
    fun openRecents(): Boolean {
        return performGlobalAction(GLOBAL_ACTION_RECENTS)
    }
    
    // 启动应用
    fun launchApp(packageName: String): Boolean {
        val intent = packageManager.getLaunchIntentForPackage(packageName) ?: return false
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
        return true
    }
    
    // 获取当前包名
    fun getCurrentPackage(): String? {
        val rootNode = rootInActiveWindow ?: return null
        return rootNode.packageName?.toString()
    }
    
    // 查找节点
    private fun findNodeById(node: AccessibilityNodeInfo, nodeId: String): AccessibilityNodeInfo? {
        if (node.viewIdResourceName == nodeId) {
            return node
        }
        
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            val found = findNodeById(child, nodeId)
            if (found != null) return found
            child.recycle()
        }
        
        return null
    }
}
