import 'dart:async';

class DebugLogService {
  static final DebugLogService _instance = DebugLogService._internal();
  factory DebugLogService() => _instance;
  DebugLogService._internal();

  final _logController = StreamController<String>.broadcast();
  final List<String> _logs = [];
  bool _isEnabled = false;

  Stream<String> get logStream => _logController.stream;
  List<String> get logs => List.unmodifiable(_logs);
  bool get isEnabled => _isEnabled;

  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    if (enabled) {
      log('[DebugLog] Debug logging enabled');
    }
  }

  void log(String message) {
    final timestamp = DateTime.now().toString().substring(
      11,
      23,
    ); // HH:MM:SS.mmm
    final logMessage = '[$timestamp] $message';

    print(logMessage); // コンソールにも出力

    if (_isEnabled) {
      _logs.add(logMessage);
      // 最大1000件まで保持
      if (_logs.length > 1000) {
        _logs.removeAt(0);
      }
      _logController.add(logMessage);
    }
  }

  void clear() {
    _logs.clear();
    _logController.add('[DebugLog] Logs cleared');
  }

  void dispose() {
    _logController.close();
  }
}
