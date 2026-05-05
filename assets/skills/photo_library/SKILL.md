---
name: photo_library
description: 读取相册图片
---

# 相册 Skill

## 功能
从设备相册选择图片。

## 使用方法

### 通过 UI 调用
```markdown
用户：选一张照片
助手：[打开相册界面，等待用户选择]
```

### 通过代码调用
```dart
final imagePath = await ImagePicker().pickImage(
  source: ImageSource.gallery,
);
```

## 参数
- 无需参数（通过 UI 交互）

## 权限要求
- 相册权限 (READ_EXTERNAL_STORAGE)

## 示例
- "选一张照片"
- "打开相册"
- "从相册选图"

## 能力层级
- 属于 L2 增强模式
- 需要开启 L2 能力层

## 实现状态
✅ 已实现（通过 image_picker 插件）
