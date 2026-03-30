// 自定义 LLM Provider
//
// 支持任意 OpenAI 兼容的 API

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'llm_base.dart';

/// 自定义 LLM Provider
///
/// 支持 OpenAI 兼容的 API 端点
class CustomLLMProvider extends LLMProvider {
  CustomLLMProvider(super.config);

  @override
  String get name => config.provider;

  @override
  Future<List<ModelInfo>> getModels() async {
    try {
      final response = await http.get(
        Uri.parse('${config.baseUrl}/models'),
        headers: {
          'Authorization': 'Bearer ${config.apiKey}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final models = (data['data'] as List)
            .map((m) => ModelInfo(
                  id: m['id'],
                  name: m['id'],
                  ownedBy: m['owned_by'] ?? 'custom',
                ))
            .toList();
        return models;
      }
    } catch (e) {
      // 如果获取模型列表失败，返回配置的默认模型
      return config.models
              ?.map((m) => ModelInfo(id: m, name: m, ownedBy: 'custom'))
              .toList() ??
          [];
    }

    return [];
  }

  @override
  Future<LLMResponse> chat(
    List<ChatMessage> messages, {
    List<ToolDefinition>? tools,
  }) async {
    final requestBody = {
      'model': config.model,
      'messages': messages
          .map((m) => {
                'role': m.role.toString().split('.').last,
                'content': m.content,
              })
          .toList(),
      'temperature': config.temperature ?? 0.7,
      'max_tokens': config.maxTokens ?? 4096,
      if (tools != null)
        'tools': tools
            .map((t) => {
                  'type': 'function',
                  'function': {
                    'name': t.name,
                    'description': t.description,
                    'parameters': t.parameters,
                  },
                })
            .toList(),
    };

    try {
      final response = await http.post(
        Uri.parse('${config.baseUrl}/chat/completions'),
        headers: {
          'Authorization': 'Bearer ${config.apiKey}',
          'Content-Type': 'application/json',
        },
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final choice = data['choices'][0];
        final message = choice['message'];

        return LLMResponse(
          content: message['content'] ?? '',
          toolCalls: message['tool_calls'] != null
              ? (message['tool_calls'] as List)
                  .map((tc) => ToolCall(
                        id: tc['id'],
                        name: tc['function']['name'],
                        arguments: tc['function']['arguments'],
                      ))
                  .toList()
              : null,
          finishReason: choice['finish_reason'],
          usage: data['usage'] != null
              ? Usage(
                  promptTokens: data['usage']['prompt_tokens'],
                  completionTokens: data['usage']['completion_tokens'],
                  totalTokens: data['usage']['total_tokens'],
                )
              : null,
        );
      } else {
        throw LLMException(
            'HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      if (e is LLMException) rethrow;
      throw LLMException('请求失败: $e');
    }
  }

  @override
  Stream<StreamEvent> chatStream(
    List<ChatMessage> messages, {
    List<ToolDefinition>? tools,
  }) async* {
    final requestBody = {
      'model': config.model,
      'messages': messages
          .map((m) => {
                'role': m.role.toString().split('.').last,
                'content': m.content,
              })
          .toList(),
      'temperature': config.temperature ?? 0.7,
      'max_tokens': config.maxTokens ?? 4096,
      'stream': true,
      if (tools != null)
        'tools': tools
            .map((t) => {
                  'type': 'function',
                  'function': {
                    'name': t.name,
                    'description': t.description,
                    'parameters': t.parameters,
                  },
                })
            .toList(),
    };

    try {
      final request = http.Request(
        'POST',
        Uri.parse('${config.baseUrl}/chat/completions'),
      );
      request.headers['Authorization'] = 'Bearer ${config.apiKey}';
      request.headers['Content-Type'] = 'application/json';
      request.body = json.encode(requestBody);

      final response = await http.Client().send(request);

      await for (final chunk
          in response.stream.transform(utf8.decoder)) {
        final lines = chunk.split('\n');

        for (final line in lines) {
          if (line.startsWith('data: ')) {
            final data = line.substring(6).trim();
            if (data == '[DONE]') {
              yield StreamEvent.complete();
              return;
            }

            try {
              final json = jsonDecode(data);
              final delta = json['choices']?[0]?['delta'];

              if (delta != null) {
                final content = delta['content'];
                if (content != null) {
                  yield StreamEvent.text(content);
                }

                final toolCalls = delta['tool_calls'];
                if (toolCalls != null) {
                  for (final tc in toolCalls) {
                    yield StreamEvent.toolCall(
                      tc['id'],
                      tc['function']['name'],
                      tc['function']['arguments'],
                    );
                  }
                }
              }
            } catch (e) {
              // 忽略解析错误
            }
          }
        }
      }
    } catch (e) {
      yield StreamEvent.error(e.toString());
    }
  }

  @override
  Future<bool> validateConfig() async {
    try {
      // 尝试获取模型列表来验证配置
      final models = await getModels();
      return models.isNotEmpty || (config.model?.isNotEmpty ?? false);
    } catch (e) {
      return false;
    }
  }
}
