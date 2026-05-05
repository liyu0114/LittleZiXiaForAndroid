# GitHub提交规范 v1.0.201

> **版本**: v1.0.201
> **更新**: 2026-05-05

---

## 铁律

**每次任务完成后，必须提交GitHub**

---

## 提交工作流

### 1. 检查变更

```bash
cd D:\LittleZiXia
git status
```

### 2. 添加变更文件

```bash
git add .
# 或指定文件
git add lib/ docs/
```

### 3. 提交

```bash
git commit -m "版本号: 简短描述"
# 格式: "v1.0.169: 代码整理完成，删除6个空壳模块"
```

### 4. 推送到GitHub（适应慢速网络）

```bash
# 适用于慢速网络的命令
git push origin main --verbose

# 或者分步骤
git push origin main
```

### 5. 如果推送失败

```bash
# 重试
git push origin main

# 或者分批push大文件
git config http.postBuffer 524288000  # 500MB
git push origin main
```

---

## 慢速网络适配

| 问题 | 解决方案 |
|------|----------|
| **连接超时** | 增加超时: `git config http.timeout 600` |
| **大文件卡住** | 增加buffer: `git config http.postBuffer 524288000` |
| **推送中断** | 使用 `--retry` 或手动重试 |
| **网络很慢** | 压缩: `git config core.compression 9` |

### 推荐配置

```bash
# 适用于慢速网络
git config --global http.timeout 600
git config --global http.postBuffer 524288000
git config --global core.compression 9
git config --global pack.windowMemory 100m
```

---

## 提交格式

### commit message格式

```
v{版本号}: {简短描述}

详细说明（可选）

- 变更1
- 变更2
```

### 示例

```
v1.0.169: 代码整理完成

- 删除6个空壳模块（health heartbeat nfc qrcode bluetooth audio）
- 创建states目录
- flutter analyze通过
```

---

## 六步法中的位置

```
1. 拿任务
2. 讨论
3. 规划
4. 执行 ← 最后一步是"收尾"
5. 验证
6. 交付 ← 包含GitHub提交
```

**注意**：在步骤6"交付"中，必须包含GitHub提交

---

## 检查清单（交付前）

- [ ] 代码编译通过
- [ ] flutter analyze零警告
- [ ] 构建APK成功
- [ ] 更新REQUIREMENTS.md
- [ ] 更新文档
- [ ] **git add .**
- [ ] **git commit -m "..."**
- [ ] **git push origin main**

---

*版本: v1.0.201*