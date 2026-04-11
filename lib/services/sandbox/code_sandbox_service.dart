// 代码沙盒服务
//
// 管理代码文件的创建、保存、执行
// 支持多种语言：HTML/CSS/JS（WebView）、Dart（预留）

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// 代码项目
class CodeProject {
  final String id;
  final String name;
  final String description;
  final DateTime createdAt;
  DateTime updatedAt;
  final Map<String, String> files; // filename -> content
  String mainFile; // 入口文件

  CodeProject({
    required this.id,
    required this.name,
    this.description = '',
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, String>? files,
    this.mainFile = 'index.html',
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        files = files ?? {};

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'files': files,
        'mainFile': mainFile,
      };

  factory CodeProject.fromJson(Map<String, dynamic> json) => CodeProject(
        id: json['id'],
        name: json['name'],
        description: json['description'] ?? '',
        createdAt: DateTime.parse(json['createdAt']),
        updatedAt: DateTime.parse(json['updatedAt']),
        files: Map<String, String>.from(json['files'] ?? {}),
        mainFile: json['mainFile'] ?? 'index.html',
      );

  /// 获取完整的 HTML 内容（合并所有文件）
  String get fullHtml {
    if (files.containsKey('index.html')) {
      return files['index.html']!;
    }
    // 自动组装
    final html = files['index.html'] ?? '';
    final css = files['style.css'] ?? '';
    final js = files['script.js'] ?? '';

    if (html.contains('<html') || html.contains('<!DOCTYPE')) {
      return html;
    }

    return '''<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>$name</title>
<style>
* { box-sizing: border-box; margin: 0; padding: 0; }
body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; padding: 16px; }
$css
</style>
</head>
<body>
$html
<script>
$js
</script>
</body>''';
  }

  /// 更新文件
  void updateFile(String filename, String content) {
    files[filename] = content;
    updatedAt = DateTime.now();
  }

  /// 获取项目摘要
  String get summary {
    final fileList = files.keys.map((f) => '- $f (${files[f]!.length} chars)').join('\n');
    return '项目: $name\n描述: $description\n文件:\n$fileList';
  }
}

/// 代码执行结果
class CodeExecutionResult {
  final bool success;
  final String output;
  final String? error;
  final Duration executionTime;
  final String? screenshot; // base64 截图（预留）

  CodeExecutionResult({
    required this.success,
    required this.output,
    this.error,
    this.executionTime = Duration.zero,
    this.screenshot,
  });

  @override
  String toString() {
    if (success) {
      return '✅ 执行成功 (${executionTime.inMilliseconds}ms)\n$output';
    } else {
      return '❌ 执行失败\n$error';
    }
  }
}

/// 代码沙盒服务
class CodeSandboxService extends ChangeNotifier {
  static final CodeSandboxService _instance = CodeSandboxService._internal();
  factory CodeSandboxService() => _instance;
  CodeSandboxService._internal();

  final Map<String, CodeProject> _projects = {};
  String? _activeProjectId;

  List<CodeProject> get projects => _projects.values.toList();
  CodeProject? get activeProject =>
      _activeProjectId != null ? _projects[_activeProjectId] : null;
  int get projectCount => _projects.length;

  /// 创建新项目
  CodeProject createProject(String name, {String description = '', Map<String, String>? files}) {
    final id = 'proj_${DateTime.now().millisecondsSinceEpoch}';
    final project = CodeProject(
      id: id,
      name: name,
      description: description,
      files: files ?? _getDefaultTemplate(name),
    );
    _projects[id] = project;
    _activeProjectId = id;
    _saveToDisk();
    notifyListeners();
    debugPrint('[CodeSandbox] 创建项目: $name ($id), ${project.files.length} 个文件');
    return project;
  }

  /// 获取默认模板
  Map<String, String> _getDefaultTemplate(String name) {
    return {
      'index.html': '''<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>$name</title>
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
    padding: 20px;
    background: #f5f5f5;
  }
  .container {
    max-width: 600px;
    margin: 0 auto;
    background: white;
    border-radius: 12px;
    padding: 20px;
    box-shadow: 0 2px 8px rgba(0,0,0,0.1);
  }
  h1 { font-size: 24px; margin-bottom: 16px; color: #333; }
  p { color: #666; line-height: 1.6; }
</style>
</head>
<body>
<div class="container">
  <h1>$name</h1>
  <p>由小紫霞自动生成的应用 🦞</p>
</div>
</body>
</html>''',
    };
  }

