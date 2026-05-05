// 权限管理服务
//
// 细粒度权限控制

import 'dart:async';
import 'package:flutter/foundation.dart';

/// 权限类型
enum Permission {
  read,
  write,
  execute,
  admin,
}

/// 角色
class Role {
  final String id;
  final String name;
  final Set<Permission> permissions;
  
  Role({
    required this.id,
    required this.name,
    required this.permissions,
  });
}

/// 用户权限
class UserPermission {
  final String userId;
  final Set<Role> roles;
  
  UserPermission({
    required this.userId,
    required this.roles,
  });
  
  bool hasPermission(Permission permission) {
    for (final role in roles) {
      if (role.permissions.contains(permission)) {
        return true;
      }
    }
    return false;
  }
}

/// 权限管理器
class PermissionManager extends ChangeNotifier {
  final List<Role> _roles = [];
  final Map<String, UserPermission> _userPermissions = {};
  
  /// 添加角色
  void addRole(Role role) {
    _roles.add(role);
    notifyListeners();
  }
  
  /// 授权角色
  void grantRole(String userId, Role role) {
    _userPermissions[userId] ??= UserPermission(userId: userId, roles: {});
    _userPermissions[userId]!.roles.add(role);
    notifyListeners();
  }
  
  /// 检查权限
  bool hasPermission(String userId, Permission permission) {
    final userPerm = _userPermissions[userId];
    if (userPerm == null) return false;
    return userPerm.hasPermission(permission);
  }
  
  /// 撤销角色
  void revokeRole(String userId, String roleId) {
    _userPermissions[userId]?.roles.removeWhere((r) => r.id == roleId);
    notifyListeners();
  }
  
  /// 初始化默认角色
  void initDefaultRoles() {
    _roles.addAll([
      Role(id: 'admin', name: '管理员', permissions: {Permission.admin}),
      Role(id: 'editor', name: '编辑', permissions: {Permission.read, Permission.write}),
      Role(id: 'viewer', name: '查看', permissions: {Permission.read}),
    ]);
    notifyListeners();
  }
}