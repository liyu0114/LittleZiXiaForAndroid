// OpenAI Provider
//
// 支持 OpenAI API 及兼容接口（如 Ollama、vLLM 等）

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'llm_base.dart';

class OpenAIProvider extends LLMProvider {
  final http.Client _client;
  final String _baseUrl;

  OpenAIProvider(super.config)
      : _client = http.Client(),
        _baseUrl = config.baseUrl ?? 'https://api.openai.com/v1';

  @override
  String get name {
    // 根据提供商 ID 返回正确的名称
    switch (config.provider.toLowerCase()) {
      case 'qwen':
        return '通义千问';
      case 'deepseek':
        return 'DeepSeek';
      case 'moonshot':
        return 'Moonshot';
      case 'ernie':
        return '文心一言';
      case 'ollama':
        return 'Ollama';
      case 'custom':
        return '自定义接口';
      default:
        return 'OpenAI';
    }
  }

  @override
  Future<List<ModelInfo>> getModels() async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/models'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final models = (data['data'] as List).map((m) {
          final id = m['id'] as String;
          return ModelInfo(
            id: id,
            name: id,
            contextLength: _guessContextLength(id),
            supportsVision: id.contains('vision') || id.contains('gpt-4o'),
            supportsTools: id.contains('gpt-4') || id.contains('gpt-3.5-turbo'),
          );
        }).toList();
        return models;
      }
    } catch (e) {
      // 如果获取模型列表失败，返回默认列表
    }

    return _defaultModels;
  }

  List<ModelInfo> get _defaultModels => [
        ModelInfo(
          id: 'gpt-4o',
          name: 'GPT-4o',
          contextLength: 128000,
          supportsVision: true,
          supportsTools: true,
        ),
        ModelInfo(
          id: 'gpt-4o-mini',
          name: 'GPT-4o Mini',
          contextLength: 128000,
          supportsVision: true,
          supportsTools: true,
        ),
        ModelInfo(
          id: 'gpt-4-turbo',
          name: 'GPT-4 Turbo',
          contextLength: 128000,
          supportsVision: true,
          supportsTools: true,
        ),
        ModelInfo(
          id: 'gpt-3.5-turbo',
          name: 'GPT-3.5 Turbo',
          contextLength: 16385,
          supportsTools: true,
        ),
      ];

  int _guessContextLength(String modelId) {
    if (modelId.contains('128k')) return 128000;
    if (modelId.contains('32k')) return 32768;
    if (modelId.contains('gpt-4') || modelId.contains('gpt-4o')) return 128000;
    if (modelId.contains('gpt-3.5')) return 16385;
    return 4096;
  }

  Map<String, String> get _headers {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    // 只有在有 API key 的情况下才添加 Authorization
    if (config.apiKey != null && config.apiKey.isNotEmpty) {
      headers['Authorization'] = 'Bearer ${config.apiKey}';
    }
    return headers;
  }

  @override
  Future<LLMResponse> chat(
    List<ChatMessage> messages, {
    List<ToolDefinition>? tools,
  }) async {
    final body = _buildRequestBody(messages, tools, stream: false);
    
    // 详细日志：请求准备
    print('========== LLM 请求开始 ==========');
    print('[1/6] URL: $_baseUrl/chat/completions');
    print('[2/6] Model: ${body['model']}');
    print('[3/6] Messages count: ${messages.length}');
    print('[4/6] Headers: $_headers');
    print('[5/6] Request body: ${jsonEncode(body).substring(0, 200)}...');
    print('[6/6] 开始发送请求...');
    
    final startTime = DateTime.now();
    
    late final http.Response response;
    try {
      // 连接开始
      print('[LLM] 📡 正在连接...');
      
      response = await _client.post(
        Uri.parse('$_baseUrl/chat/completions'),
        headers: _headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 600));
      
      // 连接成功
      final connectTime = DateTime.now().difference(startTime);
      print('[LLM] ✅ 连接成功 (耗时: ${connectTime.inMilliseconds}ms)');
      print('[LLM] 📥 收到响应 statusCode: ${response.statusCode}');
      
    } on TimeoutException {
      final elapsed = DateTime.now().difference(startTime);
      print('[LLM] ⏱️ 请求超时 (已等待: ${elapsed.inSeconds}秒)');
      print('[LLM] 💡 提示: 网络延迟高或服务器响应慢');
      rethrow;
    } on SocketException catch (e) {
      final elapsed = DateTime.now().difference(startTime);
      print('[LLM] 🌐 Socket异常 (耗时: ${elapsed.inMilliseconds}ms)');
      print('[LLM] ❌ 错误: ${e.runtimeType}');
      print('[LLM] 📍 地址: ${e.address?.address ?? "未知"}');
      print('[LLM] 🔌 端口: ${e.port ?? "未知"}');
      print('[LLM] 💬 消息: ${e.message}');
      print('[LLM] 🔍 errno: ${e.osError?.errorCode} - ${e.osError?.message}');
      rethrow;
    } catch (e, st) {
      final elapsed = DateTime.now().difference(startTime);
      print('[LLM] ❌ 未知异常 (耗时: ${elapsed.inMilliseconds}ms)');
      print('[LLM] ❌ 类型: ${e.runtimeType}');
      print('[LLM] ❌ 内容: $e');
      print('[LLM] 📚 Stack: $st');
      rethrow;
    }
    
    final elapsed = DateTime.now().difference(startTime);
    print('[LLM] ⏱️ 总耗时: ${elapsed.inSeconds}秒 ${elapsed.inMilliseconds % 1000}ms');

    if (response.statusCode != 200) {
      print('[LLM] ❌ HTTP错误: ${response.statusCode}');
      print('[LLM] ❌ 响应内容: ${response.body}');
      throw LLMException(
        'OpenAI API error: ${response.statusCode} - ${response.body}',
      );
    }

    final data = jsonDecode(response.body);
    final choice = data['choices'][0];

    print('[LLM] ✅ 请求成功完成!');
    
    return LLMResponse(
      content: choice['message']['content'] ?? '',
      finishReason: choice['finish_reason'],
      toolCalls: choice['message']['tool_calls'],
      promptTokens: data['usage']?['prompt_tokens'],
      completionTokens: data['usage']?['completion_tokens'],
    );
  }

  @override
  Stream<StreamEvent> chatStream(
    List<ChatMessage> messages, {
    List<ToolDefinition>? tools,
  }) async* {
    final body = _buildRequestBody(messages, tools, stream: true);

    print('[OpenAI Stream] 发送流式请求 - URL: $_baseUrl/chat/completions, Model: ${body['model']}');
    print('[OpenAI Stream] Request body: ${jsonEncode(body).substring(0, 200)}...');
    final startTime = DateTime.now();

    final request = http.Request(
      'POST',
      Uri.parse('$_baseUrl/chat/completions'),
    );
    request.headers.addAll(_headers);
    request.body = jsonEncode(body);

    print('[OpenAI Stream] 发送请求...');
    
    late final http.StreamedResponse response;
    try {
      response = await _client.send(request).timeout(const Duration(seconds: 600));
    } on TimeoutException {
      print('[OpenAI Stream] ⏱️ 请求超时');
      yield StreamEvent.error('请求超时');
      return;
    } on SocketException catch (e) {
      print('[OpenAI Stream] 🌐 Socket 错误: ${e.message}');
      yield StreamEvent.error('网络错误: ${e.message}');
      return;
    } catch (e) {
      print('[OpenAI Stream] ❌ 发送请求异常: ${e.runtimeType} - $e');
      yield StreamEvent.error('异常: ${e.runtimeType} - $e');
      return;
    }

    print('[OpenAI Stream] 请求已发送，等待响应...');
    final elapsed = DateTime.now().difference(startTime);
    print('[OpenAI Stream] 收到响应状态: ${response.statusCode} (耗时: ${elapsed.inSeconds}秒)');

    if (response.statusCode != 200) {
      final error = await response.stream.bytesToString();
      print('[OpenAI Stream] 错误: $error');
      yield StreamEvent.error('OpenAI API error: ${response.statusCode} - $error');
      return;
    }

    // 累积 tool_calls（流式中 tool_calls 是增量拼接的）
    final Map<int, Map<String, dynamic>> accumulatedToolCalls = {};

    await for (final line in response.stream
        .toStringStream()
        .transform(const LineSplitter())) {
      if (line.isEmpty || !line.startsWith('data: ')) continue;
      
      final data = line.substring(6);
      if (data == '[DONE]') {
        final toolCalls = accumulatedToolCalls.isEmpty
            ? null
            : (accumulatedToolCalls.keys.toList()..sort())
                .map((i) => accumulatedToolCalls[i]!).toList();
        yield StreamEvent.done(toolCalls: toolCalls);
        break;
      }

      try {
        final json = jsonDecode(data);
        final delta = json['choices']?[0]?['delta'];

        if (delta != null) {
          final content = delta['content'] as String?;
          if (content != null && content.isNotEmpty) {
            yield StreamEvent.delta(content);
          }

          // 累积 tool_calls
          final toolCallsDelta = delta['tool_calls'];
          if (toolCallsDelta is List) {
            for (final tc in toolCallsDelta) {
              if (tc is Map) {
                final idx = tc['index'] as int? ?? 0;
                if (!accumulatedToolCalls.containsKey(idx)) {
                  accumulatedToolCalls[idx] = {
                    'id': tc['id'] ?? '',
                    'type': 'function',
                    'function': {'name': '', 'arguments': ''},
                  };
                }
                final func = tc['function'];
                if (func is Map) {
                  if (func['name'] != null) {
                    accumulatedToolCalls[idx]!['function']['name'] = func['name'];
                  }
                  if (func['arguments'] != null) {
                    accumulatedToolCalls[idx]!['function']['arguments'] =
                        (accumulatedToolCalls[idx]!['function']['arguments'] ?? '') +
                        func['arguments'].toString();
                  }
                }
                if (tc['id'] != null) {
                  accumulatedToolCalls[idx]!['id'] = tc['id'];
                }
              }
            }
          }
        }
      } catch (e) {
        // 忽略解析错误
      }
    }
  }

  Map<String, dynamic> _buildRequestBody(
    List<ChatMessage> messages,
    List<ToolDefinition>? tools, {
    required bool stream,
  }) {
    final msgs = <Map<String, dynamic>>[];

    // 添加 system prompt
    if (config.systemPrompt != null && config.systemPrompt!.isNotEmpty) {
      msgs.add(ChatMessage.system(config.systemPrompt!).toJson());
    }

    // 添加对话消息
    msgs.addAll(messages.map((m) => m.toJson()));

    final body = <String, dynamic>{
      'model': config.model,
      'messages': msgs,
      'temperature': config.temperature,
      'max_tokens': config.maxTokens,
      'stream': stream,
    };

    if (tools != null && tools.isNotEmpty) {
      body['tools'] = tools.map((t) => t.toJson()).toList();
    }

    return body;
  }

  @override
  Future<bool> validateConfig() async {
    try {
      final url = '$_baseUrl/models';
      print('[OpenAI] Testing connection to: $url');
      print('[OpenAI] Using API Key: ${config.apiKey.length >= 10 ? config.apiKey.substring(0, 10) : config.apiKey}...');
      
      final response = await _client.get(
        Uri.parse(url),
        headers: _headers,
      ).timeout(const Duration(seconds: 60));
      
      print('[OpenAI] Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        return true;
      } else if (response.statusCode == 401) {
        throw Exception('API Key 无效或已过期 (HTTP 401)');
      } else if (response.statusCode == 404) {
        throw Exception('API 端点不存在 (HTTP 404)，请检查 Base URL');
      } else if (response.statusCode == 429) {
        throw Exception('API 调用频率超限 (HTTP 429)');
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } on TimeoutException {
      throw Exception('连接超时，请检查网络或 Base URL');
    } on SocketException catch (e) {
      throw Exception('网络错误: ${e.message}\n无法连接到 $_baseUrl');
    } catch (e) {
      print('[OpenAI] Validation error: $e');
      if (e is Exception) {
        rethrow;
      }
      throw Exception('验证失败: $e');
    }
  }

  @override
  void dispose() {
    _client.close();
  }
}
