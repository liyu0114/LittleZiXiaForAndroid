# LittleZiXia Android 团队完整蓝图（v1.0.166）

> **版本**: v1.0.166（2026-04-28）
> **状态**: 基于代码实现深度分析
> **方法**: 自顶向下 + 代码级对比

---

## 一、核心架构（已实现）

```
┌─────────────────────────────────────────────────────────────────┐
│                      用户交互层                            │
│  screens/  (22+ 页面)                                          │
│  - home_screen, group_chat_screen, network_chat_screen          │
│  - twenty_four_game_screen, skillhub_screen                    │
│  - debug_screen, gateway_dashboard, settings_screen         │
│  - llm_config_screen, memory_search_screen                   │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                      业务能力层                            │
│  services/     (35+ 服务文件)                                 │
│  ├─ agent/      (7文件): Agent Loop v2, 任务分解, 工具        │
│  ├─ skills/   (12文件): Skill 系统完整实现                    │
│  ├─ collaboration/ (1文件): OpenClaw 协作                    │
│  ├─ groupchat/  (1文件): 群聊服务                              │
│  ├─ games/    (3文件): 24点游戏 + 记分                        │
│  └─ chat/    (多文件): 对话服务                                │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                      基础服务层                            │
│  ├─ llm/       (GLM/Ollama/Custom 多提供者)                    │
│  ├─ web/       (web_search, web_fetch)                         │
│  ├─ memory/    (记忆服务，上下文压缩)                         │
│  ├─ remote/    (P2P + Gateway 连接)                            │
│  └─ context/   (智能上下文管理)                               │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                      设备能力层（手脚）                   │
│  ├─ voice/     (语音输入，TTS)                                │
│  ├─ vision/    (摄像头，二维码)                               │
│  ├─ sensors/   (GPS，传感器)                                  │
│  ├─ bluetooth/(蓝牙)                                          │
│  ├─ native/   (通知，权限)                                    │
│  └─ auth/    (认证)                                           │
└─────────────────────────────────────────────────────────────────┘
```

---

## 二、已实现功能深度总结

### 2.1 Agent 任务执行系统（核心）

**文件：`services/agent/`**

| 组件 | 文件名 | 功能 | 状态 |
|------|--------|------|------|
| AgentLoopV2 | agent_loop_v2.dart | 主循环，包含 function calling、上下文压缩、死循环检测、重试 | ✅ 已实现 |
| TaskDecomposer | task_decomposer.dart | 任务分解 | ✅ 已实现 |
| TaskStateService | task_state_service.dart | 任务状态管理 | ✅ 已实现 |
| AgentTools | agent_tools.dart | 工具注册（AskUser, SaveAsSkill, Calculator等） | ✅ 已实现 |
| MetaTools | meta_tools.dart | 元工具（记忆搜索等） | ✅ 已实现 |
| RetryHandler | retry_handler.dart | 重试机制 | ✅ 已实现 |
| ProgressReporter | progress_reporter.dart | 进度报告 | ✅ 已实现 |
| AgentOrchestrator | agent_orchestrator.dart | 编排器 | ✅ 已实现 |
| Lifecycle | lifecycle.dart | 生命周期 | ✅ 已实现 |

**核心能力：**
- ✅ Function Calling（原生调用 LLM 工具）
- ✅ 上下文压缩（大输出压缩为摘要）
- ✅ 死循环检测（滑动窗口指纹）
- ✅ LLM 调用重试（指数退避）
- ✅ 任务规划（v1.0.166 - 先列出计划再执行）
- ✅ 多子任务检测（v1.0.166 - 确保完成所有子任务）
- ✅ 智能 Fallback（Skill→Agent→Web→协商）

### 2.2 Skill 系统（完整实现）

**文件：`services/skills/`（12个文件）**

| 组件 | 文件名 | 功能 |
|------|--------|------|
| SkillSystem | skill_system.dart | 核心（注册、执行、生命周期） |
| SkillManagerNew | skill_manager_new.dart | 管理器 |
| MarkdownSkillExecutor | markdown_skill_executor.dart | 执行器 |
| IntentRecognizer | intent_recognizer.dart | 意图识别 |
| SkillLifecycle | skill_lifecycle.dart | 生命周期 |
| SkillShareService | skill_share_service.dart | 分享 |
| SkillSummarizer | skill_summarizer.dart | 摘要 |
| ClawhubService | clawhub_service.dart | Hub 对接 |
| SkillVersionManager | skill_version_manager.dart | 版本管理 |
| SkillParamExtractor | skill_param_extractor.dart | 参数提取 |
| MarkdownSkillParser | markdown_skill_parser.dart | 解析器 |
| SkillInstruction | skill_instruction.dart | 指令 |

**能力：**
- ✅ 外部 Skill 加载（assets/skills/）
- ✅ SkillHub 安装/卸载/启用/禁用
- ✅ 预装技能（天气、翻译等）
- ✅ 生命周期管理完���
- ✅ 学习保存（saveLearnedSkill）
- ✅ 与 OpenClaw 格式兼容

