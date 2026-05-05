// 超长上下文服务
//
// 项目管理 + 对话压缩 + 知识库检索

import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';

/// 项目
class Project {
  final String id;
  final String name;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;
  List<Conversation> conversations;
  String? summary;
  
  Project({
    required this.id,
    required this.name,
    this.description,
    required this.createdAt,
    required this.updatedAt,
    this.conversations = const [],
    this.summary,
  });
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'conversations': conversations.map((c) => c.toJson()).toList(),
    'summary': summary,
  };
}

/// 对话
class Conversation {
  final String id;
  final List<ChatMessage> messages;
  String? summary;
  final DateTime createdAt;
  
  Conversation({
    required this.id,
    required this.messages,
    this.summary,
    required this.createdAt,
  });
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'messages': messages.map((m) => m.toJson()).toList(),
    'summary': summary,
    'createdAt': createdAt.toIso8601String(),
  };
}

/// 聊天消息
class ChatMessage {
  final String role; // user/assistant
  final String content;
  final DateTime timestamp;
  
  ChatMessage({
    required this.role,
    required this.content,
    required this.timestamp,
  });
  
  Map<String, dynamic> toJson() => {
    'role': role,
    'content': content,
    'timestamp': timestamp.toIso8601String(),
  };
}

/// 超长上下文管理器
class ContextManager extends ChangeNotifier {
  final List<Project> _projects = [];
  Project? _currentProject;
  Conversation? _currentConversation;
  
  static const int MESSAGE_LIMIT = 20;
  static const int KEEP_RECENT = 10;
  
  List<Project> get projects => List.unmodifiable(_projects);
  Project? get currentProject => _currentProject;
  
  /// 创建项目
  Future<Project> createProject(String name, {String? description}) async {
    final project = Project(
      id: 'project_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      description: description,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _projects.add(project);
    _currentProject = project;
    notifyListeners();
    return project;
  }
  
  /// 添加消息到当前对话
  Future<void> addMessage(String role, String content) async {
    if (_currentProject == null) return;
    
    _currentConversation ??= Conversation(
      id: 'conv_${DateTime.now().millisecondsSinceEpoch}',
      messages: [],
      createdAt: DateTime.now(),
    );
    
    _currentConversation!.messages.add(ChatMessage(
      role: role,
      content: content,
      timestamp: DateTime.now(),
    ));
    
    // 检查是否需要压缩
    if (_currentConversation!.messages.length > MESSAGE_LIMIT) {
      await _compressConversation(_currentConversation!);
    }
    
    _currentProject!.updatedAt = DateTime.now();
    notifyListeners();
  }
  
  /// 压缩对话（生成摘要）
  Future<void> _compressConversation(Conversation conv) async {
    if (conv.summary != null) return;
    
    // 简单实现：取所有消息拼接
    final allContent = conv.messages.map((m) => '${m.role}: ${m.content}').join('\n');
    
    // TODO: 使用LLM生成真正的摘要
    // 这里简单取前几条和后几条
    final recent = conv.messages.take(5).map((m) => m.content).join('\n');
    conv.summary = '[摘要] $recent ... (共${conv.messages.length}条消息)';
    
    // 只保留最近的
    conv.messages = conv.messages.skip(conv.messages.length - KEEP_RECENT).toList();
    
    debugPrint('[ContextManager] 压缩对话: ${conv.id}');
  }
  
  /// 搜索历史（知识库检索）
  Future<List<SearchResult>> search(String query) async {
    final results = <SearchResult>[];
    
    for (final project in _projects) {
      // 搜索摘要
      if (project.summary != null && 
          project.summary!.toLowerCase().contains(query.toLowerCase())) {
        results.add(SearchResult(
          projectId: project.id,
          projectName: project.name,
          matchedText: project.summary!,
          type: 'summary',
        ));
      }
      
      // 搜索对话
      for (final conv in project.conversations) {
        for (final msg in conv.messages) {
          if (msg.content.toLowerCase().contains(query.toLowerCase())) {
            results.add(SearchResult(
              projectId: project.id,
              projectName: project.name,
              matchedText: msg.content,
              type: 'message',
            ));
          }
        }
      }
    }
    
    return results;
  }
  
  /// 获取当前项目摘要
  String? getCurrentSummary() => _currentProject?.summary;
}

/// 搜索结果
class SearchResult {
  final String projectId;
  final String projectName;
  final String matchedText;
  final String type;
  
  SearchResult({
    required this.projectId,
    required this.projectName,
    required this.matchedText,
    required this.type,
  });
}