import '../services/llm/llm_base.dart';

/// LLM状态管理
class LLMState {
  final LLMConfig config;
  final String? currentModel;
  final bool isConnected;
  
  LLMState({
    required this.config,
    this.currentModel,
    this.isConnected = false,
  });
}
