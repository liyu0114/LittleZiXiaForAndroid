// 情感计算服务测试 - L1 单元测试
import 'package:flutter_test/flutter_test.dart';

/// 情感类型
enum EmotionType {
  joy,
  sadness,
  anger,
  fear,
  surprise,
  disgust,
  neutral,
}

/// 情感
class Emotion {
  final EmotionType type;
  final double intensity;
  
  Emotion({required this.type, required this.intensity});
  
  @override
  String toString() => '$type(${intensity.toStringAsFixed(2)})';
}

/// 情感处理器
class EmotionProcessor {
  /// 识别情感
  Emotion recognize(String text) {
    text = text.toLowerCase();
    
    if (text.contains('开心') || text.contains('高兴') || text.contains('棒')) {
      return Emotion(type: EmotionType.joy, intensity: 0.9);
    }
    if (text.contains('难过') || text.contains('伤心') || text.contains('哭')) {
      return Emotion(type: EmotionType.sadness, intensity: 0.8);
    }
    if (text.contains('生气') || text.contains('愤怒') || text.contains('讨厌')) {
      return Emotion(type: EmotionType.anger, intensity: 0.8);
    }
    if (text.contains('怕') || text.contains('害怕') || text.contains('恐惧')) {
      return Emotion(type: EmotionType.fear, intensity: 0.7);
    }
    if (text.contains('惊讶') || text.contains('意外')) {
      return Emotion(type: EmotionType.surprise, intensity: 0.6);
    }
    if (text.contains('恶心') || text.contains('吐')) {
      return Emotion(type: EmotionType.disgust, intensity: 0.7);
    }
    
    return Emotion(type: EmotionType.neutral, intensity: 0.5);
  }
  
  /// 获取情感强度标签
  String getIntensityLabel(double intensity) {
    if (intensity < 0.3) return '低';
    if (intensity < 0.7) return '中';
    return '高';
  }
  
  /// 情感是否强烈
  bool isStrong(double intensity) => intensity > 0.7;
}

void main() {
  group('L1-14 情感计算测试', () {
    
    test('测试1：识别开心', () {
      final processor = EmotionProcessor();
      final emotion = processor.recognize('今天很开心');
      
      expect(emotion.type, EmotionType.joy);
      expect(emotion.intensity, 0.9);
    });
    
    test('测试2：识别难过', () {
      final processor = EmotionProcessor();
      final emotion = processor.recognize('我很难过');
      
      expect(emotion.type, EmotionType.sadness);
    });
    
    test('测试3：识别生气', () {
      final processor = EmotionProcessor();
      final emotion = processor.recognize('我很生气');
      
      expect(emotion.type, EmotionType.anger);
    });
    
    test('测试4：识别害怕', () {
      final processor = EmotionProcessor();
      final emotion = processor.recognize('我好害怕');
      
      expect(emotion.type, EmotionType.fear);
    });
    
    test('测试5：识别惊讶', () {
      final processor = EmotionProcessor();
      final emotion = processor.recognize('好惊讶');
      
      expect(emotion.type, EmotionType.surprise);
    });
    
    test('测试6：识别恶心', () {
      final processor = EmotionProcessor();
      final emotion = processor.recognize('好恶心');
      
      expect(emotion.type, EmotionType.disgust);
    });
    
    test('测试7：默认中性', () {
      final processor = EmotionProcessor();
      final emotion = processor.recognize('你好');
      
      expect(emotion.type, EmotionType.neutral);
    });
    
    test('测试8：强度标签', () {
      final processor = EmotionProcessor();
      expect(processor.getIntensityLabel(0.2), '低');
      expect(processor.getIntensityLabel(0.5), '中');
      expect(processor.getIntensityLabel(0.8), '高');
    });
    
    test('测试9：强烈判断', () {
      final processor = EmotionProcessor();
      expect(processor.isStrong(0.8), true);
      expect(processor.isStrong(0.5), false);
    });
    
    test('测试10：多关键词', () {
      final processor = EmotionProcessor();
      final emotion = processor.recognize('今天天气很好，心情很开心');
      
      expect(emotion.type, EmotionType.joy);
    });
  });
}