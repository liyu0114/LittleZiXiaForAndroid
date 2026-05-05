// 代码编辑器服务
//
// 开发者工具-代码编辑

import 'dart:async';
import 'package:flutter/foundation.dart';

/// 代码文件
class CodeFile {
  final String path;
  final String content;
  final String language;
  DateTime modified;
  
  CodeFile({
    required this.path,
    required this.content,
    required this.language,
    required this.modified,
  });
}

/// 编辑器状态
enum EditorState {
  normal,
  insert,
  visual,
}

/// 代码编辑器
class CodeEditor extends ChangeNotifier {
  final Map<String, CodeFile> _files = {};
  String? _currentFile;
  EditorState _state = EditorState.normal;
  int _cursorLine = 1;
  int _cursorColumn = 1;
  
  /// 新建文件
  void newFile(String path, String language) {
    _files[path] = CodeFile(
      path: path,
      content: '',
      language: language,
      modified: DateTime.now(),
    );
    _currentFile = path;
    notifyListeners();
  }
  
  /// 打开文件
  void openFile(String path, String content, String language) {
    _files[path] = CodeFile(
      path: path,
      content: content,
      language: language,
      modified: DateTime.now(),
    );
    _currentFile = path;
    notifyListeners();
  }
  
  /// 保存文件
  void saveFile() {
    if (_currentFile != null) {
      _files[_currentFile]!.modified = DateTime.now();
    }
    notifyListeners();
  }
  
  /// 编辑内容
  void editContent(String content) {
    if (_currentFile != null) {
      _files[_currentFile] = CodeFile(
        path: _files[_currentFile]!.path,
        content: content,
        language: _files[_currentFile]!.language,
        modified: DateTime.now(),
      );
      notifyListeners();
    }
  }
  
  /// 切换模式
  void setState(EditorState state) {
    _state = state;
    notifyListeners();
  }
  
  /// 移动光标
  void moveCursor(int line, int column) {
    _cursorLine = line;
    _cursorColumn = column;
    notifyListeners();
  }
  
  /// 获取当前文件
  CodeFile? getCurrentFile() {
    if (_currentFile == null) return null;
    return _files[_currentFile];
  }
  
  /// 撤销
  void undo() {
    // TODO: 实现撤销
  }
  
  /// 重做
  void redo() {
    // TODO: 实现重做
  }
  
  /// 查找
  List<int> find(String query) {
    final file = getCurrentFile();
    if (file == null) return [];
    
    final indices = <int>[];
    var index = 0;
    while (true) {
      index = file.content.indexOf(query, index);
      if (index == -1) break;
      indices.add(index);
      index += query.length;
    }
    return indices;
  }
  
  /// 替换
  void replace(String from, String to) {
    final file = getCurrentFile();
    if (file == null) return;
    
    final newContent = file.content.replaceAll(from, to);
    editContent(newContent);
  }
}