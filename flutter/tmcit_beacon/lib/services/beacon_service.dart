import 'dart:async';
import 'package:dchs_flutter_beacon/dchs_flutter_beacon.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/detected_beacon.dart';
import 'debug_log_service.dart';

/// 位置情報権限の状態
enum LocationPermissionStatus {
  always, // 常に許可
  whenInUse, // 使用中のみ許可
  denied, // 拒否
  permanentlyDenied, // 永続的に拒否
}

/// 権限リクエストの結果
enum PermissionRequestResult {
  granted, // 許可された
  denied, // 拒否された
  permanentlyDenied, // 永続的に拒否された
  needsSettings, // 設定画面での変更が必要（iOS の「常に許可」）
}

class BeaconService {
  // Target UUID for monitoring
  static const String targetUUID = '4b206330-cf87-4d78-b460-acc3240a4777';

  final _debugLog = DebugLogService();
  final _beaconController = StreamController<List<DetectedBeacon>>.broadcast();
  final _statusController = StreamController<String>.broadcast();

  final Map<String, DetectedBeacon> _detectedBeacons = {};
  StreamSubscription? _rangingSubscription;
  StreamSubscription? _monitoringSubscription;

  bool _isScanning = false;

  // Getters
  Stream<List<DetectedBeacon>> get beaconStream => _beaconController.stream;
  Stream<String> get statusStream => _statusController.stream;
  bool get isScanning => _isScanning;
  List<DetectedBeacon> get currentBeacons =>
      _detectedBeacons.values.toList()
        ..sort((a, b) => b.detectedAt.compareTo(a.detectedAt));

  BeaconService() {
    _initializeBeacon();
  }

  Future<void> _initializeBeacon() async {
    try {
      await flutterBeacon.initializeScanning;
      _updateStatus('Beacon initialized');
    } catch (e) {
      _updateStatus('Initialization error: $e');
    }
  }

  /// 位置情報の権限状態を取得
  Future<LocationPermissionStatus> getLocationPermissionStatus() async {
    final alwaysStatus = await Permission.locationAlways.status;
    final whenInUseStatus = await Permission.locationWhenInUse.status;

    _debugLog.log(
      '[BeaconService] getLocationPermissionStatus: Always=$alwaysStatus, WhenInUse=$whenInUseStatus',
    );

    if (alwaysStatus.isGranted) {
      _debugLog.log(
        '[BeaconService] Returning: LocationPermissionStatus.always',
      );
      return LocationPermissionStatus.always;
    } else if (whenInUseStatus.isGranted) {
      _debugLog.log(
        '[BeaconService] Returning: LocationPermissionStatus.whenInUse',
      );
      return LocationPermissionStatus.whenInUse;
    } else if (alwaysStatus.isPermanentlyDenied ||
        whenInUseStatus.isPermanentlyDenied) {
      _debugLog.log(
        '[BeaconService] Returning: LocationPermissionStatus.permanentlyDenied',
      );
      return LocationPermissionStatus.permanentlyDenied;
    } else {
      _debugLog.log(
        '[BeaconService] Returning: LocationPermissionStatus.denied',
      );
      return LocationPermissionStatus.denied;
    }
  }

  /// 位置情報の「常に許可」権限をリクエスト
  Future<PermissionRequestResult> requestAlwaysLocationPermission() async {
    _debugLog.log('[BeaconService] Starting permission request...');

    // まず「使用中のみ許可」を取得
    var whenInUseStatus = await Permission.locationWhenInUse.status;
    _debugLog.log('[BeaconService] Initial whenInUse status: $whenInUseStatus');

    if (!whenInUseStatus.isGranted) {
      _debugLog.log('[BeaconService] Requesting whenInUse permission...');
      final result = await Permission.locationWhenInUse.request();
      _debugLog.log('[BeaconService] WhenInUse request result: $result');

      if (!result.isGranted) {
        if (result.isPermanentlyDenied) {
          return PermissionRequestResult.permanentlyDenied;
        }
        return PermissionRequestResult.denied;
      }
      whenInUseStatus = result;
    }

    // iOSの場合、「使用中のみ許可」を取得した後、
    // locationAlwaysのリクエストは設定画面への誘導が必要
    var alwaysStatus = await Permission.locationAlways.status;
    _debugLog.log('[BeaconService] Always status: $alwaysStatus');

    if (!alwaysStatus.isGranted) {
      _debugLog.log('[BeaconService] Requesting always permission...');

      // iOS では、Always 権限は設定画面でしか変更できない場合がある
      final result = await Permission.locationAlways.request();
      _debugLog.log('[BeaconService] Always request result: $result');

      // 結果を再確認
      await Future.delayed(const Duration(milliseconds: 500));
      alwaysStatus = await Permission.locationAlways.status;
      _debugLog.log(
        '[BeaconService] Always status after request: $alwaysStatus',
      );

      if (alwaysStatus.isGranted) {
        return PermissionRequestResult.granted;
      } else if (alwaysStatus.isPermanentlyDenied ||
          result.isPermanentlyDenied) {
        return PermissionRequestResult.permanentlyDenied;
      } else if (whenInUseStatus.isGranted && !alwaysStatus.isGranted) {
        // iOS の場合、「使用中のみ許可」は取得できたが「常に許可」は取得できなかった
        // これは設定画面での変更が必要な状態
        return PermissionRequestResult.needsSettings;
      } else {
        return PermissionRequestResult.denied;
      }
    }

    return PermissionRequestResult.granted;
  }

