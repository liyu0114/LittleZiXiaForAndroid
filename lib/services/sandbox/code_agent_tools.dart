// Agent 代码开发工具
//
// 让 Agent 能创建项目、写代码、运行代码

import 'package:flutter/foundation.dart';
import '../agent/agent_loop_v2.dart';
import 'code_sandbox_service.dart';

/// 创建代码项目工具
class CreateCodeProjectTool extends AgentTool {
  final CodeSandboxService sandbox;

  CreateCodeProjectTool(this.sandbox);

  @override
  String get name => 'create_code_project';

  @override
  String get description => '创建一个代码项目（HTML/CSS/JS），支持在手机上运行的小程序。用于开发计算器、待办清单、小游戏等。';

  @override
  Map<String, dynamic> get parametersSchema => {
    'type': 'object',
    'properties': {
      'name': {
        'type': 'string',
        'description': '项目名称，如"计算器"、"待办清单"',
      },
      'description': {
        'type': 'string',
        'description': '项目描述',
      },
      'language': {
        'type': 'string',
        'description': '编程语言: html(默认), javascript, python',
        'enum': ['html', 'javascript', 'python'],
      },
      'code': {
        'type': 'string',
        'description': '完整代码。HTML项目提供完整HTML(含CSS/JS)；JS项目提供纯JS代码；Python项目提供Python代码。',
      },
    },
    'required': ['name', 'code'],
  };

  @override
  Future<AgentToolResult> execute(Map<String, dynamic> arguments) async {
    final name = arguments['name'] as String?;
    final code = arguments['code'] as String?;

    if (name == null || name.isEmpty) {
      return AgentToolResult.fail('缺少项目名称');
    }
    if (code == null || code.isEmpty) {
      return AgentToolResult.fail('缺少代码');
    }

    final language = arguments['language'] as String? ?? 'html';
    final description = arguments['description'] as String? ?? '';

    try {
      final project = sandbox.createFromCode(
        name: name,
        code: code,
        language: language,
        description: description,
      );

      debugPrint('[CodeTool] ✅ 创建项目: $name (${project.id}), ${project.files.length} 个文件');

      return AgentToolResult.success(
        '项目 "$name" 创建成功！\n'
        '项目ID: ${project.id}\n'
        '文件数: ${project.files.length}\n'
        '文件列表: ${project.files.keys.join(", ")}\n'
        '代码总长度: ${project.files.values.fold(0, (a, b) => a + b.length)} 字符\n\n'
        '用户可以在"代码沙盒"页面查看和运行此项目。',
      );
    } catch (e) {
      return AgentToolResult.fail('创建项目失败: $e');
    }
  }
}

/// 更新代码文件工具
class UpdateCodeFileTool extends AgentTool {
  final CodeSandboxService sandbox;

  UpdateCodeFileTool(this.sandbox);

  @override
  String get name => 'update_code_file';

  @override
  String get description => '更新代码项目中的文件。用于修改已有项目的代码。';

  @override
  Map<String, dynamic> get parametersSchema => {
    'type': 'object',
    'properties': {
      'project_name': {
        'type': 'string',
        'description': '项目名称',
      },
      'filename': {
        'type': 'string',
        'description': '文件名，如 index.html, style.css, script.js',
      },
      'content': {
        'type': 'string',
        'description': '新的文件内容',
      },
    },
    'required': ['project_name', 'filename', 'content'],
  };

  @override
  Future<AgentToolResult> execute(Map<String, dynamic> arguments) async {
    final projectName = arguments['project_name'] as String?;
    final filename = arguments['filename'] as String?;
    final content = arguments['content'] as String?;

    if (projectName == null || filename == null || content == null) {
      return AgentToolResult.fail('缺少必要参数');
    }

    // 查找项目
    final project = sandbox.projects.where((p) => p.name == projectName).firstOrNull;
    if (project == null) {
      return AgentToolResult.fail('未找到项目: $projectName');
    }

    try {
      sandbox.updateProjectFile(project.id, filename, content);
      return AgentToolResult.success(
        '文件 "$filename" 已更新 (${content.length} 字符)',
      );
    } catch (e) {
      return AgentToolResult.fail('更新失败: $e');
    }
  }
}

/// 列出代码项目工具
class ListCodeProjectsTool extends AgentTool {
  final CodeSandboxService sandbox;

  ListCodeProjectsTool(this.sandbox);

  @override
  String get name => 'list_code_projects';

  @override
  String get description => '列出所有代码项目';

  @override
  Map<String, dynamic> get parametersSchema => {
    'type': 'object',
    'properties': {},
  };

  @override
  Future<AgentToolResult> execute(Map<String, dynamic> arguments) async {
    final projects = sandbox.projects;
    if (projects.isEmpty) {
      return AgentToolResult.success('还没有任何项目。');
    }

    final buffer = StringBuffer('共 ${projects.length} 个项目:\n\n');
    for (final p in projects) {
      buffer.writeln('📌 ${p.name}');
      buffer.writeln('   文件: ${p.files.keys.join(", ")}');
      buffer.writeln('   更新: ${p.updatedAt.toString().substring(0, 16)}');
      buffer.writeln();
    }

    return AgentToolResult.success(buffer.toString());
  }
}

/// 注册所有代码沙盒工具
void registerCodeSandboxTools(AgentLoopServiceV2 agentLoop, CodeSandboxService sandbox) {
  agentLoop.registerTool(CreateCodeProjectTool(sandbox));
  agentLoop.registerTool(UpdateCodeFileTool(sandbox));
  agentLoop.registerTool(ListCodeProjectsTool(sandbox));
  debugPrint('[CodeTools] 已注册代码沙盒工具');
}
