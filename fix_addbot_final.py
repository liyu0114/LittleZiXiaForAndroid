import os
import sys

# 修复 Windows 控制台编码
sys.stdout.reconfigure(encoding='utf-8')

file_path = r'D:\LittleZiXia\openclaw_app\lib\screens\network_chat_screen.dart'

# 读取文件
try:
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
except:
    with open(file_path, 'r', encoding='gbk') as f:
        content = f.read()

# 查找并替换 _addBot 方法
old_method = '''  /// 添加机器人到群聊
  void _addBot() {
    if (_botService == null) {
      // 创建机器人
      final botId = _botService!.botId;
      final botName = _botService!.botName;'''

new_method = '''  /// 添加机器人到群聊（主机和客户端都能添加）
  void _addBot() {
    // 如果已经有机器人，不再添加
    if (_botService != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已有一个机器人在群聊中')),
      );
      return;
    }
    
    // 初始化机器人服务
    try {
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
      debugPrint('[NetworkChat] 机器人服务已初始化');
    } catch (e) {
      debugPrint('[NetworkChat] 机器人初始化失败: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('机器人初始化失败: $e')),
      );
      return;
    }
    
    // 创建机器人
    final botId = _botService!.botId;
    final botName = _botService!.botName;'''

if old_method in content:
    content = content.replace(old_method, new_method)
    print("[OK] _addBot method fixed")
else:
    print("[SKIP] _addBot method not found (may already be fixed or different)")

# 保存文件
try:
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    print("[OK] File saved (UTF-8)")
except:
    with open(file_path, 'w', encoding='gbk') as f:
        f.write(content)
    print("[OK] File saved (GBK)")

print("\nDone!")

