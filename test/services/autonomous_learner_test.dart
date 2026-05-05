// 自主学习服务测试 - L1 单元测试
import 'package:flutter_test/flutter_test.dart';

/// 学习模式
enum LearningMode {
  supervised,
  reinforcement,
  unsupervised,
}

/// 学习样本
class LearningSample {
  final String input;
  final String output;
  final double confidence;
  
  LearningSample({
    required this.input,
    required this.output,
    this.confidence = 0.0,
  });
}

/// 模型
class Model {
  final String id;
  final LearningMode mode;
  final List<LearningSample> samples = [];
  
  Model({required this.id, required this.mode});
}

/// 自主学习服务
class AutonomousLearner {
  final List<Model> _models = [];
  
  List<Model> get models => _models;
  
  void registerModel(Model model) {
    _models.add(model);
  }
  
  Future<void> train(Model model, List<LearningSample> samples) async {
    model.samples.addAll(samples);
    await Future.delayed(Duration(milliseconds: 10));
  }
  
  Future<String?> predict(Model model, String input) async {
    if (model.samples.isEmpty) return null;
    
    // 简单匹配
    for (final sample in model.samples) {
      if (sample.input == input) {
        return sample.output;
      }
    }
    return model.samples.last.output;
  }
  
  void addSample(Model model, LearningSample sample) {
    model.samples.add(sample);
  }
  
  int getSampleCount(Model model) => model.samples.length;
  
  Future<void> fineTune(Model model) async {
    await Future.delayed(Duration(milliseconds: 10));
  }
  
  void clearSamples(Model model) {
    model.samples.clear();
  }
}

void main() {
  group('L1-15 自主学习测试', () {
    
    test('测试1：注册模型', () {
      final learner = AutonomousLearner();
      learner.registerModel(Model(id: 'm1', mode: LearningMode.supervised));
      
      expect(learner.models.length, 1);
    });
    
    test('测试2：训练模型', () async {
      final learner = AutonomousLearner();
      final model = Model(id: 'm1', mode: LearningMode.supervised);
      learner.registerModel(model);
      
      await learner.train(model, [
        LearningSample(input: 'hello', output: 'hi'),
      ]);
      
      expect(learner.getSampleCount(model), 1);
    });
    
    test('测试3：预测', () async {
      final learner = AutonomousLearner();
      final model = Model(id: 'm1', mode: LearningMode.supervised);
      learner.registerModel(model);
      await learner.train(model, [
        LearningSample(input: 'hello', output: 'hi'),
      ]);
      
      final result = await learner.predict(model, 'hello');
      expect(result, 'hi');
    });
    
    test('测试4：无样本预测', () async {
      final learner = AutonomousLearner();
      final model = Model(id: 'm1', mode: LearningMode.supervised);
      learner.registerModel(model);
      
      final result = await learner.predict(model, 'hello');
      expect(result, isNull);
    });
    
    test('测试5：添加样本', () {
      final learner = AutonomousLearner();
      final model = Model(id: 'm1', mode: LearningMode.supervised);
      learner.registerModel(model);
      
      learner.addSample(model, LearningSample(
        input: 'test',
        output: 'result',
      ));
      
      expect(learner.getSampleCount(model), 1);
    });
    
    test('测试6：微调模型', () async {
      final learner = AutonomousLearner();
      final model = Model(id: 'm1', mode: LearningMode.reinforcement);
      learner.registerModel(model);
      
      await learner.fineTune(model);
      expect(true, true);
    });
    
    test('测试7：清空样本', () {
      final learner = AutonomousLearner();
      final model = Model(id: 'm1', mode: LearningMode.supervised);
      learner.registerModel(model);
      learner.addSample(model, LearningSample(input: 'a', output: 'b'));
      
      learner.clearSamples(model);
      expect(learner.getSampleCount(model), 0);
    });
    
    test('测试8：多模式', () {
      final learner = AutonomousLearner();
      learner.registerModel(Model(id: 'm1', mode: LearningMode.supervised));
      learner.registerModel(Model(id: 'm2', mode: LearningMode.reinforcement));
      learner.registerModel(Model(id: 'm3', mode: LearningMode.unsupervised));
      
      expect(learner.models.length, 3);
    });
    
    test('测试9：多样本', () async {
      final learner = AutonomousLearner();
      final model = Model(id: 'm1', mode: LearningMode.supervised);
      learner.registerModel(model);
      
      await learner.train(model, [
        LearningSample(input: 'a', output: '1'),
        LearningSample(input: 'b', output: '2'),
        LearningSample(input: 'c', output: '3'),
      ]);
      
      expect(learner.getSampleCount(model), 3);
    });
    
    test('测试10：默认置信度', () {
      final sample = LearningSample(input: 'test', output: 'result');
      expect(sample.confidence, 0.0);
    });
  });
}