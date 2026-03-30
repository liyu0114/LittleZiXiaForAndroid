// LLM Provider 工厂
//
// 根据配置创建对应的 LLM Provider 实例

import 'llm_base.dart';
import 'openai_provider.dart';
import 'glm_provider.dart';
import 'claude_provider.dart';
import 'custom_provider.dart';

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

      case 'custom':
        return CustomLLMProvider(config);

      // 以下使用 OpenAI 兼容接口
      case 'qwen':
      case 'ernie':
      case 'deepseek':
      case 'moonshot':
      case 'kimi':
      case 'ollama':
      case 'gemini':
      case 'grok':
      case 'doubao':
        return OpenAIProvider(config);

      default:
        return CustomLLMProvider(config);
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
    id: 'gemini',
    name: 'Google Gemini',
    description: 'Gemini 2.0, Gemini 1.5 等模型（OpenAI 兼容）',
    defaultBaseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai',
    apiKeyPlaceholder: 'AIza...',
    defaultModels: ['gemini-2.0-flash-exp', 'gemini-1.5-pro', 'gemini-1.5-flash'],
  ),
  ProviderInfo(
    id: 'grok',
    name: 'xAI Grok',
    description: 'Grok-2, Grok-3 等模型',
    defaultBaseUrl: 'https://api.x.ai/v1',
    apiKeyPlaceholder: 'xai-...',
    defaultModels: ['grok-2-1212', 'grok-2-vision-1212', 'grok-beta'],
  ),
  ProviderInfo(
    id: 'kimi',
    name: 'Moonshot Kimi',
    description: 'Kimi 长上下文模型',
    defaultBaseUrl: 'https://api.moonshot.cn/v1',
    apiKeyPlaceholder: 'sk-...',
    defaultModels: ['moonshot-v1-8k', 'moonshot-v1-32k', 'moonshot-v1-128k'],
  ),
  ProviderInfo(
    id: 'doubao',
    name: '字节跳动 豆包',
    description: '豆包 Pro, 豆包 Lite 等模型',
    defaultBaseUrl: 'https://ark.cn-beijing.volces.com/api/v3',
    apiKeyPlaceholder: '...',
    defaultModels: ['doubao-pro-4k', 'doubao-pro-32k', 'doubao-pro-128k', 'doubao-lite-4k'],
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
