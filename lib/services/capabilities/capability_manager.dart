// 能力层管理器
//
// 管理 L1-L4 四个能力层的开关和状态

import 'package:flutter/material.dart';

/// 能力层级
enum CapabilityLevel {
  l1Basic,      // 基础：对话、Web API
  l2Native,     // 增强：相机、位置、通知
  l3System,     // 系统：ADB 命令
  l4Remote,     // 远程：连接龙虾
}

/// 能力层配置
class CapabilityConfig {
  final bool l1Enabled;
  final bool l2Enabled;
  final bool l3Enabled;
  final bool l4Enabled;
  final bool l3AdbAuthorized;
  final String? l4RemoteUrl;
  final String? l4RemoteToken;

  CapabilityConfig({
    this.l1Enabled = true,
    this.l2Enabled = false,
    this.l3Enabled = false,
    this.l4Enabled = false,
    this.l3AdbAuthorized = false,
    this.l4RemoteUrl,
    this.l4RemoteToken,
  });

  bool isEnabled(CapabilityLevel level) {
    switch (level) {
      case CapabilityLevel.l1Basic:
        return l1Enabled;
      case CapabilityLevel.l2Native:
        return l2Enabled;
      case CapabilityLevel.l3System:
        return l3Enabled && l3AdbAuthorized;
      case CapabilityLevel.l4Remote:
        return l4Enabled && l4RemoteUrl != null;
    }
  }

  /// 获取当前最高能力层级
  int get currentLevel {
    if (l4Enabled && l4RemoteUrl != null) return 4;
    if (l3Enabled && l3AdbAuthorized) return 3;
    if (l2Enabled) return 2;
    if (l1Enabled) return 1;
    return 0;
  }

  Map<String, dynamic> toJson() {
    return {
      'l1Enabled': l1Enabled,
      'l2Enabled': l2Enabled,
      'l3Enabled': l3Enabled,
      'l4Enabled': l4Enabled,
      'l3AdbAuthorized': l3AdbAuthorized,
      'l4RemoteUrl': l4RemoteUrl,
      'l4RemoteToken': l4RemoteToken,
    };
  }

  factory CapabilityConfig.fromJson(Map<String, dynamic> json) {
    return CapabilityConfig(
      l1Enabled: json['l1Enabled'] ?? true,
      l2Enabled: json['l2Enabled'] ?? false,
      l3Enabled: json['l3Enabled'] ?? false,
      l4Enabled: json['l4Enabled'] ?? false,
      l3AdbAuthorized: json['l3AdbAuthorized'] ?? false,
      l4RemoteUrl: json['l4RemoteUrl'],
      l4RemoteToken: json['l4RemoteToken'],
    );
  }

  CapabilityConfig copyWith({
    bool? l1Enabled,
    bool? l2Enabled,
    bool? l3Enabled,
    bool? l4Enabled,
    bool? l3AdbAuthorized,
    String? l4RemoteUrl,
    String? l4RemoteToken,
  }) {
    return CapabilityConfig(
      l1Enabled: l1Enabled ?? this.l1Enabled,
      l2Enabled: l2Enabled ?? this.l2Enabled,
      l3Enabled: l3Enabled ?? this.l3Enabled,
      l4Enabled: l4Enabled ?? this.l4Enabled,
      l3AdbAuthorized: l3AdbAuthorized ?? this.l3AdbAuthorized,
      l4RemoteUrl: l4RemoteUrl ?? this.l4RemoteUrl,
      l4RemoteToken: l4RemoteToken ?? this.l4RemoteToken,
    );
  }
}

/// 能力层信息（用于 UI 显示）
class CapabilityLevelInfo {
  final CapabilityLevel level;
  final String name;
  final String description;
  final String riskWarning;
  final IconData icon;
  final List<String> features;

  const CapabilityLevelInfo({
    required this.level,
    required this.name,
    required this.description,
    required this.riskWarning,
    required this.icon,
    required this.features,
  });
}

// 注意：icon 需要从 material 导入，这里用字符串代替
const Map<CapabilityLevel, Map<String, dynamic>> capabilityLevelInfos = {
  CapabilityLevel.l1Basic: {
    'name': '基础模式',
    'description': '对话、调用大模型、Web 服务',
    'riskWarning': '',
    'icon': 'chat',
    'features': [
      '✅ 与 AI 对话',
      '✅ 调用各种大模型 API',
      '✅ 查询天气、搜索等 Web 服务',
      '✅ 本地保存对话历史',
    ],
  },
  CapabilityLevel.l2Native: {
    'name': '增强模式',
    'description': '相机、相册、位置、通知',
    'riskWarning': '需要授权相应权限（相机、位置、通知等）',
    'icon': 'devices',
    'features': [
      '✅ 访问相机拍照',
      '✅ 读取相册图片',
      '✅ 获取位置信息',
      '✅ 发送系统通知',
    ],
  },
  CapabilityLevel.l3System: {
    'name': '系统模式',
    'description': 'Shell 命令、系统控制（需要 ADB）',
    'riskWarning': '⚠️ 此模式需要 ADB 调试权限。开启后，紫霞可以执行系统级命令。\n'
        '请仅在您信任此应用且了解风险的情况下使用。\n'
        '不当操作可能导致系统不稳定或数据丢失。',
    'icon': 'terminal',
    'features': [
      '✅ 执行 Shell 命令',
      '✅ 管理应用（安装/卸载）',
      '✅ 控制系统设置',
      '✅ 截屏、录屏',
    ],
  },
  CapabilityLevel.l4Remote: {
    'name': '远程模式',
    'description': '连接 Windows/Linux 龙虾',
    'riskWarning': '⚠️ 此模式将连接远程服务器。\n'
        '您的对话内容将传输到远程设备。\n'
        '请确保您信任该服务器。',
    'icon': 'cloud',
    'features': [
      '✅ 连接远程龙虾',
      '✅ 执行远程命令',
      '✅ 访问远程文件',
      '✅ 控制远程设备',
    ],
  },
};

/// 能力管理器
class CapabilityManager {
  CapabilityConfig _config;

  CapabilityManager({CapabilityConfig? config})
      : _config = config ?? CapabilityConfig();

  CapabilityConfig get config => _config;

  void updateConfig(CapabilityConfig newConfig) {
    _config = newConfig;
  }

  bool isEnabled(CapabilityLevel level) => _config.isEnabled(level);

  /// 获取当前启用的能力层级列表
  List<CapabilityLevel> get enabledLevels {
    return CapabilityLevel.values.where(isEnabled).toList();
  }

  /// 检查是否可以执行某个操作
  bool canPerform(String capability) {
    // 根据能力类型检查对应的层级
    if (_l1Capabilities.contains(capability)) {
      return isEnabled(CapabilityLevel.l1Basic);
    }
    if (_l2Capabilities.contains(capability)) {
      return isEnabled(CapabilityLevel.l2Native);
    }
    if (_l3Capabilities.contains(capability)) {
      return isEnabled(CapabilityLevel.l3System);
    }
    if (_l4Capabilities.contains(capability)) {
      return isEnabled(CapabilityLevel.l4Remote);
    }
    return false;
  }

  static const _l1Capabilities = {
    'chat', 'llm_call', 'web_search', 'weather', 'translate',
  };

  static const _l2Capabilities = {
    'camera', 'photo_library', 'location', 'notification', 'sensor',
  };

  static const _l3Capabilities = {
    'shell', 'install_app', 'uninstall_app', 'screenshot', 'screen_record',
    'system_settings',
  };

  static const _l4Capabilities = {
    'remote_command', 'remote_file', 'remote_control',
  };
}
