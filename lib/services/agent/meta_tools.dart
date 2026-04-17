// 元工具：让 Agent 能发现和安装新工具
//
// 核心能力：
// 1. skill_hub_search - 搜索 ClawHub 技能市场
// 2. skill_hub_install - 安装新技能（安装后自动注册为可用工具）
// 3. run_script - 执行 JS/HTML 脚本（当没有现成工具时自己写代码解决）

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'agent_loop_v2.dart';
import 'agent_tools.dart'; // SkillAgentTool
import '../skills/clawhub_service.dart';
import '../skills/skill_system.dart';
import '../sandbox/code_sandbox_service.dart';

// ==================== SkillHub 搜索工具 ====================

class SkillHubSearchTool extends AgentTool {
  final ClawHubService _clawhub;
  final SkillManager _skillManager;

  SkillHubSearchTool(this._clawhub, this._skillManager);

  @override
  String get name => 'skill_hub_search';

  @override
  String get description =>
      '搜索技能市场（ClawHub），查找可用但尚未安装的技能/工具。'
      '当你发现当前工具不足以完成用户任务时，用这个工具搜索可能存在的新工具。'
      '例如：用户要查汇率但你没有汇率工具 → 搜索 "exchange rate"；'
      '用户要翻译但翻译工具不可用 → 搜索 "translate"。';

  @override
  Map<String, dynamic> get parametersSchema => {
    'type': 'object',
    'properties': {
      'query': {
        'type': 'string',
        'description': '搜索关键词，如 "weather"、"翻译"、"汇率"、"calculator"',
      },
    },
    'required': ['query'],
  };

  @override
  Future<AgentToolResult> execute(Map<String, dynamic> arguments) async {
    final query = arguments['query'] as String?;
    if (query == null || query.trim().isEmpty) {
      return AgentToolResult.fail('缺少搜索关键词');
    }

    debugPrint('[SkillHubSearch] 搜索: $query');

    try {
      final results = await _clawhub.search(query, limit: 10);
      if (results.isEmpty) {
        return AgentToolResult.success(
          '在技能市场未找到与 "$query" 相关的技能。\n'
          '建议：你可以尝试用 web_search 搜索解决方案，或用 run_script 自己写代码完成。',
        );
      }

      // 标记哪些已安装
      final installedIds = _skillManager.registry.available
          .map((s) => s.id)
          .toSet();

      final buffer = StringBuffer();
      buffer.writeln('搜索到 ${results.length} 个相关技能：\n');

      for (int i = 0; i < results.length; i++) {
        final skill = results[i];
        final isInstalled = installedIds.contains(skill.slug);
        buffer.writeln('${i + 1}. ${skill.name} (${skill.slug})${isInstalled ? " ✅已安装" : ""}');
        buffer.writeln('   ${skill.description}');
        if (skill.tags.isNotEmpty) {
          buffer.writeln('   标签: ${skill.tags.join(", ")}');
        }
        buffer.writeln();
      }

      buffer.writeln('提示：使用 skill_hub_install 安装新技能，如 skill_hub_install(slug: "exchange-rate")');

      return AgentToolResult.success(buffer.toString());
    } catch (e) {
      return AgentToolResult.fail('搜索失败: $e');
    }
  }
}

// ==================== SkillHub 安装工具 ====================

class SkillHubInstallTool extends AgentTool {
  final ClawHubService _clawhub;
  final SkillManager _skillManager;
  final AgentLoopServiceV2 _agentLoop;

  SkillHubInstallTool(this._clawhub, this._skillManager, this._agentLoop);

  @override
  String get name => 'skill_hub_install';

  @override
  String get description =>
      '从技能市场安装一个新技能，安装后立即可用。'
      '先用 skill_hub_search 搜索找到需要的技能 slug，再用这个工具安装。'
      '安装成功后，新技能会自动注册为可用工具，你可以在下一轮调用它。';

  @override
  Map<String, dynamic> get parametersSchema => {
    'type': 'object',
    'properties': {
      'slug': {
        'type': 'string',
        'description': '技能的唯一标识 slug，如 "weather"、"exchange-rate"',
      },
    },
    'required': ['slug'],
  };

  @override
  Future<AgentToolResult> execute(Map<String, dynamic> arguments) async {
    final slug = arguments['slug'] as String?;
    if (slug == null || slug.trim().isEmpty) {
      return AgentToolResult.fail('缺少技能 slug');
    }

    debugPrint('[SkillHubInstall] 安装: $slug');

    try {
      // 1. 从 ClawHub 获取技能内容
      final content = await _clawhub.getSkillContent(slug);
      if (content == null || content.isEmpty) {
        return AgentToolResult.fail(
          '无法获取技能 "$slug" 的内容。可能是网络问题或该技能不存在。\n'
          '建议：用 run_script 自己写代码完成，或用 web_search 寻找替代方案。',
        );
      }

      // 2. 用 slug 作为前缀避免冲突
      // installFromContent 需要 slug + content
      // 我们先把内容加上 slug 头部
      final fullContent = '---\nid: $slug\n---\n$content';

      // 3. 解析并安装
      final success = await _skillManager.installFromContent(fullContent);
      if (!success) {
        return AgentToolResult.fail(
          '技能 "$slug" 安装失败，可能是格式不正确。\n'
          '建议：用 run_script 自己写代码完成，或用 web_search 寻找替代方案。',
        );
      }

      // 4. 找到刚安装的 skill 并注册为 Agent Tool
      final skill = _skillManager.registry.get(slug);
      if (skill != null) {
        final tool = SkillAgentTool(skill, _skillManager);
        _agentLoop.registerTool(tool);
        debugPrint('[SkillHubInstall] ✅ 安装成功: $slug -> ${tool.name}');

        return AgentToolResult.success(
          '技能 "${skill.metadata.name}" ($slug) 安装成功！\n'
          '工具名: ${tool.name}\n'
          '描述: ${skill.metadata.description}\n\n'
          '现在你可以直接调用这个工具了。',
        );
      }

      return AgentToolResult.success(
        '技能 "$slug" 安装成功！现在你可以使用 skill_$slug 调用它。',
      );
    } catch (e) {
      return AgentToolResult.fail('安装失败: $e');
    }
  }
}

