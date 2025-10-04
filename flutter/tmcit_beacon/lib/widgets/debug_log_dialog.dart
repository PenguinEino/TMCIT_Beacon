import 'package:flutter/material.dart';
import '../services/debug_log_service.dart';

class DebugLogDialog extends StatefulWidget {
  const DebugLogDialog({super.key});

  @override
  State<DebugLogDialog> createState() => _DebugLogDialogState();
}

class _DebugLogDialogState extends State<DebugLogDialog> {
  final _debugLog = DebugLogService();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.bug_report, color: Colors.orange),
                const SizedBox(width: 8),
                const Text(
                  'デバッグログ',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.clear_all),
                  onPressed: () {
                    setState(() {
                      _debugLog.clear();
                    });
                  },
                  tooltip: 'ログをクリア',
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: '閉じる',
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: StreamBuilder<String>(
                stream: _debugLog.logStream,
                builder: (context, snapshot) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _scrollToBottom();
                  });

                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(8),
                      itemCount: _debugLog.logs.length,
                      itemBuilder: (context, index) {
                        final log = _debugLog.logs[index];
                        Color textColor = Colors.white;

                        if (log.contains('ERROR') || log.contains('error')) {
                          textColor = Colors.red;
                        } else if (log.contains('WARNING') ||
                            log.contains('warning')) {
                          textColor = Colors.orange;
                        } else if (log.contains('SUCCESS') ||
                            log.contains('granted')) {
                          textColor = Colors.green;
                        } else if (log.contains('Permission') ||
                            log.contains('status')) {
                          textColor = Colors.cyan;
                        }

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            log,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              color: textColor,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '合計: ${_debugLog.logs.length} 件',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
