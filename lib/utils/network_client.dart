// 网络客户端配置
// 
// 自定义 HTTP 客户端，解决 Android 网络问题

import 'dart:io';
import 'package:http/io_client.dart';

class NetworkClient {
  static IOClient createClient() {
    // 创建自定义 HttpClient
    final httpClient = HttpClient();
    
    // 配置 HttpClient
    httpClient.connectionTimeout = const Duration(seconds: 15);
    httpClient.idleTimeout = const Duration(seconds: 30);
    
    // Android 特殊配置
    // 允许自签名证书（开发环境）
    httpClient.badCertificateCallback = (cert, host, port) {
      // 生产环境应该验证证书
      return false; // 拒绝自签名证书
    };
    
    return IOClient(httpClient);
  }
}
