// 消息模板服务
//
// 常用消息模板管理

import 'dart:async';
import 'package:flutter/foundation.dart';

/// 消息模板
class MessageTemplate {
  final String id;
  final String name;
  final String content;
  final List<String> variables;
  
  MessageTemplate({
    required this.id,
    required this.name,
    required this.content,
    this.variables = const [],
  });
}

/// 模板管理器
class TemplateManager extends ChangeNotifier {
  final List<MessageTemplate> _templates = [];
  
  List<MessageTemplate> get templates => List.unmodifiable(_templates);
  
  /// 添加模板
  void addTemplate(MessageTemplate template) {
    _templates.add(template);
    notifyListeners();
  }
  
  /// 填充变量
  String fillTemplate(String templateId, Map<String, String> values) {
    final template = _templates.firstWhere((t) => t.id == templateId);
    var content = template.content;
    
    for (final key in values.keys) {
      content = content.replaceAll('{$key}', values[key] ?? '');
    }
    
    return content;
  }
  
  /// 删除模板
  void deleteTemplate(String id) {
    _templates.removeWhere((t) => t.id == id);
    notifyListeners();
  }
  
  /// 初始化默认模板
  void initDefaultTemplates() {
    _templates.addAll([
      MessageTemplate(
        id: 'greeting',
        name: '问候',
        content: '你好 {name}！{message}',
        variables: ['name', 'message'],
      ),
      MessageTemplate(
        id: 'reminder',
        name: '提醒',
        content: '提醒：{message}\n时间：{time}',
        variables: ['message', 'time'],
      ),
    ]);
    notifyListeners();
  }
}