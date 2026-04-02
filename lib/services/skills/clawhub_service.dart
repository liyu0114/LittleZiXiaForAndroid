// ClawHub 服务
//
// 对接 ClawHub 技能市场

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// ClawHub 技能信息
class ClawHubSkill {
  final String slug;
  final String name;
  final String description;
  final String? version;
  final double? score;
  final String? homepage;
  final List<String> tags;
  final bool mobileFriendly;
  final int? downloads;
  final int? stars;

  ClawHubSkill({
    required this.slug,
    required this.name,
    required this.description,
    this.version,
    this.score,
    this.homepage,
    this.tags = const [],
    this.mobileFriendly = false,
    this.downloads,
    this.stars,
  });

  factory ClawHubSkill.fromJson(Map<String, dynamic> json) {
    return ClawHubSkill(
      slug: json['slug'] ?? json['name'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      version: json['version'],
      score: (json['score'] as num?)?.toDouble(),
      homepage: json['homepage'],
      tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
      mobileFriendly: json['mobileFriendly'] ?? 
                      json['mobile_friendly'] ?? 
                      _checkMobileFriendly(json),
      downloads: json['downloads'],
      stars: json['stars'],
    );
  }
  
  // 根据标签和描述判断是否移动端友好
  static bool _checkMobileFriendly(Map<String, dynamic> json) {
    final desc = (json['description'] ?? '').toString().toLowerCase();
    final tags = (json['tags'] as List?)?.map((e) => e.toString().toLowerCase()) ?? <String>[];
    
    // 包含这些关键词的技能通常是移动端友好的
    final mobileKeywords = ['api', 'http', 'rest', 'weather', 'time', 'calendar', 
                            'translate', 'search', 'query', 'fetch'];
    
    // 排除移动端不友好的关键词
    final desktopOnly = ['bash', 'shell', 'cli', 'terminal', 'desktop', 
                         'macos', 'linux', 'executable', 'binary'];
    
    // 检查是否包含移动端友好关键词
    for (final keyword in mobileKeywords) {
      if (desc.contains(keyword) || tags.any((t) => t.contains(keyword))) {
        // 但如果也包含桌面关键词，则不是移动端友好
        for (final dk in desktopOnly) {
          if (desc.contains(dk) || tags.any((t) => t.contains(dk))) {
            return false;
          }
        }
        return true;
      }
    }
    
    // 默认认为不友好，需要人工判断
    return false;
  }

  Map<String, dynamic> toJson() => {
    'slug': slug,
    'name': name,
    'description': description,
    'version': version,
    'score': score,
    'homepage': homepage,
    'tags': tags,
    'mobileFriendly': mobileFriendly,
    'downloads': downloads,
    'stars': stars,
  };
}

/// ClawHub 服务
class ClawHubService extends ChangeNotifier {
  static final ClawHubService _instance = ClawHubService._internal();
  factory ClawHubService() => _instance;
  ClawHubService._internal();

  // Gateway 配置
  String? _gatewayUrl;
  String? _gatewayToken;
  
  // 缓存
  List<ClawHubSkill> _cachedSkills = [];
  DateTime? _cacheTime;
  static const Duration _cacheExpiry = Duration(hours: 6);
  
  // 状态
  bool _isSearching = false;
  String? _lastError;
  
  // Getters
  List<ClawHubSkill> get cachedSkills => _cachedSkills;
  bool get isSearching => _isSearching;
  String? get lastError => _lastError;
  bool get hasValidCache => _cacheTime != null && 
      DateTime.now().difference(_cacheTime!) < _cacheExpiry;
  
  /// 设置 Gateway 配置
  void setGateway(String url, {String? token}) {
    _gatewayUrl = url;
    _gatewayToken = token;
  }

  /// 搜索技能
  Future<List<ClawHubSkill>> search(String query, {int limit = 20}) async {
    _isSearching = true;
    _lastError = null;
    notifyListeners();
    
    try {
      // 方案1: 通过 Gateway 代理 clawhub 命令
      if (_gatewayUrl != null) {
        final results = await _searchViaGateway(query, limit: limit);
        if (results.isNotEmpty) {
          _isSearching = false;
          notifyListeners();
          return results;
        }
      }
      
      // 方案2: 使用内置推荐列表（带搜索）
      final results = _searchLocal(query, limit: limit);
      
      _isSearching = false;
      notifyListeners();
      return results;
      
    } catch (e) {
      _lastError = e.toString();
      _isSearching = false;
      notifyListeners();
      return [];
    }
  }

