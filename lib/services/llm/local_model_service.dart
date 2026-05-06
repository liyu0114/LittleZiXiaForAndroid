// 本地模型服务
//
// 支持本地LLM模型加载和运行 (llama.cpp)

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const _channel = MethodChannel('com.example.openclaw_app/local_model');

/// 模型信息
class LocalModel {
  final String id;
  final String name;
  final int sizeMB;
  final int contextLength;
  final bool isLoaded;
  
  LocalModel({
    required this.id,
    required this.name,
    required this.sizeMB,
    this.contextLength = 4096,
    this.isLoaded = false,
  });
  
  factory LocalModel.fromJson(Map<String, dynamic> json) {
    return LocalModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      sizeMB: json['sizeMB'] ?? 0,
      contextLength: json['contextLength'] ?? 4096,
      isLoaded: false,
    );
  }
}

/// 本地模型管理器
class LocalModelManager extends ChangeNotifier {
  List<LocalModel> _models = [];
  LocalModel? _currentModel;
  bool _isLoading = false;
  bool _isInitialized = false;
  
  List<LocalModel> get models => _models;
  LocalModel? get currentModel => _currentModel;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  
  /// 初始化并扫描模型
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      final result = await _channel.invokeMethod<List>('getModels');
      if (result != null) {
        _models = result.map((m) => LocalModel.fromJson(Map<String, dynamic>.from(m))).toList();
      }
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('[LocalModel] 初始化失败: $e');
    }
  }
  
  /// 加载模型
  Future<bool> loadModel(String modelId) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      await _channel.invokeMethod('loadModel', {'modelId': modelId});
      
      _currentModel = _models.firstWhere(
        (m) => m.id == modelId,
        orElse: () => _models.first,
      );
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint('[LocalModel] 加载失败: $e');
      return false;
    }
  }
  
  /// 生成文本
  Future<String> generate(String prompt, {int maxTokens = 256, double temperature = 0.7}) async {
    if (_currentModel == null) {
      return '请先加载模型';
    }
    
    try {
      final result = await _channel.invokeMethod<String>('generate', {
        'prompt': prompt,
        'maxTokens': maxTokens,
        'temperature': temperature,
      });
      return result ?? '生成失败';
    } catch (e) {
      debugPrint('[LocalModel] 生成失败: $e');
      return '生成失败: $e';
    }
  }
  
  /// 卸载模型
  Future<void> unloadModel() async {
    try {
      await _channel.invokeMethod('unload');
      _currentModel = null;
      notifyListeners();
    } catch (e) {
      debugPrint('[LocalModel] 卸载失败: $e');
    }
  }
  
  /// 检查模型是否加载
  Future<bool> isModelLoaded() async {
    try {
      final result = await _channel.invokeMethod<bool>('isLoaded');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }
}