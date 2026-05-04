# 代码瘦身记录

> 持续记录代码冗余和清理工作

---

## 2026-05-04 首次记录

### 已知冗余
1. ❓ `check_dup.txt` - 需检查是否还有效
2. ❓ 多个 build 脚本 - install-flutter-*.cmd/.ps1 有 5+ 个，可能可以合并
3. ❓ `openclaw_app` 和 `openclaw_sdk` 目录 - 需确认是否还在用
4. ❓ 旧版本 docx 文件 - `docs/` 下有大量历史版本

### 待检查
- [ ] 清理重复的 build 脚本
- [ ] 确认 openclaw_app/openclaw_sdk 是否还在用
- [ ] 归档旧的 docx 文件
- [ ] 检查废弃的 HardCode

---

*持续更新*