  /// 通过 Gateway 代理搜索
  Future<List<ClawHubSkill>> _searchViaGateway(String query, {int limit = 20}) async {
    if (_gatewayUrl == null) return [];
    
    try {
      final response = await http.post(
        Uri.parse('$_gatewayUrl/api/clawhub/search'),
        headers: {
          'Content-Type': 'application/json',
          if (_gatewayToken != null) 'Authorization': 'Bearer $_gatewayToken',
        },
        body: json.encode({
          'query': query,
          'limit': limit,
        }),
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final List<dynamic> skills = data['skills'] ?? data;
        
        return skills.map((s) => ClawHubSkill.fromJson(s)).toList();
      }
    } catch (e) {
      debugPrint('[ClawHubService] Gateway 搜索失败: $e');
    }
    
    return [];
  }

  /// 本地搜索（从推荐列表）
  List<ClawHubSkill> _searchLocal(String query, {int limit = 20}) {
    final queryLower = query.toLowerCase();
    
    // 获取推荐列表
    final recommendations = _getRecommendedSkills();
    
    // 搜索匹配
    final matches = recommendations.where((skill) {
      return skill.name.toLowerCase().contains(queryLower) ||
             skill.description.toLowerCase().contains(queryLower) ||
             skill.tags.any((t) => t.toLowerCase().contains(queryLower));
    }).toList();
    
    // 按相关性排序
    matches.sort((a, b) {
      // 名称完全匹配优先
      final aNameMatch = a.name.toLowerCase() == queryLower ? 0 : 1;
      final bNameMatch = b.name.toLowerCase() == queryLower ? 0 : 1;
      if (aNameMatch != bNameMatch) return aNameMatch - bNameMatch;
      
      // 名称包含匹配
      final aNameContains = a.name.toLowerCase().contains(queryLower) ? 0 : 1;
      final bNameContains = b.name.toLowerCase().contains(queryLower) ? 0 : 1;
      if (aNameContains != bNameContains) return aNameContains - bNameContains;
      
      // 然后按下载量排序
      return (b.downloads ?? 0) - (a.downloads ?? 0);
    });
    
    return matches.take(limit).toList();
  }

  /// 获取推荐技能列表（移动端友好）
  List<ClawHubSkill> _getRecommendedSkills() {
    // 如果缓存有效，使用缓存
    if (hasValidCache && _cachedSkills.isNotEmpty) {
      return _cachedSkills;
    }
    
    // 内置推荐技能列表（移动端友好）
    return [
      // === 实用工具类 ===
      ClawHubSkill(
        slug: 'weather',
        name: 'Weather',
        description: 'Get current weather and forecasts via wttr.in or Open-Meteo. Use when user asks about weather, temperature, or forecasts for any location.',
        tags: ['weather', 'api', 'http'],
        mobileFriendly: true,
        downloads: 5000,
      ),
      ClawHubSkill(
        slug: 'qrcode',
        name: 'QR Code Generator',
        description: 'Generate QR codes from text or URLs using public APIs.',
        tags: ['qrcode', 'generator', 'api'],
        mobileFriendly: true,
        downloads: 3000,
      ),
      ClawHubSkill(
        slug: 'ip-lookup',
        name: 'IP Lookup',
        description: 'Query IP address geolocation information.',
        tags: ['ip', 'geo', 'location', 'api'],
        mobileFriendly: true,
        downloads: 2000,
      ),
      ClawHubSkill(
        slug: 'exchange-rate',
        name: 'Exchange Rate',
        description: 'Query real-time currency exchange rates.',
        tags: ['currency', 'finance', 'api'],
        mobileFriendly: true,
        downloads: 2500,
      ),
      ClawHubSkill(
        slug: 'translate',
        name: 'Translate',
        description: 'Translate text between languages using free translation APIs.',
        tags: ['translate', 'language', 'api'],
        mobileFriendly: true,
        downloads: 4000,
      ),
      ClawHubSkill(
        slug: 'calculator',
        name: 'Calculator',
        description: 'Perform mathematical calculations and conversions.',
        tags: ['math', 'calculator', 'utility'],
        mobileFriendly: true,
        downloads: 3500,
      ),
      ClawHubSkill(
        slug: 'unit-converter',
        name: 'Unit Converter',
        description: 'Convert between different units of measurement.',
        tags: ['unit', 'convert', 'measurement'],
        mobileFriendly: true,
        downloads: 1500,
      ),
      ClawHubSkill(
        slug: 'timezone',
        name: 'Timezone',
        description: 'Convert time between different timezones.',
        tags: ['time', 'timezone', 'utility'],
        mobileFriendly: true,
        downloads: 1800,
      ),
      
      // === 信息查询类 ===
      ClawHubSkill(
        slug: 'wikipedia',
        name: 'Wikipedia Search',
        description: 'Search and summarize Wikipedia articles.',
        tags: ['wikipedia', 'search', 'knowledge'],
        mobileFriendly: true,
        downloads: 2800,
      ),
      ClawHubSkill(
        slug: 'dictionary',
        name: 'Dictionary',
        description: 'Look up word definitions and synonyms.',
        tags: ['dictionary', 'words', 'language'],
        mobileFriendly: true,
        downloads: 2200,
      ),
      ClawHubSkill(
        slug: 'news',
        name: 'News Headlines',
        description: 'Get latest news headlines from various sources.',
        tags: ['news', 'headlines', 'api'],
        mobileFriendly: true,
        downloads: 2000,
      ),
      ClawHubSkill(
        slug: 'quote',
        name: 'Daily Quote',
        description: 'Get inspirational quotes and proverbs.',
        tags: ['quote', 'inspiration', 'api'],
        mobileFriendly: true,
        downloads: 1200,
      ),
      
      // === 娱乐类 ===
      ClawHubSkill(
        slug: 'joke',
        name: 'Jokes',
        description: 'Get random jokes to lighten the mood.',
        tags: ['joke', 'fun', 'entertainment'],
        mobileFriendly: true,
        downloads: 3000,
      ),
      ClawHubSkill(
        slug: 'cat-facts',
        name: 'Cat Facts',
        description: 'Get interesting facts about cats.',
        tags: ['cat', 'facts', 'fun'],
        mobileFriendly: true,
        downloads: 1800,
      ),
      ClawHubSkill(
        slug: 'dog-images',
        name: 'Dog Images',
        description: 'Get random cute dog images.',
        tags: ['dog', 'image', 'fun'],
        mobileFriendly: true,
        downloads: 2500,
      ),
      ClawHubSkill(
        slug: 'random-fact',
        name: 'Random Facts',
        description: 'Get random interesting facts.',
        tags: ['fact', 'trivia', 'knowledge'],
        mobileFriendly: true,
        downloads: 1500,
      ),
      
      // === 生产力类 ===
      ClawHubSkill(
        slug: 'pomodoro',
        name: 'Pomodoro Timer',
        description: 'Focus timer for productivity using Pomodoro technique.',
        tags: ['pomodoro', 'timer', 'productivity'],
        mobileFriendly: true,
        downloads: 2200,
      ),
      ClawHubSkill(
        slug: 'reminder',
        name: 'Reminder',
        description: 'Set reminders for tasks and events.',
        tags: ['reminder', 'task', 'productivity'],
        mobileFriendly: true,
        downloads: 1800,
      ),
      ClawHubSkill(
        slug: 'note',
        name: 'Quick Note',
        description: 'Create and manage quick notes.',
        tags: ['note', 'memo', 'productivity'],
        mobileFriendly: true,
        downloads: 2000,
      ),
    ];
  }

