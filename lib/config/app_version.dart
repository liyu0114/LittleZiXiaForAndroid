// 应用版本配置
//
// 统一管理版本号，避免不一致

class AppVersion {
  static const String version = '1.0.15';
  static const String buildNumber = '45';
  static const String fullVersion = 'v1.0.15';
  static const String buildDate = '2026-03-23';
  
  static String get displayVersion => 'v$version';
  static String get fullDisplayVersion => 'v$version+$buildNumber';
  static String get debugInfo => 'v$version+$buildNumber · $buildDate';
}
