import 'package:flutter/material.dart';
import '../services/beacon_service.dart';
import '../models/detected_beacon.dart';

class BeaconListTab extends StatefulWidget {
  final BeaconService beaconService;

  const BeaconListTab({super.key, required this.beaconService});

  @override
  State<BeaconListTab> createState() => _BeaconListTabState();
}

class _BeaconListTabState extends State<BeaconListTab> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<DetectedBeacon>>(
      stream: widget.beaconService.beaconStream,
      initialData: widget.beaconService.currentBeacons,
      builder: (context, snapshot) {
        final beacons = snapshot.data ?? [];

        if (beacons.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.bluetooth_disabled,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'ビーコンが検出されていません',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Text(
                  'スキャンタブからスキャンを開始してください',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '検出されたビーコン: ${beacons.length}個',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: beacons.length,
                padding: const EdgeInsets.all(8),
                itemBuilder: (context, index) {
                  final beacon = beacons[index];
                  return _buildBeaconCard(context, beacon);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBeaconCard(BuildContext context, DetectedBeacon beacon) {
    final now = DateTime.now();
    final difference = now.difference(beacon.detectedAt);
    final timeAgo = _formatTimeDifference(difference);

    // Determine signal strength
    String signalStrength;
    Color signalColor;
    if (beacon.rssi >= -60) {
      signalStrength = '強';
      signalColor = Colors.green;
    } else if (beacon.rssi >= -75) {
      signalStrength = '中';
      signalColor = Colors.orange;
    } else {
      signalStrength = '弱';
      signalColor = Colors.red;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 2,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: signalColor.withOpacity(0.2),
          child: Icon(Icons.bluetooth, color: signalColor),
        ),
        title: Text(
          'Major: ${beacon.major} / Minor: ${beacon.minor}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('検出: $timeAgo'),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow('UUID', beacon.uuid),
                const Divider(),
                _buildInfoRow('Major', beacon.major.toString()),
                _buildInfoRow('Minor', beacon.minor.toString()),
                const Divider(),
                _buildInfoRow('RSSI', '${beacon.rssi} dBm'),
                Row(
                  children: [
                    Expanded(child: _buildInfoRow('信号強度', signalStrength)),
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: signalColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
                if (beacon.accuracy != null)
                  _buildInfoRow(
                    '推定距離',
                    '${beacon.accuracy!.toStringAsFixed(2)} m',
                  ),
                const Divider(),
                _buildInfoRow(
                  '最終検出',
                  '${beacon.detectedAt.hour.toString().padLeft(2, '0')}:'
                      '${beacon.detectedAt.minute.toString().padLeft(2, '0')}:'
                      '${beacon.detectedAt.second.toString().padLeft(2, '0')}',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontFamily: 'monospace')),
          ),
        ],
      ),
    );
  }

  String _formatTimeDifference(Duration difference) {
    if (difference.inSeconds < 60) {
      return '${difference.inSeconds}秒前';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}分前';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}時間前';
    } else {
      return '${difference.inDays}日前';
    }
  }
}
