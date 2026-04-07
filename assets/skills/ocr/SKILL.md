---
name: ocr
version: 1.0.0
description: 文字识别（OCR）。从图片、照片中提取文字。支持多语言、手写体、表格识别。
metadata:
  openclaw:
    emoji: "🔍"
    category: vision
    platform: mobile
    requires:
      permissions: [camera, photo_library]
---

# 文字识别（OCR）🔍

从图片中提取文字，支持印刷体和手写体。

## 使用场景

- **识别文档** - 拍照提取纸质文档文字
- **翻译菜单** - 国外旅游拍菜单自动翻译
- **提取名片** - 拍照保存联系人信息
- **识别截图** - 从截图中提取代码或文字
- **扫描二维码** - 读取二维码内容

## 功能

### 1. 从图片提取文字

```dart
final result = await OCR.recognize(
  imagePath: "/path/to/image.jpg",
);
print(result.text);
```

### 2. 从摄像头实时识别

```dart
final result = await OCR.recognizeFromCamera(
  language: "zh-CN",
);
```

### 3. 多语言支持

**支持语言：**
- 🇨🇳 中文（简体/繁体）
- 🇺🇸 英文
- 🇯🇵 日文
- 🇰🇷 韩文
- 🇫🇷 法文
- 🇩🇪 德文
- 🇷🇺 俄文
- 🇪🇸 西班牙文

### 4. 手写体识别

```dart
final result = await OCR.recognize(
  imagePath: "/path/to/handwriting.jpg",
  mode: OCRMode.handwriting,
);
```

### 5. 表格识别

```dart
final table = await OCR.recognizeTable(
  imagePath: "/path/to/table.jpg",
);
print(table.rows);  // 表格行数据
```

### 6. 结构化识别

```dart
final result = await OCR.recognize(
  imagePath: "/path/to/document.jpg",
  structured: true,
);

// 获取文字块和位置
for (final block in result.blocks) {
  print("${block.text} at ${block.boundingBox}");
}
```

## 使用方式

### AI 助手调用

```
用户：识别这张图片里的文字
[用户上传图片]
AI：
识别结果：
"床前明月光，疑是地上霜。
举头望明月，低头思故乡。"

[复制] [翻译] [分享]
```

```
用户：帮我识别这个名片
[用户上传名片照片]
AI：
已识别名片信息：
- 姓名：张三
- 电话：138****1234
- 邮箱：zhangsan@example.com
- 公司：科技有限公司

[保存到通讯录] [复制]
```

### 执行流程

1. **获取图片**
   ```dart
   // 方式1：从相册选择
   final image = await ImagePicker.pickImage(source: ImageSource.gallery);

   // 方式2：拍照
   final image = await ImagePicker.pickImage(source: ImageSource.camera);
   ```

2. **识别文字**
   ```dart
   final result = await OCR.recognize(
     imagePath: image.path,
     language: "zh-CN",
   );
   ```

3. **处理结果**
   ```dart
   if (result.success) {
     final text = result.text;
     final confidence = result.confidence;  // 置信度 0-1

     if (confidence < 0.8) {
       // 提示用户可能不准确
     }
   }
   ```

## 技术实现

### 本地 OCR（ML Kit）

```dart
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

final recognizer = TextRecognizer(script: TextRecognitionScript.chinese);
final inputImage = InputImage.fromFilePath(imagePath);
final result = await recognizer.processImage(inputImage);

for (final block in result.blocks) {
  print(block.text);
}
```

**优点：**
- 无需网络
- 隐私安全
- 速度快（<1 秒）

**缺点：**
- 精度略低于云服务
- 不支持复杂版面

### 云端 OCR（可选）

```dart
final result = await CloudOCR.recognize(
  imagePath: image.path,
  provider: OCRProvider.baidu,  // 或 tencent, ali
);
```

**优点：**
- 精度更高
- 支持复杂版面
- 支持更多语言

**缺点：**
- 需要网络
- 需要上传图片
- 可能有费用

## 使用示例

### 识别文档

```
用户：识别这个文档
[上传文档照片]
AI：
识别结果（置信度 95%）：
"合同编号：2026-001

甲方：张三
乙方：李四

双方就以下事项达成一致..."

[复制全文] [保存为笔记] [翻译]
```

### 识别并翻译

```
用户：识别并翻译这段英文
[上传英文图片]
AI：
原文：
"To be or not to be, that is the question."

翻译：
"生存还是毁灭，这是一个问题。"
```

### 提取联系人

```dart
final result = await OCR.recognize(imagePath);
final contact = ContactParser.parse(result.text);

// contact.name = "张三"
// contact.phone = "138****1234"
// contact.email = "zhangsan@example.com"

await ContactsService.addContact(contact);
```

### 识别代码

```
用户：识别这段代码
[上传代码截图]
AI：
识别结果：
```python
def hello():
    print("Hello, World!")
```

[复制代码]
```

## 配置

### 基础配置

```yaml
ocr:
  engine: "local"  # 或 "cloud"
  language: "zh-CN"
  fallback_to_cloud: true  # 本地失败时使用云端
```

### 云端配置

```yaml
ocr:
  engine: "cloud"
  provider: "baidu"
  api_key: "your-api-key"
  secret_key: "your-secret-key"
```

### 高级配置

```yaml
ocr:
  preprocessing:
    auto_rotate: true  # 自动旋转
    denoise: true  # 降噪
    enhance: true  # 增强对比度

  postprocessing:
    remove_line_breaks: false  # 移除换行
    fix_common_errors: true  # 修正常见错误
```

## 常见问题

**Q: 识别不准确？**
A:
- 确保图片清晰、光线充足
- 文字不要太小或模糊
- 尝试使用云端 OCR（精度更高）

**Q: 手写体识别不了？**
A: 手写体需要更清晰的字迹，或使用云端 OCR。

**Q: 支持 PDF 吗？**
A: 需要先转换为图片，然后识别。

**Q: 耗电吗？**
A: 本地 OCR 使用 NPU 加速，耗电很少。云端 OCR 需要上传数据。

## 性能指标

| 指标 | 本地 OCR | 云端 OCR |
|-----|---------|---------|
| 速度 | <1 秒 | 2-3 秒 |
| 精度（印刷体） | 95% | 99% |
| 精度（手写体） | 80% | 95% |
| 网络需求 | 无 | 必需 |
| 隐私 | 本地处理 | 上传云端 |
| 费用 | 免费 | 可能收费 |

## 权限需求

- ✅ **摄像头** - 拍照识别
- ✅ **相册** - 从相册选择图片
- ⭕ **网络** - 云端 OCR 需要时

---

*图片变文字，信息随手得。* 🔍

**作者：** OpenClaw Community
