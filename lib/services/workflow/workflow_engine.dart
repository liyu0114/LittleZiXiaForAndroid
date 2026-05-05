// 工作流引擎
//
// 自动化工作流执行

import 'dart:async';
import 'package:flutter/foundation.dart';

/// 工作流步骤
class WorkflowStep {
  final String id;
  final String name;
  final String action;
  final Map<String, dynamic> params;
  final String? nextStepId;
  
  WorkflowStep({
    required this.id,
    required this.name,
    required this.action,
    this.params = const {},
    this.nextStepId,
  });
}

/// 工作流
class Workflow {
  final String id;
  final String name;
  final List<WorkflowStep> steps;
  final bool isEnabled;
  
  Workflow({
    required this.id,
    required this.name,
    required this.steps,
    this.isEnabled = true,
  });
}

/// 工作流引擎
class WorkflowEngine extends ChangeNotifier {
  final List<Workflow> _workflows = [];
  final Map<String, bool> _runningSteps = {};
  
  List<Workflow> get workflows => List.unmodifiable(_workflows);
  
  /// 添加工作流
  void addWorkflow(Workflow workflow) {
    _workflows.add(workflow);
    notifyListeners();
  }
  
  /// 执行工作流
  Future<void> runWorkflow(String workflowId) async {
    final workflow = _workflows.firstWhere((w) => w.id == workflowId);
    
    for (final step in workflow.steps) {
      _runningSteps[step.id] = true;
      notifyListeners();
      
      await _executeStep(step);
      
      _runningSteps[step.id] = false;
      notifyListeners();
    }
  }
  
  Future<void> _executeStep(WorkflowStep step) async {
    debugPrint('[WorkflowEngine] 执行步骤: ${step.name}');
    // TODO: 执行实际动作
    await Future.delayed(Duration(milliseconds: 100));
  }
  
  /// 停止工作流
  void stopWorkflow(String workflowId) {
    _runningSteps.clear();
    notifyListeners();
  }
  
  /// 删除工作流
  void deleteWorkflow(String id) {
    _workflows.removeWhere((w) => w.id == id);
    notifyListeners();
  }
}