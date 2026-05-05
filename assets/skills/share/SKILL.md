---
name: share
version: 1.0.0
description: 系统分享面板。快速分享文本、图片、文件到其他应用（微信、QQ、邮件等）。支持多种内容类型。
metadata:
  openclaw:
    emoji: "📤"
    category: system
    platform: mobile
    requires:
      permissions: []
---

# 系统分享 📤

调用系统分享面板，快速分享内容到其他应用。

## 使用场景

- **分享文本** - 快速复制链接、代码片段到微信/QQ
- **分享图片** - 把生成的图片发到朋友圈
- **分享文件** - 发送文档、PDF 到邮件或其他应用
- **跨应用协作** - 把内容传到其他 App

## 功能

### 1. 分享文本

```dart
Share.text(
  text: "这是一段要分享的文本",
  subject: "主题（邮件用）",
);
```

**效果：** 弹出系统分享面板，选择目标应用。

### 2. 分享图片

```dart
Share.image(
  imagePath: "/path/to/image.png",
  text: "图片说明（可选）",
);
```

**支持格式：** PNG, JPG, GIF, WEBP

### 3. 分享文件

```dart
Share.file(
  filePath: "/path/to/document.pdf",
  mimeType: "application/pdf",
  text: "文件说明（可选）",
);
```

**常用 MIME 类型：**
- `application/pdf` - PDF
- `application/zip` - ZIP 压缩包
- `text/plain` - 纯文本
- `application/json` - JSON 文件

### 4. 分享多种内容

```dart
Share.multiple(
  texts: ["文本1", "文本2"],
  imagePaths: ["/path/to/image1.png", "/path/to/image2.jpg"],
  filePaths: ["/path/to/file.pdf"],
);
```

### 5. 分享到指定应用

```dart
Share.toApp(
  app: ShareApp.wechat,
  text: "分享到微信",
);
```

**预设应用：**
- `wechat` - 微信
- `qq` - QQ
- `email` - 邮件
- `sms` - 短信
- `clipboard` - 剪贴板

## 使用方式

### AI 助手调用

```
用户：把这段代码分享出去
AI：[弹出分享面板] 选择要分享的应用...
```

```
用户：分享到微信
AI：已分享到微信。
```

```
用户：把这张图片发到朋友圈
AI：[调用微信分享图片]
```

### 执行流程

1. **准备内容**
   ```dart
   final content = ShareContent(
     type: ShareType.text,
     text: "要分享的文本",
   );
   ```

2. **调用系统分享**
   ```dart
   await Share.share(content);
   ```

3. **系统弹出分享面板**
   - 显示所有可分享的应用
   - 用户选择目标应用
   - 内容传递给目标应用

## 技术实现

### Android（Intent）

```kotlin
val intent = Intent(Intent.ACTION_SEND).apply {
    type = "text/plain"
    putExtra(Intent.EXTRA_TEXT, text)
    putExtra(Intent.EXTRA_SUBJECT, subject)
}
startActivity(Intent.createChooser(intent, "分享到"))
```

### iOS（UIActivityViewController）

```swift
let activityVC = UIActivityViewController(
    activityItems: [text, image],
    applicationActivities: nil
)
present(activityVC, animated: true)
```

### Flutter（share_plus）

```dart
import 'package:share_plus/share_plus.dart';

// 分享文本
await Share.share(
  text,
  subject: subject,
);

// 分享文件
await Share.shareXFiles(
  [XFile(path)],
  text: description,
);
```

## 使用示例

### 分享 AI 生成的文本

```
用户：生成一首诗，然后分享给朋友
AI：
已生成诗歌：
"床前明月光，疑是地上霜..."

[分享按钮] [复制]

用户：[点击分享]
AI：[弹出分享面板]
```

### 分享截图

```
用户：截图并分享
AI：
1. 截图当前屏幕
2. 弹出分享面板
3. 选择目标应用
```

### 分享位置

```dart
Share.location(
  latitude: 39.9042,
  longitude: 116.4074,
  address: "北京市东城区天安门",
);
```

**分享内容：**
```
📍 我的位置
北京市东城区天安门
https://maps.google.com/?q=39.9042,116.4074
```

### 分享链接

```dart
Share.link(
  url: "https://example.com/article",
  title: "有趣的文章",
  description: "推荐阅读这篇文章",
);
```

**分享内容：**
```
有趣的文章
推荐阅读这篇文章
https://example.com/article
```

## 高级功能

### 自定义分享面板标题

```dart
Share.share(
  content,
  title: "选择分享方式",  // Android
);
```

### 排除特定应用

```dart
Share.share(
  content,
  excludedApps: ["com.some.app"],  // Android
);
```

### 获取分享结果

```dart
final result = await Share.share(content);

if (result.status == ShareResultStatus.success) {
  print("分享成功");
} else if (result.status == ShareResultStatus.dismissed) {
  print("用户取消");
}
```

### 后台分享（无需用户交互）

```dart
// 直接分享到指定应用，不显示面板
Share.shareDirectly(
  app: ShareApp.wechat,
  content: content,
);
```

## 常见问题

**Q: 分享面板没有我想要的应用？**
A: 系统只显示支持该内容类型的应用。分享图片时，只显示支持图片的应用。

**Q: 分享到微信失败？**
A: 检查微信是否安装，是否有分享权限。部分应用需要额外的 SDK 支持。

**Q: iOS 分享后无回调？**
A: iOS 的 `UIActivityViewController` 不提供完成回调，无法确定是否分享成功。

**Q: 可以静默分享吗？**
A: 出于隐私考虑，系统要求用户确认分享操作，无法完全静默。

## 权限需求

- ✅ **Android** - 通常无需特殊权限
- ✅ **iOS** - 无需权限

## 注意事项

- **用户体验** - 分享面板会中断当前流程，适合明确的分享意图
- **内容长度** - 部分应用有内容长度限制
- **图片大小** - 大图可能被压缩
- **隐私** - 确保不分享敏感信息

---

*一键分享，连接万物。* 📤

**作者：** OpenClaw Community
