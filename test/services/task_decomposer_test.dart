// 任务分解服务测试 - L1 单元测试
import 'package:flutter_test/flutter_test.dart';

/// 子任务（从 task_decomposer.dart 复制）
class SubTask {
  final String id;
  final String description;
  final List<String> dependencies;
  String status;
  String? result;

  SubTask({
    required this.id,
    required this.description,
    this.dependencies = const [],
    this.status = 'pending',
    this.result,
  });

  factory SubTask.fromJson(Map<String, dynamic> json) {
    return SubTask(
      id: json['id'] as String? ?? '',
      description: json['description'] as String? ?? '',
      dependencies: (json['dependencies'] as List?)?.map((e) => e.toString()).toList() ?? [],
      status: json['status'] as String? ?? 'pending',
      result: json['result'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'description': description,
    'dependencies': dependencies,
    'status': status,
    'result': result,
  };
}

/// 任务计划（从 task_decomposer.dart 复制）
class TaskPlan {
  final String mainTask;
  final List<SubTask> subtasks;
  final DateTime createdAt;
  String? summary;

  TaskPlan({
    required this.mainTask,
    required this.subtasks,
    required this.createdAt,
    this.summary,
  });

  SubTask? getNextExecutable() {
    for (final subtask in subtasks) {
      if (subtask.status != 'pending') continue;

      bool allDepsMet = true;
      for (final depId in subtask.dependencies) {
        final dep = subtasks.where((s) => s.id == depId).firstOrNull;
        if (dep == null || dep.status != 'completed') {
          allDepsMet = false;
          break;
        }
      }

      if (allDepsMet) return subtask;
    }
    return null;
  }

  bool get isCompleted => subtasks.every((s) => s.status == 'completed');

  double get progress {
    if (subtasks.isEmpty) return 0;
    final completed = subtasks.where((s) => s.status == 'completed').length;
    return completed / subtasks.length;
  }

  String get progressText {
    final completed = subtasks.where((s) => s.status == 'completed').length;
    return '$completed/${subtasks.length}';
  }

  void markCompleted(String subtaskId, String result) {
    final subtask = subtasks.where((s) => s.id == subtaskId).firstOrNull;
    if (subtask != null) {
      subtask.status = 'completed';
      subtask.result = result;
    }
  }

  void markFailed(String subtaskId, String error) {
    final subtask = subtasks.where((s) => s.id == subtaskId).firstOrNull;
    if (subtask != null) {
      subtask.status = 'failed';
      subtask.result = error;
    }
  }
}

void main() {
  group('L1-01 任务分解器测试', () {
    
    test('测试1：TaskPlan 创建', () {
      final plan = TaskPlan(
        mainTask: '查天气',
        subtasks: [
          SubTask(id: '1', description: '调用天气API'),
        ],
        createdAt: DateTime.now(),
      );
      expect(plan.mainTask, '查天气');
      expect(plan.subtasks.length, 1);
    });
    
    test('测试2：依赖关系解析 - 无依赖', () {
      final plan = TaskPlan(
        mainTask: '查天气',
        subtasks: [
          SubTask(id: '1', description: '任务1'),
          SubTask(id: '2', description: '任务2'),
        ],
        createdAt: DateTime.now(),
      );
      
      final next = plan.getNextExecutable();
      expect(next?.id, '1');
    });
    
    test('测试3：依赖关系解析 - 有依赖', () {
      final plan = TaskPlan(
        mainTask: '测试',
        subtasks: [
          SubTask(id: '1', description: '任务1'),
          SubTask(id: '2', description: '任务2', dependencies: ['1']),
        ],
        createdAt: DateTime.now(),
      );
      
      final next = plan.getNextExecutable();
      expect(next?.id, '1');
      expect(next?.dependencies.isEmpty, true);
    });
    
    test('测试4：依赖完成后的任务可执行', () {
      final plan = TaskPlan(
        mainTask: '测试',
        subtasks: [
          SubTask(id: '1', description: '任务1', status: 'completed', result: '完成'),
          SubTask(id: '2', description: '任务2', dependencies: ['1']),
        ],
        createdAt: DateTime.now(),
      );
      
      final next = plan.getNextExecutable();
      expect(next?.id, '2');
    });
    
    test('测试5：计划完成判断 - 全部完成', () {
      final plan = TaskPlan(
        mainTask: '测试',
        subtasks: [
          SubTask(id: '1', description: '任务1', status: 'completed'),
        ],
        createdAt: DateTime.now(),
      );
      expect(plan.isCompleted, true);
    });
    
    test('测试6：计划完成判断 - 未全部完成', () {
      final plan = TaskPlan(
        mainTask: '测试',
        subtasks: [
          SubTask(id: '1', description: '任务1', status: 'completed'),
          SubTask(id: '2', description: '任务2', status: 'pending'),
        ],
        createdAt: DateTime.now(),
      );
      expect(plan.isCompleted, false);
    });
    
    test('测试7：进度计算', () {
      final plan = TaskPlan(
        mainTask: '测试',
        subtasks: [
          SubTask(id: '1', description: '任务1', status: 'completed'),
          SubTask(id: '2', description: '任务2', status: 'pending'),
        ],
        createdAt: DateTime.now(),
      );
      expect(plan.progress, 0.5);
      expect(plan.progressText, '1/2');
    });
    
    test('测试8：标记子任务完成', () {
      final plan = TaskPlan(
        mainTask: '测试',
        subtasks: [
          SubTask(id: '1', description: '任务1'),
        ],
        createdAt: DateTime.now(),
      );
      
      plan.markCompleted('1', '结果是晴天');
      expect(plan.subtasks[0].status, 'completed');
      expect(plan.subtasks[0].result, '结果是晴天');
    });
    
    test('测试9：标记子任务失败', () {
      final plan = TaskPlan(
        mainTask: '测试',
        subtasks: [
          SubTask(id: '1', description: '任务1'),
        ],
        createdAt: DateTime.now(),
      );
      
      plan.markFailed('1', '网络错误');
      expect(plan.subtasks[0].status, 'failed');
      expect(plan.subtasks[0].result, '网络错误');
    });
    
    test('测试10：SubTask JSON序列化', () {
      final subtask = SubTask(
        id: '1',
        description: '任务1',
        dependencies: ['2'],
        status: 'pending',
      );
      
      final json = subtask.toJson();
      expect(json['id'], '1');
      expect(json['dependencies'], ['2']);
      
      final restored = SubTask.fromJson(json);
      expect(restored.id, '1');
      expect(restored.dependencies, ['2']);
    });
    
    test('测试11：空任务计划', () {
      final plan = TaskPlan(
        mainTask: '空任务',
        subtasks: [],
        createdAt: DateTime.now(),
      );
      expect(plan.progress, 0);
      expect(plan.isCompleted, true);
    });
    
    test('测试12：多级依赖', () {
      final plan = TaskPlan(
        mainTask: '多级任务',
        subtasks: [
          SubTask(id: '1', description: '任务1'),
          SubTask(id: '2', description: '任务2', dependencies: ['1']),
          SubTask(id: '3', description: '任务3', dependencies: ['2']),
        ],
        createdAt: DateTime.now(),
      );
      
      expect(plan.getNextExecutable()?.id, '1');
      plan.markCompleted('1', 'ok');
      expect(plan.getNextExecutable()?.id, '2');
      plan.markCompleted('2', 'ok');
      expect(plan.getNextExecutable()?.id, '3');
    });
  });
}