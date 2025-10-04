import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/beacon_service.dart';

class ScanTab extends StatefulWidget {
  final BeaconService beaconService;

  const ScanTab({super.key, required this.beaconService});

  @override
  State<ScanTab> createState() => _ScanTabState();
}

class _ScanTabState extends State<ScanTab> {
  String _statusMessage = 'Ready to scan';
  LocationPermissionStatus _permissionStatus = LocationPermissionStatus.denied;

  @override
  void initState() {
    super.initState();
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 画面に戻ってきたときに権限状態を再確認
    _checkPermissionStatus();
  }

  Future<void> _checkPermissionStatus() async {
    final status = await widget.beaconService.getLocationPermissionStatus();
    if (mounted) {
      setState(() {
        _permissionStatus = status;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
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
    );
  }

  Widget _buildPermissionStatusCard() {
    String statusText;
    Color statusColor;
    IconData statusIcon;

    switch (_permissionStatus) {
      case LocationPermissionStatus.always:
        statusText = '位置情報: 常に許可 ✓';
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case LocationPermissionStatus.whenInUse:
        statusText = '位置情報: 使用中のみ許可 (不十分)';
        statusColor = Colors.orange;
        statusIcon = Icons.warning;
        break;
      case LocationPermissionStatus.denied:
        statusText = '位置情報: 未許可';
        statusColor = Colors.red;
        statusIcon = Icons.error;
        break;
      case LocationPermissionStatus.permanentlyDenied:
        statusText = '位置情報: 拒否済み';
        statusColor = Colors.red;
        statusIcon = Icons.block;
        break;
    }

    return Card(
      color: statusColor.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(statusIcon, color: statusColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                statusText,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleStartScanning() async {
    // 権限状態を再確認
    await _checkPermissionStatus();

    if (_permissionStatus == LocationPermissionStatus.always) {
      // 「常に許可」の場合、スキャン開始
      await widget.beaconService.startScanning();
      setState(() {});
    } else {
      // それ以外の場合、権限リクエストダイアログを表示
      await _showPermissionDialog();
    }
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
        title: const Row(
          children: [
            Icon(Icons.location_on, color: Colors.blue),
            SizedBox(width: 8),
            Text('位置情報の許可が必要です'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'バックグラウンドでビーコンを検出するため、位置情報の「常に許可」が必要です。',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Text(
              '次の画面で「常に許可」を選択してください：',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            SizedBox(height: 8),
            Text('1. 「使用中のみ許可」を選択'),
            Text('2. 再度表示される画面で「常に許可に変更」を選択'),
          ],
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

      if (requestResult == PermissionRequestResult.granted) {
        await _checkPermissionStatus();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('位置情報の権限が許可されました'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else if (requestResult == PermissionRequestResult.permanentlyDenied) {
        await _checkPermissionStatus();
        if (mounted) {
          await _showOpenSettingsDialog();
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

  Future<void> _showOpenSettingsDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.settings, color: Colors.orange),
            SizedBox(width: 8),
            Text('設定が必要です'),
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
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _checkPermissionStatus();
          }
        });
      }
    }
  }
}
