// _addBot 方法的正确实现
// 问题：原代码 if (_botService == null) 后立即访问 _botService!.botId 会崩溃
// 修复：先检查是否已有机器人，然后初始化

void _addBot() {
  // 1. 检查是否已有机器人
  if (_botService != null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已有一个机器人在群聊中')),
    );
    return;
  }
  
  // 2. 初始化机器人服务
  final appState = context.read<AppState>();
  _botService = ChatBotService(
    skillExecuteCallback: (skillId, params) async {
      try {
        return await appState.executeSkill(skillId, params);
      } catch (e) {
        return null;
      }
    },
    config: BotConfig.defaultBot(),
    replyProbability: 0.15,
  );
  
  // 3. 添加机器人到玩家列表
  final botId = _botService!.botId;
  final botName = _botService!.botName;
  
  setState(() {
    _players.add({
      'id': botId,
      'name': botName,
      'isHost': false,
      'isBot': true,
    });
  });
  
  // 4. 广播更新
  _broadcastPlayerList();
  
  // 5. 发送欢迎消息
  if (_chatStarted) {
    _sendBotWelcomeMessage();
  }
  
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('机器人 $botName 已加入群聊')),
  );
}
