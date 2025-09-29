import 'package:flutter/material.dart';
import 'dart:async';
import '../services/beacon_service.dart';
import '../models/beacon_data.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final BeaconService _beaconService = BeaconService();
  StreamSubscription<String>? _statusSubscription;
  StreamSubscription<List<BeaconData>>? _beaconSubscription;

  List<BeaconData> _recentBeacons = [];
  String _statusMessage = 'Beacon service not initialized';
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeBeaconService();
  }

  Future<void> _initializeBeaconService() async {
    try {
      await _beaconService.initialize();
      setState(() {
        _isInitialized = true;
      });

      // Listen to status updates
      _statusSubscription = _beaconService.statusStream.listen((status) {
        if (mounted) {
          setState(() {
            _statusMessage = status;
          });
        }
      });

      // Listen to beacon updates
      _beaconSubscription = _beaconService.beaconStream.listen((beacons) {
        if (mounted) {
          setState(() {
            _recentBeacons = beacons;
          });
        }
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Failed to initialize: $e';
      });
    }
  }

  Future<void> _startScanning() async {
    try {
      await _beaconService.startScanning();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to start scanning: $e')));
      }
    }
  }

  Future<void> _stopScanning() async {
    try {
      await _beaconService.stopScanning();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to stop scanning: $e')));
      }
    }
  }

  void _clearBeacons() {
    _beaconService.clearDetectedBeacons();
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    _beaconSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('iBeacon Scanner'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _statusMessage,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Target UUID: ${BeaconService.targetUuid}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Control buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isInitialized && !_beaconService.isScanning
                        ? _startScanning
                        : null,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start Scanning'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isInitialized && _beaconService.isScanning
                        ? _stopScanning
                        : null,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop Scanning'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            ElevatedButton.icon(
              onPressed: _clearBeacons,
              icon: const Icon(Icons.clear_all),
              label: const Text('Clear Results'),
            ),

            const SizedBox(height: 16),

            // Recent beacons
            Text(
              'Recently Detected Beacons (${_recentBeacons.length})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),

            Expanded(
              child: _recentBeacons.isEmpty
                  ? const Center(child: Text('No beacons detected yet'))
                  : ListView.builder(
                      itemCount: _recentBeacons.length,
                      itemBuilder: (context, index) {
                        final beacon = _recentBeacons[index];
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.bluetooth),
                            title: Text(
                              'Major: ${beacon.major}, Minor: ${beacon.minor}',
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('UUID: ${beacon.uuid}'),
                                Text(
                                  'Distance: ${beacon.distance?.toStringAsFixed(2) ?? 'Unknown'}m',
                                ),
                                Text('RSSI: ${beacon.rssi} dBm'),
                                Text(
                                  'Proximity: ${beacon.proximity ?? 'Unknown'}',
                                ),
                                Text(
                                  'Last seen: ${_formatTime(beacon.timestamp)}',
                                ),
                              ],
                            ),
                            isThreeLine: true,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 60) {
      return '${difference.inSeconds}s ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else {
      return '${difference.inHours}h ago';
    }
  }
}