  /// 获取热门技能
  Future<List<ClawHubSkill>> getPopularSkills({int limit = 20}) async {
    final skills = _getRecommendedSkills();
    skills.sort((a, b) => (b.downloads ?? 0) - (a.downloads ?? 0));
    return skills.take(limit).toList();
  }

  /// 获取技能详情（包含 SKILL.md）
  Future<String?> getSkillContent(String slug) async {
    // 通过 Gateway 获取
    if (_gatewayUrl != null) {
      try {
        final response = await http.get(
          Uri.parse('$_gatewayUrl/api/clawhub/skill/$slug'),
          headers: {
            if (_gatewayToken != null) 'Authorization': 'Bearer $_gatewayToken',
          },
        ).timeout(const Duration(seconds: 15));
        
        if (response.statusCode == 200) {
          final data = json.decode(utf8.decode(response.bodyBytes));
          return data['content'] ?? data['body'];
        }
      } catch (e) {
        debugPrint('[ClawHubService] 获取技能内容失败: $e');
      }
    }
    
    // 返回本地生成的内容
    return _generateLocalSkillContent(slug);
  }

  /// 生成本地技能内容
  String? _generateLocalSkillContent(String slug) {
    final skills = _getRecommendedSkills();
    final skill = skills.firstWhere(
      (s) => s.slug == slug,
      orElse: () => throw StateError('Skill not found'),
    );
    
    // 根据技能类型生成 SKILL.md 内容
    switch (slug) {
      case 'weather':
        return '''---
name: weather
description: ${skill.description}
---

# Weather

Get current weather info.

## Current Weather

```http
GET https://wttr.in/{location}?format=3
```

## Parameters

- `location`: City name (e.g., "Beijing", "Nanning")
''';

      case 'qrcode':
        return '''---
name: qrcode
description: ${skill.description}
---

# QR Code Generator

Generate QR codes from text or URLs.

## Generate QR Code

```http
GET https://api.qrserver.com/v1/create-qr-code/?size=300x300&data={content}
```

## Parameters

- `content`: Text or URL to encode
- `size`: Image size (default: 300x300)
''';

      case 'ip-lookup':
        return '''---
name: ip-lookup
description: ${skill.description}
---

# IP Lookup

Query IP address geolocation information.

## Lookup IP

```http
GET http://ip-api.com/json/{ip}
```

## Parameters

- `ip`: IP address to lookup (omit for current IP)
''';

      case 'exchange-rate':
        return '''---
name: exchange-rate
description: ${skill.description}
---

# Exchange Rate

Query real-time currency exchange rates.

## Get Rates

```http
GET https://api.exchangerate.host/latest?base={from}&symbols={to}
```

## Parameters

- `from`: Base currency code (e.g., USD, EUR, CNY)
- `to`: Target currency code
''';

      case 'translate':
        return '''---
name: translate
description: ${skill.description}
---

# Translate

Translate text between languages.

## Translate Text

```http
GET https://api.mymemory.translated.net/get?q={text}&langpair={from}|{to}
```

## Parameters

- `text`: Text to translate
- `from`: Source language code (e.g., en, zh, ja)
- `to`: Target language code
''';

      case 'joke':
        return '''---
name: joke
description: ${skill.description}
---

# Jokes

Get random jokes.

## Random Joke

```http
GET https://official-joke-api.appspot.com/random_joke
```

## Programming Jokes

```http
GET https://official-joke-api.appspot.com/jokes/programming/random
```
''';

      case 'quote':
        return '''---
name: quote
description: ${skill.description}
---

# Daily Quote

Get inspirational quotes.

## Random Quote

```http
GET https://api.quotable.io/random
```

## Quote by Author

```http
GET https://api.quotable.io/random?author={author}
```
''';

      case 'cat-facts':
        return '''---
name: cat-facts
description: ${skill.description}
---

# Cat Facts

Get interesting facts about cats.

## Random Cat Fact

```http
GET https://catfact.ninja/fact
```
''';

      case 'dog-images':
        return '''---
name: dog-images
description: ${skill.description}
---

# Dog Images

Get random cute dog images.

## Random Dog Image

```http
GET https://dog.ceo/api/breeds/image/random
```

## By Breed

```http
GET https://dog.ceo/api/breed/{breed}/images/random
```
''';

      case 'calculator':
        return '''---
name: calculator
description: ${skill.description}
---

# Calculator

Perform mathematical calculations.

## Basic Expression

Calculate math expressions safely.

Supported operations: +, -, *, /, %, **, sqrt, sin, cos, tan, log

## Examples

- "What is 123 * 456?"
- "Calculate sqrt(144)"
- "What is 15% of 200?"
''';

      default:
        return '''---
name: ${skill.name}
description: ${skill.description}
---

# ${skill.name}

${skill.description}

## Usage

This skill can be used to enhance your assistant's capabilities.
''';
    }
  }

