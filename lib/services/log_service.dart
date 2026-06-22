import 'dart:convert';
import 'package:flutter/foundation.dart';

/// 全局日志服务 — 记录所有API调用、错误、操作
class LogService {
  static final LogService _instance = LogService._();
  factory LogService() => _instance;
  LogService._();

  final List<LogEntry> _logs = [];
  static const int _maxLogs = 500;

  List<LogEntry> get logs => List.unmodifiable(_logs);

  void api(String method, String path, {Map<String, dynamic>? params, int? statusCode, dynamic response, Duration? duration}) {
    _add(LogEntry(
      timestamp: DateTime.now(),
      type: 'API',
      message: '$method $path',
      detail: 'Status: $statusCode | Duration: ${duration?.inMilliseconds ?? 0}ms\n'
          'Params: ${jsonEncode(params)}\nResponse: ${_truncate(jsonEncode(response))}',
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
  }

  String exportAsText() {
    final buffer = StringBuffer();
    buffer.writeln('=== LoveGirl Debug Log ===');
    buffer.writeln('Exported: ${DateTime.now().toIso8601String()}');
    buffer.writeln('Total entries: ${_logs.length}');
    buffer.writeln('');
    for (final entry in _logs) {
      buffer.writeln('[${_formatTime(entry.timestamp)}] [${entry.level}] [${entry.type}] ${entry.message}');
      if (entry.detail.isNotEmpty) {
        buffer.writeln('  ${entry.detail.replaceAll('\n', '\n  ')}');
      }
      buffer.writeln('');
    }
    return buffer.toString();
  }

  void clear() => _logs.clear();

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}:${dt.second.toString().padLeft(2,'0')}.${dt.millisecond.toString().padLeft(3,'0')}';
  }

  String _truncate(String s) => s.length > 500 ? '${s.substring(0, 500)}...' : s;
}

class LogEntry {
  final DateTime timestamp;
  final String type;   // API, ERROR, INFO, USER
  final String message;
  final String detail;
  final String level;  // INFO, WARN, ERROR

  LogEntry({
    required this.timestamp,
    required this.type,
    required this.message,
    required this.detail,
    required this.level,
  });
}
