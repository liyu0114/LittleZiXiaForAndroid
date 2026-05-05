# 技术决策日志

**目的：** 记录重要技术决策及其原因，避免重复踩坑

---

## 2026-03-30: SkillHub 同步方案

**问题：** https://clawhub.com/api/skills 返回 404

**方案：** 使用 ClawHubService 的内置推荐技能列表

**原因：**
1. 远程 API 不存在或不稳定
2. 内置列表有 20+ 个移动端友好技能
3. 离线可用，不依赖网络
4. 响应速度快，无需网络请求

**实现：**
- 移除硬编码的 URL
- 调用 `getPopularSkills(limit: 50)` 获取推荐技能
- 全部标记为移动端友好

**影响：**
- ✅ 离线可用
- ✅ 响应快速
- ⚠️ 技能列表固定，无法动态更新

**提交：** 5576570

**文件：** `lib/screens/skillhub_screen.dart`

---

## 2026-03-30: 技能预装逻辑

**问题：** 已安装技能显示为 0，但 assets 中有 50 个技能

**原因：**
1. 初始化顺序错误
2. `_loadManagedSkills()` 先执行，加载了 SharedPreferences 中的空数据
3. `_preloadBuiltinSkills()` 后执行，但检查时发现列表"已存在"（虽然为空）

**方案：** 调整初始化顺序

**实现：**
```dart
// 旧顺序（错误）
1. 初始化基础管理器
2. 加载托管技能 ← 先加载空数据
3. 预装内置技能 ← 检查时发现列表"已存在"

// 新顺序（正确）
1. 初始化基础管理器
2. 预装内置技能 ← 先添加 50 个技能
3. 加载托管技能 ← 后加载用户数据
```

**影响：**
- ✅ 内置技能总是可用
- ✅ 用户数据不会覆盖内置技能

**提交：** 1d1b54e

**文件：** `lib/services/skills/skill_manager_new.dart`

---

## 2026-03-30: 界面 Tab 数量

**问题：** 传感器页、设置页、Gateway页、调试页界面全部错位

**原因：**
- TabController length = 11
- Tabs 定义 = 10 个
- TabBarView = 11 个（多余的 Container）

**方案：** 统一为 10 个

**实现：**
1. `TabController(length: 10)`
2. 删除 TabBarView 中多余的 `Container(child: Center(child: Text('生命周期管理界面开发中')))`

**对应关系：**
```
0. 对话 → _buildChatTab()
1. 模型 → LLMConfigScreen
2. 能力 → CapabilityScreen
3. 技能 → SkillsScreenV2
4. SkillHub → SkillHubScreen
5. 生命周期 → SkillLifecycleScreen
6. 传感器 → SensorDataScreen
7. 设置 → SettingsScreen
8. Gateway → GatewayDashboard
9. 调试 → DebugScreen
```

**提交：** c874a74

**文件：** `lib/screens/home_screen.dart`

---

## 2026-03-30: 大模型扩展方案

**问题：** 硬编码 7 个提供商，无法穷尽新模型

**方案：** 混合方案（P0 + P1）

**实现：**
1. **P0 - CustomLLMProvider**（3h）
   - 支持任意 OpenAI 兼容接口
   - 用户可自定义添加
   
2. **P1 - 添加主流模型**（3h）
   - Gemini Provider
   - Grok Provider
   - Kimi Provider
   - 豆包 Provider

**影响：**
- ✅ 支持 11 个提供商
- ✅ 用户可自定义添加
- ✅ 覆盖主流模型

**提交：** a373810

**文件：**
- `lib/services/llm/custom_provider.dart`
- `lib/services/llm/llm_factory.dart`

---

## 2026-03-30: 无障碍服务技术选型

**需求：** 让小紫霞能操作其他 APP（如支付宝）

**方案：** Android Accessibility Service

**技术要点：**
1. **Flutter 层**
   - `AccessibilityService` - MethodChannel 通信
   - `AccessibilityNode` - UI 节点模型

2. **Android 原生层**
   - `LittleZiXiaAccessibilityService` - 继承 AccessibilityService
   - 支持：点击、输入、滚动、导航

3. **权限**
   - `BIND_ACCESSIBILITY_SERVICE`
   - 用户需手动开启无障碍服务

**风险：**
- 用户可能不理解权限申请
- 应用 UI 变更可能导致脚本失效
- 需要详细用户引导

**提交：** fa018cd

**文件：**
- `lib/services/accessibility/accessibility_service.dart`
- `android/app/src/main/kotlin/.../LittleZiXiaAccessibilityService.kt`

---

## 模板

```markdown
## YYYY-MM-DD: 决策标题

**问题：** 遇到了什么问题

**方案：** 选择了什么方案

**原因：**
1. 原因1
2. 原因2

**实现：**
- 具体实现步骤1
- 具体实现步骤2

**影响：**
- ✅ 正面影响
- ⚠️ 潜在风险

**提交：** commit hash

**文件：** 相关文件路径
```
