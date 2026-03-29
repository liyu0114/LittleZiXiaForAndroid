// 话题切换服务
//
// 处理话题切换逻辑，包括消息历史加载和状态同步

import 'package:flutter/foundation.dart';
import '../providers/app_state.dart';
import '../services/conversation/topic_manager.dart';
import '../services/llm/llm_base.dart';

/// 话题切换服务
///
/// 负责处理话题切换时的：
/// 1. 消息历史保存
/// 2. 新话题消息加载
/// 3. 状态同步
/// 4. UI 通知
class TopicSwitchService extends ChangeNotifier {
  final AppState _appState;
  final TopicManager _topicManager;

  bool _isSwitching = false;
  String? _switchingFrom;
  String? _switchingTo;

  TopicSwitchService({
    required AppState appState,
    required TopicManager topicManager,
  })  : _appState = appState,
        _topicManager = topicManager;

  bool get isSwitching => _isSwitching;
  String? get switchingFrom => _switchingFrom;
  String? get switchingTo => _switchingTo;

  /// 切换到指定话题
  ///
  /// 返回是否切换成功
  Future<bool> switchToTopic(String topicId) async {
    if (_isSwitching) {
      debugPrint('[TopicSwitchService] 正在切换中，忽略请求');
      return false;
    }

    final currentTopic = _topicManager.currentTopic;
    if (currentTopic?.id == topicId) {
      debugPrint('[TopicSwitchService] 已经是当前话题');
      return false;
    }

    _isSwitching = true;
    _switchingFrom = currentTopic?.id;
    _switchingTo = topicId;
    notifyListeners();

    try {
      // 1. 保存当前话题的消息
      if (currentTopic != null) {
        await _saveCurrentMessages(currentTopic);
      }

      // 2. 切换话题
      _topicManager.switchTopic(topicId);

      // 3. 加载新话题的消息
      await _loadTopicMessages(topicId);

      debugPrint('[TopicSwitchService] 切换成功: $topicId');
      return true;
    } catch (e) {
      debugPrint('[TopicSwitchService] 切换失败: $e');
      return false;
    } finally {
      _isSwitching = false;
      _switchingFrom = null;
      _switchingTo = null;
      notifyListeners();
    }
  }

  /// 保存当前消息到话题
  Future<void> _saveCurrentMessages(ConversationTopic topic) async {
    try {
      final messages = _appState.messages;
      if (messages.isEmpty) {
        debugPrint('[TopicSwitchService] 当前没有消息，跳过保存');
        return;
      }

      // 将 AppState 的消息同步到话题
      topic.messages.clear();
      for (final msg in messages) {
        topic.messages.add(ChatMessage(
          role: msg.role == ConversationMessageRole.user
              ? MessageRole.user
              : MessageRole.assistant,
          content: msg.content,
        ));
      }

      debugPrint('[TopicSwitchService] 已保存 ${messages.length} 条消息到话题 ${topic.id}');
    } catch (e) {
      debugPrint('[TopicSwitchService] 保存消息失败: $e');
    }
  }

  /// 从话题加载消息到 AppState
  Future<void> _loadTopicMessages(String topicId) async {
    try {
      final topic = _topicManager.topics.where((t) => t.id == topicId).firstOrNull;
      if (topic == null) {
        debugPrint('[TopicSwitchService] 找不到话题: $topicId');
        return;
      }

      // 清空当前消息
      _appState.clearMessages();

      // 加载话题消息
      if (topic.messages.isNotEmpty) {
        for (final msg in topic.messages) {
          _appState.addMessage(ConversationMessage(
            role: msg.role == MessageRole.user
                ? ConversationMessageRole.user
                : ConversationMessageRole.assistant,
            content: msg.content,
          ));
        }
        debugPrint('[TopicSwitchService] 已加载 ${topic.messages.length} 条消息');
      } else {
        debugPrint('[TopicSwitchService] 话题没有历史消息');
      }
    } catch (e) {
      debugPrint('[TopicSwitchService] 加载消息失败: $e');
    }
  }

  /// 创建新话题
  Future<String> createNewTopic({String? title}) async {
    final topic = _topicManager.createTopic(title: title);
    await switchToTopic(topic.id);
    return topic.id;
  }

  /// 删除话题
  Future<void> deleteTopic(String topicId) async {
    final currentTopic = _topicManager.currentTopic;

    // 如果删除的是当前话题，先切换到其他话题
    if (currentTopic?.id == topicId) {
      final otherTopics = _topicManager.activeTopics
          .where((t) => t.id != topicId)
          .toList();

      if (otherTopics.isNotEmpty) {
        await switchToTopic(otherTopics.first.id);
      } else {
        // 没有其他话题，创建新的
        await createNewTopic();
      }
    }

    _topicManager.deleteTopic(topicId);
  }

  /// 归档话题
  Future<void> archiveTopic(String topicId) async {
    final currentTopic = _topicManager.currentTopic;

    // 如果归档的是当前话题，先切换到其他话题
    if (currentTopic?.id == topicId) {
      final otherTopics = _topicManager.activeTopics
          .where((t) => t.id != topicId)
          .toList();

      if (otherTopics.isNotEmpty) {
        await switchToTopic(otherTopics.first.id);
      }
    }

    _topicManager.archiveTopic(topicId);
  }
}
