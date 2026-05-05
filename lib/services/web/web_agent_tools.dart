// Web Agent 工具
//
// 将 WebSearchService 和 WebFetchService 包装为 Agent Tool
// 让 Agent Loop 能联网搜索和获取网页内容

import 'package:flutter/foundation.dart';
import '../agent/agent_loop_v2.dart';
import 'web_search_service.dart';
import 'web_fetch_service.dart';

/// 网页搜索工具
class WebSearchAgentTool extends AgentTool {
  final WebSearchService _searchService;

  WebSearchAgentTool(this._searchService);

  @override
  String get name => 'web_search';

  @override
  String get description => '搜索互联网获取信息。适用于查天气、新闻、百科知识、技术问题等。返回搜索结果标题、链接和摘要。';

  @override
  Map<String, dynamic> get parametersSchema => {
    'type': 'object',
    'properties': {
      'query': {
        'type': 'string',
        'description': '搜索关键词',
      },
      'count': {
        'type': 'integer',
        'description': '返回结果数量，默认5',
      },
    },
    'required': ['query'],
  };

  @override
  Future<AgentToolResult> execute(Map<String, dynamic> arguments) async {
    final query = arguments['query'] as String?;
    if (query == null || query.trim().isEmpty) {
      return AgentToolResult.fail('缺少搜索关键词');
    }

    final count = arguments['count'] as int? ?? 5;
    debugPrint('[WebSearchTool] 搜索: $query');

    try {
      final results = await _searchService.search(query, count: count);
      if (results.isEmpty) {
        return AgentToolResult.success('没有找到与"$query"相关的结果');
      }

      final buffer = StringBuffer();
      buffer.writeln('搜索结果（$query）:');
      for (int i = 0; i < results.length; i++) {
        final r = results[i];
        buffer.writeln('\n${i + 1}. ${r.title}');
        if (r.description != null && r.description!.isNotEmpty) {
          buffer.writeln('   ${r.description}');
        }
        if (r.url.isNotEmpty) {
          buffer.writeln('   链接: ${r.url}');
        }
      }
      return AgentToolResult.success(buffer.toString());
    } catch (e) {
      return AgentToolResult.fail('搜索失败: $e');
    }
  }
}

/// 网页内容获取工具
class WebFetchAgentTool extends AgentTool {
  final WebFetchService _fetchService;

  WebFetchAgentTool(this._fetchService);

  @override
  String get name => 'web_fetch';

  @override
  String get description => '获取指定URL的网页内容，提取主要文本信息。适用于读取文章、文档、API返回等。';

  @override
  Map<String, dynamic> get parametersSchema => {
    'type': 'object',
    'properties': {
      'url': {
        'type': 'string',
        'description': '要获取的网页URL',
      },
      'maxChars': {
        'type': 'integer',
        'description': '最大返回字符数，默认3000',
      },
    },
    'required': ['url'],
  };

  @override
  Future<AgentToolResult> execute(Map<String, dynamic> arguments) async {
    final url = arguments['url'] as String?;
    if (url == null || url.trim().isEmpty) {
      return AgentToolResult.fail('缺少URL');
    }

    final maxChars = arguments['maxChars'] as int? ?? 3000;
    debugPrint('[WebFetchTool] 获取: $url');

    try {
      final content = await _fetchService.fetch(url, maxChars: maxChars);
      if (content.startsWith('❌')) {
        return AgentToolResult.fail(content.substring(2).trim());
      }
      return AgentToolResult.success(content);
    } catch (e) {
      return AgentToolResult.fail('获取网页失败: $e');
    }
  }
}

/// 注册 Web 工具到 Agent Loop
void registerWebTools(AgentLoopServiceV2 agentLoop, WebSearchService searchService, WebFetchService fetchService) {
  agentLoop.registerTool(WebSearchAgentTool(searchService));
  agentLoop.registerTool(WebFetchAgentTool(fetchService));
  debugPrint('[WebAgentTools] 已注册 web_search 和 web_fetch 工具');
}
