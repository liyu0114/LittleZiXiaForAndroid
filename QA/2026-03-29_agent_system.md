# 质检报告：Agent 系统

**检测时间：** 2026-03-29 14:00
**检测范围：** lib/services/agent/
**检测员：** 飞书龙虾

---

## 检测结果：🟡 有改进空间

---

## 一、架构概览

```
AgentOrchestrator (编排器)
       │
       └─→ AgentLoopService (核心循环)
              │
              ├─→ 思考（调用 LLM）
              ├─→ 行动（执行工具）
              └─→ 观察（检查结果）

TaskDecomposer (任务分解器) ─→ 未被使用 ⚠️
```

---

## 二、代码质量

### ✅ 优点

1. **循环检测机制完善**
   - 有历史记录追踪
   - 有警告/临界两级阈值
   - 有冷却时间防止误判

2. **状态管理清晰**
   - `AgentState` 枚举明确：idle → thinking → acting → observing → completed/failed
   - 使用 `ChangeNotifier` 支持监听

3. **工具调用格式设计合理**
   - 使用 ` ```tool ``` 代码块
   - 支持多种工具类型

### ⚠️ 问题

| 优先级 | 问题 | 位置 | 影响 |
|--------|------|------|------|
| P1 | TaskDecomposer 未被使用 | agent_orchestrator.dart | 复杂任务无法分解 |
| P1 | 自定义 JSON 解析器 | task_decomposer.dart:160-210 | 容易解析失败 |
| P2 | 循环检测配置硬编码 | agent_loop_service.dart:60 | 无法动态调整 |
| P2 | 无进度回调 | agent_loop_service.dart | 用户看不到执行进度 |

---

## 三、详细分析

### 问题 1：TaskDecomposer 未被使用

```dart
// agent_orchestrator.dart:20
/// Agent 编排服务（简化版）
class AgentOrchestrator extends ChangeNotifier {
  // ...
  // 初始化 Agent Loop（简化版，不使用 Task Decomposer）
  _agentLoop = AgentLoopService();
```

**影响：** 复杂任务（如"先查北京天气，再查上海天气，最后对比"）无法被分解，全靠 LLM 自己处理，可能出错。

**建议：** 提供执行模式选择：
- `simple` — 直接执行，适合简单任务
- `planned` — 先分解再执行，适合复杂任务

---

### 问题 2：自定义 JSON 解析器

```dart
// task_decomposer.dart:160-210
/// 简化的 JSON 解码
Map<String, dynamic> _simpleJsonDecode(String jsonStr) {
  // 这是一个非常简化的实现
  // 实际应用中应该使用 dart:convert 的 json.decode
  // ...
  final subtasksMatch = RegExp(r'"subtasks"\s*:\s*\[([\s\S]*?)\]').firstMatch(jsonStr);
```

**问题：** 用正则解析 JSON 非常脆弱：
- 不支持嵌套对象
- 不支持字符串中包含特殊字符（如引号）
- 不支持 Unicode

**建议：** 直接使用 `dart:convert` 的 `json.decode`：

```dart
import 'dart:convert';

Map<String, dynamic>? _parseJson(String str) {
  try {
    final start = str.indexOf('{');
    final end = str.lastIndexOf('}');
    if (start == -1 || end == -1) return null;
    
    return json.decode(str.substring(start, end + 1)) as Map<String, dynamic>;
  } catch (e) {
    debugPrint('[TaskDecomposer] JSON 解析失败: $e');
    return null;
  }
}
```

---

### 问题 3：无进度回调

```dart
// agent_loop_service.dart
Future<AgentResult> execute(String task) async {
  // ... 执行过程中没有任何回调
}
```

**影响：** 用户不知道任务执行到哪一步了。

**建议：** 添加进度回调：

```dart
typedef ProgressCallback = void Function(String step, double progress);

Future<AgentResult> execute(
  String task, {
  ProgressCallback? onProgress,
}) async {
  // ...
  onProgress?.call('思考中...', 0.3);
  // ...
}
```

---

### 问题 4：工具错误返回字符串

```dart
// agent_loop_service.dart:340
Future<String> _executeTool(String name, Map<String, dynamic> arguments) async {
  // ...
  return '错误：未知工具 $name';
}
```

**问题：** 错误返回字符串，无法区分是工具不存在还是工具执行失败。

**建议：** 使用 `SkillExecutionResult` 风格：

```dart
class ToolResult {
  final bool success;
  final String output;
  final String? error;
}
```

---

## 四、对标 OpenClaw

| 特性 | OpenClaw | 小紫霞 | 状态 |
|------|----------|--------|------|
| Agent Loop | ✅ 思考-行动-观察 | ✅ 已实现 | OK |
| 任务分解 | ✅ 支持 | ⚠️ 代码存在但未使用 | 需集成 |
| 工具调用 | ✅ 函数调用格式 | ✅ 代码块格式 | OK |
| 循环检测 | ✅ | ✅ 已实现 | OK |
| 最大迭代限制 | ✅ | ✅ 10次 | OK |
| 进度回调 | ✅ | ❌ 缺失 | 需添加 |

---

## 五、用户视角问题

### P1 体验问题

| 问题 | 场景 | 影响 |
|------|------|------|
| 复杂任务执行失败 | "先查天气再翻译" | LLM 可能漏掉某一步 |
| 长时间无反馈 | 执行 5+ 秒的任务 | 用户以为卡死 |

### P2 优化建议

| 建议 |
|------|
| 添加"任务分解"开关，让用户选择是否分解 |
| 显示当前执行步骤（"正在查询天气..."） |
| 任务完成后显示执行历史 |

---

## 六、修复计划

### 立即修复（P1）

1. **替换自定义 JSON 解析器** — 使用 `dart:convert`
2. **集成 TaskDecomposer** — 提供执行模式选择

### 后续优化（P2）

3. **添加进度回调**
4. **工具结果结构化**

---

## 七、总结

### 优点
- Agent Loop 核心设计合理
- 循环检测机制完善
- 状态管理清晰

### 需要改进
1. **P1** TaskDecomposer 未集成 ~~✅ 已集成~~
2. **P1** 自定义 JSON 解析器不稳定 ~~✅ 已替换为 dart:convert~~
3. **P2** 缺少进度反馈 ⏳ 待优化

### 修复记录

**2026-03-29 14:15**

1. **JSON 解析器** — 替换自定义解析器为 `dart:convert` 的 `json.decode`
2. **TaskDecomposer 集成** — 添加 `ExecutionMode` 枚举，支持 `simple` 和 `planned` 模式
3. **进度追踪改进** — 添加 `_progress` 和 `_progressMessage` 字段

### 建议优先级
1. ~~替换 JSON 解析器（快速修复）~~ ✅ 已完成
2. ~~集成 TaskDecomposer（解锁复杂任务能力）~~ ✅ 已完成
3. 添加详细进度回调（改善用户体验）

---

**下一步：** 检测 UI 界面。
