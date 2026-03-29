// 平台格式化
//
// 根据不同平台优化消息格式

import 'package:flutter/foundation.dart';

/// 平台类型
enum MessagePlatform {
  discord,
  whatsapp,
  telegram,
  signal,
  feishu,
  web,
  mobile,
}

/// 平台格式化服务
class PlatformFormatter {
  /// 格式化消息
  static String format(String message, MessagePlatform platform) {
    switch (platform) {
      case MessagePlatform.discord:
        return _formatForDiscord(message);
      case MessagePlatform.whatsapp:
        return _formatForWhatsApp(message);
      case MessagePlatform.telegram:
        return _formatForTelegram(message);
      case MessagePlatform.signal:
        return _formatForSignal(message);
      case MessagePlatform.feishu:
        return _formatForFeishu(message);
      case MessagePlatform.mobile:
        return _formatForMobile(message);
      default:
        return message;
    }
  }

  /// Discord 格式化
  static String _formatForDiscord(String message) {
    // 不使用 Markdown 表格
    message = _convertTables(message);

    // 链接抑制
    message = _suppressLinks(message);

    return message;
  }

  /// WhatsApp 格式化
  static String _formatForWhatsApp(String message) {
    // 不使用 Markdown 表格
    message = _convertTables(message);

    // 不使用标题，改用粗体
    message = message.replaceAllMapped(
      RegExp(r'^#+\s+(.+)$', multiLine: true),
      (match) => '*${match.group(1)}*',
    );

    return message;
  }

  /// Telegram 格式化
  static String _formatForTelegram(String message) {
    // Telegram 支持 Markdown
    return message;
  }

  /// Signal 格式化
  static String _formatForSignal(String message) {
    // Signal 支持 Markdown
    return message;
  }

  /// 飞书格式化
  static String _formatForFeishu(String message) {
    // 飞书支持 Markdown
    return message;
  }

  /// 移动端格式化
  static String _formatForMobile(String message) {
    // 优化移动端显示
    message = _convertTables(message);

    // 简化标题
    message = message.replaceAll('###### ', '• ');
    message = message.replaceAll('##### ', '• ');
    message = message.replaceAll('#### ', '• ');
    message = message.replaceAll('### ', '• ');
    message = message.replaceAll('## ', '• ');
    message = message.replaceAll('# ', '• ');

    return message;
  }

  /// 转换表格为列表
  static String _convertTables(String message) {
    // 检测 Markdown 表格
    final tableRegex = RegExp(r'\|.+\|\n\|[-:\s|]+\|\n((?:\|.+\|\n?)+)');

    return message.replaceAllMapped(tableRegex, (match) {
      final rows = match.group(1)!.split('\n');
      final buffer = StringBuffer();

      for (final row in rows) {
        if (row.trim().isEmpty) continue;
        final cells = row.split('|').where((c) => c.trim().isNotEmpty).toList();
        if (cells.isNotEmpty) {
          buffer.writeln('• ${cells.join(' - ')}');
        }
      }

      return buffer.toString();
    });
  }

  /// 链接抑制（Discord）
  static String _suppressLinks(String message) {
    // 包裹多个链接以抑制 embed
    final linkRegex = RegExp(r'(https?://[^\s]+)');

    int count = 0;
    return message.replaceAllMapped(linkRegex, (match) {
      count++;
      if (count > 1) {
        return '<${match.group(0)}>';
      }
      return match.group(0)!;
    });
  }
}