  /// Bluetooth権限をチェック・リクエスト
  Future<bool> checkAndRequestBluetoothPermissions() async {
    if (await Permission.bluetooth.isDenied) {
      await Permission.bluetooth.request();
    }

    if (await Permission.bluetoothScan.isDenied) {
      await Permission.bluetoothScan.request();
    }

    if (await Permission.bluetoothConnect.isDenied) {
      await Permission.bluetoothConnect.request();
    }

    return true;
  }

  /// 全ての必須権限をチェック（「常に許可」が必須）
  Future<bool> checkAllPermissions() async {
    final locationStatus = await getLocationPermissionStatus();
    return locationStatus == LocationPermissionStatus.always;
  }

  Future<void> startScanning() async {
    if (_isScanning) {
      _updateStatus('Already scanning');
      return;
    }

    try {
      // 「常に許可」権限のチェック
      final hasAllPermissions = await checkAllPermissions();
      if (!hasAllPermissions) {
        _updateStatus('位置情報の「常に許可」が必要です');
        return;
      }

      // Bluetooth権限のチェック
      await checkAndRequestBluetoothPermissions();

      _isScanning = true;
      _updateStatus('Starting beacon scan...');

      // Define the region to monitor
      final region = Region(
        identifier: 'TMCIT_Beacon_Region',
        proximityUUID: targetUUID,
      );

      // Start monitoring
      _monitoringSubscription = flutterBeacon
          .monitoring([region])
          .listen(
            (MonitoringResult result) {
              _updateStatus(
                'Monitoring: ${result.monitoringState == MonitoringState.inside ? "Inside" : "Outside"} region',
              );

              if (result.monitoringState == MonitoringState.inside) {
                _startRanging(region);
              }
            },
            onError: (error) {
              _updateStatus('Monitoring error: $error');
            },
          );

      // Start ranging immediately
      _startRanging(region);

      _updateStatus('Scanning started');
    } catch (e) {
      _isScanning = false;
      _updateStatus('Error starting scan: $e');
    }
  }

  void _startRanging(Region region) {
    _rangingSubscription?.cancel();

    _rangingSubscription = flutterBeacon
        .ranging([region])
        .listen(
          (RangingResult result) {
            if (result.beacons.isNotEmpty) {
              _updateStatus('Found ${result.beacons.length} beacon(s)');

              for (var beacon in result.beacons) {
                final detectedBeacon = DetectedBeacon(
                  uuid: beacon.proximityUUID.toLowerCase(),
                  major: beacon.major,
                  minor: beacon.minor,
                  rssi: beacon.rssi,
                  accuracy: beacon.accuracy,
                  detectedAt: DateTime.now(),
                );

                _detectedBeacons[detectedBeacon.uniqueId] = detectedBeacon;
              }

              _beaconController.add(currentBeacons);
            }
          },
          onError: (error) {
            _updateStatus('Ranging error: $error');
          },
        );
  }

  Future<void> stopScanning() async {
    if (!_isScanning) {
      return;
    }

    try {
      await _rangingSubscription?.cancel();
      await _monitoringSubscription?.cancel();
      _rangingSubscription = null;
      _monitoringSubscription = null;
      _isScanning = false;
      _updateStatus('Scanning stopped');
    } catch (e) {
      _updateStatus('Error stopping scan: $e');
    }
  }

  void clearBeacons() {
    _detectedBeacons.clear();
    _beaconController.add([]);
    _updateStatus('Beacon list cleared');
  }

  void _updateStatus(String status) {
    _debugLog.log('[BeaconService] Status: $status');
    _statusController.add(status);
  }

  void dispose() {
    _rangingSubscription?.cancel();
    _monitoringSubscription?.cancel();
    _beaconController.close();
    _statusController.close();
  }
}
