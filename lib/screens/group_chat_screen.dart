// 单机群聊屏幕
//
// 对话页的扩展版：用户 + 多个机器人
// 完全本地化，不需要网络

import 'dart:async';
import 'dart:math';  // 添加 Random
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';  // 用于复制到剪贴板
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../services/chat/chat_bot_service.dart';
import '../services/llm_logger_service.dart';  // LLM 日志服务

/// 群聊消息
class LocalChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String content;
  final DateTime time;
  final bool isBot;
  final List<String> mentionIds;  // 被艾特的用户/机器人ID

  LocalChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.time,
    this.isBot = false,
    this.mentionIds = const [],
  });

  /// 解析消息中的 @mentions
  static List<String> parseMentions(String content, List<ChatBotService> bots) {
    final mentions = <String>[];
    final regex = RegExp(r'@(\S+)');
    final matches = regex.allMatches(content);

    for (final match in matches) {
      final name = match.group(1);
      if (name != null) {
        // 查找对应的机器人
        for (final bot in bots) {
          if (bot.botName == name || bot.botName.contains(name)) {
            mentions.add(bot.botId);
            break;
          }
        }
      }
    }

    return mentions;
  }
}

class GroupChatScreen extends StatefulWidget {
  const GroupChatScreen({super.key});

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  // 消息列表
  final List<LocalChatMessage> _messages = [];
  final _messageController = TextEditingController();

  // 用户信息
  late String _localUserId;
  final String _localUserName = '我';

  // 机器人列表
  final List<ChatBotService> _bots = [];
  int _botCounter = 0;  // 机器人计数器，用于命名

  // 艾特功能
  bool _showMentionList = false;  // 是否显示艾特列表
  String _mentionFilter = '';  // 艾特过滤词
  final _random = Random();  // 随机数生成器

  // 是否已初始化
  bool _initialized = false;
  
  @override
  void initState() {
    super.initState();
    _localUserId = 'user_${DateTime.now().millisecondsSinceEpoch}';
    _messageController.addListener(_onMessageChanged);  // 监听输入变化
    _initServices();
  }

  void _initServices() async {
    setState(() => _initialized = true);

    // 默认添加一个小紫霞机器人
    _addBotWithRole(BotRole.assistant);  // 默认添加通用助手
  }

  /// 输入框内容变化
  void _onMessageChanged() {
    final text = _messageController.text;
    final cursorPos = _messageController.selection.baseOffset;

    // 检查是否输入了 @
    if (cursorPos > 0 && text[cursorPos - 1] == '@') {
      setState(() {
        _showMentionList = true;
        _mentionFilter = '';
      });
    } else if (_showMentionList) {
      // 提取 @ 后面的过滤词
      final beforeCursor = text.substring(0, cursorPos);
      final lastAtIndex = beforeCursor.lastIndexOf('@');
      if (lastAtIndex != -1) {
        final afterAt = beforeCursor.substring(lastAtIndex + 1);
        if (!afterAt.contains(' ')) {
          setState(() {
            _mentionFilter = afterAt;
          });
        } else {
          setState(() {
            _showMentionList = false;
          });
        }
      }
    }
  }

