// 多媒体消息模型
//
// 支持文字、图像、语音的组合消息

import 'dart:convert';
import 'dart:io';

/// 消息类型
enum MessageType {
  text,       // 纯文字
  image,      // 纯图像
  multimodal, // 文字 + 图像
}

/// 多媒体消息
class MultimodalMessage {
  final String id;
  final String role;        // 'user' 或 'assistant'
  final MessageType type;
  final String? text;       // 文字内容
  final String? imagePath;  // 图像文件路径
  final DateTime timestamp;

  MultimodalMessage({
    required this.id,
    required this.role,
    this.type = MessageType.text,
    this.text,
    this.imagePath,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// 是否有图像
  bool get hasImage => imagePath != null && imagePath!.isNotEmpty;

  /// 是否有文字
  bool get hasText => text != null && text!.isNotEmpty;

  /// 是否为纯文字
  bool get isTextOnly => type == MessageType.text && hasText && !hasImage;

  /// 是否为纯图像
  bool get isImageOnly => type == MessageType.image && hasImage && !hasText;

  /// 是否为多模态
  bool get isMultimodal => type == MessageType.multimodal || (hasText && hasImage);

  /// 创建纯文字消息
  factory MultimodalMessage.text({
    required String id,
    required String role,
    required String text,
  }) {
    return MultimodalMessage(
      id: id,
      role: role,
      type: MessageType.text,
      text: text,
    );
  }

  /// 创建图像消息
  factory MultimodalMessage.image({
    required String id,
    required String role,
    required String imagePath,
  }) {
    return MultimodalMessage(
      id: id,
      role: role,
      type: MessageType.image,
      imagePath: imagePath,
    );
  }

  /// 创建多模态消息（文字 + 图像）
  factory MultimodalMessage.multimodal({
    required String id,
    required String role,
    String? text,
    String? imagePath,
  }) {
    return MultimodalMessage(
      id: id,
      role: role,
      type: MessageType.multimodal,
      text: text,
      imagePath: imagePath,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': role,
      'type': type.name,
      'text': text,
      'imagePath': imagePath,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  /// 从 JSON 创建
  factory MultimodalMessage.fromJson(Map<String, dynamic> json) {
    return MultimodalMessage(
      id: json['id'],
      role: json['role'],
      type: MessageType.values.firstWhere((t) => t.name == json['type']),
      text: json['text'],
      imagePath: json['imagePath'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }

  @override
  String toString() {
    return 'MultimodalMessage(id: $id, role: $role, type: $type, hasText: $hasText, hasImage: $hasImage)';
  }
}

/// 图像工具类
class ImageUtils {
  /// 将图像文件转换为 Base64
  static Future<String> imageToBase64(String imagePath) async {
    final file = File(imagePath);
    final bytes = await file.readAsBytes();
    return base64Encode(bytes);
  }

  /// 获取图像的 MIME 类型
  static String getMimeType(String imagePath) {
    final extension = imagePath.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  /// 创建 Data URI (data:image/jpeg;base64,...)
  static Future<String> createDataUri(String imagePath) async {
    final base64 = await imageToBase64(imagePath);
    final mimeType = getMimeType(imagePath);
    return 'data:$mimeType;base64,$base64';
  }
}
