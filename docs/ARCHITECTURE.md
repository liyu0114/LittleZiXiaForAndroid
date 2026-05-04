# 小紫霞能力架构

> **对标 OpenClaw 的核心设计**

---

## 一、能力分层

### 1. 基础能力层（内置）

**任务分解能力**
- 将复杂任务拆分为子任务
- 按依赖关系排序执行
- 支持并行和串行

**手脚能力（移动设备特有）**
| 手脚 | 能力 | 对应服务 |
|------|------|----------|
| 眼 | 摄像头、二维码 | CameraService |
| 耳 | 麦克风、语音识别 | VoiceInputService |
| 口 | 扬声器、TTS | TTSService |
| 腿 | GPS、移动 | LocationService |
| 触觉 | 传感器、震动 | SensorService |
| 记忆 | 存储、数据库 | StorageService |
| 社交 | 蓝牙、网络 | NetworkService |

### 2. 外部注入层（Skill）

**从 assets/skills/ 加载**
- 天气、翻译、计算器等基础技能
- 预装在 APK 中
- 可从 SkillHub 安装新技能

**Skill 组装基础能力**
```yaml
# 示例：天气技能组装多个基础能力
skill: local_weather
steps:
  - use: location       # 用"腿"获取位置
  - use: http_get       # 用"网络"调用API
  - use: tts           # 用"口"播报结果
```

---

## 二、任务执行流程

```
用户请求 → 意图识别 → 任务分解 → 执行调度 → 结果汇总
                           ↓
                    选择执行器：
                    - Skill 执行器
                    - 原生能力执行器
                    - LLM 执行器
```

---

## 三、群聊角色系统

### 设计思路
- 每个机器人可定义角色
- 角色决定行为模式和技能集
- 机器人之间可协作

### 示例角色

**文档机器人**
```yaml
role: document_writer
skills:
  - write_document
  - edit_document
  - format_text
behavior:
  - 接收文档请求
  - 生成初稿
  - 等待质检反馈
  - 修改文档
```

**质检机器人**
```yaml
role: quality_checker
skills:
  - check_spelling
  - check_grammar
  - check_format
behavior:
  - 接收文档
  - 检查问题
  - 返回修改建议
  - 确认修改完成
```

### 协作流程
```
用户 → 文档机器人 → 质检机器人
         ↑              ↓
         └──── 修改 ←───┘
```

---

## 四、24点游戏记分

### 记录内容
- 玩家 ID
- 胜利次数
- 总游戏次数
- 最佳用时
- 历史答案

### 存储方式
- 本地：SharedPreferences
- 联网：同步到主机

---

## 五、实现优先级

| 优先级 | 任务 | 状态 |
|--------|------|------|
| P0 | 客户端机器人同步 | 🔴 进行中 |
| P1 | 24点记分系统 | 待开始 |
| P1 | 基础能力层完善 | 待开始 |
| P2 | Skill 组装机制 | 待开始 |
| P2 | 群聊角色系统 | 待开始 |
