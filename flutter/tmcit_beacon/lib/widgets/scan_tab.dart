import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/beacon_service.dart';
import '../services/debug_log_service.dart';
import 'debug_log_dialog.dart';

class ScanTab extends StatefulWidget {
  final BeaconService beaconService;

  const ScanTab({super.key, required this.beaconService});

  @override
  State<ScanTab> createState() => _ScanTabState();
}

class _ScanTabState extends State<ScanTab> with WidgetsBindingObserver {
  final _debugLog = DebugLogService();
  String _statusMessage = 'Ready to scan';
  LocationPermissionStatus _permissionStatus = LocationPermissionStatus.denied;
  BluetoothPermissionStatus _bluetoothStatus =
      BluetoothPermissionStatus.notRequired;

  @override
  void initState() {
    super.initState();
    // デバッグログを自動的に有効化（開発中は便利）
    _debugLog.setEnabled(true);
    _debugLog.log('[ScanTab] initState() called');

    WidgetsBinding.instance.addObserver(this);
    widget.beaconService.statusStream.listen((status) {
      if (mounted) {
        setState(() {
          _statusMessage = status;
        });
      }
    });
    _checkPermissionStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // アプリがフォアグラウンドに戻ってきたときに権限状態を再確認
    if (state == AppLifecycleState.resumed) {
      _debugLog.log('[ScanTab] App resumed, checking permissions...');
      // 設定アプリから戻った直後は権限情報が更新されていない可能性があるため、
      // 少し遅延を入れてから確認
      Future.delayed(const Duration(milliseconds: 500), () async {
        if (mounted) {
          await _checkPermissionStatus();
          // 権限が「常に許可」になっていて、スキャンが開始されていない場合は
          // 自動的にスキャンを開始するかメッセージを表示
          if (_permissionStatus == LocationPermissionStatus.always &&
              !widget.beaconService.isScanning) {
            _debugLog.log(
              '[ScanTab] Permission granted after settings, showing message',
            );
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✓ 位置情報の「常に許可」が設定されました'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 2),
                ),
              );
            }
          }
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 画面に戻ってきたときに権限状態を再確認
    _checkPermissionStatus();
  }

  Future<void> _checkPermissionStatus() async {
    _debugLog.log('[ScanTab] _checkPermissionStatus() called');
    final locationStatus = await widget.beaconService
        .getLocationPermissionStatus();
    final bluetoothStatus = await widget.beaconService
        .getBluetoothPermissionStatus();
    _debugLog.log(
      '[ScanTab] Permission status checked - Location: $locationStatus, Bluetooth: $bluetoothStatus',
    );
    if (mounted) {
      final oldLocationStatus = _permissionStatus;
      final oldBluetoothStatus = _bluetoothStatus;
      setState(() {
        _permissionStatus = locationStatus;
        _bluetoothStatus = bluetoothStatus;
      });
      _debugLog.log(
        '[ScanTab] State updated - Location: $oldLocationStatus -> $_permissionStatus, '
        'Bluetooth: $oldBluetoothStatus -> $_bluetoothStatus',
      );
    } else {
      _debugLog.log(
        '[ScanTab] WARNING: Widget not mounted, skipping state update',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  widget.beaconService.isScanning
                      ? Icons.radar
                      : Icons.bluetooth_searching,
                  size: 100,
                  color: widget.beaconService.isScanning
                      ? Colors.blue
                      : Colors.grey,
                ),
                const SizedBox(height: 32),
                Text(
                  widget.beaconService.isScanning ? 'スキャン中...' : 'スキャン停止中',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                Text(
                  _statusMessage,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Target UUID:\n${BeaconService.targetUUID}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                _buildPermissionStatusCard(),
                const SizedBox(height: 12),
                _buildBluetoothStatusCard(),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: widget.beaconService.isScanning
                          ? null
                          : () async {
                              await _handleStartScanning();
                            },
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('スキャン開始'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: !widget.beaconService.isScanning
                          ? null
                          : () async {
                              await widget.beaconService.stopScanning();
                              setState(() {});
                            },
                      icon: const Icon(Icons.stop),
                      label: const Text('スキャン停止'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () {
                    widget.beaconService.clearBeacons();
                    setState(() {});
                  },
                  icon: const Icon(Icons.clear_all),
                  label: const Text('検出履歴をクリア'),
                ),
              ],
            ),
          ),
        ),
        // デバッグコントロールボタン（右下）
        Positioned(
          bottom: 16,
          right: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton(
                mini: true,
                heroTag: 'debug_log',
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => const DebugLogDialog(),
                  );
                },
                tooltip: 'デバッグログを表示',
                child: const Icon(Icons.bug_report),
              ),
              const SizedBox(height: 8),
              FloatingActionButton(
                mini: true,
                heroTag: 'debug_toggle',
                backgroundColor: _debugLog.isEnabled
                    ? Colors.orange
                    : Colors.grey,
                onPressed: () {
                  setState(() {
                    _debugLog.setEnabled(!_debugLog.isEnabled);
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        _debugLog.isEnabled ? 'デバッグログ: ON' : 'デバッグログ: OFF',
                      ),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
                tooltip: 'デバッグログ ON/OFF',
                child: Icon(
                  _debugLog.isEnabled ? Icons.visibility : Icons.visibility_off,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPermissionStatusCard() {
    String statusText;
    Color statusColor;
    IconData statusIcon;

    String detailText = '';

    switch (_permissionStatus) {
      case LocationPermissionStatus.always:
        statusText = '位置情報: 常に許可 ✓';
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        detailText = 'バックグラウンドでのBeacon検出が可能です';
        break;
      case LocationPermissionStatus.whenInUse:
        statusText = '位置情報: 使用中のみ許可';
        statusColor = Colors.orange;
        statusIcon = Icons.warning;
        detailText = 'バックグラウンド検出には「常に許可」が必要です';
        break;
      case LocationPermissionStatus.denied:
        statusText = '位置情報: 未許可';
        statusColor = Colors.red;
        statusIcon = Icons.error;
        detailText = '位置情報の権限を許可してください';
        break;
      case LocationPermissionStatus.permanentlyDenied:
        statusText = '位置情報: 拒否済み';
        statusColor = Colors.red;
        statusIcon = Icons.block;
        detailText = '設定アプリから権限を変更してください';
        break;
    }

    return Card(
      color: statusColor.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(statusIcon, color: statusColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            if (detailText.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                detailText,
                style: TextStyle(
                  color: statusColor.withOpacity(0.8),
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBluetoothStatusCard() {
    String statusText;
    Color statusColor;
    IconData statusIcon;
    String detailText = '';

    switch (_bluetoothStatus) {
      case BluetoothPermissionStatus.granted:
        statusText = 'Bluetooth: 許可済み ✓';
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        detailText = 'Beaconのスキャンが可能です';
        break;
      case BluetoothPermissionStatus.denied:
        statusText = 'Bluetooth: 未許可';
        statusColor = Colors.orange;
        statusIcon = Icons.warning;
        detailText = 'Bluetooth権限を許可してください';
        break;
      case BluetoothPermissionStatus.permanentlyDenied:
        statusText = 'Bluetooth: 拒否済み';
        statusColor = Colors.red;
        statusIcon = Icons.block;
        detailText = '設定アプリから権限を変更してください';
        break;
      case BluetoothPermissionStatus.notRequired:
        statusText = 'Bluetooth: OK';
        statusColor = Colors.grey;
        statusIcon = Icons.check_circle_outline;
        detailText = 'このデバイスでは追加の権限は不要です';
        break;
    }

    return Card(
      color: statusColor.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(statusIcon, color: statusColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            if (detailText.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                detailText,
                style: TextStyle(
                  color: statusColor.withOpacity(0.8),
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _handleStartScanning() async {
    _debugLog.log('[ScanTab] _handleStartScanning called');
    _debugLog.log(
      '[ScanTab] Current permissions before check - Location: $_permissionStatus, Bluetooth: $_bluetoothStatus',
    );

    // 権限状態を再確認
    await _checkPermissionStatus();

    _debugLog.log(
      '[ScanTab] Current permissions after check - Location: $_permissionStatus, Bluetooth: $_bluetoothStatus',
    );

    // 位置情報の権限チェック
    if (_permissionStatus != LocationPermissionStatus.always) {
      _debugLog.log(
        '[ScanTab] Location permission not always ($_permissionStatus), showing dialog...',
      );
      await _showPermissionDialog();
      return;
    }

    // Bluetooth権限チェック
    if (_bluetoothStatus == BluetoothPermissionStatus.denied ||
        _bluetoothStatus == BluetoothPermissionStatus.permanentlyDenied) {
      _debugLog.log(
        '[ScanTab] Bluetooth permission denied ($_bluetoothStatus), requesting...',
      );
      await _requestBluetoothPermission();
      return;
    }

    // 全ての権限OK、スキャン開始
    _debugLog.log('[ScanTab] All permissions OK, starting scan...');
    await widget.beaconService.startScanning();
    setState(() {});
  }

  Future<void> _showPermissionDialog() async {
    if (_permissionStatus == LocationPermissionStatus.permanentlyDenied) {
      // 永続的に拒否されている場合、設定画面へ誘導
      await _showOpenSettingsDialog();
    } else {
      // 権限をリクエストするダイアログを表示
      await _showRequestPermissionDialog();
    }
  }

  Future<void> _showRequestPermissionDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.location_on, color: Colors.blue),
            const SizedBox(width: 8),
            Expanded(child: const Text('位置情報の許可が必要です')),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'バックグラウンドでビーコンを検出するため、位置情報の「常に許可」が必要です。',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 16),
              Text(
                '📱 iOSの場合の手順：',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              SizedBox(height: 8),
              Text('1. まず「使用中のみ許可」または\n   「アプリの使用中は許可」を選択'),
              SizedBox(height: 4),
              Text('2. その後、自動的に設定画面に移動'),
              Text('   「位置情報」→「常に」を選択'),
              SizedBox(height: 16),
              Text(
                '🤖 Androidの場合の手順：',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              SizedBox(height: 8),
              Text('1. まず「アプリの使用中のみ」を選択'),
              SizedBox(height: 4),
              Text('2. 次のダイアログで\n   「常に許可」を選択してください'),
              SizedBox(height: 12),
              Text(
                '⚠️ 「使用中のみ許可」だけでは、バックグラウンドでビーコンを検出できません。必ず「常に許可」を選択してください。',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('許可する'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      // 権限をリクエスト
      final requestResult = await widget.beaconService
          .requestAlwaysLocationPermission();

      _debugLog.log('[ScanTab] Permission request result: $requestResult');

      if (requestResult == PermissionRequestResult.granted) {
        await _checkPermissionStatus();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('位置情報の権限が許可されました'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
          // 権限が取得できたので自動的にスキャンを開始
          await Future.delayed(const Duration(milliseconds: 500));
          if (_permissionStatus == LocationPermissionStatus.always) {
            await widget.beaconService.startScanning();
            setState(() {});
          }
        }
      } else if (requestResult == PermissionRequestResult.permanentlyDenied) {
        await _checkPermissionStatus();
        if (mounted) {
          await _showOpenSettingsDialog();
        }
      } else if (requestResult == PermissionRequestResult.needsSettings) {
        // iOS で「使用中のみ許可」を取得した場合、設定画面へ誘導
        await _checkPermissionStatus();
        if (mounted) {
          await _showIOSAlwaysPermissionDialog();
        }
      } else {
        await _checkPermissionStatus();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('位置情報の「常に許可」が必要です'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    }
  }

  Future<void> _showIOSAlwaysPermissionDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.settings, color: Colors.blue),
            const SizedBox(width: 8),
            Expanded(child: const Text('設定で「常に許可」に変更')),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('「使用中のみ許可」を選択されました。', style: TextStyle(fontSize: 16)),
            SizedBox(height: 16),
            Text(
              'バックグラウンドでビーコンを検出するには、設定で「常に許可」に変更する必要があります。',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 16),
            Text(
              '設定手順：',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            SizedBox(height: 8),
            Text('1. 「設定を開く」をタップ'),
            Text('2. 「位置情報」をタップ'),
            Text('3. 「常に」を選択'),
            Text('4. アプリに戻る'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('後で'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('設定を開く'),
          ),
        ],
      ),
    );

    if (result == true) {
      await openAppSettings();
      // 注: 設定アプリから戻ってきたときは didChangeAppLifecycleState で自動的にチェックされる
    } else {
      // キャンセルされた場合も権限状態を更新
      await _checkPermissionStatus();
    }
  }

  Future<void> _showOpenSettingsDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.settings, color: Colors.orange),
            const SizedBox(width: 8),
            Expanded(child: const Text('設定が必要です')),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('位置情報の権限が拒否されています。', style: TextStyle(fontSize: 16)),
            SizedBox(height: 16),
            Text(
              '設定アプリで位置情報を「常に許可」に変更してください：',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            SizedBox(height: 8),
            Text('1. 設定アプリを開く'),
            Text('2. このアプリを選択'),
            Text('3. 位置情報 → 「常に」を選択'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('設定を開く'),
          ),
        ],
      ),
    );

    if (result == true) {
      await openAppSettings();
      if (mounted) {
        // 設定から戻ってきたら権限状態を再確認
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            _checkPermissionStatus();
          }
        });
      }
    }
  }

  Future<void> _requestBluetoothPermission() async {
    _debugLog.log('[ScanTab] _requestBluetoothPermission called');

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.bluetooth, color: Colors.blue),
            const SizedBox(width: 8),
            Expanded(child: const Text('Bluetooth権限が必要です')),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ビーコンを検出するため、Bluetooth権限が必要です。',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 16),
              Text(
                '📱 権限を許可すると：',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              SizedBox(height: 8),
              Text('• 近くのiBeaconを検出できます'),
              Text('• バックグラウンドでも動作します'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('許可する'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      // Bluetooth権限をリクエスト
      final requestResult = await widget.beaconService
          .requestBluetoothPermission();

      _debugLog.log(
        '[ScanTab] Bluetooth permission request result: $requestResult',
      );

      // 権限状態を再確認
      await _checkPermissionStatus();

      if (requestResult == PermissionRequestResult.granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bluetooth権限が許可されました'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
          // 権限が取得できたのでスキャンを試行
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) {
            await _handleStartScanning();
          }
        }
      } else if (requestResult == PermissionRequestResult.permanentlyDenied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bluetooth権限が拒否されています。設定から変更してください。'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }
}
