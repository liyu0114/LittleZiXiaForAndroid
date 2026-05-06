// 模型下载服务测试
import 'package:flutter_test/flutter_test.dart';

/// 测试模型信息
class TestDownloadableModel {
  final String id;
  final String name;
  final int sizeMB;
  
  TestDownloadableModel({required this.id, required this.name, required this.sizeMB});
}

/// 模拟下载管理器
class TestDownloadManager {
  final List<TestDownloadableModel> _models = [
    TestDownloadableModel(id: 'qwen3-0.6b', name: 'Qwen3 0.6B', sizeMB: 470),
    TestDownloadableModel(id: 'qwen3-1.7b', name: 'Qwen3 1.7B', sizeMB: 970),
    TestDownloadableModel(id: 'phi3-mini', name: 'Phi-3-mini', sizeMB: 700),
  ];
  
  List<TestDownloadableModel> getModels() => _models;
  
  List<TestDownloadableModel> getModelsForMemory(int maxMB) {
    return _models.where((m) => m.sizeMB <= maxMB).toList();
  }
  
  Future<int> downloadModel(String modelId) async {
    await Future.delayed(Duration(milliseconds: 100));
    return 100; // 模拟返回进度
  }
}

void main() {
  group('模型下载服务测试', () {
    
    test('获取模型列表', () {
      final manager = TestDownloadManager();
      final models = manager.getModels();
      expect(models.length, 3);
    });
    
    test('按内存筛选', () {
      final manager = TestDownloadManager();
      final models = manager.getModelsForMemory(800);
      expect(models.length, 2);
      expect(models.any((m) => m.id == 'qwen3-0.6b'), true);
    });
    
    test('下载进度', () async {
      final manager = TestDownloadManager();
      final progress = await manager.downloadModel('qwen3-0.6b');
      expect(progress, 100);
    });
    
    test('模型ID正确', () {
      final manager = TestDownloadManager();
      final models = manager.getModels();
      expect(models.first.id, 'qwen3-0.6b');
      expect(models.last.id, 'phi3-mini');
    });
    
    test('模型大小', () {
      final manager = TestDownloadManager();
      final model = manager.getModels().first;
      expect(model.sizeMB, greaterThan(0));
    });
    
    test('筛选返回空', () {
      final manager = TestDownloadManager();
      final models = manager.getModelsForMemory(10);
      expect(models.isEmpty, true);
    });
  });
}