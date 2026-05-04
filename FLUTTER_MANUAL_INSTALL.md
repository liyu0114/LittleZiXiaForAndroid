# Flutter SDK 手动安装步骤

## 第一步：下载 Flutter SDK

### 方式 1：官网下载（推荐）
1. 打开浏览器
2. 访问：https://docs.flutter.dev/get-started/install/windows
3. 点击蓝色按钮 **"Download Flutter SDK"**
4. 保存 ZIP 文件（约 1GB）

### 方式 2：直接下载链接
复制这个链接到浏览器：
```
https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.19.3-stable.zip
```

## 第二步：解压

### 方法 1：使用资源管理器（推荐）
1. 找到下载的 `flutter_windows_3.19.3-stable.zip`
2. 右键 → 解压到当前位置
3. 将解压出的 `flutter` 文件夹移动到 `C:\`
4. 最终路径应该是：`C:\flutter\bin\flutter.bat`

### 方法 2：使用 7-Zip 或 WinRAR
1. 右键 ZIP 文件 → 7-Zip → 解压到 "flutter\"
2. 将 `flutter` 文件夹移动到 `C:\`

## 第三步：验证

解压完成后，告诉我，我会帮你：
1. 配置环境变量
2. 验证安装
3. 开始构建 App

## 常见问题

**Q: 下载太慢怎么办？**
A: 可以使用下载工具（IDM、FDM）或者让浏览器后台下载

**Q: 解压到哪里？**
A: 必须解压到 `C:\flutter`，不是 `C:\flutter\flutter`

**Q: 需要安装其他东西吗？**
A: 不需要，解压后我会自动配置

## 完成后

解压到 `C:\flutter` 后，在飞书告诉我：**"Flutter 已解压"**

我会立即继续！
