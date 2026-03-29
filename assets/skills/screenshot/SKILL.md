---
name: screenshot
description: 截取屏幕（需要 ADB）
---

# 截屏 Skill

## 功能
截取当前屏幕画面。

## 使用方法

### 通过 ADB 命令
```bash
adb shell screencap -p /sdcard/screenshot.png
adb pull /sdcard/screenshot.png
```

## 参数
- `save_path` (string): 保存路径（可选）

## 权限要求
- ADB 调试权限
- 需要 L3 系统模式授权

## 示例
- "截个屏"
- "截屏"
- "帮我截图"

## 能力层级
- 属于 L3 系统模式
- 需要开启 L3 能力层并授权 ADB

## 实现状态
⚠️ 框架已实现，但需要 ADB 授权后才能使用
