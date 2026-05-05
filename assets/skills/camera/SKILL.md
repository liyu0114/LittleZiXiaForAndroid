---
name: camera
description: 访问相机拍照
---

# 相机 Skill

## 功能
打开设备相机进行拍照。

## 使用方法

### 通过 UI 调用
```markdown
用户：拍张照片
助手：[打开相机界面，等待用户拍照]
```

### 通过代码调用
```dart
final imagePath = await ImagePicker().pickImage(
  source: ImageSource.camera,
);
```

## 参数
- 无需参数（通过 UI 交互）

## 权限要求
- 相机权限 (CAMERA)
- 存储权限 (WRITE_EXTERNAL_STORAGE)

## 示例
- "拍张照片"
- "打开相机"
- "帮我拍个照"

## 能力层级
- 属于 L2 增强模式
- 需要开启 L2 能力层

## 实现状态
✅ 已实现（通过 image_picker 插件）
