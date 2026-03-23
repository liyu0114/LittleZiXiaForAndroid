// GLM Provider (智谱 AI)
//
// 支持智谱 GLM 系列模型

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'llm_base.dart';

// 当前版本号（用于错误报告）
const _APP_VERSION = 'v0.6.1 (Build 17)';

class GLMProvider extends LLMProvider {
  final http.Client _client;
  final String _baseUrl;

  GLMProvider(super.config)
      : _client = _createClient(),
        _baseUrl = config.baseUrl?.isNotEmpty == true 
            ? config.baseUrl! 
            : 'https://open.bigmodel.cn/api/paas/v4' {
    print('[GLM] Provider 初始化');
    print('[GLM] config.baseUrl: ${config.baseUrl}');
    print('[GLM] 实际使用的 _baseUrl: $_baseUrl');
  }
  
  static http.Client _createClient() {
    // 创建自定义 HttpClient，解决 Android 网络问题
    final httpClient = HttpClient();
    httpClient.connectionTimeout = const Duration(seconds: 15);
    return IOClient(httpClient);
  }

  @override
  String get name => 'GLM (智谱)';

  @override
  Future<List<ModelInfo>> getModels() async {
    // GLM 暂不支持动态获取模型列表
    return _defaultModels;
  }

  List<ModelInfo> get _defaultModels => [
        ModelInfo(
          id: 'glm-5',
          name: 'GLM-5 (最新推荐)',
          contextLength: 128000,
          supportsTools: true,
          supportsVision: true,
        ),
        ModelInfo(
          id: 'glm-4-flash',
          name: 'GLM-4 Flash (免费)',
          contextLength: 128000,
          supportsTools: true,
        ),
        ModelInfo(
          id: 'glm-4-plus',
          name: 'GLM-4 Plus',
          contextLength: 128000,
          supportsTools: true,
          supportsVision: true,
        ),
        ModelInfo(
          id: 'glm-4-0520',
          name: 'GLM-4 0520',
          contextLength: 128000,
          supportsTools: true,
        ),
        ModelInfo(
          id: 'glm-4-air',
          name: 'GLM-4 Air',
          contextLength: 128000,
          supportsTools: true,
        ),
        ModelInfo(
          id: 'glm-4-airx',
          name: 'GLM-4 AirX',
          contextLength: 8192,
          supportsTools: true,
        ),
        ModelInfo(
          id: 'glm-4v-plus',
          name: 'GLM-4V Plus (视觉)',
          contextLength: 8192,
          supportsVision: true,
        ),
      ];

  Map<String, String> get _headers => {
        'Authorization': 'Bearer ${config.apiKey}',
        'Content-Type': 'application/json',
      };

  // 辅助方法：包装异常，添加版本号
  Exception _wrapError(dynamic e, String context) {
    return Exception('$context\n\n错误: $e\n\n━━━━━━━━━━━━━━━━━━━━\n📱 小紫霞版本: $_APP_VERSION\n━━━━━━━━━━━━━━━━━━━━');
  }

  @override
  Future<LLMResponse> chat(
    List<ChatMessage> messages, {
    List<ToolDefinition>? tools,
  }) async {
    try {
      final body = _buildRequestBody(messages, tools, stream: false);

      final response = await _client.post(
        Uri.parse('$_baseUrl/chat/completions'),
        headers: _headers,
        body: jsonEncode(body),
      );

      if (response.statusCode != 200) {
        throw _wrapError(
          'GLM API error: ${response.statusCode} - ${response.body}',
          '对话请求失败',
        );
      }

      final data = jsonDecode(response.body);
      final choice = data['choices'][0];

      return LLMResponse(
        content: choice['message']['content'] ?? '',
        finishReason: choice['finish_reason'],
        toolCalls: choice['message']['tool_calls'],
        promptTokens: data['usage']?['prompt_tokens'],
        completionTokens: data['usage']?['completion_tokens'],
      );
    } catch (e) {
      throw _wrapError(e, 'GLM 对话请求异常');
    }
  }

  @override
  Stream<StreamEvent> chatStream(
    List<ChatMessage> messages, {
    List<ToolDefinition>? tools,
  }) async* {
    final body = _buildRequestBody(messages, tools, stream: true);

    final request = http.Request(
      'POST',
      Uri.parse('$_baseUrl/chat/completions'),
    );
    request.headers.addAll(_headers);
    request.body = jsonEncode(body);

    final response = await _client.send(request);

    if (response.statusCode != 200) {
      final error = await response.stream.bytesToString();
      yield StreamEvent.error('GLM API error: ${response.statusCode} - $error');
      return;
    }

    await for (final line in response.stream
        .toStringStream()
        .transform(const LineSplitter())) {
      if (line.isEmpty || !line.startsWith('data: ')) continue;

      final data = line.substring(6);
      if (data == '[DONE]') {
        yield StreamEvent.done();
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

    if (config.systemPrompt != null && config.systemPrompt!.isNotEmpty) {
      msgs.add(ChatMessage.system(config.systemPrompt!).toJson());
    }

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
      // 使用用户实际选择的模型进行测试
      final url = '$_baseUrl/chat/completions';
      print('[GLM] Testing connection to: $url');
      print('[GLM] Using API Key: ${config.apiKey.substring(0, 10)}...');
      print('[GLM] Testing model: ${config.model}');
      
      final response = await _client.post(
        Uri.parse(url),
        headers: _headers,
        body: jsonEncode({
          'model': config.model, // 使用用户选择的模型
          'messages': [{'role': 'user', 'content': 'hi'}],
          'max_tokens': 1,
        }),
      ).timeout(const Duration(seconds: 15));
      
      print('[GLM] Response status: ${response.statusCode}');
      print('[GLM] Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        return true;
      } else if (response.statusCode == 401) {
        throw _wrapError('HTTP 401', 'API Key 无效或已过期');
      } else if (response.statusCode == 404) {
        throw _wrapError('HTTP 404', 'API 端点不存在，请检查 Base URL');
      } else if (response.statusCode == 429) {
        throw _wrapError('HTTP 429', 'API 调用频率超限');
      } else if (response.statusCode == 400) {
        // 模型不存在通常返回 400
        throw _wrapError(
          'HTTP 400',
          '模型不存在或不可用\n模型: ${config.model}\n请选择其他模型',
        );
      } else {
        throw _wrapError(
          'HTTP ${response.statusCode}',
          'API 请求失败\n${response.body}',
        );
      }
    } on TimeoutException {
      throw _wrapError('TimeoutException', '连接超时，请检查网络或 Base URL');
    } on SocketException catch (e) {
      throw _wrapError('SocketException', '网络错误: ${e.message}\n无法连接到 $_baseUrl');
    } catch (e) {
      print('[GLM] Validation error: $e');
      if (e is Exception) {
        rethrow;
      }
      throw _wrapError(e.toString(), '验证失败');
    }
  }

  @override
  void dispose() {
    _client.close();
  }
}
