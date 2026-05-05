// 文件同步服务
//
// 多设备间文件同步

import 'dart:async';
import 'package:flutter/foundation.dart';

/// 文件信息
class FileInfo {
  final String path;
  final String name;
  final int size;
  final DateTime modified;
  final String deviceId;
  
  FileInfo({
    required this.path,
    required this.name,
    required this.size,
    required this.modified,
    required this.deviceId,
  });
}

/// 同步冲突处理
enum ConflictResolution {
  keepLocal,
  keepRemote,
  keepBoth,
  newest,
}

/// 文件同步器
class FileSync extends ChangeNotifier {
  final Map<String, List<FileInfo>> _filesByDevice = {};
  
  /// 获取设备文件
  List<FileInfo> getDeviceFiles(String deviceId) {
    return _filesByDevice[deviceId] ?? [];
  }
  
  /// 扫描设备文件
  Future<void> scanFiles(String deviceId) async {
    // TODO: 扫描设备上的文件
    _filesByDevice[deviceId] = [
      FileInfo(
        path: '/documents/test.txt',
        name: 'test.txt',
        size: 1024,
        modified: DateTime.now(),
        deviceId: deviceId,
      ),
    ];
    notifyListeners();
  }
  
  /// 同步文件
  Future<bool> syncFile(String deviceId, String remotePath) async {
    debugPrint('[FileSync] 同步文件: $remotePath from $deviceId');
    // TODO: 实际同步
    return true;
  }
  
  /// 检测冲突
  Future<ConflictResolution> detectConflict(
    FileInfo local,
    FileInfo remote,
  ) async {
    if (local.modified.isAfter(remote.modified)) {
      return ConflictResolution.newest;
    }
    return ConflictResolution.keepRemote;
  }
  
  /// 删除文件
  Future<void> deleteFile(String deviceId, String path) async {
    _filesByDevice[deviceId]?.removeWhere((f) => f.path == path);
    notifyListeners();
  }
}