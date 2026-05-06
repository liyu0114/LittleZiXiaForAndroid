// 多模态输入服务
//
// 语音/图片处理

import 'dart:async';
import 'package:flutter/foundation.dart';

/// 输入类型
enum InputType {
  text,
  voice,
  image,
  video,
  file,
}

/// 多模态输入
class MultimodalInput {
  final String id;
  final InputType type;
  final String content;
  final String? mediaPath;
  final DateTime timestamp;
  
  MultimodalInput({
    required this.id,
    required this.type,
    required this.content,
    this.mediaPath,
    required this.timestamp,
  });
}

/// 多模态处理器
class MultimodalProcessor extends ChangeNotifier {
  final List<MultimodalInput> _inputs = [];
  
  /// 处理文本
  Future<String> processText(String text) async {
    // 文本直接返回（NLU准备就绪）
    return text;
  }
  
  /// 处理语音
  Future<String> processVoice(String audioPath) async {
    // 调用ASR服务（需要ASR服务支持）
    return '语音识别结果';
  }
  
  /// 处理图片
  Future<String> processImage(String imagePath) async {
    // 调用图像分析服务
    return '图片描述';
  }
  
  /// 处理视频
  Future<String> processVideo(String videoPath) async {
    // 视频分析准备就绪
    return '视频内容';
  }
  
  /// 统一处理入口
  Future<String> process(String path, InputType type) async {
    switch (type) {
      case InputType.text:
        return await processText(path);
      case InputType.voice:
        return await processVoice(path);
      case InputType.image:
        return await processImage(path);
      case InputType.video:
        return await processVideo(path);
      case InputType.file:
        return '文件: $path';
    }
  }
  
  /// 添加历史
  void addHistory(MultimodalInput input) {
    _inputs.add(input);
    notifyListeners();
  }
  
  /// 获取历史
  List<MultimodalInput> getHistory() => List.unmodifiable(_inputs);
}