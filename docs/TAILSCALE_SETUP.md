# Tailscale 安装配置指南

## 📱 手机端安装 Tailscale

### Android / HarmonyOS

#### 步骤 1: 下载 Tailscale App

**方式 A: Google Play Store（推荐）**
```
1. 打开 Google Play Store
2. 搜索 "Tailscale"
3. 点击"安装"
```

**方式 B: 华为应用市场**
```
1. 打开华为应用市场
2. 搜索 "Tailscale"
3. 如果没有，需要从官网下载 APK
```

**方式 C: 官网下载 APK**
```
1. 访问: https://tailscale.com/download/android
2. 下载最新版 APK
3. 安装（需要允许"安装未知来源应用"）
```

#### 步骤 2: 注册 Tailscale 账号

```
1. 打开 Tailscale App
2. 选择注册方式:
   - Google 账号（推荐）
   - Microsoft 账号
   - GitHub 账号
   - 邮箱注册
3. 完成邮箱验证
```

#### 步骤 3: 连接到 Tailscale 网络

```
1. 登录后，点击 "Get Started"
2. 授予 VPN 权限（重要！）
3. 点击 "Connect" 按钮
4. 等待连接成功（显示绿色对勾 ✓）
```

#### 步骤 4: 验证连接

```
1. 在 Tailscale App 中查看状态
2. 应该显示:
   - Status: Connected
   - IP: 100.x.x.x
3. 点击你的机器名，可以看到分配的 IP
```

---

## 💻 Windows 服务端配置

### 验证 Tailscale 状态

```powershell
# 检查 Tailscale 服务
Get-Service Tailscale

# 查看连接状态
C:\Program Files\Tailscale\tailscale.exe status

# 应该显示:
# 100.80.206.8   pc-20230328vcfz  liyu0114@  windows  -
# 100.98.121.70  macbook-pro      liyu0114@  macOS    -
```

### 获取 Gateway 地址

```
Gateway URL: http://100.80.206.8:18789
```

---

## ✅ 连接测试

### 在手机上测试连接

#### 方法 1: 使用浏览器

```
1. 确保手机已连接 Tailscale
2. 打开浏览器
3. 访问: http://100.80.206.8:18789
4. 应该看到 OpenClaw Gateway 页面
```

#### 方法 2: 使用 Ping（需要终端 App）

```bash
# 下载 Termux (Android)
# 安装后运行:
ping 100.80.206.8

# 应该能 ping 通
```

---

## 🔧 常见问题

### 问题 1: 无法连接到 Tailscale

**解决方案**:
```
1. 检查网络连接（WiFi/移动数据）
2. 尝试切换网络（WiFi ↔ 移动数据）
3. 重启 Tailscale App
4. 重新登录 Tailscale 账号
```

### 问题 2: 无法访问 Gateway

**解决方案**:
```
1. 确认 Windows 上的 Tailscale 正在运行
2. 确认 Windows 防火墙已放行端口 18789
3. 在 Windows 上运行:
   netstat -ano | findstr ":18789"
   应该显示 LISTENING
```

### 问题 3: Tailscale 频繁断开

**解决方案**:
```
1. Android 设置 → 电池优化 → 找到 Tailscale → 选择"不优化"
2. Android 设置 → 应用 → Tailscale → 电池 → "无限制"
3. 锁定 Tailscale 在后台运行（不同手机设置不同）
```

### 问题 4: 华为手机无法从 Google Play 下载

**解决方案**:
```
1. 使用华为应用市场
2. 或从官网下载 APK: https://tailscale.com/download/android
3. 安装时需要允许"安装未知来源应用"
```

---

## 🎯 最佳实践

### 1. 保持 Tailscale 后台运行

```
- 不要强制停止 Tailscale App
- 添加到电池优化白名单
- 允许后台运行
```

### 2. 自动连接

```
- 在 Tailscale 设置中启用"开机自动连接"
- 启用"始终开启 VPN"（如果支持）
```

### 3. 多设备管理

```
- 所有设备使用同一个 Tailscale 账号
- 在 https://login.tailscale.com 管理设备
- 可以为设备设置标签和权限
```

---

## 📞 获取帮助

如果遇到问题：

1. **Tailscale 官方文档**: https://tailscale.com/kb
2. **Tailscale 社区**: https://tailscale.com/community
3. **联系我**: 在 OpenClaw 中发送消息

---

## 🎉 完成！

现在你的手机已经通过 Tailscale 连接到 Windows Gateway，可以开始使用 OpenClaw 客户端了！
