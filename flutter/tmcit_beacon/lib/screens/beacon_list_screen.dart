import 'package:flutter/material.dart';
import 'dart:async';
import '../services/beacon_service.dart';
import '../models/beacon_data.dart';

class BeaconListScreen extends StatefulWidget {
  const BeaconListScreen({super.key});

  @override
  State<BeaconListScreen> createState() => _BeaconListScreenState();
}

class _BeaconListScreenState extends State<BeaconListScreen> {
  final BeaconService _beaconService = BeaconService();
  StreamSubscription<List<BeaconData>>? _beaconSubscription;
  StreamSubscription<String>? _statusSubscription;

  List<BeaconData> _allDetectedBeacons = [];
  String _statusMessage = '';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _setupStreamos();
  }

  void _setupStreamos() {
    // Listen to beacon updates
    _beaconSubscription = _beaconService.beaconStream.listen((beacons) {
      if (mounted) {
        setState(() {
          _allDetectedBeacons = beacons;
        });
      }
    });

    // Listen to status updates
    _statusSubscription = _beaconService.statusStream.listen((status) {
      if (mounted) {
        setState(() {
          _statusMessage = status;
        });
      }
    });
  }

  List<BeaconData> get _filteredBeacons {
    if (_searchQuery.isEmpty) {
      return _allDetectedBeacons;
    }

    return _allDetectedBeacons.where((beacon) {
      return beacon.major.toString().contains(_searchQuery) ||
          beacon.minor.toString().contains(_searchQuery) ||
          beacon.uuid.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  void dispose() {
    _beaconSubscription?.cancel();
    _statusSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredBeacons = _filteredBeacons;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detected Beacons'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by Major, Minor, or UUID...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Status bar
          if (_statusMessage.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8.0),
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                _statusMessage,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ),

          // Summary card
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text(
                          '${_allDetectedBeacons.length}',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const Text('Total Detected'),
                      ],
                    ),
                    Column(
                      children: [
                        Text(
                          '${filteredBeacons.length}',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const Text('Filtered Results'),
                      ],
                    ),
                    Column(
                      children: [
                        Icon(
                          _beaconService.isScanning
                              ? Icons.radar
                              : Icons.stop_circle,
                          color: _beaconService.isScanning
                              ? Colors.green
                              : Colors.red,
                          size: 32,
                        ),
                        Text(
                          _beaconService.isScanning ? 'Scanning' : 'Stopped',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Beacon list
          Expanded(
            child: filteredBeacons.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.bluetooth_searching,
                          size: 64,
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _allDetectedBeacons.isEmpty
                              ? 'No beacons detected yet'
                              : 'No beacons match your search',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _allDetectedBeacons.isEmpty
                              ? 'Start scanning from the Scanner tab'
                              : 'Try adjusting your search terms',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredBeacons.length,
                    itemBuilder: (context, index) {
                      final beacon = filteredBeacons[index];
                      final isRecent =
                          DateTime.now()
                              .difference(beacon.timestamp)
                              .inSeconds <
                          30;

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        color: isRecent
                            ? Theme.of(
                                context,
                              ).colorScheme.primaryContainer.withOpacity(0.3)
                            : null,
                        child: ExpansionTile(
                          leading: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.bluetooth,
                                color: isRecent ? Colors.green : Colors.grey,
                              ),
                              if (isRecent)
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                          title: Text(
                            'Major: ${beacon.major}, Minor: ${beacon.minor}',
                            style: TextStyle(
                              fontWeight: isRecent
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Distance: ${beacon.distance?.toStringAsFixed(2) ?? 'Unknown'}m',
                              ),
                              Text('RSSI: ${beacon.rssi} dBm'),
                              Text(
                                'Last seen: ${_formatTime(beacon.timestamp)}',
                                style: TextStyle(
                                  color: isRecent ? Colors.green : null,
                                ),
                              ),
                            ],
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildDetailRow('UUID', beacon.uuid),
                                  _buildDetailRow(
                                    'Major',
                                    beacon.major.toString(),
                                  ),
                                  _buildDetailRow(
                                    'Minor',
                                    beacon.minor.toString(),
                                  ),
                                  _buildDetailRow(
                                    'Distance',
                                    '${beacon.distance?.toStringAsFixed(2) ?? 'Unknown'}m',
                                  ),
                                  _buildDetailRow(
                                    'Proximity',
                                    beacon.proximity ?? 'Unknown',
                                  ),
                                  _buildDetailRow('RSSI', '${beacon.rssi} dBm'),
                                  _buildDetailRow(
                                    'Identifier',
                                    beacon.identifier,
                                  ),
                                  _buildDetailRow(
                                    'Timestamp',
                                    beacon.timestamp.toString(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ],
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
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}
