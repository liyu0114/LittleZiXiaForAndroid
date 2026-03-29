// 图像分析服务
//
// 使用 LLM Vision API 分析图像

import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// 图像分析结果
class ImageAnalysisResult {
  final String description;
  final List<String>? labels;
  final String? text;
  final Map<String, dynamic>? details;

  ImageAnalysisResult({
    required this.description,
    this.labels,
    this.text,
    this.details,
  });

  factory ImageAnalysisResult.fromJson(Map<String, dynamic> json) {
    return ImageAnalysisResult(
      description: json['description'] ?? '',
      labels: json['labels'] != null ? List<String>.from(json['labels']) : null,
      text: json['text'],
      details: json['details'],
    );
  }
}

/// 图像分析服务
class ImageAnalysisService {
  final String provider;
  final String apiKey;
  final String? baseUrl;

  ImageAnalysisService({
    required this.provider,
    required this.apiKey,
    this.baseUrl,
  });

  /// 分析图像（使用 Vision API）
  Future<ImageAnalysisResult?> analyze(
    String imagePath, {
    String? prompt,
    int maxTokens = 1000,
  }) async {
    try {
      // 读取图像
      final bytes = await _readImageFile(imagePath);
      if (bytes == null) {
        return null;
      }

      // 转换为 base64
      final base64 = base64Encode(bytes);
      
      // 根据提供商选择 API
      switch (provider.toLowerCase()) {
        case 'openai':
          return await _analyzeWithOpenAI(base64, prompt, maxTokens);
        case 'qwen':
        case 'tongyi':
          return await _analyzeWithQwen(base64, prompt, maxTokens);
        default:
          return await _analyzeWithOpenAI(base64, prompt, maxTokens);
      }
    } catch (e) {
      print('[ImageAnalysisService] 分析失败: $e');
      return null;
    }
  }

  /// 分析图像（从 URL）
  Future<ImageAnalysisResult?> analyzeFromUrl(
    String url, {
    String? prompt,
    int maxTokens = 1000,
  }) async {
    try {
      switch (provider.toLowerCase()) {
        case 'openai':
          return await _analyzeUrlWithOpenAI(url, prompt, maxTokens);
        case 'qwen':
        case 'tongyi':
          return await _analyzeUrlWithQwen(url, prompt, maxTokens);
        default:
          return await _analyzeUrlWithOpenAI(url, prompt, maxTokens);
      }
    } catch (e) {
      print('[ImageAnalysisService] URL 分析失败: $e');
      return null;
    }
  }

  /// 读取图像文件
  Future<Uint8List?> _readImageFile(String path) async {
    // 这里需要使用 file_picker 或 path_provider
    // 暂时返回 null
    print('[ImageAnalysisService] 读取图像: $path');
    return null;
  }

  /// 使用 OpenAI Vision API 分析
  Future<ImageAnalysisResult?> _analyzeWithOpenAI(
    String base64,
    String? prompt,
    int maxTokens,
  ) async {
    try {
      final response = await http.post(
        Uri.parse(baseUrl ?? 'https://api.openai.com/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-4o-mini',
          'messages': [
            {
              'role': 'user',
              'content': [
                {
                  'type': 'text',
                  'text': prompt ?? '请描述这张图片',
                },
                {
                  'type': 'image_url',
                  'image_url': {
                    'url': 'data:image/jpeg;base64,$base64',
                  },
                },
              ],
            },
          ],
          'max_tokens': maxTokens,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices']?[0]?['message']?['content'] ?? '';
        
        return ImageAnalysisResult(
          description: content,
        );
      }
      
      return null;
    } catch (e) {
      print('[ImageAnalysisService] OpenAI 分析失败: $e');
      return null;
    }
  }

  /// 使用通义千问 Vision API 分析
  Future<ImageAnalysisResult?> _analyzeWithQwen(
    String base64,
    String? prompt,
    int maxTokens,
  ) async {
    try {
      final response = await http.post(
        Uri.parse(baseUrl ?? 'https://dashscope.aliyuncs.com/api/v1/services/aigc/multimodal-generation/generation'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': 'qwen-vl-max',
          'input': {
            'messages': [
              {
                'role': 'user',
                'content': [
                  {'image': 'data:image/jpeg;base64,$base64'},
                  {'text': prompt ?? '请描述这张图片'},
                ],
              },
            ],
          },
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['output']?['choices']?[0]?['message']?['content'] ?? '';
        
        return ImageAnalysisResult(
          description: content,
        );
      }
      
      return null;
    } catch (e) {
      print('[ImageAnalysisService] 通义千问分析失败: $e');
      return null;
    }
  }

  /// 使用 OpenAI 分析 URL 图像
  Future<ImageAnalysisResult?> _analyzeUrlWithOpenAI(
    String url,
    String? prompt,
    int maxTokens,
  ) async {
    try {
      final response = await http.post(
        Uri.parse(baseUrl ?? 'https://api.openai.com/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-4o-mini',
          'messages': [
            {
              'role': 'user',
              'content': [
                {
                  'type': 'text',
                  'text': prompt ?? '请描述这张图片',
                },
                {
                  'type': 'image_url',
                  'image_url': {'url': url},
                },
              ],
            },
          ],
          'max_tokens': maxTokens,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices']?[0]?['message']?['content'] ?? '';
        
        return ImageAnalysisResult(
          description: content,
        );
      }
      
      return null;
    } catch (e) {
      print('[ImageAnalysisService] URL 分析失败: $e');
      return null;
    }
  }

  /// 使用通义千问分析 URL 图像
  Future<ImageAnalysisResult?> _analyzeUrlWithQwen(
    String url,
    String? prompt,
    int maxTokens,
  ) async {
    try {
      final response = await http.post(
        Uri.parse(baseUrl ?? 'https://dashscope.aliyuncs.com/api/v1/services/aigc/multimodal-generation/generation'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': 'qwen-vl-max',
          'input': {
            'messages': [
              {
                'role': 'user',
                'content': [
                  {'image': url},
                  {'text': prompt ?? '请描述这张图片'},
                ],
              },
            ],
          },
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['output']?['choices']?[0]?['message']?['content'] ?? '';
        
        return ImageAnalysisResult(
          description: content,
        );
      }
      
      return null;
    } catch (e) {
      print('[ImageAnalysisService] URL 分析失败: $e');
      return null;
    }
  }
}
