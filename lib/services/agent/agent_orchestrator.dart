// Agent 编排服务 - 简化版
//
// 不使用 Task Decomposer，让 LLM 自己决策

import 'package:flutter/foundation.dart';
import '../llm/llm_base.dart';
import '../memory/memory_service.dart';
import '../skills/skill_system.dart';
import '../skills/skill_lifecycle.dart';
import '../remote/remote_connection.dart';
import 'agent_loop_service.dart';

/// 执行进度
class ExecutionProgress {
  final String taskId;
  final String status;
  final String? currentStep;
  final double progress;
  final String? message;

  ExecutionProgress({
    required this.taskId,
    required this.status,
    this.currentStep,
    required this.progress,
    this.message,
  });
}

/// Agent 编排服务（简化版）
class AgentOrchestrator extends ChangeNotifier {
  static final AgentOrchestrator _instance = AgentOrchestrator._internal();
  factory AgentOrchestrator() => _instance;
  AgentOrchestrator._internal();

  // 核心服务
  AgentLoopService? _agentLoop;
  MemoryService? _memoryService;
  SkillManager? _skillManager;
  SkillLifecycleManager? _lifecycleManager;
  RemoteConnection? _remoteConnection;

  // 执行状态
  bool _isExecuting = false;
  ExecutionProgress? _progress;
  final List<String> _logs = [];

  // Getters
  bool get isExecuting => _isExecuting;
  ExecutionProgress? get progress => _progress;
  List<String> get logs => List.unmodifiable(_logs);

  /// 初始化
  void initialize({
    required LLMProvider llmProvider,
    MemoryService? memoryService,
    SkillManager? skillManager,
    SkillLifecycleManager? lifecycleManager,
    RemoteConnection? remoteConnection,
  }) {
    _memoryService = memoryService;
    _skillManager = skillManager;
    _lifecycleManager = lifecycleManager;
    _remoteConnection = remoteConnection;

    // 初始化 Agent Loop（简化版，不使用 Task Decomposer）
    _agentLoop = AgentLoopService();
    _agentLoop!.initialize(
      llmProvider: llmProvider,
      memoryService: memoryService,
      skillManager: skillManager,
      remoteConnection: remoteConnection,
    );

    // 监听状态变化
    _agentLoop!.addListener(_onAgentLoopChange);

    debugPrint('[AgentOrchestrator] 初始化完成（简化版）');
  }

  void _onAgentLoopChange() {
    notifyListeners();
  }

  /// 执行任务（主入口）
  Future<String> execute(String task) async {
    _isExecuting = true;
    _logs.clear();
    _addLog('开始执行任务: $task');

    _progress = ExecutionProgress(
      taskId: DateTime.now().millisecondsSinceEpoch.toString(),
      status: 'running',
      progress: 0,
    );
    notifyListeners();

    try {
      // 直接执行，让 LLM 自己决策
      final result = await _agentLoop!.execute(task);

      _progress = ExecutionProgress(
        taskId: _progress!.taskId,
        status: 'completed',
        progress: 1.0,
        message: result.content,
      );
      _addLog('任务完成: ${result.content.length > 100 ? '${result.content.substring(0, 100)}...' : result.content}');

      // 保存到记忆
      if (_memoryService != null) {
        await _memoryService!.add(
          '任务完成: $task\n结果: ${result.content}',
          tags: ['task', 'completed'],
        );
      }

      return result.content;
    } catch (e) {
      _progress = ExecutionProgress(
        taskId: _progress!.taskId,
        status: 'failed',
        progress: _progress?.progress ?? 0,
        message: e.toString(),
      );
      _addLog('任务失败: $e');
      return '任务执行失败: $e';
    } finally {
      _isExecuting = false;
      notifyListeners();
    }
  }

  /// 停止执行
  void stop() {
    if (_agentLoop != null) {
      _agentLoop!.stop();
    }
    _isExecuting = false;
    _progress = ExecutionProgress(
      taskId: _progress?.taskId ?? '',
      status: 'stopped',
      progress: _progress?.progress ?? 0,
    );
    _addLog('任务已停止');
    notifyListeners();
  }

  /// 重置
  void reset() {
    stop();
    _logs.clear();
    _progress = null;
    notifyListeners();
  }

  void _addLog(String message) {
    _logs.add('[${DateTime.now().toIso8601String()}] $message');
    debugPrint('[AgentOrchestrator] $message');
  }

  /// 获取 Skill 生命周期管理器
  SkillLifecycleManager? get lifecycleManager => _lifecycleManager;
}
