---
name: qr_code
description: 生成和扫描二维码
---

# 二维码 Skill

## 功能
生成和扫描二维码。

## 使用方法

### 生成二维码
```markdown
用户：生成二维码：https://example.com
助手：[显示二维码图片]
```

### 扫描二维码
```markdown
用户：扫描二维码
助手：[打开相机扫描]
```

## 参数
- `content` (string): 二维码内容（生成时）
- `action` (string): generate/scan

## 示例
- "生成二维码：Hello World"
- "扫描二维码"
- "帮我扫码"

## 实现状态
⚠️ 框架已实现（需要添加 qr_flutter 和 qr_code_scanner 插件）
