// 网页搜索服务
//
// 使用 Brave Search API 进行网页搜索

import 'dart:convert';
import 'package:http/http.dart' as http;

/// 搜索结果
class SearchResult {
  final String title;
  final String url;
  final String? description;

  SearchResult({
    required this.title,
    required this.url,
    this.description,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      title: json['title'] ?? '',
      url: json['url'] ?? json['link'] ?? '',
      description: json['description'] ?? json['snippet'],
    );
  }
}

/// 网页搜索服务
class WebSearchService {
  // Brave Search API（免费，无需 API Key）
  static const String _baseUrl = 'https://search.brave.com/search?q=';
  
  // 或者使用 DuckDuckGo Instant Answer API
  static const String _ddgUrl = 'https://api.duckduckgo.com/';

  /// 搜索网页
  Future<List<SearchResult>> search(String query, {int count = 5}) async {
    try {
      print('[WebSearchService] 开始搜索: $query');
      
      // 方案1：使用 DuckDuckGo Instant Answer API（免费，无需 API Key）
      final response = await http.get(
        Uri.parse('$_ddgUrl?q=${Uri.encodeComponent(query)}&format=json&no_html=1'),
      ).timeout(const Duration(seconds: 10));

      print('[WebSearchService] 响应状态: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = <SearchResult>[];

        // 抽象结果（最重要的结果）
        final abstract = data['Abstract'] as String?;
        if (abstract != null && abstract.isNotEmpty) {
          results.add(SearchResult(
            title: data['Heading'] ?? query,
            url: data['AbstractURL'] ?? '',
            description: abstract,
          ));
          print('[WebSearchService] 找到抽象结果');
        }

        // 相关主题
        final relatedTopics = data['RelatedTopics'] as List?;
        if (relatedTopics != null) {
          print('[WebSearchService] 相关主题数: ${relatedTopics.length}');
          for (final topic in relatedTopics.take(count)) {
            if (topic is Map && topic['FirstURL'] != null) {
              results.add(SearchResult(
                title: topic['Text']?.toString().split(' - ').first ?? '',
                url: topic['FirstURL'],
                description: topic['Text'],
              ));
            }
          }
        }

        // 结果分类（如果相关主题为空）
        if (results.isEmpty && data['Results'] != null) {
          final resultList = data['Results'] as List?;
          if (resultList != null) {
            print('[WebSearchService] 结果分类数: ${resultList.length}');
            for (final result in resultList.take(count)) {
              if (result is Map && result['FirstURL'] != null) {
                results.add(SearchResult(
                  title: result['Text'] ?? '',
                  url: result['FirstURL'],
                  description: result['Text'],
                ));
              }
            }
          }
        }

        print('[WebSearchService] 总结果数: ${results.length}');
        return results;
      }

      return [];
    } catch (e) {
      print('[WebSearchService] 搜索失败: $e');
      return [];
    }
  }

  /// 格式化搜索结果
  String formatResults(List<SearchResult> results, {String query = ''}) {
    if (results.isEmpty) {
      return '🔍 没有找到与"$query"相关的结果';
    }

    final buffer = StringBuffer();
    buffer.writeln('🔍 搜索结果：$query');
    buffer.writeln('');

    for (int i = 0; i < results.length; i++) {
      final result = results[i];
      buffer.writeln('${i + 1}. **${result.title}**');
      if (result.description != null && result.description!.isNotEmpty) {
        buffer.writeln('   ${result.description}');
      }
      buffer.writeln('   🔗 ${result.url}');
      buffer.writeln('');
    }

    return buffer.toString().trim();
  }
}
