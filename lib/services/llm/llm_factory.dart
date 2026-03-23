// LLM Provider 工厂
//
// 根据配置创建对应的 LLM Provider 实例

import 'llm_base.dart';
import 'openai_provider.dart';
import 'glm_provider.dart';
import 'claude_provider.dart';

/// LLM 工厂
class LLMFactory {
  /// 创建 LLM Provider
  static LLMProvider create(LLMConfig config) {
    final providerId = config.provider.toLowerCase();

    switch (providerId) {
      case 'openai':
        return OpenAIProvider(config);

      case 'claude':
        return ClaudeProvider(config);

      case 'glm':
        return GLMProvider(config);

      // 以下使用 OpenAI 兼容接口
      case 'qwen':
      case 'ernie':
      case 'deepseek':
      case 'moonshot':
      case 'ollama':
      case 'custom':
        return OpenAIProvider(config);

      default:
        return OpenAIProvider(config);
    }
  }

  /// 获取提供商信息
  static ProviderInfo? getProviderInfo(String providerId) {
    try {
      return availableProviders.firstWhere(
        (p) => p.id == providerId.toLowerCase(),
      );
    } catch (e) {
      return null;
    }
  }

  /// 获取所有提供商
  static List<ProviderInfo> getAllProviders() {
    return availableProviders;
  }
}

/// 提供商信息
class ProviderInfo {
  final String id;
  final String name;
  final String description;
  final String defaultBaseUrl;
  final String apiKeyPlaceholder;
  final List<String> defaultModels;

  const ProviderInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.defaultBaseUrl,
    required this.apiKeyPlaceholder,
    required this.defaultModels,
  });
}

/// 提供商列表（通义千问排第一位）
const List<ProviderInfo> availableProviders = [
  ProviderInfo(
    id: 'qwen',
    name: '通义千问',
    description: 'Qwen 系列模型',
    defaultBaseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
    apiKeyPlaceholder: 'sk-...',
    defaultModels: ['qwen-max', 'qwen-plus', 'qwen-turbo'],
  ),
  ProviderInfo(
    id: 'openai',
    name: 'OpenAI',
    description: 'GPT-4, GPT-3.5 等模型',
    defaultBaseUrl: 'https://api.openai.com/v1',
    apiKeyPlaceholder: 'sk-...',
    defaultModels: ['gpt-4o', 'gpt-4o-mini', 'gpt-4-turbo', 'gpt-3.5-turbo'],
  ),
  ProviderInfo(
    id: 'claude',
    name: 'Claude (Anthropic)',
    description: 'Claude 3.5, Claude 3 等模型',
    defaultBaseUrl: 'https://api.anthropic.com/v1',
    apiKeyPlaceholder: 'sk-ant-...',
    defaultModels: ['claude-sonnet-4-20250514', 'claude-3-5-sonnet-20241022', 'claude-3-5-haiku-20241022'],
  ),
  ProviderInfo(
    id: 'glm',
    name: 'GLM (智谱)',
    description: 'GLM-5, GLM-4 等模型',
    defaultBaseUrl: 'https://open.bigmodel.cn/api/paas/v4',
    apiKeyPlaceholder: '...',
    defaultModels: ['glm-5', 'glm-4-plus', 'glm-4-flash', 'glm-4-0520', 'glm-4-air', 'glm-4-airx', 'glm-4v-plus'],
  ),
  ProviderInfo(
    id: 'deepseek',
    name: 'DeepSeek',
    description: 'DeepSeek 系列模型',
    defaultBaseUrl: 'https://api.deepseek.com/v1',
    apiKeyPlaceholder: 'sk-...',
    defaultModels: ['deepseek-chat', 'deepseek-coder'],
  ),
  ProviderInfo(
    id: 'ollama',
    name: 'Ollama (本地)',
    description: '本地运行的开源模型',
    defaultBaseUrl: 'http://localhost:11434/v1',
    apiKeyPlaceholder: 'ollama',
    defaultModels: ['llama3', 'mistral', 'qwen2'],
  ),
  ProviderInfo(
    id: 'custom',
    name: '自定义接口',
    description: 'OpenAI 兼容的自定义接口',
    defaultBaseUrl: '',
    apiKeyPlaceholder: 'API Key',
    defaultModels: [],
  ),
];
