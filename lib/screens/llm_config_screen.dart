import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../services/llm/llm_base.dart';
import '../services/llm/llm_factory.dart';
import '../utils/network_diagnostics.dart';

class LLMConfigScreen extends StatefulWidget {
  const LLMConfigScreen({super.key});

  @override
  State<LLMConfigScreen> createState() => _LLMConfigScreenState();
}

class _LLMConfigScreenState extends State<LLMConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // 默认配置：Ollama + Mac Tailscale IP
  String _selectedProvider = 'ollama';
  final _apiKeyController = TextEditingController(text: 'ollama');
  final _baseUrlController = TextEditingController(text: 'http://100.98.121.70:11434/v1');
  String _selectedModel = 'qwen2.5-coder:7b';
  double _temperature = 0.7;
  int _maxTokens = 4096;
  final _systemPromptController = TextEditingController();
  
  bool _obscureApiKey = false;  // 不隐藏 API Key
  bool _isTesting = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  void _loadConfig() {
    final appState = context.read<AppState>();
    final config = appState.llmConfig;
    
    print('[DEBUG] _loadConfig() 被调用');
    print('[DEBUG] config 是否为 null: ${config == null}');
    
    if (config != null) {
      print('[DEBUG] 加载已保存的配置:');
      print('[DEBUG]   provider: ${config.provider}');
      print('[DEBUG]   baseUrl: ${config.baseUrl}');
      print('[DEBUG]   model: ${config.model}');
      
      _selectedProvider = config.provider;
      _apiKeyController.text = config.apiKey;
      
      // 如果 baseUrl 为空，使用默认值
      if (config.baseUrl == null || config.baseUrl!.isEmpty) {
        final providerInfo = LLMFactory.getProviderInfo(config.provider);
        _baseUrlController.text = providerInfo?.defaultBaseUrl ?? '';
        print('[DEBUG] baseUrl 为空，使用默认值: ${_baseUrlController.text}');
      } else {
        _baseUrlController.text = config.baseUrl!;
        print('[DEBUG] 使用保存的 baseUrl: ${_baseUrlController.text}');
      }
      
      _selectedModel = config.model;
      _temperature = config.temperature;
      _maxTokens = config.maxTokens;
      _systemPromptController.text = config.systemPrompt ?? '';
    } else {
      print('[DEBUG] 没有保存的配置，使用默认值');
      // 默认选择第一个模型
      final providerInfo = LLMFactory.getProviderInfo(_selectedProvider);
      if (providerInfo != null && providerInfo.defaultModels.isNotEmpty) {
        _selectedModel = providerInfo.defaultModels.first;
        _baseUrlController.text = providerInfo.defaultBaseUrl;
        print('[DEBUG] 默认 baseUrl: ${_baseUrlController.text}');
      }
    }
    
    // 特殊处理：Qwen 默认使用 qwen-plus
    if (_selectedProvider == 'qwen' && _selectedModel.isEmpty) {
      _selectedModel = 'qwen-plus';
    }
    
    // 特殊处理：Ollama 默认使用 qwen2.5-coder:7b
    if (_selectedProvider == 'ollama' && (_selectedModel.isEmpty || _selectedModel == 'llama3')) {
      _selectedModel = 'qwen2.5-coder:7b';
    }
    
    // 特殊处理：GLM 默认使用 glm-5
    if (_selectedProvider == 'glm' && _selectedModel.isEmpty) {
      _selectedModel = 'glm-5';
    }
    
    print('[DEBUG] _loadConfig() 完成');
    print('[DEBUG] _baseUrlController.text = "${_baseUrlController.text}"');
    
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final providers = LLMFactory.getAllProviders();
    final currentProvider = LLMFactory.getProviderInfo(_selectedProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 提供商选择
            const Text(
              '选择大模型提供商',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            DropdownButtonFormField<String>(
              value: _selectedProvider,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: providers.map((p) {
                return DropdownMenuItem(
                  value: p.id,
                  child: Row(
                    children: [
                      Expanded(child: Text(p.name)),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedProvider = value;
                    final providerInfo = LLMFactory.getProviderInfo(value);
                    if (providerInfo != null) {
                      _baseUrlController.text = providerInfo.defaultBaseUrl;
                      if (providerInfo.defaultModels.isNotEmpty) {
                        _selectedModel = providerInfo.defaultModels.first;
                      }
                    }
                  });
                }
              },
            ),
            
            if (currentProvider != null) ...[
              const SizedBox(height: 8),
              Text(
                currentProvider.description,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],

            const SizedBox(height: 24),

            // API Key
            const Text(
              'API Key',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            TextFormField(
              controller: _apiKeyController,
              obscureText: _obscureApiKey,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: currentProvider?.apiKeyPlaceholder ?? 'API Key',
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureApiKey ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureApiKey = !_obscureApiKey;
                    });
                  },
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入 API Key';
                }
                return null;
              },
            ),

            const SizedBox(height: 24),

            // 模型选择
            const Text(
              '模型',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              value: _selectedModel.isNotEmpty ? _selectedModel : null,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: (currentProvider?.defaultModels ?? []).map((m) {
                return DropdownMenuItem(
                  value: m,
                  child: Text(m),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedModel = value;
                  });
                }
              },
            ),

            const SizedBox(height: 24),

            // 自定义 Base URL（可展开）
            ExpansionTile(
              title: const Text('高级设置'),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('自定义 Base URL'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _baseUrlController,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: '留空使用默认值',
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('Temperature: ${_temperature.toStringAsFixed(1)}'),
                      Slider(
                        value: _temperature,
                        min: 0,
                        max: 2,
                        divisions: 20,
                        onChanged: (value) {
                          setState(() {
                            _temperature = value;
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      Text('Max Tokens: $_maxTokens'),
                      Slider(
                        value: _maxTokens.toDouble(),
                        min: 256,
                        max: 32768,
                        divisions: 127,
                        onChanged: (value) {
                          setState(() {
                            _maxTokens = value.toInt();
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      const Text('System Prompt'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _systemPromptController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: '可选，设置系统提示词',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // 测试和保存按钮
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isTesting ? null : _testConnection,
                    icon: _isTesting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.psychology),
                    label: const Text('连接模型'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _saveConfig,
                    icon: const Icon(Icons.save),
                    label: const Text('保存配置'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 网络诊断按钮
            Center(
              child: TextButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => const NetworkDiagnosticsDialog(),
                  );
                },
                icon: const Icon(Icons.network_check, size: 18),
                label: const Text('网络诊断'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _testConnection() async {
    // ========== DEBUG: 最早期检查 ==========
    String debugLog = '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n';
    debugLog += '[DEBUG] 点击了"连接模型"按钮\n';
    debugLog += '[DEBUG] 当前时间: ${DateTime.now()}\n';
    debugLog += '[DEBUG] 表单验证开始...\n';
    
    print(debugLog);
    
    if (!_formKey.currentState!.validate()) {
      debugLog += '[DEBUG] ❌ 表单验证失败\n';
      print(debugLog);
      _showDebugDialog('表单验证失败', debugLog);
      return;
    }
    
    debugLog += '[DEBUG] ✓ 表单验证通过\n';
    debugLog += '[DEBUG] 开始设置加载状态...\n';
    print(debugLog);

    setState(() {
      _isTesting = true;
    });
    
    debugLog += '[DEBUG] ✓ 加载状态已设置\n';
    print(debugLog);

    try {
      // ========== DEBUG: 检查输入框内容 ==========
      debugLog += '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n';
      debugLog += '[DEBUG] 检查输入框内容:\n';
      debugLog += '[DEBUG] 提供商: $_selectedProvider\n';
      debugLog += '[DEBUG] API Key 长度: ${_apiKeyController.text.length}\n';
      debugLog += '[DEBUG] Base URL 输入框内容: "${_baseUrlController.text}"\n';
      debugLog += '[DEBUG] Base URL 输入框长度: ${_baseUrlController.text.length}\n';
      debugLog += '[DEBUG] 模型: $_selectedModel\n';
      debugLog += '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n';
      print(debugLog);
      
      // 如果 Base URL 为空，自动填充默认值
      if (_baseUrlController.text.isEmpty) {
        final providerInfo = LLMFactory.getProviderInfo(_selectedProvider);
        if (providerInfo != null) {
          _baseUrlController.text = providerInfo.defaultBaseUrl;
          debugLog += '[DEBUG] ⚠️ Base URL 为空，自动填充默认值\n';
          debugLog += '[DEBUG] 自动填充的 Base URL: ${_baseUrlController.text}\n';
          print('[DEBUG] Base URL 为空，自动填充: ${_baseUrlController.text}');
        }
      } else {
        debugLog += '[DEBUG] ✓ Base URL 已有值，无需填充\n';
      }
      
      // 显示当前配置
      _showDebugDialog('当前配置', debugLog);

      // ========== DEBUG: 显示配置信息 ==========
      print('[DEBUG] 步骤 1: 创建配置对象');
      
      // 检查 Base URL
      String? baseUrl = _baseUrlController.text.isNotEmpty 
          ? _baseUrlController.text 
          : null;
      
      debugLog += '[DEBUG] 步骤 1: 创建配置对象\n';
      debugLog += '[DEBUG] Base URL 输入框内容: "${_baseUrlController.text}"\n';
      debugLog += '[DEBUG] Base URL 长度: ${_baseUrlController.text.length}\n';
      debugLog += '[DEBUG] Base URL 是否为空: ${_baseUrlController.text.isEmpty}\n';
      debugLog += '[DEBUG] 传递给 Config 的 Base URL: $baseUrl\n';
      
      print('[DEBUG] Base URL 输入框内容: "${_baseUrlController.text}"');
      print('[DEBUG] Base URL 长度: ${_baseUrlController.text.length}');
      print('[DEBUG] Base URL 是否为空: ${_baseUrlController.text.isEmpty}');
      print('[DEBUG] 传递给 Config 的 Base URL: $baseUrl');
      
      final config = LLMConfig(
        provider: _selectedProvider,
        apiKey: _apiKeyController.text,
        baseUrl: baseUrl,
        model: _selectedModel,
        temperature: _temperature,
        maxTokens: _maxTokens,
        systemPrompt: _systemPromptController.text.isNotEmpty
            ? _systemPromptController.text
            : null,
      );
      
      debugLog += '[DEBUG] 配置对象已创建\n';
      debugLog += '[DEBUG] config.baseUrl = ${config.baseUrl}\n';
      
      print('[DEBUG] 配置信息:');
      print('  - 提供商: ${config.provider}');
      print('  - API Key: ${config.apiKey.substring(0, 10)}...');
      print('  - Base URL: ${config.baseUrl ?? "默认"}');
      print('  - 模型: ${config.model}');
      print('  - Temperature: ${config.temperature}');
      print('  - Max Tokens: ${config.maxTokens}');

      // ========== DEBUG: 创建 Provider ==========
      print('[DEBUG] 步骤 2: 创建 Provider');
      final provider = LLMFactory.create(config);
      print('[DEBUG] Provider 类型: ${provider.runtimeType}');
      print('[DEBUG] Provider 名称: ${provider.name}');

      // ========== DEBUG: 验证配置 ==========
      print('[DEBUG] 步骤 3: 验证配置（调用 API）');
      print('[DEBUG] 这将发送一个测试请求到 LLM API...');
      final success = await provider.validateConfig();
      
      print('[DEBUG] 步骤 4: 收到响应');
      print('[DEBUG] 验证结果: ${success ? "成功" : "失败"}');

      if (mounted) {
        if (success) {
          print('[DEBUG] ✓ 模型连接成功！');
          _showSuccessSnackBar('✅ 模型连接成功！\n提供商: ${provider.name}\n模型: ${config.model}');
        } else {
          print('[DEBUG] ✗ 模型连接失败');
          _showErrorSnackBar(
            '❌ 模型连接失败\n\n'
            '可能原因:\n'
            '• API Key 错误或已过期\n'
            '• Base URL 不正确\n'
            '• 网络连接问题\n'
            '• API 配额不足\n\n'
            '当前配置:\n'
            '提供商: ${provider.name}\n'
            'Base URL: ${config.baseUrl ?? "默认"}\n'
            '模型: ${config.model}'
          );
        }
      }
    } catch (e, stackTrace) {
      // ========== DEBUG: 捕获异常 ==========
      debugLog += '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n';
      debugLog += '[DEBUG] ❌ 捕获到异常！\n';
      debugLog += '[DEBUG] 异常类型: ${e.runtimeType}\n';
      debugLog += '[DEBUG] 异常信息: $e\n';
      
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('[DEBUG] ❌ 捕获到异常！');
      print('[DEBUG] 异常类型: ${e.runtimeType}');
      print('[DEBUG] 异常信息: $e');
      print('[DEBUG] 堆栈跟踪:');
      print(stackTrace);
      print('[DEBUG] Base URL 输入框: ${_baseUrlController.text}');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      
      if (mounted) {
        // 构建更准确的错误信息
        String errorMessage = '❌ 模型连接异常\n\n';
        errorMessage += '错误类型: ${e.runtimeType}\n';
        errorMessage += '错误信息: $e\n\n';
        errorMessage += '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n';
        errorMessage += '配置信息:\n';
        errorMessage += '提供商: $_selectedProvider\n';
        errorMessage += 'Base URL: ${_baseUrlController.text}\n';
        errorMessage += '模型: $_selectedModel\n';
        errorMessage += '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n';
        errorMessage += '详细堆栈:\n${stackTrace.toString().split('\n').take(5).join('\n')}';
        
        _showErrorSnackBar(errorMessage);
      }
    } finally {
      setState(() {
        _isTesting = false;
      });
      print('[DEBUG] 测试完成，状态已重置');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating, // 浮动模式
        margin: const EdgeInsets.all(16), // 添加边距
        action: SnackBarAction(
          label: '关闭',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    // 添加版本号信息
    const versionInfo = '\n\n━━━━━━━━━━━━━━━━━━━━\n📱 小紫霞版本: v0.6.8 (Build 23)\n━━━━━━━━━━━━━━━━━━━━';
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: SizedBox(
          height: 400, // 固定高度
          child: SingleChildScrollView(
            child: Text(message + versionInfo),
          ),
        ),
        backgroundColor: Colors.red,
        duration: const Duration(minutes: 1), // 延长到 1 分钟
        behavior: SnackBarBehavior.floating, // 浮动模式
        margin: const EdgeInsets.all(16), // 添加边距
        action: SnackBarAction(
          label: '关闭',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  void _showDebugDialog(String title, String debugLog) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.bug_report, color: Colors.blue),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: SingleChildScrollView(
            child: SelectableText(
              debugLog,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) return;

    final config = LLMConfig(
      provider: _selectedProvider,
      apiKey: _apiKeyController.text,
      baseUrl: _baseUrlController.text.isNotEmpty ? _baseUrlController.text : null,
      model: _selectedModel,
      temperature: _temperature,
      maxTokens: _maxTokens,
      systemPrompt: _systemPromptController.text.isNotEmpty
          ? _systemPromptController.text
          : null,
    );

    await context.read<AppState>().saveLLMConfig(config);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ 配置已保存'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _baseUrlController.dispose();
    _systemPromptController.dispose();
    super.dispose();
  }
}