  /// 更新项目文件
  void updateProjectFile(String projectId, String filename, String content) {
    final project = _projects[projectId];
    if (project == null) return;
    project.updateFile(filename, content);
    _saveToDisk();
    notifyListeners();
    debugPrint('[CodeSandbox] 更新文件: $projectId/$filename (${content.length} chars)');
  }

  /// 添加文件到项目
  void addFile(String projectId, String filename, String content) {
    final project = _projects[projectId];
    if (project == null) return;
    project.updateFile(filename, content);
    _saveToDisk();
    notifyListeners();
  }

  /// 删除项目
  void deleteProject(String projectId) {
    _projects.remove(projectId);
    if (_activeProjectId == projectId) {
      _activeProjectId = _projects.isNotEmpty ? _projects.keys.first : null;
    }
    _saveToDisk();
    notifyListeners();
  }

  /// 设置活跃项目
  void setActiveProject(String projectId) {
    if (_projects.containsKey(projectId)) {
      _activeProjectId = projectId;
      notifyListeners();
    }
  }

  /// 从 Agent 描述创建项目（LLM 生成的代码）
  CodeProject createFromCode({
    required String name,
    required String code,
    String language = 'html',
    String description = '',
  }) {
    Map<String, String> files;

    if (language == 'html' || language == 'html-css-js') {
      files = {'index.html': code};
    } else if (language == 'javascript' || language == 'js') {
      // 包装成完整 HTML
      files = {
        'index.html': '''<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>$name</title>
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body { font-family: monospace; padding: 16px; background: #1e1e1e; color: #d4d4d4; }
  pre { white-space: pre-wrap; font-size: 14px; line-height: 1.5; }
</style>
</head>
<body>
<pre id="output"></pre>
<script>
const _output = document.getElementById('output');
const _log = console.log;
console.log = (...args) => {
  _output.textContent += args.map(a => typeof a === 'object' ? JSON.stringify(a, null, 2) : String(a)).join(' ') + '\\n';
  _log(...args);
};
console.error = (...args) => {
  _output.innerHTML += '<span style="color:#f44747">' + args.join(' ') + '</span>\\n';
};
try {
$code
} catch(e) {
  console.error('Error: ' + e.message);
}
</script>
</body>
</html>'''
      };
    } else if (language == 'python') {
      // Python 暂不支持直接执行，包装成显示代码的 HTML
      files = {
        'main.py': code,
        'index.html': '''<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>$name</title>
<style>
  body { font-family: monospace; padding: 16px; background: #1e1e1e; color: #d4d4d4; }
  pre { white-space: pre-wrap; font-size: 14px; }
  .header { color: #569cd6; font-size: 18px; margin-bottom: 12px; }
</style>
</head>
<body>
<div class="header">🐍 Python (预览模式)</div>
<pre>${_escapeHtml(code)}</pre>
</body>
</html>'''
      };
    } else {
      files = {'index.html': code};
    }

    return createProject(name, description: description, files: files);
  }

  static String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
  }

  // ==================== 持久化 ====================

  Future<void> _saveToDisk() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/code_sandbox_projects.json');
      final data = {
        'projects': _projects.map((k, v) => MapEntry(k, v.toJson())),
        'activeProjectId': _activeProjectId,
      };
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      debugPrint('[CodeSandbox] 保存失败: $e');
    }
  }

  Future<void> loadFromDisk() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/code_sandbox_projects.json');
      if (!await file.exists()) return;

      final data = jsonDecode(await file.readAsString());
      final projects = data['projects'] as Map<String, dynamic>;
      for (final entry in projects.entries) {
        _projects[entry.key] = CodeProject.fromJson(entry.value);
      }
      _activeProjectId = data['activeProjectId'];
      debugPrint('[CodeSandbox] 加载了 ${_projects.length} 个项目');
      notifyListeners();
    } catch (e) {
      debugPrint('[CodeSandbox] 加载失败: $e');
    }
  }
}
