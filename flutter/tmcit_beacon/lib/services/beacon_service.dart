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

/// Bluetooth権限の状態
enum BluetoothPermissionStatus {
  granted, // 許可済み
  denied, // 拒否
  permanentlyDenied, // 永続的に拒否
  notRequired, // 権限不要（古いAndroidバージョン）
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

      // iOS で「常に許可」を要求するように設定
      try {
        await flutterBeacon.setLocationAuthorizationTypeDefault(
          AuthorizationStatus.always,
        );
        _debugLog.log(
          '[BeaconService] Set location authorization type to ALWAYS',
        );
      } catch (e) {
        _debugLog.log(
          '[BeaconService] Could not set authorization type (may be Android): $e',
        );
      }

      _updateStatus('Beacon initialized');
    } catch (e) {
      _updateStatus('Initialization error: $e');
    }
  }

  /// 位置情報の権限状態を取得
  Future<LocationPermissionStatus> getLocationPermissionStatus() async {
    try {
      // permission_handler を使用して正確な権限状態を取得
      final alwaysStatus = await Permission.locationAlways.status;
      final whenInUseStatus = await Permission.locationWhenInUse.status;

      _debugLog.log(
        '[BeaconService] permission_handler status - Always: $alwaysStatus, WhenInUse: $whenInUseStatus',
      );

      // 参考: dchs_flutter_beacon の authorizationStatus も記録
      try {
        final beaconAuthStatus = await flutterBeacon.authorizationStatus;
        _debugLog.log(
          '[BeaconService] (Reference) flutterBeacon.authorizationStatus: $beaconAuthStatus (value: ${beaconAuthStatus.value})',
        );
      } catch (e) {
        _debugLog.log('[BeaconService] Could not get beacon auth status: $e');
      }

      // iOS/Android 共通の判定ロジック
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
      } else if (alwaysStatus.isDenied || whenInUseStatus.isDenied) {
        _debugLog.log(
          '[BeaconService] Returning: LocationPermissionStatus.denied',
        );
        return LocationPermissionStatus.denied;
      } else {
        // notDetermined など
        _debugLog.log(
          '[BeaconService] Returning: LocationPermissionStatus.denied (default)',
        );
        return LocationPermissionStatus.denied;
      }
    } catch (e) {
      _debugLog.log('[BeaconService] Error getting auth status: $e');
      return LocationPermissionStatus.denied;
    }
  }

  /// 位置情報の「常に許可」権限をリクエスト
  Future<PermissionRequestResult> requestAlwaysLocationPermission() async {
    _debugLog.log('[BeaconService] Starting permission request...');

    try {
      // ステップ1: まず「使用中のみ許可」を取得
      var whenInUseStatus = await Permission.locationWhenInUse.status;
      _debugLog.log(
        '[BeaconService] Initial WhenInUse status: $whenInUseStatus',
      );

      if (!whenInUseStatus.isGranted) {
        _debugLog.log('[BeaconService] Requesting WhenInUse permission...');
        whenInUseStatus = await Permission.locationWhenInUse.request();
        _debugLog.log(
          '[BeaconService] WhenInUse request result: $whenInUseStatus',
        );

        if (!whenInUseStatus.isGranted) {
          if (whenInUseStatus.isPermanentlyDenied) {
            return PermissionRequestResult.permanentlyDenied;
          }
          return PermissionRequestResult.denied;
        }
      }

      // ステップ2: 「常に許可」を取得
      _debugLog.log('[BeaconService] WhenInUse granted, requesting Always...');
      var alwaysStatus = await Permission.locationAlways.status;
      _debugLog.log('[BeaconService] Initial Always status: $alwaysStatus');

      if (!alwaysStatus.isGranted) {
        _debugLog.log('[BeaconService] Requesting Always permission...');
        alwaysStatus = await Permission.locationAlways.request();
        _debugLog.log('[BeaconService] Always request result: $alwaysStatus');

        // 結果を再確認（OSによる遅延を考慮）
        await Future.delayed(const Duration(milliseconds: 500));
        alwaysStatus = await Permission.locationAlways.status;
        whenInUseStatus = await Permission.locationWhenInUse.status;
        _debugLog.log(
          '[BeaconService] After delay - Always: $alwaysStatus, WhenInUse: $whenInUseStatus',
        );

        if (alwaysStatus.isGranted) {
          return PermissionRequestResult.granted;
        } else if (alwaysStatus.isPermanentlyDenied) {
          return PermissionRequestResult.permanentlyDenied;
        } else if (whenInUseStatus.isGranted && !alwaysStatus.isGranted) {
          // iOSの場合: 「使用中のみ許可」は取得できたが「常に許可」は取得できなかった
          // Androidの場合: バックグラウンド権限が拒否された
          // どちらも設定画面での変更が必要
          _debugLog.log(
            '[BeaconService] Got WhenInUse but not Always - needs settings',
          );
          return PermissionRequestResult.needsSettings;
        } else {
          return PermissionRequestResult.denied;
        }
      }

      // すでに「常に許可」が付与されている
      _debugLog.log('[BeaconService] Always permission already granted');
      return PermissionRequestResult.granted;
    } catch (e) {
      _debugLog.log('[BeaconService] Error requesting authorization: $e');
      return PermissionRequestResult.denied;
    }
  }

  /// Bluetooth権限の状態を取得
  Future<BluetoothPermissionStatus> getBluetoothPermissionStatus() async {
    try {
      _debugLog.log('[BeaconService] Checking Bluetooth permissions...');

      // Android 12+ (API 31+) では BLUETOOTH_SCAN と BLUETOOTH_CONNECT が必要
      // iOS では Bluetooth 権限は NSBluetoothAlwaysUsageDescription で管理
      final bluetoothScanStatus = await Permission.bluetoothScan.status;
      final bluetoothConnectStatus = await Permission.bluetoothConnect.status;
      final bluetoothStatus = await Permission.bluetooth.status;

      _debugLog.log(
        '[BeaconService] Bluetooth permissions - Scan: $bluetoothScanStatus, '
        'Connect: $bluetoothConnectStatus, Bluetooth: $bluetoothStatus',
      );

      // Android 12+ の場合（bluetoothScan が denied 以外 = サポートされている）
      if (!bluetoothScanStatus.isDenied ||
          bluetoothScanStatus.isGranted ||
          bluetoothScanStatus.isPermanentlyDenied ||
          bluetoothScanStatus.isRestricted ||
          bluetoothScanStatus.isLimited) {
        if (bluetoothScanStatus.isGranted && bluetoothConnectStatus.isGranted) {
          _debugLog.log('[BeaconService] Bluetooth: granted (Android 12+)');
          return BluetoothPermissionStatus.granted;
        } else if (bluetoothScanStatus.isPermanentlyDenied ||
            bluetoothConnectStatus.isPermanentlyDenied) {
          _debugLog.log('[BeaconService] Bluetooth: permanentlyDenied');
          return BluetoothPermissionStatus.permanentlyDenied;
        } else {
          _debugLog.log('[BeaconService] Bluetooth: denied');
          return BluetoothPermissionStatus.denied;
        }
      }
      // iOS または 古いAndroid の場合
      else {
        // iOS では Bluetooth 権限は Info.plist で宣言するだけで、
        // ユーザーの明示的な許可は不要（システムが自動管理）
        if (bluetoothStatus.isGranted || bluetoothStatus.isDenied) {
          _debugLog.log(
            '[BeaconService] Bluetooth: notRequired (iOS or old Android)',
          );
          return BluetoothPermissionStatus.notRequired;
        } else if (bluetoothStatus.isPermanentlyDenied) {
          _debugLog.log('[BeaconService] Bluetooth: permanentlyDenied');
          return BluetoothPermissionStatus.permanentlyDenied;
        } else {
          _debugLog.log('[BeaconService] Bluetooth: notRequired (default)');
          return BluetoothPermissionStatus.notRequired;
        }
      }
    } catch (e) {
      _debugLog.log('[BeaconService] Error getting Bluetooth status: $e');
      // エラーの場合は権限不要として扱う（互換性のため）
      return BluetoothPermissionStatus.notRequired;
    }
  }

  /// Bluetooth権限をリクエスト
  Future<PermissionRequestResult> requestBluetoothPermission() async {
    _debugLog.log('[BeaconService] Requesting Bluetooth permissions...');

    try {
      // Android 12+ の場合（bluetoothScan が denied 以外 = サポートされている）
      final bluetoothScanStatus = await Permission.bluetoothScan.status;
      if (!bluetoothScanStatus.isDenied ||
          bluetoothScanStatus.isGranted ||
          bluetoothScanStatus.isPermanentlyDenied) {
        _debugLog.log(
          '[BeaconService] Requesting Android 12+ Bluetooth permissions...',
        );

        final scanResult = await Permission.bluetoothScan.request();
        final connectResult = await Permission.bluetoothConnect.request();

        _debugLog.log(
          '[BeaconService] Bluetooth request results - Scan: $scanResult, Connect: $connectResult',
        );

        if (scanResult.isGranted && connectResult.isGranted) {
          return PermissionRequestResult.granted;
        } else if (scanResult.isPermanentlyDenied ||
            connectResult.isPermanentlyDenied) {
          return PermissionRequestResult.permanentlyDenied;
        } else {
          return PermissionRequestResult.denied;
        }
      }
      // 古い Android または iOS の場合
      else {
        final bluetoothStatus = await Permission.bluetooth.status;
        if (!bluetoothStatus.isGranted && !bluetoothStatus.isDenied) {
          _debugLog.log(
            '[BeaconService] Requesting legacy Bluetooth permission...',
          );
          final result = await Permission.bluetooth.request();
          _debugLog.log('[BeaconService] Bluetooth request result: $result');

          if (result.isGranted) {
            return PermissionRequestResult.granted;
          } else if (result.isPermanentlyDenied) {
            return PermissionRequestResult.permanentlyDenied;
          } else {
            return PermissionRequestResult.denied;
          }
        }
        // iOS または権限不要（自動的に許可される）
        _debugLog.log('[BeaconService] Bluetooth: granted (not required)');
        return PermissionRequestResult.granted;
      }
    } catch (e) {
      _debugLog.log('[BeaconService] Error requesting Bluetooth: $e');
      return PermissionRequestResult.denied;
    }
  }

  /// 全ての必須権限をチェック（「常に許可」が必須）
  Future<bool> checkAllPermissions() async {
    final locationStatus = await getLocationPermissionStatus();
    final bluetoothStatus = await getBluetoothPermissionStatus();

    final locationOk = locationStatus == LocationPermissionStatus.always;
    final bluetoothOk =
        bluetoothStatus == BluetoothPermissionStatus.granted ||
        bluetoothStatus == BluetoothPermissionStatus.notRequired;

    _debugLog.log(
      '[BeaconService] All permissions check - Location: $locationOk, Bluetooth: $bluetoothOk',
    );

    return locationOk && bluetoothOk;
  }

  Future<void> startScanning() async {
    if (_isScanning) {
      _updateStatus('Already scanning');
      return;
    }

    try {
      // 全ての必須権限のチェック
      final hasAllPermissions = await checkAllPermissions();
      if (!hasAllPermissions) {
        _updateStatus('必要な権限が許可されていません');
        return;
      }

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
