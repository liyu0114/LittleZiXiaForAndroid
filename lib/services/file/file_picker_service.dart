// 文件选择服务
//
// 使用 Android 原生文件选择器

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class FilePickResult {
  final String path;       // 文件 URI
  final String name;       // 文件名
  final int size;          // 文件大小（字节）
  final String type;       // MIME 类型

  FilePickResult({
    required this.path,
    required this.name,
    required this.size,
    required this.type,
  });

  factory FilePickResult.fromMap(Map<String, dynamic> map) {
    return FilePickResult(
      path: map['path'] as String,
      name: map['name'] as String,
      size: map['size'] as int,
      type: map['type'] as String,
    );
  }

  /// 获取文件大小（格式化）
  String get sizeFormatted {
    if (size < 1024) {
      return '$size B';
    } else if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    } else if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  /// 获取文件扩展名
  String get extension {
    final parts = name.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : '';
  }

  /// 获取文件图标
  String get icon {
    switch (extension) {
      case 'pdf':
        return '📄';
      case 'doc':
      case 'docx':
        return '📝';
      case 'xls':
      case 'xlsx':
        return '📊';
      case 'ppt':
      case 'pptx':
        return '📽️';
      case 'txt':
        return '📃';
      case 'csv':
        return '📈';
      default:
        return '📎';
    }
  }

  @override
  String toString() {
    return 'FilePickResult(path: $path, name: $name, size: $sizeFormatted, type: $type)';
  }
}

class FilePickerService {
  static const _channel = MethodChannel('com.example.openclaw_app/file');

  /// 选择文件
  /// 
  /// 支持的文件类型：
  /// - PDF (.pdf)
  /// - Word (.doc, .docx)
  /// - Excel (.xls, .xlsx)
  /// - PowerPoint (.ppt, .pptx)
  /// - 文本 (.txt, .csv)
  static Future<FilePickResult?> pickFile() async {
    try {
      debugPrint('[FilePicker] 启动文件选择器...');
      
      final result = await _channel.invokeMethod<Map>('pickFile');
      
      if (result != null) {
        final fileResult = FilePickResult.fromMap(Map<String, dynamic>.from(result));
        debugPrint('[FilePicker] 文件选择成功: $fileResult');
        return fileResult;
      }
      
      return null;
    } on PlatformException catch (e) {
      if (e.code == 'CANCELLED') {
        debugPrint('[FilePicker] 用户取消选择');
        return null;
      }
      
      debugPrint('[FilePicker] 文件选择失败: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('[FilePicker] 未知错误: $e');
      return null;
    }
  }
}
