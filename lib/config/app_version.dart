// 应用版本配置
//
// 统一管理版本号，避免不一致

class AppVersion {
  static const String version = '1.0.54';
  static const String buildNumber = '82';
  static const String fullVersion = 'v1.0.54';
  static const String buildDate = '2026-04-01';
  
  static String get displayVersion => 'v$version';
  static String get fullDisplayVersion => 'v$version+$buildNumber';
  static String get debugInfo => 'v$version+$buildNumber · $buildDate';
}