### 2.3 群聊协作系统

**文件：`services/collaboration/` + `services/groupchat/`**

| 组件 | 文件名 | 功能 |
|------|--------|------|
| OpenCollabService | openclaw_collab_service.dart | OpenClaw 协作（Gateway WebSocket） |
| GroupChatService | group_chat_service.dart | 群聊服务 |
| NetworkChatService | network_chat_service.dart | 联网聊天 |

**能力：**
- ✅ 角色系统（6种角色定义）
- ✅ 艾特功能（@成员）
- ✅ 机器人协作（串行/并行/回调）
- ✅ 远程聊天（P2P + Gateway）
- ✅ 消息隧道
- ✅ 状态同步

### 2.4 24点游戏系统

**文件：`services/games/`**

| 组件 | 文件名 | 功能 |
|------|--------|------|
| TwentyFourGame | twenty_four_game.dart | 游戏核心逻辑 |
| TwentyFourScore | twenty_four_score.dart | 记分系统 |
| NetworkGameService | network_game_service.dart | 联网服务 |

**能力：**
- ✅ 房间创建/加入
- ✅ 联网对战
- ✅ 抢答机制
- ✅ 计时器
- ✅ 本地记分 + 联网同步
- ✅ 排行榜

### 2.5 远程控制系统

**文件：`services/remote/`**

| 组件 | 文件名 | 功能 |
|------|--------|------|
| RemoteConnection | remote_connection.dart | P2P 连接核心 |
| RemoteWebSearch | remote_web_search.dart | 远程搜索 |
| RemoteWebFetch | remote_web_fetch.dart | 远程获取 |
| RemoteExec | remote_exec.dart | 远程执行 |

**能力：**
- ✅ P2P 直连
- ✅ Gateway 代理
- ✅ 远程工具调用
- ✅ 消息隧道

### 2.6 记忆与上下文系统

**文件：`services/memory/` + services 根目录**

| 组件 | 文件名 | 功能 |
|------|--------|------|
| MemoryService | memory/memory_service.dart | 核心记忆服务 |
| MemoryCompressor | memory_compressor.dart | 压缩器 |
| SmartContextService | context/smart_context_service.dart | 智能上下文 |
| TopicTitleGenerator | topic_title_generator.dart | 话题生成 |

**能力：**
- ✅ 长期记忆存储
- ✅ 对话历史压缩（30条→10条）
- ✅ 跨话题记忆搜索
- ✅ Token 感知裁剪
- ✅ 智能上下文管理

---

## 三、与 iOS 蓝图对比

### 3.1 已对齐

| iOS 蓝图需求 | Android 实现 | 对齐度 |
|--------------|--------------|--------|
| Task Decomposer | task_decomposer.dart | 100% |
| Skill Runtime | skill_system.dart (12文件) | 100% |
| Memory Governance | memory/ + context/ | 95% |
| Interop Bus | collaboration/ | 90% |
| 群聊协作 | groupchat/ + collaboration/ | 95% |
| 角色系统 | 6种角色定义 | 100% |
| 设备能力层 | sensors/voice/vision/ | 90% |

### 3.2 差距

| iOS 蓝图需求 | Android 现状 | 差距 |
|--------------|--------------|------|
| Compute Fabric | remote/ (P2P) | 需完善多机拼算力 |
| 游戏生成引擎 | twenty_four_game | 需通用化 |
| Apple Watch | 无 | 需开发 |
| 本地模型 | Ollama 远程 | Android 需本地 |

---

## 四、代码级 TODO 清单

### P0 - 立即验证

- [ ] **v1.0.166 任务规划测试**
  - [ ] 测试："北京和上海的天气怎么样？"
  - [ ] 测试："帮我查天气、翻译、计算"
  - [ ] 测试：复杂多步任务

- [ ] **Skill 自动生成验证**
  - [ ] 查看 saveLearnedSkill 实现
  - [ ] 测试复杂任务后保存

- [ ] **版本号同步**
  - [ ] pubspec.yaml
  - [ ] app_version.dart
  - [ ] settings_screen.dart

### P1 - 本季度

- [ ] **上下文管理增强**
  - [ ] smart_context_service.dart 优化
  - [ ] 压缩策略调优

- [ ] **多机协作优化**
  - [ ] 断线重连
  - [ ] 消息确认

- [ ] **本地模型支持**
  - [ ] Android NDK + Llama.cpp
  - [ ] 接口统一

### P2 - 下半年

- [ ] **代码瘦身**
  - [ ] 脚本合并
  - [ ] 归档旧文件

- [ ] **SkillHub 增强**
  - [ ] 批���操作

### P3 - 长期

- [ ] 老机器复用
- [ ] 游戏生成引擎
- [ ] 多端统一

---

## 五、工作规范

每次开发：
1. 读 TODO 清单
2. 选取任务
3. 开发 + 测试
4. 更新 REQUIREMENTS.md
5. 写入 worklog
6. 提交 GitHub

---

*版本: v1.0.166_20260504*