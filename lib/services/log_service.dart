import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// 全局日志服务 — 记录所有API调用、错误、操作
/// 日志持久化到文件，只有手动调用 clear() 才会清除
class LogService {
  static final LogService _instance = LogService._();
  factory LogService() => _instance;
  LogService._();

  final List<LogEntry> _logs = [];
  static const int _maxLogs = 500;
  static const String _logFileName = 'lovegirl_debug.log';
  bool _loaded = false;

  List<LogEntry> get logs => List.unmodifiable(_logs);

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_logFileName');
      if (await file.exists()) {
        final content = await file.readAsString();
        _loadFromText(content);
      }
    } catch (e) {
      debugPrint('[LogService] 加载日志文件失败: $e');
    }
  }

  void _loadFromText(String content) {
    try {
      final lines = content.split('\n');
      for (final line in lines) {
        if (line.isEmpty ||
            line.startsWith('===') ||
            line.startsWith('Exported') ||
            line.startsWith('Total')) {
          continue;
        }
        // 格式: [HH:mm:ss.ms] [LEVEL] [TYPE] message
        if (line.startsWith('[')) {
          final parts = line.split('] ');
          if (parts.length >= 3) {
            final entry = LogEntry(
              timestamp: DateTime.now(),
              type: parts[2].trim(),
              message: parts.length > 3 ? parts.sublist(3).join('] ') : '',
              detail: '',
              level: parts[1].trim(),
            );
            _logs.add(entry);
          }
        }
      }
      if (_logs.length > _maxLogs) {
        _logs.removeRange(_maxLogs, _logs.length);
      }
    } catch (_) {
      _logs.clear();
    }
  }

  Future<void> _persistToFile() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_logFileName');
      await file.writeAsString(exportAsText());
    } catch (e) {
      debugPrint('[LogService] 写入日志文件失败: $e');
    }
  }

  void api(String method, String path,
      {Map<String, dynamic>? params, int? statusCode, Duration? duration}) {
    _add(LogEntry(
      timestamp: DateTime.now(),
      type: 'API',
      message: '$method $path',
      detail:
          'Status: $statusCode | Duration: ${duration?.inMilliseconds ?? 0}ms\n'
          'Params: ${jsonEncode(params)}',
      level: statusCode != null && statusCode >= 400 ? 'ERROR' : 'INFO',
    ));
  }

  void error(String source, dynamic error, {StackTrace? stack}) {
    _add(LogEntry(
      timestamp: DateTime.now(),
      type: 'ERROR',
      message: '[$source] $error',
      detail: stack?.toString() ?? '',
      level: 'ERROR',
    ));
  }

  void info(String source, String message) {
    _add(LogEntry(
      timestamp: DateTime.now(),
      type: 'INFO',
      message: '[$source] $message',
      detail: '',
      level: 'INFO',
    ));
  }

  void userAction(String action, {String? detail}) {
    _add(LogEntry(
      timestamp: DateTime.now(),
      type: 'USER',
      message: action,
      detail: detail ?? '',
      level: 'INFO',
    ));
  }

  void _add(LogEntry entry) {
    _logs.insert(0, entry);
    if (_logs.length > _maxLogs) {
      _logs.removeRange(_maxLogs, _logs.length);
    }
    debugPrint('[LOG][${entry.level}] ${entry.message}');
    // 异步持久化，不阻塞当前操作
    _persistToFile().catchError((_) {});
  }

  /// 加载持久化的日志（应在main中调用）
  static Future<void> init() async {
    await _instance._ensureLoaded();
  }

  String exportAsText() {
    final buffer = StringBuffer();
    buffer.writeln('=== LoveGirl Debug Log ===');
    buffer.writeln('Exported: ${DateTime.now().toIso8601String()}');
    buffer.writeln('Total entries: ${_logs.length}');
    buffer.writeln('');
    for (final entry in _logs) {
      buffer.writeln(
          '[${_formatTime(entry.timestamp)}] [${entry.level}] [${entry.type}] ${entry.message}');
      if (entry.detail.isNotEmpty) {
        buffer.writeln('  ${entry.detail.replaceAll('\n', '\n  ')}');
      }
      buffer.writeln('');
    }
    return buffer.toString();
  }

  /// 手动清除日志（同时清除文件）
  Future<void> clear() async {
    _logs.clear();
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_logFileName');
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}.${dt.millisecond.toString().padLeft(3, '0')}';
  }
}

class LogEntry {
  final DateTime timestamp;
  final String type; // API, ERROR, INFO, USER
  final String message;
  final String detail;
  final String level; // INFO, WARN, ERROR

  LogEntry({
    required this.timestamp,
    required this.type,
    required this.message,
    required this.detail,
    required this.level,
  });
}
