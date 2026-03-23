// Claude Provider (Anthropic)
//
// 支持 Claude 系列模型

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'llm_base.dart';

class ClaudeProvider extends LLMProvider {
  final http.Client _client;
  final String _baseUrl;

  ClaudeProvider(super.config)
      : _client = http.Client(),
        _baseUrl = config.baseUrl ?? 'https://api.anthropic.com/v1';

  @override
  String get name => 'Claude (Anthropic)';

  @override
  Future<List<ModelInfo>> getModels() async {
    // Claude 暂不支持动态获取模型列表
    return _defaultModels;
  }

  List<ModelInfo> get _defaultModels => [
        ModelInfo(
          id: 'claude-sonnet-4-20250514',
          name: 'Claude Sonnet 4',
          contextLength: 200000,
          supportsVision: true,
          supportsTools: true,
        ),
        ModelInfo(
          id: 'claude-opus-4-20250514',
          name: 'Claude Opus 4',
          contextLength: 200000,
          supportsVision: true,
          supportsTools: true,
        ),
        ModelInfo(
          id: 'claude-3-5-sonnet-20241022',
          name: 'Claude 3.5 Sonnet',
          contextLength: 200000,
          supportsVision: true,
          supportsTools: true,
        ),
        ModelInfo(
          id: 'claude-3-5-haiku-20241022',
          name: 'Claude 3.5 Haiku',
          contextLength: 200000,
          supportsTools: true,
        ),
        ModelInfo(
          id: 'claude-3-opus-20240229',
          name: 'Claude 3 Opus',
          contextLength: 200000,
          supportsVision: true,
          supportsTools: true,
        ),
      ];

  Map<String, String> get _headers => {
        'x-api-key': config.apiKey,
        'anthropic-version': '2023-06-01',
        'Content-Type': 'application/json',
      };

  @override
  Future<LLMResponse> chat(
    List<ChatMessage> messages, {
    List<ToolDefinition>? tools,
  }) async {
    final body = _buildRequestBody(messages, tools, stream: false);

    final response = await _client.post(
      Uri.parse('$_baseUrl/messages'),
      headers: _headers,
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw LLMException(
        'Claude API error: ${response.statusCode} - ${response.body}',
      );
    }

    final data = jsonDecode(response.body);
    
    // Claude 的响应格式不同
    String content = '';
    if (data['content'] is List) {
      for (final block in data['content']) {
        if (block['type'] == 'text') {
          content += block['text'] ?? '';
        }
      }
    }

    return LLMResponse(
      content: content,
      finishReason: data['stop_reason'],
      promptTokens: data['usage']?['input_tokens'],
      completionTokens: data['usage']?['output_tokens'],
    );
  }

  @override
  Stream<StreamEvent> chatStream(
    List<ChatMessage> messages, {
    List<ToolDefinition>? tools,
  }) async* {
    final body = _buildRequestBody(messages, tools, stream: true);

    final request = http.Request(
      'POST',
      Uri.parse('$_baseUrl/messages'),
    );
    request.headers.addAll(_headers);
    request.body = jsonEncode(body);

    final response = await _client.send(request);

    if (response.statusCode != 200) {
      final error = await response.stream.bytesToString();
      yield StreamEvent.error('Claude API error: ${response.statusCode} - $error');
      return;
    }

    await for (final line in response.stream
        .toStringStream()
        .transform(const LineSplitter())) {
      if (line.isEmpty || !line.startsWith('data: ')) continue;

      final data = line.substring(6);
      try {
        final json = jsonDecode(data);
        final type = json['type'];

        if (type == 'content_block_delta') {
          final delta = json['delta']?['text'];
          if (delta != null) {
            yield StreamEvent.delta(delta);
          }
        } else if (type == 'message_stop') {
          yield StreamEvent.done();
          break;
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
    // Claude 的消息格式不同：system 单独传，messages 不含 system
    final msgs = <Map<String, dynamic>>[];
    
    for (final m in messages) {
      if (m.role != MessageRole.system) {
        // Claude 使用 'user' 和 'assistant'
        msgs.add({
          'role': m.role == MessageRole.user ? 'user' : 'assistant',
          'content': m.content,
        });
      }
    }

    final body = <String, dynamic>{
      'model': config.model,
      'messages': msgs,
      'max_tokens': config.maxTokens,
      'stream': stream,
    };

    // system prompt 单独传递
    if (config.systemPrompt != null && config.systemPrompt!.isNotEmpty) {
      body['system'] = config.systemPrompt;
    }

    if (tools != null && tools.isNotEmpty) {
      body['tools'] = tools.map((t) => _convertTool(t)).toList();
    }

    return body;
  }

  Map<String, dynamic> _convertTool(ToolDefinition tool) {
    // Claude 的 tool 格式略有不同
    return {
      'name': tool.name,
      'description': tool.description,
      'input_schema': tool.parameters,
    };
  }

  @override
  Future<bool> validateConfig() async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/messages'),
        headers: _headers,
        body: jsonEncode({
          'model': 'claude-3-5-haiku-20241022',
          'messages': [{'role': 'user', 'content': 'hi'}],
          'max_tokens': 1,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  @override
  void dispose() {
    _client.close();
  }
}