  /// 插入艾特
  void _insertMention(String name) {
    final text = _messageController.text;
    final cursorPos = _messageController.selection.baseOffset;
    final beforeCursor = text.substring(0, cursorPos);
    final lastAtIndex = beforeCursor.lastIndexOf('@');

    if (lastAtIndex != -1) {
      final newText = text.replaceRange(lastAtIndex, cursorPos, '@$name ');
      _messageController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: lastAtIndex + name.length + 1),
      );
    }

    setState(() {
      _showMentionList = false;
      _mentionFilter = '';
    });
  }

  @override
  void dispose() {
    _messageController.removeListener(_onMessageChanged);
    _messageController.dispose();
    for (final bot in _bots) {
      bot.dispose();
    }
    super.dispose();
  }
  
  /// 格式化时间（微信风格）
  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(time.year, time.month, time.day);
    
    final timeStr = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    
    if (messageDate == today) {
      return timeStr;
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return '昨天 $timeStr';
    } else {
      return '${time.month}/${time.day} $timeStr';
    }
  }
  
  /// 添加机器人（选择角色）
  void _addBot() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择机器人角色'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: BotRole.values.map((role) {
            final info = _getRoleInfo(role);
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: info['color'],
                child: Icon(info['icon'], color: Colors.white),
              ),
              title: Text(info['name']),
              subtitle: Text(info['description'], style: const TextStyle(fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                _addBotWithRole(role);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  /// 获取角色信息
  Map<String, dynamic> _getRoleInfo(BotRole role) {
    switch (role) {
      case BotRole.assistant:
        return {
          'name': '通用助手',
          'icon': Icons.smart_toy,
          'color': Colors.purple,
          'description': '回答各种问题，提供帮助和建议',
        };
      case BotRole.document:
        return {
          'name': '文档专家',
          'icon': Icons.description,
          'color': Colors.blue,
          'description': '编写和改进技术文档',
        };
      case BotRole.qa:
        return {
          'name': '质检专家',
          'icon': Icons.fact_check,
          'color': Colors.red,
          'description': '检查代码和文档质量',
        };
      case BotRole.translator:
        return {
          'name': '翻译专家',
          'icon': Icons.translate,
          'color': Colors.green,
          'description': '中英互译，注重本地化',
        };
      case BotRole.coder:
        return {
          'name': '编程专家',
          'icon': Icons.code,
          'color': Colors.orange,
          'description': '编写高质量代码，性能优化',
        };
      case BotRole.analyst:
        return {
          'name': '分析师',
          'icon': Icons.analytics,
          'color': Colors.teal,
          'description': '数据分析，提供洞察',
        };
    }
  }

  /// 添加指定角色的机器人
  void _addBotWithRole(BotRole role) {
    final appState = context.read<AppState>();
    _botCounter++;

    final botConfig = BotConfig.createWithRole(role, _botCounter);

    final bot = ChatBotService(
      skillExecuteCallback: (skillId, params) async {
        try {
          debugPrint('[GroupChat] 执行技能: $skillId, params: $params');
          final result = await appState.executeSkill(skillId, params);
          debugPrint('[GroupChat] 技能结果: $result');
          return result;
        } catch (e) {
          debugPrint('[GroupChat] 技能执行失败: $e');
          return null;
        }
      },
      llmGenerateCallback: (message, history) async {
        try {
          debugPrint('[GroupChat] 调用 LLM 生成回复: $message');
          final result = await appState.generateLLMResponse(message, history);
          debugPrint('[GroupChat] LLM 回复: $result');
          return result;
        } catch (e) {
          debugPrint('[GroupChat] LLM 生成失败: $e');
          return null;
        }
      },
      config: botConfig,
      replyProbability: 0.15,  // 降低随机回复概率到 15%
      minReplyDelay: 2000,
      maxReplyDelay: 5000,
    );

    setState(() {
      _bots.add(bot);
    });

    // 机器人发送欢迎消息
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        final info = _getRoleInfo(role);
        _addBotMessage(bot, '大家好！我是${bot.botName}（${info['name']}），很高兴加入群聊~');
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('✅ ${bot.botName} 已加入群聊')),
    );
  }
  
  /// 添加机器人消息
  void _addBotMessage(ChatBotService bot, String content) {
    final message = LocalChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      senderId: bot.botId,
      senderName: bot.botName,
      content: content,
      time: DateTime.now(),
      isBot: true,
    );
    
    setState(() {
      _messages.add(message);
    });
    
    // 添加到所有机器人的历史
    for (final b in _bots) {
      b.addToHistory(bot.botId, bot.botName, content);
    }
  }
  
  /// 发送消息
  void _sendMessage() {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    // 解析艾特
    final mentionIds = LocalChatMessage.parseMentions(content, _bots);

    // 添加用户消息
    final message = LocalChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      senderId: _localUserId,
      senderName: _localUserName,
      content: content,
      time: DateTime.now(),
      mentionIds: mentionIds,
    );

    setState(() {
      _messages.add(message);
    });

    // 添加到所有机器人的历史
    for (final bot in _bots) {
      bot.addToHistory(_localUserId, _localUserName, content);
    }

    _messageController.clear();

    // 让机器人决定是否回复
    _handleBotReplies(content, mentionIds);
  }

  /// 处理机器人回复（支持艾特 + 协作）
  void _handleBotReplies(String content, List<String> mentionIds) {
    for (final bot in _bots) {
      // 被艾特的机器人必须回复
      final isMentioned = mentionIds.contains(bot.botId);

      if (isMentioned || bot.shouldReply(content, _localUserId)) {
        // 延迟回复（模拟思考）
        Future.delayed(bot.getReplyDelay(), () async {
          if (!mounted) return;

          final reply = await bot.generateReply(content, _localUserName);
          if (reply != null && reply.isNotEmpty) {
            _addBotMessage(bot, reply);

            // 检查是否需要协作（机器人艾特其他机器人）
            final botMentions = LocalChatMessage.parseMentions(reply, _bots);
            if (botMentions.isNotEmpty) {
              // 被艾特的机器人在1-2秒后回复
              Future.delayed(Duration(milliseconds: 1000 + _random.nextInt(1000)), () {
                _handleBotCollaboration(bot, reply, botMentions);
              });
            }
          }
        });
      }
    }
  }

  /// 处理机器人协作
  void _handleBotCollaboration(ChatBotService senderBot, String content, List<String> mentionIds) {
    for (final bot in _bots) {
      if (mentionIds.contains(bot.botId) && bot.botId != senderBot.botId) {
        // 被艾特的机器人回复
        Future.delayed(bot.getReplyDelay(), () async {
          if (!mounted) return;

          final reply = await bot.generateReply(content, senderBot.botName);
          if (reply != null && reply.isNotEmpty) {
            _addBotMessage(bot, reply);
          }
        });
      }
    }
  }
  
  /// 显示 LLM 日志
  void _showLLMLogs() {
    final logger = LLMLoggerService();
    final logs = logger.logs.reversed.toList();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          color: Colors.black87,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Text('LLM 日志', style: TextStyle(color: Colors.white, fontSize: 18)),
                    const SizedBox(width: 8),
                    Text('(${logs.length} 条)', style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: logger.exportToJson()));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('日志已复制到剪贴板')),
                        );
                      },
                      child: const Text('复制 JSON'),
                    ),
                    TextButton(
                      onPressed: () {
                        logger.clearLogs();
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('日志已清空')),
                        );
                      },
                      child: const Text('清空'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('关闭'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: logs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.info_outline, size: 48, color: Colors.grey.shade600),
                            const SizedBox(height: 16),
                            Text(
                              '暂无 LLM 日志',
                              style: TextStyle(color: Colors.grey.shade400, fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '发送消息后，这里会显示 LLM 的请求和响应',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.all(8),
                        itemCount: logs.length,
                        itemBuilder: (context, index) {
                          final log = logs[index];
                          Color color;
                          IconData icon;
                          switch (log.type) {
                            case 'request':
                              color = Colors.blue.shade300;
                              icon = Icons.upload;
                              break;
                            case 'response':
                              color = Colors.green.shade300;
                              icon = Icons.download;
                              break;
                            case 'error':
                              color = Colors.red.shade300;
                              icon = Icons.error;
                              break;
                            default:
                              color = Colors.grey.shade300;
                              icon = Icons.info;
                          }
                          
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: color.withOpacity(0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(icon, size: 16, color: color),
                                    const SizedBox(width: 8),
                                    Text(
                                      '[${log.time.toString().substring(11, 19)}] ${log.type.toUpperCase()}',
                                      style: TextStyle(
                                        color: color,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                    if (log.provider != null) ...[
                                      const SizedBox(width: 8),
                                      Text(
                                        log.provider!,
                                        style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                                      ),
                                    ],
                                    if (log.model != null) ...[
                                      const SizedBox(width: 4),
                                      Text(
                                        '/ ${log.model}',
                                        style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 8),
                                SelectableText(
                                  log.data['content'] ?? log.data['error'] ?? log.data['lastMessage'] ?? 'No content',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// 清空聊天记录
  void _clearChat() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空聊天记录'),
        content: const Text('确定要清空所有聊天记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              setState(() {
                _messages.clear();
                for (final bot in _bots) {
                  bot.clearHistory();
                }
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✅ 聊天记录已清空')),
              );
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
  
  /// 显示机器人列表
  void _showBotList() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('机器人列表', style: Theme.of(context).textTheme.titleLarge),
                Text('${_bots.length} 个机器人'),
              ],
            ),
            const SizedBox(height: 16),
            if (_bots.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('暂无机器人', style: TextStyle(color: Colors.grey)),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                itemCount: _bots.length,
                itemBuilder: (context, index) {
                  final bot = _bots[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.purple.shade100,
                      child: const Icon(Icons.smart_toy, color: Colors.purple),
                    ),
                    title: Text(bot.botName),
                    subtitle: const Text('小紫霞 AI 助手'),
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () {
                        setState(() {
                          _bots.removeAt(index);
                        });
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('✅ 机器人 ${bot.botName} 已移除')),
                        );
                      },
                    ),
                  );
                },
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _addBot();
                },
                icon: const Icon(Icons.add),
                label: const Text('添加机器人'),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('单机群聊'),
        actions: [
          IconButton(
            icon: const Icon(Icons.smart_toy),
            onPressed: _showBotList,
            tooltip: '机器人列表',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addBot,
            tooltip: '添加机器人',
          ),
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: _showLLMLogs,
            tooltip: '查看 LLM 日志',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'clear') {
                _clearChat();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline),
                    SizedBox(width: 8),
                    Text('清空聊天记录'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // 机器人数量提示
          if (_bots.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.purple.shade50,
              child: Row(
                children: [
                  Icon(Icons.smart_toy, size: 16, color: Colors.purple.shade700),
                  const SizedBox(width: 8),
                  Text(
                    '${_bots.length} 个机器人在线',
                    style: TextStyle(color: Colors.purple.shade700),
                  ),
                ],
              ),
            ),
          
          // 消息列表
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          '开始聊天吧！',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '已添加 ${_bots.length} 个机器人',
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isMe = msg.senderId == _localUserId;
                      
                      return Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.all(12),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75,
                          ),
                          decoration: BoxDecoration(
                            color: isMe 
                                ? Theme.of(context).colorScheme.primaryContainer
                                : msg.isBot
                                    ? Colors.purple.shade50
                                    : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!isMe)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (msg.isBot)
                                      Icon(Icons.smart_toy, size: 14, color: Colors.purple.shade700)
                                    else
                                      Icon(Icons.person, size: 14, color: Colors.grey.shade700),
                                    const SizedBox(width: 4),
                                    Text(
                                      msg.senderName,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: msg.isBot ? Colors.purple.shade700 : Colors.grey.shade700,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _formatTime(msg.time),
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                              if (!isMe) const SizedBox(height: 4),
                              Text(msg.content),
                              if (isMe)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    _formatTime(msg.time),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade600,
                                    ),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // 艾特成员列表
          if (_showMentionList && _bots.isNotEmpty)
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  top: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                itemCount: _bots.length,
                itemBuilder: (context, index) {
                  final bot = _bots[index];
                  final info = _getRoleInfo(bot.config.role);

                  // 过滤
                  if (_mentionFilter.isNotEmpty &&
                      !bot.botName.toLowerCase().contains(_mentionFilter.toLowerCase())) {
                    return const SizedBox.shrink();
                  }

                  return GestureDetector(
                    onTap: () => _insertMention(bot.botName),
                    child: Container(
                      width: 100,
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (info['color'] as MaterialColor).shade50,
                        border: Border.all(color: (info['color'] as MaterialColor).shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: info['color'],
                            child: Icon(info['icon'], color: Colors.white, size: 20),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            bot.botName,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

          // 输入框
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade300,
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: '输入消息...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _sendMessage,
                  icon: const Icon(Icons.send),
                  style: IconButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
