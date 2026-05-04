# Flutter 手动安装指南

## 方法 1: 官网下载（推荐）

1. 访问 Flutter 官网下载页面：
   https://docs.flutter.dev/get-started/install/windows

2. 下载最新稳定版 ZIP 文件

3. 解压到 `C:\flutter`

4. 添加到系统 PATH：
   - 右键"此电脑" → 属性 → 高级系统设置
   - 环境变量 → 系统变量 → Path → 编辑
   - 新建 → 输入 `C:\flutter\bin`
   - 确定保存

5. 打开新的命令行窗口，验证：
   ```
   flutter --version
   ```

## 方法 2: 使用国内镜像（更快）

如果官网下载慢，使用国内镜像：

1. 设置环境变量：
   ```
   setx PUB_HOSTED_URL "https://pub.flutter-io.cn"
   setx FLUTTER_STORAGE_BASE_URL "https://storage.flutter-io.cn"
   ```

2. 从清华大学镜像下载：
   https://mirrors.tuna.tsinghua.edu.cn/flutter/flutter_infra/releases/stable/windows/

3. 下载最新的 `flutter_windows_x.x.x-stable.zip`

4. 解压到 `C:\flutter`

5. 添加到 PATH（同上）

## 方法 3: 使用 Git（开发者）

```
git clone https://github.com/flutter/flutter.git -b stable C:\flutter
```

## 验证安装

打开新的命令行窗口，运行：
```
flutter doctor
```

如果显示 Flutter 版本信息，说明安装成功！

## 下一步

安装 Android Studio：
https://developer.android.com/studio

然后运行：
```
flutter doctor --android-licenses
flutter doctor
```

## 需要帮助？

如果遇到问题，告诉我具体的错误信息，我会帮你解决。