// ==================== 运行脚本工具 ====================

class RunScriptTool extends AgentTool {
  final CodeSandboxService _sandbox;

  RunScriptTool(this._sandbox);

  @override
  String get name => 'run_script';

  @override
  String get description =>
      '执行自定义代码脚本（HTML/JS），用于当你没有合适的工具时自己写代码解决问题。'
      '适用场景：特殊计算、数据转换、API调用、生成图表、数学公式求解等。\n'
      '代码会在沙盒环境中运行并返回结果。\n'
      '注意：JS 代码可以通过 fetch() 调用外部 API（如果网络可用）。';

  @override
  Map<String, dynamic> get parametersSchema => {
    'type': 'object',
    'properties': {
      'name': {
        'type': 'string',
        'description': '脚本名称/用途描述，如 "汇率计算"、"JSON解析"',
      },
      'code': {
        'type': 'string',
        'description':
            '要执行的代码。推荐完整 HTML 格式（包含JS），运行后返回结果。\n'
            'JS 脚本需要将最终结果写入 document.body.innerText 或通过 alert() 输出。\n'
            '示例：\n'
            '<html><body><script>\n'
            '// 你的计算逻辑\n'
            'const result = 42 * 6.5;\n'
            'document.body.innerText = "计算结果: " + result;\n'
            '</script></body></html>',
      },
      'description': {
        'type': 'string',
        'description': '对脚本功能和结果的简要说明',
      },
    },
    'required': ['name', 'code'],
  };

  @override
  Future<AgentToolResult> execute(Map<String, dynamic> arguments) async {
    final name = arguments['name'] as String?;
    final code = arguments['code'] as String?;

    if (name == null || code == null) {
      return AgentToolResult.fail('缺少必要参数');
    }

    debugPrint('[RunScript] 执行: $name (${code.length} chars)');

    try {
      // 尝试从代码中提取 API URL 并直接请求
      final apiUrls = _extractApiUrls(code);
      if (apiUrls.isNotEmpty) {
        debugPrint('[RunScript] 检测到 API URL: $apiUrls');
        final results = <String>[];
        for (final url in apiUrls) {
          try {
            final response = await http.get(Uri.parse(url))
                .timeout(const Duration(seconds: 10));
            if (response.statusCode == 200) {
              final body = utf8.decode(response.bodyBytes);
              results.add('✅ GET $url\n${body.length > 2000 ? '${body.substring(0, 2000)}...(截断)' : body}');
            } else {
              results.add('❌ GET $url → HTTP ${response.statusCode}');
            }
          } catch (e) {
            results.add('❌ GET $url → $e');
          }
        }
        if (results.isNotEmpty) {
          return AgentToolResult.success(
            'API 请求结果:\n${results.join('\n\n')}\n\n请根据以上结果回答用户。',
          );
        }
      }

      // 没有可提取的 API，创建项目保存
      _sandbox.createFromCode(
        name: name,
        code: code,
        language: 'html',
        description: arguments['description'] as String? ?? 'Agent 自动脚本',
      );

      return AgentToolResult.fail(
        '脚本无法自动执行（当前不支持 JS 运行时）。'
        '建议：如需获取数据，直接用 web_fetch 工具；如需搜索，用 web_search。'
        '不要再用 run_script 做 API 调用，web_fetch 更可靠。',
      );
    } catch (e) {
      return AgentToolResult.fail('脚本执行失败: $e');
    }
  }

  /// 从 JS/HTML 代码中提取 API URL
  List<String> _extractApiUrls(String code) {
    final urls = <String>[];
    // 匹配 fetch("url") 和 fetch('url')
    final fetchRegex = RegExp(r"""fetch\s*\(\s*['"]([^'"]+)['"]\s*""");
    for (final match in fetchRegex.allMatches(code)) {
      final url = match.group(1);
      if (url != null && url.startsWith('http')) {
        urls.add(url);
      }
    }
    return urls;
  }
}

// ==================== 注册辅助 ====================

void registerMetaTools(
  AgentLoopServiceV2 agentLoop, {
  required ClawHubService clawhub,
  required SkillManager skillManager,
  required CodeSandboxService sandbox,
}) {
  agentLoop.registerTool(SkillHubSearchTool(clawhub, skillManager));
  agentLoop.registerTool(SkillHubInstallTool(clawhub, skillManager, agentLoop));
  agentLoop.registerTool(RunScriptTool(sandbox));
  debugPrint('[MetaTools] 已注册元工具: skill_hub_search, skill_hub_install, run_script');
}
