// 网页搜索服务
//
// 使用 DuckDuckGo Lite + HTML 解析进行网页搜索
// v2: 使用 DuckDuckGo Lite HTML 页面抓取，获取更丰富的搜索结果

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
  // DuckDuckGo Instant Answer API
  static const String _ddgApiUrl = 'https://api.duckduckgo.com/';
  // DuckDuckGo Lite HTML 搜索
  static const String _ddgLiteUrl = 'https://lite.duckduckgo.com/lite/';

  /// 搜索网页
  Future<List<SearchResult>> search(String query, {int count = 5}) async {
    try {
      print('[WebSearchService] 开始搜索: $query');

      // 尝试 HTML 搜索（更丰富的结果）
      final htmlResults = await _searchDuckDuckGoLite(query, count: count);
      if (htmlResults.isNotEmpty) {
        print('[WebSearchService] HTML 搜索返回 ${htmlResults.length} 条结果');
        return htmlResults;
      }

      // 回退到 Instant Answer API
      final apiResults = await _searchDuckDuckGoApi(query, count: count);
      print('[WebSearchService] API 搜索返回 ${apiResults.length} 条结果');
      return apiResults;
    } catch (e) {
      print('[WebSearchService] 搜索失败: $e');
      return [];
    }
  }

  /// DuckDuckGo Lite HTML 搜索（更丰富的结果）
  Future<List<SearchResult>> _searchDuckDuckGoLite(String query, {int count = 5}) async {
    try {
      final response = await http.post(
        Uri.parse(_ddgLiteUrl),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
        },
        body: {
          'q': query,
          'kl': 'cn-zh',
        },
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) return [];

      final html = response.body;
      final results = <SearchResult>[];

      // DuckDuckGo Lite 的结果在 <a> 标签中，class="result-link" 和 class="result-snippet"
      // 也尝试通用的 HTML 解析

      // 方案1: 解析 <a rel="nofollow"> 链接（DuckDuckGo Lite 格式）
      final linkPattern = RegExp(r'<a[^>]*rel="nofollow"[^>]*href="([^"]+)"[^>]*>(.*?)</a>', dotAll: true);
      final snippetPattern = RegExp(r'<td[^>]*class="result-snippet"[^>]*>(.*?)</td>', dotAll: true);

      final links = linkPattern.allMatches(html).toList();
      final snippets = snippetPattern.allMatches(html).toList();

      for (int i = 0; i < links.length && results.length < count; i++) {
        final url = links[i].group(1) ?? '';
        final title = _stripHtml(links[i].group(2) ?? '');

        if (url.isEmpty || title.isEmpty) continue;
        if (url.contains('duckduckgo.com')) continue; // 跳过 DuckDuckGo 自身链接

        String? description;
        if (i < snippets.length) {
          description = _stripHtml(snippets[i].group(1) ?? '');
        }

        results.add(SearchResult(
          title: title,
          url: url,
          description: description,
        ));
      }

      // 方案2: 如果方案1没结果，尝试更通用的解析
      if (results.isEmpty) {
        final genericLink = RegExp(r'<a[^>]*href="(https?://[^"]+)"[^>]*>(.*?)</a>', dotAll: true);
        for (final match in genericLink.allMatches(html)) {
          if (results.length >= count) break;
          final url = match.group(1) ?? '';
          final title = _stripHtml(match.group(2) ?? '');

          if (url.isEmpty || title.isEmpty) continue;
          if (url.contains('duckduckgo.com')) continue;
          if (title.length < 3) continue; // 跳过太短的标题

          results.add(SearchResult(
            title: title,
            url: url,
          ));
        }
      }

      return results;
    } catch (e) {
      print('[WebSearchService] Lite 搜索失败: $e');
      return [];
    }
  }

  /// DuckDuckGo Instant Answer API（回退方案）
  Future<List<SearchResult>> _searchDuckDuckGoApi(String query, {int count = 5}) async {
    try {
      final response = await http.get(
        Uri.parse('$_ddgApiUrl?q=${Uri.encodeComponent(query)}&format=json&no_html=1'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return [];

      final data = json.decode(response.body);
      final results = <SearchResult>[];

      // 抽象结果
      final abstract = data['Abstract'] as String?;
      if (abstract != null && abstract.isNotEmpty) {
        results.add(SearchResult(
          title: data['Heading'] ?? query,
          url: data['AbstractURL'] ?? '',
          description: abstract,
        ));
      }

      // 相关主题
      final relatedTopics = data['RelatedTopics'] as List?;
      if (relatedTopics != null) {
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

      // 结果分类
      if (results.isEmpty && data['Results'] != null) {
        final resultList = data['Results'] as List?;
        if (resultList != null) {
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

      return results;
    } catch (e) {
      print('[WebSearchService] API 搜索失败: $e');
      return [];
    }
  }

  /// 移除 HTML 标签
  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ')
        .trim();
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
