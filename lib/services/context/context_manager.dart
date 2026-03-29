// 上下文管理服务
//
// 管理注入到 LLM 的上下文大小限制

/// 上下文配置
class ContextConfig {
  /// 单文件最大字符数
  final int maxCharsPerFile;
  
  /// 总上下文最大字符数
  final int maxTotalChars;
  
  /// 对话历史最大条数
  final int maxHistoryMessages;

  const ContextConfig({
    this.maxCharsPerFile = 20000,
    this.maxTotalChars = 150000,
    this.maxHistoryMessages = 20,
  });

  /// 默认配置（向 OpenClaw 看齐）
  static const ContextConfig defaultConfig = ContextConfig();

  /// 精简配置（用于子代理）
  static const ContextConfig minimalConfig = ContextConfig(
    maxCharsPerFile: 5000,
    maxTotalChars: 50000,
    maxHistoryMessages: 5,
  );
}

/// 上下文管理器
class ContextManager {
  final ContextConfig config;

  ContextManager({this.config = ContextConfig.defaultConfig});

  /// 截断文本
  String truncateText(String text, {String? source}) {
    if (text.length <= config.maxCharsPerFile) {
      return text;
    }

    final truncated = text.substring(0, config.maxCharsPerFile);
    final marker = '\n\n... (内容已截断，原长度: ${text.length} 字符)';
    
    print('[ContextManager] 截断 $source: ${text.length} -> ${truncated.length + marker.length}');
    
    return truncated + marker;
  }

  /// 检查并截断上下文
  String checkAndTruncate(String context, {String? source}) {
    if (context.length <= config.maxTotalChars) {
      return context;
    }

    final truncated = context.substring(0, config.maxTotalChars);
    final marker = '\n\n... (总上下文已截断，原长度: ${context.length} 字符)';
    
    print('[ContextManager] 总上下文截断: ${context.length} -> ${truncated.length + marker.length}');
    
    return truncated + marker;
  }

  /// 限制对话历史条数
  List<T> limitHistory<T>(List<T> messages) {
    if (messages.length <= config.maxHistoryMessages) {
      return messages;
    }

    final limited = messages.skip(messages.length - config.maxHistoryMessages).toList();
    print('[ContextManager] 限制对话历史: ${messages.length} -> ${limited.length}');
    
    return limited;
  }

  /// 计算上下文统计
  ContextStats calculateStats({
    required List<String> files,
    required int historyCount,
  }) {
    int totalChars = 0;
    int truncatedCount = 0;
    final fileStats = <FileStats>[];

    for (final file in files) {
      final chars = file.length;
      totalChars += chars;
      
      if (chars > config.maxCharsPerFile) {
        truncatedCount++;
      }
    }

    return ContextStats(
      totalChars: totalChars,
      fileCount: files.length,
      truncatedCount: truncatedCount,
      historyCount: historyCount,
      maxHistory: config.maxHistoryMessages,
      maxTotal: config.maxTotalChars,
      isOverLimit: totalChars > config.maxTotalChars,
    );
  }
}

/// 上下文统计
class ContextStats {
  final int totalChars;
  final int fileCount;
  final int truncatedCount;
  final int historyCount;
  final int maxHistory;
  final int maxTotal;
  final bool isOverLimit;

  ContextStats({
    required this.totalChars,
    required this.fileCount,
    required this.truncatedCount,
    required this.historyCount,
    required this.maxHistory,
    required this.maxTotal,
    required this.isOverLimit,
  });

  @override
  String toString() {
    return 'ContextStats(chars: $totalChars/$maxTotal, files: $fileCount, truncated: $truncatedCount, history: $historyCount/$maxHistory)';
  }
}

/// 文件统计
class FileStats {
  final String name;
  final int chars;
  final bool isTruncated;

  FileStats({
    required this.name,
    required this.chars,
    required this.isTruncated,
  });
}
