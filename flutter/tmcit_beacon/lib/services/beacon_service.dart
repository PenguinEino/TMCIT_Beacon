import 'dart:async';
import 'dart:io';
import 'package:dchs_flutter_beacon/dchs_flutter_beacon.dart';
import '../models/beacon_data.dart';

class BeaconService {
  static final BeaconService _instance = BeaconService._internal();
  factory BeaconService() => _instance;
  BeaconService._internal();

  // Target UUID for filtering
  static const String targetUuid = '4b206330-cf87-4d78-b460-acc3240a4777';

  final StreamController<List<BeaconData>> _beaconController =
      StreamController<List<BeaconData>>.broadcast();
  final StreamController<String> _statusController =
      StreamController<String>.broadcast();

  Stream<List<BeaconData>> get beaconStream => _beaconController.stream;
  Stream<String> get statusStream => _statusController.stream;

  final List<BeaconData> _detectedBeacons = [];
  StreamSubscription<BluetoothState>? _bluetoothSubscription;
  StreamSubscription<RangingResult>? _rangingSubscription;
  StreamSubscription<MonitoringResult>? _monitoringSubscription;

  bool _isScanning = false;

  bool get isScanning => _isScanning;
  List<BeaconData> get detectedBeacons => List.unmodifiable(_detectedBeacons);

  Future<void> initialize() async {
    try {
      await flutterBeacon.initializeAndCheckScanning;

      // Configure scanning settings for better performance and background detection
      await flutterBeacon.setScanPeriod(1000); // 1 second scan period
      await flutterBeacon.setBetweenScanPeriod(500); // 0.5 second between scans

      // Enable tracking cache for persistent beacon detection
      await flutterBeacon.setUseTrackingCache(true);
      await flutterBeacon.setMaxTrackingAge(10000); // 10 seconds max age

      _statusController.add(
        'Beacon service initialized with background support',
      );

      // Listen to bluetooth state changes
      _bluetoothSubscription = flutterBeacon.bluetoothStateChanged().listen((
        state,
      ) {
        _statusController.add('Bluetooth state: ${state.toString()}');
      });
    } catch (e) {
      _statusController.add('Failed to initialize beacon service: $e');
      rethrow;
    }
  }

  Future<bool> checkPermissions() async {
    // Check Bluetooth state
    final bluetoothState = await flutterBeacon.bluetoothState;
    if (bluetoothState != BluetoothState.stateOn) {
      _statusController.add('Bluetooth is not enabled');
      return false;
    }

    // Check location permission
    final authorizationStatus = await flutterBeacon.authorizationStatus;
    if (authorizationStatus == AuthorizationStatus.notDetermined) {
      final result = await flutterBeacon.requestAuthorization;
      if (result != AuthorizationStatus.whenInUse &&
          result != AuthorizationStatus.always) {
        _statusController.add('Location permission denied');
        return false;
      }
    } else if (authorizationStatus == AuthorizationStatus.denied) {
      _statusController.add('Location permission is denied');
      return false;
    }

    // For background scanning, we need always permission
    if (authorizationStatus != AuthorizationStatus.always) {
      _statusController.add(
        'Warning: Background scanning requires "Always" location permission',
      );
    }

    return true;
  }

  Future<void> startScanning() async {
    if (_isScanning) {
      _statusController.add('Already scanning');
      return;
    }

    try {
      final hasPermissions = await checkPermissions();
      if (!hasPermissions) {
        throw Exception('Insufficient permissions for beacon scanning');
      }

      _isScanning = true;
      _statusController.add('Starting beacon scanning...');

      // Create regions list for scanning
      final regions = <Region>[];

      if (Platform.isIOS) {
        // iOS requires proximityUUID for region scanning
        regions.add(
          Region(identifier: 'tmcit_beacon_region', proximityUUID: targetUuid),
        );
      } else {
        // Android can scan all beacons
        regions.add(Region(identifier: 'tmcit_beacon_region'));
      }

      // Start ranging beacons
      _rangingSubscription = flutterBeacon.ranging(regions).listen((
        RangingResult result,
      ) {
        _handleRangingResult(result);
      });

      // Start monitoring beacons for background detection
      _monitoringSubscription = flutterBeacon.monitoring(regions).listen((
        MonitoringResult result,
      ) {
        _statusController.add(
          'Monitoring result: ${result.monitoringState} for region ${result.region.identifier}',
        );
      });

      _statusController.add('Beacon scanning started');
    } catch (e) {
      _isScanning = false;
      _statusController.add('Failed to start scanning: $e');
      rethrow;
    }
  }

  void _handleRangingResult(RangingResult result) {
    if (result.beacons.isNotEmpty) {
      final now = DateTime.now();
      final newBeacons = result.beacons
          .where(
            (beacon) =>
                beacon.proximityUUID.toLowerCase() == targetUuid.toLowerCase(),
          )
          .map(
            (beacon) => BeaconData(
              uuid: beacon.proximityUUID,
              major: beacon.major,
              minor: beacon.minor,
              distance: beacon.accuracy,
              proximity: beacon.proximity.toString(),
              rssi: beacon.rssi,
              timestamp: now,
            ),
          )
          .toList();

      // Update the detected beacons list
      for (final newBeacon in newBeacons) {
        final existingIndex = _detectedBeacons.indexWhere(
          (existing) => existing.identifier == newBeacon.identifier,
        );

        if (existingIndex != -1) {
          _detectedBeacons[existingIndex] = newBeacon;
        } else {
          _detectedBeacons.add(newBeacon);
        }
      }

      // Remove old beacons (older than 10 seconds)
      _detectedBeacons.removeWhere(
        (beacon) => now.difference(beacon.timestamp).inSeconds > 10,
      );

      _beaconController.add(List.from(_detectedBeacons));
      _statusController.add('Found ${newBeacons.length} beacons');
    }
  }

  Future<void> stopScanning() async {
    if (!_isScanning) {
      _statusController.add('Not currently scanning');
      return;
    }

    try {
      _isScanning = false;

      // Cancel subscriptions - the plugin handles stopping automatically
      _rangingSubscription?.cancel();
      _monitoringSubscription?.cancel();

      _statusController.add('Beacon scanning stopped');
    } catch (e) {
      _statusController.add('Failed to stop scanning: $e');
      rethrow;
    }
  }

  void clearDetectedBeacons() {
    _detectedBeacons.clear();
    _beaconController.add([]);
    _statusController.add('Cleared detected beacons');
  }

  void dispose() {
    _bluetoothSubscription?.cancel();
    _rangingSubscription?.cancel();
    _monitoringSubscription?.cancel();
    _beaconController.close();
    _statusController.close();
  }
}
