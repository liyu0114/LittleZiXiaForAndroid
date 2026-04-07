// 应用版本配置
//
// 统一管理版本号，避免不一致

class AppVersion {
  static const String version = '1.0.104';
  static const String buildNumber = '122';
  static const String fullVersion = 'v1.0.104';
  static const String buildDate = '2026-04-07';
  
  static String get displayVersion => version;
  static String get fullDisplayVersion => '$version+$buildNumber';
  static String get debugInfo => '$version+$buildNumber ($buildDate)';
}
