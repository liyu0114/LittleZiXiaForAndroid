// 本地模型服务测试 - L1 单元测试
import 'package:flutter_test/flutter_test.dart';

/// 模型信息
class ModelInfo {
  final String id;
  final String name;
  final String size;
  final bool isLoaded;
  
  ModelInfo({
    required this.id,
    required this.name,
    required this.size,
    this.isLoaded = false,
  });
}

/// 本地模型服务
class LocalModelService {
  final Map<String, ModelInfo> _models = {};
  String? _currentModel;
  bool _isLoading = false;
  
  bool get isLoading => _isLoading;
  String? get currentModel => _currentModel;
  
  void registerModel(String id, String name, String size) {
    _models[id] = ModelInfo(id: id, name: name, size: size);
  }
  
  List<ModelInfo> get availableModels => _models.values.toList();
  
  Future<bool> loadModel(String id) async {
    if (!_models.containsKey(id)) return false;
    
    _isLoading = true;
    await Future.delayed(Duration(milliseconds: 100));
    
    _models[id] = ModelInfo(
      id: _models[id]!.id,
      name: _models[id]!.name,
      size: _models[id]!.size,
      isLoaded: true,
    );
    _currentModel = id;
    _isLoading = false;
    return true;
  }
  
  Future<void> unloadModel(String id) async {
    if (_models.containsKey(id)) {
      _models[id] = ModelInfo(
        id: _models[id]!.id,
        name: _models[id]!.name,
        size: _models[id]!.size,
        isLoaded: false,
      );
    }
    if (_currentModel == id) {
      _currentModel = null;
    }
  }
  
  ModelInfo? getModelInfo(String id) => _models[id];
  
  bool isModelLoaded(String id) => _models[id]?.isLoaded ?? false;
  
  void unloadAll() {
    for (final id in _models.keys) {
      _models[id] = ModelInfo(
        id: _models[id]!.id,
        name: _models[id]!.name,
        size: _models[id]!.size,
        isLoaded: false,
      );
    }
    _currentModel = null;
  }
  
  bool get hasLoadedModel => _models.values.any((m) => m.isLoaded);
}

void main() {
  group('L1-03 本地模型服务测试', () {
    
    test('测试1：注册模型', () {
      final service = LocalModelService();
      service.registerModel('gpt2', 'GPT-2', '1.5GB');
      
      expect(service.availableModels.length, 1);
      expect(service.getModelInfo('gpt2')?.name, 'GPT-2');
    });
    
    test('测试2：加载模型', () async {
      final service = LocalModelService();
      service.registerModel('gpt2', 'GPT-2', '1.5GB');
      
      final success = await service.loadModel('gpt2');
      expect(success, true);
      expect(service.isModelLoaded('gpt2'), true);
    });
    
    test('测试3：卸载模型', () async {
      final service = LocalModelService();
      service.registerModel('gpt2', 'GPT-2', '1.5GB');
      await service.loadModel('gpt2');
      
      await service.unloadModel('gpt2');
      expect(service.isModelLoaded('gpt2'), false);
    });
    
    test('测试4：当前模型', () async {
      final service = LocalModelService();
      service.registerModel('gpt2', 'GPT-2', '1.5GB');
      await service.loadModel('gpt2');
      
      expect(service.currentModel, 'gpt2');
    });
    
    test('测试5：加载不存在的模型', () async {
      final service = LocalModelService();
      final success = await service.loadModel('nonexistent');
      expect(success, false);
    });
    
    test('测试6：卸载所有模型', () async {
      final service = LocalModelService();
      service.registerModel('gpt2', 'GPT-2', '1.5GB');
      service.registerModel('llama', 'LLaMA', '3GB');
      await service.loadModel('gpt2');
      await service.loadModel('llama');
      
      service.unloadAll();
      expect(service.hasLoadedModel, false);
      expect(service.currentModel, isNull);
    });
    
    test('测试7：多个模型', () {
      final service = LocalModelService();
      service.registerModel('gpt2', 'GPT-2', '1.5GB');
      service.registerModel('llama', 'LLaMA', '3GB');
      service.registerModel('bloom', 'BLOOM', '5GB');
      
      expect(service.availableModels.length, 3);
    });
    
    test('测试8：模型大小', () {
      final service = LocalModelService();
      service.registerModel('gpt2', 'GPT-2', '1.5GB');
      
      expect(service.getModelInfo('gpt2')?.size, '1.5GB');
    });
    
    test('测试9：模型信息', () {
      final info = ModelInfo(id: 'test', name: 'Test', size: '100MB');
      expect(info.isLoaded, false);
    });
    
    test('测试10：重复注册', () {
      final service = LocalModelService();
      service.registerModel('gpt2', 'GPT-2', '1.5GB');
      service.registerModel('gpt2', 'GPT-2-Dup', '2GB');
      
      expect(service.availableModels.length, 1);
      expect(service.getModelInfo('gpt2')?.size, '2GB');
    });
  });
}