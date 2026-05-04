# 小紫霞开发铁律

> **最大铁律：对标 OpenClaw 的功能**

---

## 一、Skill 机制

### ✅ 正确做法
- **注入机制** - 所有 Skill 从外部加载
- **预装方式** - 基本技能随 APK 包注入（assets/skills/）
- **动态扩展** - 用户可从 SkillHub 安装新技能

### ❌ 禁止做法
- 硬编码 Skill 实现（如 `_executeWeatherSkill`）
- 在代码中写死 API 调用逻辑
- 针对单个功能点做特殊处理

---

## 二、任务执行能力

学习 OpenClaw 的任务分解和执行机制：

1. **任务分解** - 复杂任务拆分为子任务
2. **任务执行** - 按顺序或并行执行
3. **手脚健全** - 完善的执行能力

参考：`TaskExecutor` 服务

---

## 三、移动设备"手脚"

发挥移动设备特有能力：

| 能力 | 对应 Skill |
|------|-----------|
| 📍 GPS 定位 | location, local_weather, reverse_geocoding |
| 📷 摄像头 | camera, qr_code |
| 🎤 麦克风 | voice_input |
| 🔊 扬声器 | TTS |
| 📱 传感器 | compass, accelerometer, step_counter |
| 📶 蓝牙 | bluetooth_scanner |
| 🔔 通知 | notification, reminder |
| 🌐 网络 | web_search, web_fetch |

---

## 四、坚持一个思路

### 不要做的
- ❌ 为了实现某个功能就换思路
- ❌ 针对某个点做硬编码
- ❌ 放弃整体架构去解决局部问题

### 应该做的
- ✅ 保持架构一致性
- ✅ 用通用机制解决具体问题
- ✅ 优先考虑扩展性

---

## 五、具体实现规范

### Skill 文件结构
```
assets/skills/
├── weather/SKILL.md          # 天气技能
├── translate/SKILL.md        # 翻译技能
├── location/SKILL.md         # 位置技能
└── ...                       # 其他技能
```

### Skill 加载流程
1. App 启动时从 assets 加载预装技能
2. 用户可从 SkillHub 安装新技能
3. 所有技能统一通过 `SkillManager` 执行

### 代码规范
- 技能逻辑写在 SKILL.md 中，不在 Dart 代码中
- 用 `MarkdownSkillExecutor` 执行技能指令
- 新增能力时先考虑是否能用 Skill 机制实现

---

## 六、常见错误

| 错误 | 后果 | 正确做法 |
|------|------|----------|
| 硬编码技能 | 无法扩展、难维护 | 用 SKILL.md 定义 |
| 针对性修复 | 架构混乱 | 通用机制解决 |
| 忽视移动特性 | 功能平庸 | 利用移动设备能力 |

---

**记住：对标 OpenClaw，不是超越，是学习它的设计思想！**