  /// 刷新缓存
  Future<void> refreshCache() async {
    _cacheTime = null;
    _cachedSkills = [];
    
    // 尝试从 Gateway 获取最新列表
    if (_gatewayUrl != null) {
      try {
        final response = await http.get(
          Uri.parse('$_gatewayUrl/api/clawhub/skills'),
          headers: {
            if (_gatewayToken != null) 'Authorization': 'Bearer $_gatewayToken',
          },
        ).timeout(const Duration(seconds: 15));
        
        if (response.statusCode == 200) {
          final data = json.decode(utf8.decode(response.bodyBytes));
          final List<dynamic> skills = data['skills'] ?? data;
          
          _cachedSkills = skills.map((s) => ClawHubSkill.fromJson(s)).toList();
          _cacheTime = DateTime.now();
          
          // 持久化缓存
          await _saveCache();
        }
      } catch (e) {
        debugPrint('[ClawHubService] 刷新缓存失败: $e');
      }
    }
    
    notifyListeners();
  }

  /// 保存缓存到本地
  Future<void> _saveCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'time': _cacheTime?.toIso8601String(),
        'skills': _cachedSkills.map((s) => s.toJson()).toList(),
      };
      await prefs.setString('clawhub_cache', json.encode(data));
    } catch (e) {
      debugPrint('[ClawHubService] 保存缓存失败: $e');
    }
  }

  /// 加载缓存
  Future<void> loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('clawhub_cache');
      
      if (jsonStr != null) {
        final data = json.decode(jsonStr);
        _cacheTime = data['time'] != null 
            ? DateTime.parse(data['time']) 
            : null;
        
        final List<dynamic> skills = data['skills'] ?? [];
        _cachedSkills = skills.map((s) => ClawHubSkill.fromJson(s)).toList();
      }
    } catch (e) {
      debugPrint('[ClawHubService] 加载缓存失败: $e');
    }
  }
}
