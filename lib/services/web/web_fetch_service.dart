// 网页获取服务
//
// 获取网页内容并转换为可读文本

import 'package:http/http.dart' as http;
import 'dart:convert';

/// 网页获取服务
class WebFetchService {
  /// 获取网页内容
  Future<String> fetch(String url, {int maxChars = 5000}) async {
    try {
      // 验证 URL
      final uri = Uri.parse(url);
      if (!uri.hasScheme || (!uri.scheme.startsWith('http'))) {
        return '❌ 无效的 URL: $url';
      }

      final response = await http.get(
        uri,
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        return '❌ 请求失败: HTTP ${response.statusCode}';
      }

      // 解码内容
      String content;
      try {
        // 使用 bodyBytes 确保正确 UTF-8 解码
        final bytes = response.bodyBytes;
        // 尝试检测是否已经是正确的 UTF-8
        content = utf8.decode(bytes, allowMalformed: true);
        
        // 修复常见的双重编码问题（如 Â°C → °C）
        content = _fixDoubleEncoding(content);
      } catch (_) {
        content = response.body;
      }

      // 提取主要内容
      final extracted = _extractMainContent(content);
      
      // 限制长度
      if (extracted.length > maxChars) {
        return extracted.substring(0, maxChars) + '\n\n... (内容已截断)';
      }

      return extracted;
    } catch (e) {
      return '❌ 获取网页失败: $e';
    }
  }

  /// 提取网页主要内容
  String _extractMainContent(String html) {
    // 移除 script 和 style 标签
    html = html.replaceAll(RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false), '');
    html = html.replaceAll(RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false), '');
    
    // 移除注释
    html = html.replaceAll(RegExp(r'<!--[\s\S]*?-->', caseSensitive: false), '');
    
    // 提取 title
    String title = '';
    final titleMatch = RegExp(r'<title[^>]*>([^<]+)</title>', caseSensitive: false).firstMatch(html);
    if (titleMatch != null) {
      title = titleMatch.group(1)?.trim() ?? '';
    }
    
    // 提取 meta description
    String description = '';
    final descMatch = RegExp(r'<meta[^>]*name="description"[^>]*content="([^"]+)"', caseSensitive: false).firstMatch(html);
    if (descMatch != null) {
      description = descMatch.group(1)?.trim() ?? '';
    }
    
    // 移除所有 HTML 标签
    String text = html.replaceAll(RegExp(r'<[^>]+>'), ' ');
    
    // 解码 HTML 实体
    text = _decodeHtmlEntities(text);
    
    // 清理空白
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    // 构建结果
    final buffer = StringBuffer();
    if (title.isNotEmpty) {
      buffer.writeln('📌 标题: $title');
      buffer.writeln('');
    }
    if (description.isNotEmpty) {
      buffer.writeln('📝 描述: $description');
      buffer.writeln('');
    }
    if (text.isNotEmpty) {
      buffer.writeln('📄 内容:');
      buffer.writeln(text);
    }
    
    return buffer.toString().trim();
  }

  /// 解码 HTML 实体
  String _decodeHtmlEntities(String text) {
    return text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'");
        // 简化：不处理数字实体
  }

  /// 修复双重 UTF-8 编码问题
  /// 例如：Â°C → °C, Ã© → é 等
  String _fixDoubleEncoding(String text) {
    // 常见的双重编码替换
    return text
        .replaceAll('Â°C', '°C')
        .replaceAll('Â°F', '°F')
        .replaceAll('â€™', "'")
        .replaceAll('â€œ', '"')
        .replaceAll('â€', '"')
        .replaceAll('â€“', '–')
        .replaceAll('â€”', '—')
        .replaceAll('â€¦', '…')
        .replaceAll('Ã©', 'é')
        .replaceAll('Ã¨', 'è')
        .replaceAll('Ã¡', 'á')
        .replaceAll('Ã±', 'ñ')
        .replaceAll('Ã¼', 'ü')
        .replaceAll('Ã¶', 'ö')
        .replaceAll('Ã¤', 'ä');
  }

  /// 获取网页标题
  Future<String> fetchTitle(String url) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final titleMatch = RegExp(r'<title[^>]*>([^<]+)</title>', caseSensitive: false)
            .firstMatch(response.body);
        return titleMatch?.group(1)?.trim() ?? '';
      }
      return '';
    } catch (_) {
      return '';
    }
  }
}
