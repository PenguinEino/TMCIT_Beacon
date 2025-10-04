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
      // dchs_flutter_beacon の authorizationStatus を使用
      final authStatus = await flutterBeacon.authorizationStatus;

      _debugLog.log(
        '[BeaconService] flutterBeacon.authorizationStatus: $authStatus (value: ${authStatus.value})',
      );

      // iOS の場合
      if (authStatus == AuthorizationStatus.always) {
        _debugLog.log(
          '[BeaconService] Returning: LocationPermissionStatus.always',
        );
        return LocationPermissionStatus.always;
      } else if (authStatus == AuthorizationStatus.whenInUse) {
        _debugLog.log(
          '[BeaconService] Returning: LocationPermissionStatus.whenInUse',
        );
        return LocationPermissionStatus.whenInUse;
      }
      // Android の場合 - permission_handlerで正確な状態を確認
      else if (authStatus == AuthorizationStatus.allowed) {
        _debugLog.log(
          '[BeaconService] Android ALLOWED detected, checking precise permission...',
        );

        // Android API 29+ では ACCESS_BACKGROUND_LOCATION が必要
        final bgLocationStatus = await Permission.locationAlways.status;
        final fineLocationStatus = await Permission.locationWhenInUse.status;

        _debugLog.log(
          '[BeaconService] Android permissions - Background: $bgLocationStatus, Fine: $fineLocationStatus',
        );

        if (bgLocationStatus.isGranted && fineLocationStatus.isGranted) {
          _debugLog.log(
            '[BeaconService] Returning: LocationPermissionStatus.always (Android with background)',
          );
          return LocationPermissionStatus.always;
        } else if (fineLocationStatus.isGranted &&
            !bgLocationStatus.isGranted) {
          _debugLog.log(
            '[BeaconService] Returning: LocationPermissionStatus.whenInUse (Android without background)',
          );
          return LocationPermissionStatus.whenInUse;
        } else {
          _debugLog.log(
            '[BeaconService] Returning: LocationPermissionStatus.denied (Android missing permissions)',
          );
          return LocationPermissionStatus.denied;
        }
      }
      // 拒否された場合
      else if (authStatus == AuthorizationStatus.denied) {
        _debugLog.log(
          '[BeaconService] Returning: LocationPermissionStatus.permanentlyDenied',
        );
        return LocationPermissionStatus.permanentlyDenied;
      } else if (authStatus == AuthorizationStatus.restricted) {
        _debugLog.log(
          '[BeaconService] Returning: LocationPermissionStatus.permanentlyDenied (restricted)',
        );
        return LocationPermissionStatus.permanentlyDenied;
      } else {
        // notDetermined
        _debugLog.log(
          '[BeaconService] Returning: LocationPermissionStatus.denied (notDetermined)',
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
      // まず、dchs_flutter_beacon の requestAuthorization を使用
      _debugLog.log(
        '[BeaconService] Calling flutterBeacon.requestAuthorization...',
      );
      final result = await flutterBeacon.requestAuthorization;
      _debugLog.log('[BeaconService] requestAuthorization result: $result');

      // 権限状態を再確認
      await Future.delayed(const Duration(milliseconds: 500));
      final authStatus = await flutterBeacon.authorizationStatus;
      _debugLog.log(
        '[BeaconService] Authorization status after request: $authStatus (value: ${authStatus.value})',
      );

      // iOS の場合
      if (authStatus == AuthorizationStatus.always) {
        return PermissionRequestResult.granted;
      } else if (authStatus == AuthorizationStatus.whenInUse) {
        // iOS の場合、「使用中のみ許可」は取得できたが「常に許可」は取得できなかった
        // これは設定画面での変更が必要な状態
        _debugLog.log(
          '[BeaconService] Got WhenInUse, but need Always - directing to settings',
        );
        return PermissionRequestResult.needsSettings;
      }
      // Android の場合 - 追加で background location を要求
      else if (authStatus == AuthorizationStatus.allowed) {
        _debugLog.log(
          '[BeaconService] Android ALLOWED, checking background permission...',
        );

        // Android API 29+ では ACCESS_BACKGROUND_LOCATION を明示的に要求
        final bgLocationStatus = await Permission.locationAlways.status;
        _debugLog.log(
          '[BeaconService] Background location status: $bgLocationStatus',
        );

        if (!bgLocationStatus.isGranted) {
          _debugLog.log(
            '[BeaconService] Requesting background location permission...',
          );
          final bgResult = await Permission.locationAlways.request();
          _debugLog.log(
            '[BeaconService] Background location request result: $bgResult',
          );

          if (bgResult.isGranted) {
            return PermissionRequestResult.granted;
          } else if (bgResult.isPermanentlyDenied) {
            return PermissionRequestResult.permanentlyDenied;
          } else {
            // ユーザーが拒否したか、設定画面での変更が必要
            return PermissionRequestResult.needsSettings;
          }
        } else {
          // すでに background location が許可されている
          return PermissionRequestResult.granted;
        }
      } else if (authStatus == AuthorizationStatus.denied ||
          authStatus == AuthorizationStatus.restricted) {
        return PermissionRequestResult.permanentlyDenied;
      } else {
        return PermissionRequestResult.denied;
      }
    } catch (e) {
      _debugLog.log('[BeaconService] Error requesting authorization: $e');
      return PermissionRequestResult.denied;
    }
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
