// 增强版消息输入组件
//
// 学习微信布局：输入框更大，工具栏更紧凑

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/voice/asr_service.dart';
import '../services/file/file_picker_service.dart';

class MessageInput extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final Function(String imagePath)? onImagePicked;
  final Function(String videoPath)? onVideoPicked;
  final Function(FilePickResult fileResult)? onFilePicked;
  final Function(String text)? onVoiceInput;
  final bool enabled;

  const MessageInput({
    super.key,
    required this.controller,
    required this.onSend,
    this.onImagePicked,
    this.onVideoPicked,
    this.onFilePicked,
    this.onVoiceInput,
    this.enabled = true,
  });

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  final ImagePicker _picker = ImagePicker();
  final ASRService _asrService = ASRService();
  String? _selectedImagePath;
  String? _selectedVideoPath;
  FilePickResult? _selectedFile;
  bool _isRecording = false;
  bool _showTools = false;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final hasText = widget.controller.text.isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  void _handleSend() {
    _clearMedia();
    widget.onSend();
  }

  void _clearMedia() {
    setState(() {
      _selectedImagePath = null;
      _selectedVideoPath = null;
      _selectedFile = null;
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() {
          _selectedImagePath = image.path;
          _selectedVideoPath = null;
          _selectedFile = null;
        });
        widget.onImagePicked?.call(image.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择图像失败: $e')),
        );
      }
    }
  }

  Future<void> _pickVideo() async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: 15),
      );
      if (video != null) {
        final file = File(video.path);
        final fileSize = await file.length();
        if (fileSize > 50 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('视频文件过大')),
            );
          }
          return;
        }
        setState(() {
          _selectedVideoPath = video.path;
          _selectedImagePath = null;
          _selectedFile = null;
        });
        widget.onVideoPicked?.call(video.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择视频失败: $e')),
        );
      }
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePickerService.pickFile();
      if (result != null) {
        if (result.size > 50 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('文件过大')),
            );
          }
          return;
        }
        setState(() {
          _selectedFile = result;
          _selectedImagePath = null;
          _selectedVideoPath = null;
        });
        widget.onFilePicked?.call(result);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择文件失败: $e')),
        );
      }
    }
  }

  Future<void> _startVoiceInput() async {
    if (!_asrService.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('语音识别未初始化')),
      );
      return;
    }
    setState(() => _isRecording = true);
    final result = await _asrService.listen();
    setState(() => _isRecording = false);
    if (result != null && result.isNotEmpty) {
      widget.controller.text = result;
      widget.onVoiceInput?.call(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 8,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 媒体预览
          if (_selectedImagePath != null || _selectedVideoPath != null || _selectedFile != null)
            Container(
              height: 80,
              margin: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _buildMediaPreview(),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: _clearMedia,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.close, color: Colors.white, size: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          
          // 工具栏（点击展开）
          if (_showTools)
            Container(
              height: 90,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildToolButton(Icons.photo_library, '相册', () {
                    setState(() => _showTools = false);
                    _pickImage(ImageSource.gallery);
                  }),
                  _buildToolButton(Icons.camera_alt, '拍照', () {
                    setState(() => _showTools = false);
                    _pickImage(ImageSource.camera);
                  }),
                  _buildToolButton(Icons.videocam, '视频', () {
                    setState(() => _showTools = false);
                    _pickVideo();
                  }),
                  _buildToolButton(Icons.attach_file, '文件', () {
                    setState(() => _showTools = false);
                    _pickFile();
                  }),
                ],
              ),
            ),
          
          // 主输入行（微信风格）
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // 语音按钮
              IconButton(
                icon: Icon(
                  _isRecording ? Icons.mic : Icons.mic_none,
                  color: _isRecording
                      ? Colors.red
                      : (widget.enabled ? Theme.of(context).colorScheme.primary : Colors.grey),
                ),
                onPressed: widget.enabled && !_isRecording ? _startVoiceInput : null,
              ),
              
              // 输入框（扩大）
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(minHeight: 40, maxHeight: 120),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: TextField(
                    controller: widget.controller,
                    enabled: widget.enabled,
                    maxLines: 5,
                    minLines: 1,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: widget.enabled ? '输入消息...' : '请等待...',
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      isDense: true,
                    ),
                  ),
                ),
              ),
              
              // 表情/更多按钮
              IconButton(
                icon: Icon(
                  _hasText ? Icons.send : (_showTools ? Icons.keyboard : Icons.add_circle_outline),
                  color: _hasText
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outline,
                ),
                onPressed: _hasText
                    ? (widget.enabled ? _handleSend : null)
                    : () => setState(() => _showTools = !_showTools),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMediaPreview() {
    if (_selectedFile != null) {
      return Container(
        width: 80,
        height: 80,
        color: Colors.grey.shade200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_selectedFile!.icon, style: const TextStyle(fontSize: 24)),
              const SizedBox(height: 4),
              Text(
                _selectedFile!.extension.toUpperCase(),
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    }
    if (_selectedVideoPath != null) {
      return Container(
        width: 80,
        height: 80,
        color: Colors.grey.shade300,
        child: const Center(child: Icon(Icons.videocam, size: 32, color: Colors.grey)),
      );
    }
    if (_selectedImagePath != null) {
      return Image.file(File(_selectedImagePath!), width: 80, height: 80, fit: BoxFit.cover);
    }
    return const SizedBox.shrink();
  }

  Widget _buildToolButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }
}
