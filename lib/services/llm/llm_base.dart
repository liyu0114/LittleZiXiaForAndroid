// LLM Provider 基础接口
//
// 所有 LLM 提供商都需要实现此接口

import 'dart:async';

/// 消息角色
enum MessageRole {
  system,
  user,
  assistant,
  tool,
}

/// 聊天消息
class ChatMessage {
  final MessageRole role;
  final String content;
  final String? name;
  final dynamic toolCalls;  // OpenAI/GLM 返回 List
  final String? toolCallId;
  
  // 多模态支持
  final List<Map<String, dynamic>>? images;  // 图片列表（base64 或 URL）
  final bool isMultimodal;  // 是否多模态消息

  ChatMessage({
    required this.role,
    required this.content,
    this.name,
    this.toolCalls,
    this.toolCallId,
    this.images,
    this.isMultimodal = false,
  });

  Map<String, dynamic> toJson() {
    // 如果是视觉模型且包含图片，使用多模态格式
    if (isMultimodal && images != null && images!.isNotEmpty) {
      final contentParts = <Map<String, dynamic>>[
        {'type': 'text', 'text': content},
      ];
      
      // 添加图片（通义千问 VL 格式）
      for (final img in images!) {
        // image_url 必须是一个对象，包含 url 字段
        if (img.containsKey('url')) {
          contentParts.add({
            'type': 'image_url',
            'image_url': {
              'url': img['url'],
            },
          });
        } else {
          // 如果直接是 URL
          contentParts.add({
            'type': 'image_url',
            'image_url': img,
          });
        }
      }
      
      return {
        'role': role.name,
        'content': contentParts,
        if (name != null) 'name': name,
        if (toolCalls != null) 'tool_calls': toolCalls,
        if (toolCallId != null) 'tool_call_id': toolCallId,
      };
    }
    
    // 普通文本消息
    return {
      'role': role.name,
      'content': content,
      if (name != null) 'name': name,
      if (toolCalls != null) 'tool_calls': toolCalls,
      if (toolCallId != null) 'tool_call_id': toolCallId,
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      role: MessageRole.values.firstWhere((r) => r.name == json['role']),
      content: json['content'] ?? '',
      name: json['name'],
      toolCalls: json['tool_calls'],
      toolCallId: json['tool_call_id'],
    );
  }

  factory ChatMessage.system(String content) =>
      ChatMessage(role: MessageRole.system, content: content);

  factory ChatMessage.user(String content) =>
      ChatMessage(role: MessageRole.user, content: content);

  factory ChatMessage.assistant(String content) =>
      ChatMessage(role: MessageRole.assistant, content: content);
  
  /// 创建多模态消息（文本 + 图片）
  factory ChatMessage.multimodal({
    required String text,
    required List<Map<String, dynamic>> images,
  }) => ChatMessage(
    role: MessageRole.user,
    content: text,
    images: images,
    isMultimodal: true,
  );
}

/// 模型信息
class ModelInfo {
  final String id;
  final String name;
  final String? description;
  final int? contextLength;
  final bool supportsVision;
  final bool supportsTools;

  ModelInfo({
    required this.id,
    required this.name,
    this.description,
    this.contextLength,
    this.supportsVision = false,
    this.supportsTools = false,
  });
}

/// Tool 定义
class ToolDefinition {
  final String name;
  final String description;
  final Map<String, dynamic> parameters;

  ToolDefinition({
    required this.name,
    required this.description,
    required this.parameters,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': 'function',
      'function': {
        'name': name,
        'description': description,
        'parameters': parameters,
      },
    };
  }
}

/// LLM 配置
class LLMConfig {
  final String provider;
  final String apiKey;
  final String? baseUrl;
  final String model;
  final double temperature;
  final int maxTokens;
  final String? systemPrompt;

  LLMConfig({
    required this.provider,
    required this.apiKey,
    this.baseUrl,
    required this.model,
    this.temperature = 0.7,
    this.maxTokens = 4096,
    this.systemPrompt,
  });
  
  /// 检测是否为视觉模型
  bool get isVisionModel {
    final lowerModel = model.toLowerCase();
    return lowerModel.contains('vl') ||
           lowerModel.contains('vision') ||
           lowerModel.contains('gemini') ||
           lowerModel.contains('gpt-4o') ||
           lowerModel.contains('claude-3');
  }

  Map<String, dynamic> toJson() {
    return {
      'provider': provider,
      'apiKey': apiKey,
      'baseUrl': baseUrl,
      'model': model,
      'temperature': temperature,
      'maxTokens': maxTokens,
      'systemPrompt': systemPrompt,
    };
  }

  factory LLMConfig.fromJson(Map<String, dynamic> json) {
    return LLMConfig(
      provider: json['provider'] ?? 'openai',
      apiKey: json['apiKey'] ?? '',
      baseUrl: json['baseUrl'],
      model: json['model'] ?? 'gpt-3.5-turbo',
      temperature: (json['temperature'] ?? 0.7).toDouble(),
      maxTokens: json['maxTokens'] ?? 4096,
      systemPrompt: json['systemPrompt'],
    );
  }
}

/// LLM 响应
class LLMResponse {
  final String content;
  final String? finishReason;
  final dynamic toolCalls;  // OpenAI/GLM 返回 List，某些 provider 可能返回 Map
  final int? promptTokens;
  final int? completionTokens;

  LLMResponse({
    required this.content,
    this.finishReason,
    this.toolCalls,
    this.promptTokens,
    this.completionTokens,
  });
}

/// 流式响应事件
class StreamEvent {
  final String? delta;
  final bool done;
  final String? error;
  /// 完整的工具调用列表（仅在 done 事件中携带）
  final List<Map<String, dynamic>>? toolCallsList;

  StreamEvent({
    this.delta,
    this.done = false,
    this.error,
    this.toolCallsList,
  });

  /// 是否包含工具调用
  bool get hasToolCalls => toolCallsList != null && toolCallsList!.isNotEmpty;

  // 保留旧字段兼容
  Map<String, dynamic>? get toolCalls =>
      toolCallsList != null && toolCallsList!.isNotEmpty ? {'tool_calls': toolCallsList} : null;

  factory StreamEvent.delta(String text) => StreamEvent(delta: text);
  factory StreamEvent.done({List<Map<String, dynamic>>? toolCalls}) =>
      StreamEvent(done: true, toolCallsList: toolCalls);
  factory StreamEvent.error(String message) => StreamEvent(error: message);
}

/// LLM 异常
class LLMException implements Exception {
  final String message;
  LLMException(this.message);

  @override
  String toString() => 'LLMException: $message';
}

/// LLM Provider 抽象基类
abstract class LLMProvider {
  final LLMConfig config;

  LLMProvider(this.config);

  /// 提供商名称
  String get name;

  /// 支持的模型列表
  Future<List<ModelInfo>> getModels();

  /// 发送聊天请求（一次性返回）
  Future<LLMResponse> chat(
    List<ChatMessage> messages, {
    List<ToolDefinition>? tools,
  });

  /// 发送聊天请求（流式返回）
  Stream<StreamEvent> chatStream(
    List<ChatMessage> messages, {
    List<ToolDefinition>? tools,
  });

  /// 验证配置是否有效
  Future<bool> validateConfig();

  /// 释放资源
  void dispose() {}
}
