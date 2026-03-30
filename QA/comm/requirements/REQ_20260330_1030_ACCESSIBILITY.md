# 需求：无障碍服务对接手机 APP

**需求编号:** REQ_20260330_1030
**优先级:** P0
**状态:** 待确认
**提出人:** Liyu
**时间:** 2026-03-30 10:30

---

## 一、需求背景

让小紫霞像人一样能够使用手机上已安装的 APP，通过官方合法渠道实现。

## 二、技术方案

### 2.1 前台服务 (Foreground Service)

**作用：** 确保 AI 应用在后台持续运行不被系统杀死

**支持的服务类型：**

| 类型 | 能力 | 权限要求 |
|------|------|----------|
| microphone | 后台持续监听音频 | RECORD_AUDIO |
| mediaProjection | 实时捕获屏幕内容 | createScreenCaptureIntent() |
| phoneCall | 管理通话 | MANAGE_OWN_CALLS |
| remoteMessaging | 设备间消息同步 | - |
| shortService | 短时关键任务（约3分钟） | - |

### 2.2 无障碍服务 (Accessibility Service)

**核心能力：**

1. **感知屏幕内容**
   - 实时获取屏幕上所有 UI 元素信息
   - 识别文本、按钮、列表等

2. **模拟用户操作**
   - 点击、长按
   - 输入文本
   - 滑动、滚动

3. **监听全局事件**
   - 应用切换
   - 通知弹出
   - 窗口状态变化

## 三、开发计划

### Phase 1: 基础框架（预计 4 小时）

1. **Android 原生层**
   - 创建 `AccessibilityService` 子类
   - 配置 `accessibility_service_config.xml`
   - 实现基础事件监听

2. **Flutter 层**
   - 创建 `accessibility_service.dart`
   - 实现方法通道 (MethodChannel)
   - 封装常用操作 API

### Phase 2: 屏幕感知（预计 3 小时）

1. 解析 `AccessibilityNodeInfo`
2. 提取 UI 元素树
3. 文本内容识别
4. 可操作元素识别

### Phase 3: 操作执行（预计 3 小时）

1. 点击操作
2. 文本输入
3. 滚动操作
4. 返回/主页/最近任务

### Phase 4: 应用知识库（预计 4 小时）

1. 设计应用操作脚本格式
2. 内置主流应用脚本（微信、支付宝等）
3. LLM 辅助理解未知应用

## 四、用户交互流程

```
用户: "帮我给张三发微信说我要迟到了"
  ↓
小紫霞:
  1. 打开微信
  2. 找到张三的聊天
  3. 输入消息
  4. 发送
  ↓
反馈: "已发送"
```

## 五、权限配置

**AndroidManifest.xml:**
```xml
<!-- 前台服务 -->
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MICROPHONE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PROJECTION" />

<!-- 无障碍服务 -->
<uses-permission android:name="android.permission.BIND_ACCESSIBILITY_SERVICE" />

<!-- 录音 -->
<uses-permission android:name="android.permission.RECORD_AUDIO" />
```

## 六、待确认问题

1. **优先实现哪些应用的操作脚本？**
   - 微信（发消息、朋友圈）
   - 支付宝（付款、转账）
   - 其他？

2. **是否需要屏幕截图能力（mediaProjection）？**
   - 用于 AI 视觉理解屏幕内容
   - 需要额外权限申请

3. **语音唤醒是否需要后台持续监听？**
   - 需要 microphone 前台服务
   - 耗电影响

---

**等待确认后开始开发。**
