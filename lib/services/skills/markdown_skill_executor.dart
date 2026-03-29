// Markdown Skill 执行器
//
// 执行从 SKILL.md 解析出的指令

import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'skill_instruction.dart';
import 'markdown_skill_parser.dart';
import '../native/location_service.dart';
import '../native/notification_service.dart';
import '../native/shell_service.dart';

/// Skill 执行结果
class SkillExecutionResult {
  final bool success;
  final String output;
  final String? error;

  SkillExecutionResult({
    required this.success,
    required this.output,
    this.error,
  });

  factory SkillExecutionResult.success(String output) {
    return SkillExecutionResult(success: true, output: output);
  }

  factory SkillExecutionResult.error(String error) {
    return SkillExecutionResult(success: false, output: '', error: error);
  }

  @override
  String toString() => success ? output : 'Error: $error';
}

/// Markdown Skill 执行器
class MarkdownSkillExecutor {
  final LocationService? locationService;
  final NotificationService? notificationService;
  final ShellService? shellService;
  final Map<String, dynamic> context;

  MarkdownSkillExecutor({
    this.locationService,
    this.notificationService,
    this.shellService,
    this.context = const {},
  });

  /// 执行 Skill
  Future<SkillExecutionResult> execute(
    ParsedSkill skill,
    Map<String, dynamic> params,
  ) async {
    final primaryInstruction = MarkdownSkillParser.extractPrimaryInstruction(skill);
    
    if (primaryInstruction == null) {
      return SkillExecutionResult.error('没有找到可执行的指令');
    }

    try {
      // 替换参数
      final processedInstruction = _injectParams(primaryInstruction, params);

      // 根据指令类型执行
      if (processedInstruction is HttpInstruction) {
        return await _executeHttp(processedInstruction);
      } else if (processedInstruction is DartInstruction) {
        return await _executeDart(processedInstruction, params);
      } else if (processedInstruction is BashInstruction) {
        return await _executeBash(processedInstruction);
      } else {
        return SkillExecutionResult.error('不支持的指令类型: ${processedInstruction.language}');
      }
    } catch (e) {
      return SkillExecutionResult.error('执行失败: $e');
    }
  }

  /// 注入参数到指令
  SkillInstruction _injectParams(SkillInstruction instruction, Map<String, dynamic> params) {
    if (instruction is HttpInstruction) {
      String url = instruction.url;
      
      // 替换 URL 中的参数
      params.forEach((key, value) {
        url = url.replaceAll('{$key}', value.toString());
      });

      return HttpInstruction(
        method: instruction.method,
        url: url,
        headers: instruction.headers,
        body: instruction.body,
      );
    }
    
    return instruction;
  }

