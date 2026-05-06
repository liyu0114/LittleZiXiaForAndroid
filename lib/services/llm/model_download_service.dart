// 模型下载服务
// 支持从 HuggingFace/Ollama 下载 GGUF 模型

import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

/// 模型信息（带下载链接）
class DownloadableModel {
  final String id;
  final String name;
  final String description;
  final String downloadUrl;
  final int sizeMB;
  final int contextLength;
  final String source;

  DownloadableModel({
    required this.id,
    required this.name,
    required this.description,
    required this.downloadUrl,
    required this.sizeMB,
    this.contextLength = 4096,
    this.source = 'huggingface',
  });
}

/// 模型下载管理器
class ModelDownloadManager {
  static final List<DownloadableModel> availableModels = [
    // Qwen3 系列 (推荐手机)
    DownloadableModel(
      id: 'qwen3-0.6b',
      name: 'Qwen3 0.6B',
      description: '最小模型，适合低端手机',
      downloadUrl: 'https://huggingface.co/Qwen/Qwen3-0.6B-GGUF/resolve/main/qwen3-0.6b-q4_k_m.gguf',
      sizeMB: 470,
      contextLength: 32000,
      source: 'huggingface',
    ),
    DownloadableModel(
      id: 'qwen3-1.7b',
      name: 'Qwen3 1.7B',
      description: '平衡性能和内存',
      downloadUrl: 'https://huggingface.co/Qwen/Qwen3-1.7B-GGUF/resolve/main/qwen3-1.7b-q4_k_m.gguf',
      sizeMB: 970,
      contextLength: 32000,
      source: 'huggingface',
    ),
    DownloadableModel(
      id: 'qwen3-4b',
      name: 'Qwen3 4B',
      description: '高性能，需要大内存',
      downloadUrl: 'https://huggingface.co/Qwen/Qwen3-4B-GGUF/resolve/main/qwen3-4b-q4_k_m.gguf',
      sizeMB: 2700,
      contextLength: 128000,
      source: 'huggingface',
    ),
    // Phi 系列
    DownloadableModel(
      id: 'phi3-mini',
      name: 'Phi-3-mini',
      description: '微软小模型',
      downloadUrl: 'https://huggingface.co/microsoft/Phi-3-mini-4k-instruct-gguf/resolve/main/Phi-3-mini-4k-instruct-q4_k_m.gguf',
      sizeMB: 700,
      contextLength: 4000,
      source: 'huggingface',
    ),
    // Llama3
    DownloadableModel(
      id: 'llama3-2b',
      name: 'Llama3 2B',
      description: 'Meta 小模型',
      downloadUrl: 'https://huggingface.co/UnsandboxAI/Llama-3-2B-Instruct-M2-GGUF/resolve/main/Llama-3-2B-Instruct-M2-Q4_K_M.gguf',
      sizeMB: 1400,
      contextLength: 8000,
      source: 'huggingface',
    ),
  ];

  /// 获取可用模型列表
  static List<DownloadableModel> getModels() => availableModels;

  /// 按内存筛选
  static List<DownloadableModel> getModelsForMemory(int maxMemoryMB) {
    return availableModels.where((m) => m.sizeMB <= maxMemoryMB).toList();
  }

  /// 下载模型
  static Stream<DownloadProgress> downloadModel(
    DownloadableModel model,
    String savePath,
  ) async* {
    final client = http.Client();
    final request = http.Request('GET', Uri.parse(model.downloadUrl));

    try {
      final response = await client.send(request);
      final totalBytes = response.contentLength ?? model.sizeMB * 1024 * 1024;
      var receivedBytes = 0;

      final file = File(savePath);
      final sink = file.openWrite();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;

        yield DownloadProgress(
          modelId: model.id,
          downloadedBytes: receivedBytes,
          totalBytes: totalBytes,
          percent: (receivedBytes / totalBytes * 100).round(),
        );
      }

      await sink.close();
      debugPrint('[ModelDownload] 完成: ${model.name}');
    } catch (e) {
      debugPrint('[ModelDownload] 失败: $e');
      yield DownloadProgress(
        modelId: model.id,
        downloadedBytes: 0,
        totalBytes: model.sizeMB * 1024 * 1024,
        percent: -1,
        error: e.toString(),
      );
    } finally {
      client.close();
    }
  }
}

/// 下载进度
class DownloadProgress {
  final String modelId;
  final int downloadedBytes;
  final int totalBytes;
  final int percent;
  final String? error;

  DownloadProgress({
    required this.modelId,
    required this.downloadedBytes,
    required this.totalBytes,
    required this.percent,
    this.error,
  });

  bool get isComplete => percent >= 100;
  bool get hasError => percent < 0;
}