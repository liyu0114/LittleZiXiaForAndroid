/// Skill 生命周期管理服务
///
/// 管理技能的完整生命周期：
/// 待测试 → 待安装 → 已安装 → 翡用

/// 已禁用 → 卸载

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Skill 状态枚举
enum SkillStatus {
  pendingTest,    // 待测试（从 ClawHub 同步或对话生成）
  editing,             // 编辑中
  readyToInstall,  // 待安装（测试通过）
  installed,              // 已安装（正式启用)
  disabled,               // 已禁用(保留但不运行)
}

