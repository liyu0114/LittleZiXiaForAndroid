# Quick Start - OpenClaw Mobile

## 最快上手指南

### 第一步：安装 Flutter

```bash
# 下载 Flutter SDK
https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.19.3-stable.zip

# 解压到 C:\flutter

# 添加到 PATH
# 系统属性 → 环境变量 → Path → 添加 C:\flutter\bin
```

### 第二步：安装 Android Studio

```bash
# 下载安装
https://developer.android.com/studio

# 打开后会自动安装 Android SDK
```

### 第三步：构建 App

```bash
# 进入项目目录
cd C:\Users\Administrator\.openclaw\workspace\mobile-client\openclaw_app

# 安装依赖
flutter pub get

# 构建 APK
flutter build apk
```

### 第四步：安装到手机

1. 将 `build/app/outputs/flutter-apk/app-release.apk` 传到手机
2. 在手机上打开 APK 安装
3. 允许"安装未知来源应用"

### 第五步：配置 Tailscale

见 `docs/TAILSCALE_SETUP.md`

### 第六步：使用 App

1. 打开 App
2. 进入设置，配置：
   - Gateway URL: `http://100.80.206.8:18789`
   - Token: (从 `C:\Users\Administrator\.openclaw\gateway.cmd` 获取)
3. 点击连接按钮
4. 开始发送消息！

---

## 常见问题

**Q: Flutter 下载太慢怎么办？**

A: 使用国内镜像：
```bash
set PUB_HOSTED_URL=https://pub.flutter-io.cn
set FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
```

**Q: 找不到 Android SDK？**

A: 设置环境变量：
```bash
setx ANDROID_HOME "C:\Users\Administrator\AppData\Local\Android\Sdk"
```

**Q: 构建失败？**

A: 清理后重试：
```bash
flutter clean
flutter pub get
flutter build apk
```

---

## 代码已完成！

所有核心代码已写好：

✅ SDK - `packages/openclaw_sdk`
✅ App - `packages/openclaw_app`
✅ Tailscale 配置指南 - `docs/TAILSCALE_SETUP.md`
✅ 构建指南 - `BUILD.md`

只需安装 Flutter 和 Android Studio，然后运行 `flutter build apk` 即可！
