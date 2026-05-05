// 本地模型服务
//
// 支持本地LLM模型加载和运行

import 'dart:async';
import 'package:flutter/foundation.dart';

/// 模型信息
class LocalModel {
  final String id;
  final String name;
  final String path;
  final int sizeMB;
  final int contextLength;
  final bool isLoaded;
  
  LocalModel({
    required this.id,
    required this.name,
    required this.path,
    required this.sizeMB,
    this.contextLength = 4096,
    this.isLoaded = false,
  });
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'path': path,
    'sizeMB': sizeMB,
    'contextLength': contextLength,
    'isLoaded': isLoaded,
  };
  
  factory LocalModel.fromJson(Map<String, dynamic> json) => LocalModel(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    path: json['path'] ?? '',
    sizeMB: json['sizeMB'] ?? 0,
    contextLength: json['contextLength'] ?? 4096,
    isLoaded: json['isLoaded'] ?? false,
  );
}

/// 本地模型管理器
class LocalModelManager extends ChangeNotifier {
  final List<LocalModel> _models = [];
  LocalModel? _currentModel;
  bool _isLoading = false;
  
  List<LocalModel> get models => List.unmodifiable(_models);
  LocalModel? get currentModel => _currentModel;
  bool get isLoading => _isLoading;
  
  /// 扫描本地模型
  Future<List<LocalModel>> scanModels() async {
    // TODO: 扫描模型目录
    // 返回预设列表作为示例
    _models.clear();
    _models.addAll([
      LocalModel(
        id: 'qwen2.5-0.5b',
        name: 'Qwen2.5 0.5B',
        path: '/models/qwen2.5-0.5b.gguf',
        sizeMB: 1000,
        contextLength: 4096,
      ),
      LocalModel(
        id: 'llama3-1b',
        name: 'Llama3 1B',
        path: '/models/llama3-1b.gguf',
        sizeMB: 700,
        contextLength: 4096,
      ),
      LocalModel(
        id: 'phi3-1b',
        name: 'Phi3 1B',
        path: '/models/phi3-1b.gguf',
        sizeMB: 500,
        contextLength: 4096,
      ),
    ]);
    
    notifyListeners();
    return _models;
  }
  
  /// 加载模型
  Future<bool> loadModel(String modelId) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final model = _models.firstWhere((m) => m.id == modelId);
      // TODO: 使用llama.cpp加载模型
      await Future.delayed(Duration(seconds: 1));
      
      _currentModel = LocalModel(
        id: model.id,
        name: model.name,
        path: model.path,
        sizeMB: model.sizeMB,
        contextLength: model.contextLength,
        isLoaded: true,
      );
      
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[LocalModelManager] 加载失败: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// 卸载模型
  Future<void> unloadModel() async {
    _currentModel = null;
    notifyListeners();
  }
  
  /// 对模型提问
  Future<String> chat(String prompt) async {
    if (_currentModel == null) {
      return '请先加载模型';
    }
    
    // TODO: 使用加载的模型进行推理
    return '[$(_currentModel!.name)] 返回: $prompt';
  }
}