  /// 执行 HTTP 指令
  Future<SkillExecutionResult> _executeHttp(HttpInstruction instruction) async {
    try {
      debugPrint('[SkillExecutor] 执行 HTTP 请求: ${instruction.method} ${instruction.url}');

      http.Response response;
      
      switch (instruction.method.toUpperCase()) {
        case 'GET':
          response = await http.get(
            Uri.parse(instruction.url),
            headers: instruction.headers,
          );
          break;
        
        case 'POST':
          response = await http.post(
            Uri.parse(instruction.url),
            headers: instruction.headers,
            body: instruction.body,
          );
          break;
        
        case 'PUT':
          response = await http.put(
            Uri.parse(instruction.url),
            headers: instruction.headers,
            body: instruction.body,
          );
          break;
        
        case 'DELETE':
          response = await http.delete(
            Uri.parse(instruction.url),
            headers: instruction.headers,
          );
          break;
        
        default:
          return SkillExecutionResult.error('不支持的 HTTP 方法: ${instruction.method}');
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return SkillExecutionResult.success(response.body);
      } else {
        return SkillExecutionResult.error('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      return SkillExecutionResult.error('HTTP 请求失败: $e');
    }
  }

  /// 执行 Dart 指令（移动端特有）
  Future<SkillExecutionResult> _executeDart(
    DartInstruction instruction,
    Map<String, dynamic> params,
  ) async {
    try {
      debugPrint('[SkillExecutor] 执行 Dart 代码');

      final code = instruction.code.trim();
      
      // ==================== 位置服务相关 ====================
      
      // local_weather - 基于位置查询天气
      if (code.contains('api.open-meteo.com') && locationService != null) {
        final position = await locationService!.getCurrentPosition();
        if (position == null) {
          return SkillExecutionResult.error('无法获取位置，请授予位置权限');
        }

        try {
          final response = await http.get(
            Uri.parse('https://api.open-meteo.com/v1/forecast?'
                'latitude=${position.latitude}&longitude=${position.longitude}'
                '&current=temperature_2m,weather_code,wind_speed_10m&timezone=auto'),
          );

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            final current = data['current'];
            final temp = current['temperature_2m'];
            final weatherCode = current['weather_code'];
            final windSpeed = current['wind_speed_10m'];
            
            // 天气代码转描述
            final weatherDesc = _weatherCodeToDescription(weatherCode);
            
            return SkillExecutionResult.success(
              '🌤️ ${weatherDesc}\n'
              '🌡️ 温度: ${temp}°C\n'
              '💨 风速: ${windSpeed} km/h\n'
              '📍 位置: ${position.latitude.toStringAsFixed(4)}°, ${position.longitude.toStringAsFixed(4)}°',
            );
          } else {
            return SkillExecutionResult.error('天气查询失败: HTTP ${response.statusCode}');
          }
        } catch (e) {
          return SkillExecutionResult.error('天气查询失败: $e');
        }
      }
      
      // current_location - 获取当前位置
      if (code.contains('Geolocator.getCurrentPosition') && 
          !code.contains('api.open-meteo') && 
          locationService != null) {
        final position = await locationService!.getCurrentPosition();
        if (position == null) {
          return SkillExecutionResult.error('无法获取位置，请授予位置权限');
        }

        return SkillExecutionResult.success(
          '📍 当前位置\n'
          '纬度: ${position.latitude.toStringAsFixed(6)}°\n'
          '经度: ${position.longitude.toStringAsFixed(6)}°\n'
          '海拔: ${position.altitude.toStringAsFixed(2)} 米\n'
          '精度: ${position.accuracy.toStringAsFixed(2)} 米\n'
          '时间: ${DateTime.now().toString().substring(0, 19)}',
        );
      }
      
      // distance_to - 计算距离
      if (code.contains('Geolocator.distanceBetween') && locationService != null) {
        final position = await locationService!.getCurrentPosition();
        if (position == null) {
          return SkillExecutionResult.error('无法获取位置，请授予位置权限');
        }

        final targetLat = params['latitude'] as double?;
        final targetLng = params['longitude'] as double?;
        final targetName = params['name']?.toString() ?? '目标地点';

        if (targetLat == null || targetLng == null) {
          return SkillExecutionResult.error(
            '⚠️ 请提供目标地点坐标\n'
            '示例：latitude=39.9042, longitude=116.4074, name=北京',
          );
        }

        final distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          targetLat,
          targetLng,
        );

        String distanceStr;
        if (distance < 1000) {
          distanceStr = '${distance.toStringAsFixed(0)} 米';
        } else {
          distanceStr = '${(distance / 1000).toStringAsFixed(2)} 公里';
        }

        return SkillExecutionResult.success(
          '📍 距离计算\n\n'
          '您的位置: ${position.latitude.toStringAsFixed(4)}°, ${position.longitude.toStringAsFixed(4)}°\n'
          '目标地点: $targetName\n\n'
          '直线距离: $distanceStr',
        );
      }
      
      // nearby_restaurants/gas_stations/hospitals - 附近搜索
      if (code.contains('搜索附近') && locationService != null) {
        final position = await locationService!.getCurrentPosition();
        if (position == null) {
          return SkillExecutionResult.error('无法获取位置，请授予位置权限');
        }

        final radius = params['radius'] ?? 1000;
        String searchType = '设施';
        
        if (code.contains('餐厅') || code.contains('美食')) {
          searchType = '餐厅';
        } else if (code.contains('加油站')) {
          searchType = '加油站';
        } else if (code.contains('医院') || code.contains('药店')) {
          searchType = '医院/药店';
        }

        return SkillExecutionResult.success(
          '🔍 正在搜索附近$searchType...\n\n'
          '您的位置:\n'
          '- 纬度: ${position.latitude.toStringAsFixed(6)}°\n'
          '- 经度: ${position.longitude.toStringAsFixed(6)}°\n'
          '- 搜索范围: ${radius}米\n\n'
          '⚠️ 需要地图 API 支持（高德/百度地图）',
        );
      }
      
      // ==================== 通知服务 ====================
      
      if (code.contains('NotificationService') && notificationService != null) {
        final title = params['title']?.toString() ?? '小紫霞通知';
        final body = params['body']?.toString() ?? '';
        
        await notificationService!.show(title: title, body: body);
        return SkillExecutionResult.success('✅ 已发送通知');
      }

      // ==================== 默认 ====================
      
      return SkillExecutionResult.error(
        '⚠️ Dart 代码需要具体实现:\n```dart\n$code\n```',
      );
    } catch (e) {
      return SkillExecutionResult.error('Dart 执行失败: $e');
    }
  }

  /// 天气代码转描述
  String _weatherCodeToDescription(int code) {
    if (code == 0) return '晴朗 ☀️';
    if (code <= 3) return '多云 ⛅';
    if (code <= 49) return '雾 🌫️';
    if (code <= 59) return '毛毛雨 🌧️';
    if (code <= 69) return '雨 🌧️';
    if (code <= 79) return '雪 🌨️';
    if (code <= 99) return '雷暴 ⛈️';
    return '未知';
  }

  /// 执行 Bash 指令（有限支持）
  Future<SkillExecutionResult> _executeBash(BashInstruction instruction) async {
    try {
      debugPrint('[SkillExecutor] 执行 Bash 命令');

      // 移动端：大部分 bash 不可用
      // 只支持一些简单命令
      final code = instruction.code.trim();
      
      // 简单命令白名单
      if (code.startsWith('echo ')) {
        final output = code.substring(5).replaceAll('"', '').replaceAll("'", '');
        return SkillExecutionResult.success(output);
      }
      
      if (code == 'date') {
        return SkillExecutionResult.success(DateTime.now().toString());
      }

      // 需要使用 ShellService（需要 ADB 授权）
      if (shellService != null && shellService!.adbAuthorized) {
        // 解析命令和参数
        final parts = code.split(' ');
        final command = parts.first;
        final args = parts.skip(1).toList();
        
        final result = await shellService!.execute(command, args: args);
        
        if (result.success) {
          return SkillExecutionResult.success(result.output);
        } else {
          return SkillExecutionResult.error(result.error);
        }
      }

      return SkillExecutionResult.error(
        '⚠️ Bash 命令需要 ADB 授权\n'
        '命令: $code',
      );
    } catch (e) {
      return SkillExecutionResult.error('Bash 执行失败: $e');
    }
  }
}
