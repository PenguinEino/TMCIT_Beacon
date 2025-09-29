import 'dart:async';
import 'dart:io';

import 'package:dchs_flutter_beacon/dchs_flutter_beacon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BeaconApp());
}

class BeaconApp extends StatelessWidget {
  const BeaconApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TMCIT Beacon Scanner',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const BeaconHomePage(),
    );
  }
}

class BeaconHomePage extends StatefulWidget {
  const BeaconHomePage({super.key});

  @override
  State<BeaconHomePage> createState() => _BeaconHomePageState();
}

class _BeaconHomePageState extends State<BeaconHomePage> {
  late final BeaconScannerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = BeaconScannerController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('iBeacon モニタ'),
              bottom: const TabBar(
                tabs: [
                  Tab(icon: Icon(Icons.settings_remote), text: 'スキャン'),
                  Tab(icon: Icon(Icons.list_alt), text: '検出一覧'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _buildControlTab(context, _controller),
                _buildDetectedTab(context, _controller),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildControlTab(
    BuildContext context,
    BeaconScannerController controller,
  ) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildStatusCard(theme, controller),
        const SizedBox(height: 16),
        FilledButton.icon(
          icon: Icon(controller.isScanning ? Icons.stop : Icons.play_arrow),
          onPressed: controller.isInitializing
              ? null
              : () async {
                  if (controller.isScanning) {
                    await controller.stopScanning();
                  } else {
                    await controller.startScanning();
                  }
                },
          label: Text(controller.isScanning ? 'スキャン停止' : 'ビーコン検出を開始'),
        ),
        const SizedBox(height: 24),
        if (controller.error != null) ...[
          Card(
            color: theme.colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                controller.error!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
        Text('モニタリングイベント', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (controller.monitoringLog.isEmpty) const Text('まだモニタリングイベントはありません。'),
        if (controller.monitoringLog.isNotEmpty)
          ...controller.monitoringLog
              .take(8)
              .map((entry) => _MonitoringTile(entry: entry))
              .toList(),
        const SizedBox(height: 24),
        Text(
          '現在検出中のビーコン (${controller.nearbyBeacons.length})',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (controller.nearbyBeacons.isEmpty)
          Text(
            controller.isScanning
                ? 'ビーコンを探索中です…'
                : '検出を開始すると、周辺のビーコンがここに表示されます。',
          ),
        ...controller.nearbyBeacons
            .take(5)
            .map((beacon) => _BeaconTile(beacon: beacon))
            .toList(),
        const SizedBox(height: 24),
        Text('バックグラウンド動作について', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          '初回に「位置情報を常に許可」と Bluetooth 利用の確認が表示されます。許可すると、アプリをバックグラウンドにしてもモニタリングとレンジングは継続します。',
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildStatusCard(ThemeData theme, BeaconScannerController controller) {
    final status = controller.isInitializing
        ? '初期化中'
        : controller.isScanning
        ? '稼働中'
        : '待機中';
    final subtitle = controller.isInitializing
        ? 'ライブラリ初期化と権限確認を行っています'
        : controller.isScanning
        ? 'モニタリングとレンジングを実行中'
        : '「ビーコン検出を開始」ボタンを押して検出を始めましょう';
    final lastSeen = controller.lastScanTick;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ステータス: $status', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(subtitle),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.rss_feed, size: 18),
                const SizedBox(width: 8),
                Text('検出済みビーコン数: ${controller.nearbyBeacons.length}'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.timer_outlined, size: 18),
                const SizedBox(width: 8),
                Text(
                  lastSeen == null
                      ? 'まだビーコンを検出していません'
                      : '最終検出: ${_formatTime(lastSeen)}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetectedTab(
    BuildContext context,
    BeaconScannerController controller,
  ) {
    if (controller.trackedBeacons.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'UUID 4b206330-cf87-4d78-b460-acc3240a4777 の iBeacon はまだ検出されていません。',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final beacon = controller.trackedBeacons[index];
        return Card(
          child: ListTile(
            leading: const Icon(Icons.bluetooth_searching),
            title: Text('Major ${beacon.major} / Minor ${beacon.minor}'),
            subtitle: Text(
              'RSSI: ${beacon.rssi}  |  距離推定: ${_formatDistance(beacon.accuracy)}\n最終検出: ${_formatRelative(beacon.lastSeen)}',
            ),
            trailing: const Icon(Icons.chevron_right),
          ),
        );
      },
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemCount: controller.trackedBeacons.length,
    );
  }

  static String _formatTime(DateTime timestamp) {
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    final second = timestamp.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }

  static String _formatRelative(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inSeconds < 60) {
      return '${diff.inSeconds}秒前';
    }
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}分前';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours}時間前';
    }
    return '${diff.inDays}日前';
  }

  static String _formatDistance(double meters) {
    if (!meters.isFinite || meters <= 0) {
      return '不明';
    }
    return '${meters.toStringAsFixed(2)} m';
  }
}

class BeaconScannerController extends ChangeNotifier {
  static const String targetUuid = '4B206330-CF87-4D78-B460-ACC3240A4777';

  bool _isInitializing = false;
  bool _isScanning = false;
  String? _error;
  DateTime? _lastScanTick;

  final Map<String, BeaconSnapshot> _targetBeacons = {};
  final Map<String, BeaconSnapshot> _nearbyBeacons = {};
  final List<MonitoringEventEntry> _monitoringLog = [];

  StreamSubscription<RangingResult>? _rangingSub;
  StreamSubscription<MonitoringResult>? _monitoringSub;

  bool get isInitializing => _isInitializing;
  bool get isScanning => _isScanning;
  String? get error => _error;
  DateTime? get lastScanTick => _lastScanTick;

  List<BeaconSnapshot> get trackedBeacons => _sorted(_targetBeacons.values);
  List<BeaconSnapshot> get nearbyBeacons => _sorted(_nearbyBeacons.values);
  List<MonitoringEventEntry> get monitoringLog =>
      List.unmodifiable(_monitoringLog);

  Future<void> startScanning() async {
    if (_isScanning || _isInitializing) return;

    _error = null;
    _isInitializing = true;
    _nearbyBeacons.clear();
    _targetBeacons.clear();
    _lastScanTick = null;
    notifyListeners();

    try {
      final permissionsGranted = await _ensurePermissions();
      if (!permissionsGranted) {
        return;
      }

      if (Platform.isIOS) {
        await flutterBeacon.setLocationAuthorizationTypeDefault(
          AuthorizationStatus.always,
        );
      }

      await flutterBeacon.initializeAndCheckScanning;
      await flutterBeacon.setUseTrackingCache(true);
      await flutterBeacon.setMaxTrackingAge(15000);
      await flutterBeacon.setScanPeriod(1100);
      await flutterBeacon.setBetweenScanPeriod(500);

      await _startMonitoring();
      await _startRanging();

      _isScanning = true;
    } on PlatformException catch (e) {
      _error = '初期化に失敗しました (${e.code}): ${e.message ?? '不明なエラー'}';
      await _stopStreams();
    } catch (e) {
      _error = '初期化に失敗しました: $e';
      await _stopStreams();
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  Future<bool> _ensurePermissions() async {
    try {
      if (Platform.isAndroid) {
        final initialStatuses = await [
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.locationWhenInUse,
        ].request();

        final permanentlyDenied = initialStatuses.entries.where(
          (entry) => entry.value.isPermanentlyDenied,
        );
        if (permanentlyDenied.isNotEmpty) {
          _error =
              'Bluetooth または位置情報の権限が「今後表示しない」に設定されています。\n設定アプリで許可を付与してください。';
          await openAppSettings();
          return false;
        }

        final missingInitial = initialStatuses.entries.where(
          (entry) => !entry.value.isGranted,
        );
        if (missingInitial.isNotEmpty) {
          _error = 'Bluetooth または位置情報の権限が不足しています。';
          return false;
        }

        var backgroundStatus = await Permission.locationAlways.status;
        if (!backgroundStatus.isGranted) {
          backgroundStatus = await Permission.locationAlways.request();
        }

        if (!backgroundStatus.isGranted) {
          if (backgroundStatus.isPermanentlyDenied) {
            _error = 'バックグラウンドでも検出するには位置情報を「常に許可」に設定してください。\n設定アプリから変更できます。';
            await openAppSettings();
          } else {
            _error = 'バックグラウンド検出には位置情報「常に許可」が必要です。';
          }
          return false;
        }

        return true;
      }

      if (Platform.isIOS) {
        var whenInUseStatus = await Permission.locationWhenInUse.status;
        if (!whenInUseStatus.isGranted) {
          whenInUseStatus = await Permission.locationWhenInUse.request();
        }

        if (!whenInUseStatus.isGranted) {
          if (whenInUseStatus.isPermanentlyDenied) {
            _error = '位置情報の使用が拒否されています。設定から許可を付与してください。';
            await openAppSettings();
          } else {
            _error = 'ビーコン検出には位置情報の利用許可が必要です。';
          }
          return false;
        }

        var alwaysStatus = await Permission.locationAlways.status;
        if (!alwaysStatus.isGranted) {
          alwaysStatus = await Permission.locationAlways.request();
        }

        if (!alwaysStatus.isGranted) {
          if (alwaysStatus.isPermanentlyDenied) {
            _error = 'バックグラウンド検出を行うには「常に許可」が必要です。設定アプリで変更してください。';
            await openAppSettings();
          } else {
            _error = 'バックグラウンド検出を行うには位置情報を「常に許可」にしてください。';
          }
          return false;
        }

        return true;
      }

      return true;
    } catch (e) {
      _error = '権限リクエスト中にエラーが発生しました: $e';
      return false;
    }
  }

  Future<void> stopScanning() async {
    await _stopStreams();
    _isScanning = false;
    notifyListeners();
  }

  Future<void> _startMonitoring() async {
    await _monitoringSub?.cancel();
    _monitoringLog.clear();

    final regions = _buildMonitoringRegions();

    _monitoringSub = flutterBeacon
        .monitoring(regions)
        .listen(
          (result) {
            _monitoringLog.insert(
              0,
              MonitoringEventEntry(result: result, timestamp: DateTime.now()),
            );
            if (_monitoringLog.length > 40) {
              _monitoringLog.removeLast();
            }
            notifyListeners();
          },
          onError: (error) {
            _error = 'Monitoring error: $error';
            notifyListeners();
          },
        );
  }

  Future<void> _startRanging() async {
    await _rangingSub?.cancel();

    final regions = _buildRangingRegions();

    _rangingSub = flutterBeacon
        .ranging(regions)
        .listen(
          (result) {
            final now = DateTime.now();
            _lastScanTick = now;

            for (final beacon in result.beacons) {
              final snapshot = BeaconSnapshot.fromBeacon(beacon, now);
              if (snapshot.identityKey.isEmpty) continue;

              _nearbyBeacons[snapshot.identityKey] = snapshot;

              if (snapshot.proximityUUID == targetUuid) {
                _targetBeacons[snapshot.identityKey] = snapshot;
              }
            }

            _nearbyBeacons.removeWhere(
              (_, snapshot) =>
                  now.difference(snapshot.lastSeen) >
                  const Duration(seconds: 45),
            );
            _targetBeacons.removeWhere(
              (_, snapshot) =>
                  now.difference(snapshot.lastSeen) >
                  const Duration(minutes: 5),
            );

            notifyListeners();
          },
          onError: (error) {
            _error = 'Ranging error: $error';
            notifyListeners();
          },
        );
  }

  Future<void> _stopStreams() async {
    await _rangingSub?.cancel();
    await _monitoringSub?.cancel();
    _rangingSub = null;
    _monitoringSub = null;
  }

  List<Region> _buildMonitoringRegions() {
    final regions = <Region>[];

    if (Platform.isIOS) {
      regions.add(
        Region(identifier: 'tmcit-target', proximityUUID: targetUuid),
      );
    } else {
      regions
        ..add(Region(identifier: 'tmcit-all'))
        ..add(Region(identifier: 'tmcit-target', proximityUUID: targetUuid));
    }

    return regions;
  }

  List<Region> _buildRangingRegions() {
    if (Platform.isIOS) {
      return [
        Region(identifier: 'tmcit-target-range', proximityUUID: targetUuid),
      ];
    }

    return [Region(identifier: 'tmcit-range')];
  }

  List<BeaconSnapshot> _sorted(Iterable<BeaconSnapshot> values) {
    final list = List<BeaconSnapshot>.from(values);
    list.sort((a, b) => b.lastSeen.compareTo(a.lastSeen));
    return list;
  }

  @override
  void dispose() {
    _stopStreams();
    super.dispose();
  }
}

class BeaconSnapshot {
  BeaconSnapshot({
    required this.proximityUUID,
    required this.major,
    required this.minor,
    required this.rssi,
    required this.accuracy,
    required this.lastSeen,
  });

  final String proximityUUID;
  final int major;
  final int minor;
  final int rssi;
  final double accuracy;
  final DateTime lastSeen;

  String get identityKey => '$proximityUUID|$major|$minor';

  factory BeaconSnapshot.fromBeacon(Beacon beacon, DateTime timestamp) {
    final uuid = beacon.proximityUUID.toUpperCase();
    final accuracy = beacon.accuracy.isFinite
        ? beacon.accuracy
        : double.infinity;

    return BeaconSnapshot(
      proximityUUID: uuid,
      major: beacon.major,
      minor: beacon.minor,
      rssi: beacon.rssi,
      accuracy: accuracy,
      lastSeen: timestamp,
    );
  }
}

class MonitoringEventEntry {
  MonitoringEventEntry({required this.result, required this.timestamp});

  final MonitoringResult result;
  final DateTime timestamp;

  String get eventLabel {
    switch (result.monitoringEventType) {
      case MonitoringEventType.didEnterRegion:
        return '領域に入りました';
      case MonitoringEventType.didExitRegion:
        return '領域から離れました';
      case MonitoringEventType.didDetermineStateForRegion:
        return '領域状態を判定しました';
    }
  }

  String get stateLabel {
    final state = result.monitoringState;
    if (state == null) {
      return '現在: 状態未取得';
    }

    switch (state) {
      case MonitoringState.inside:
        return '現在: 内部';
      case MonitoringState.outside:
        return '現在: 外部';
      case MonitoringState.unknown:
        return '現在: 不明';
    }
  }
}

class _MonitoringTile extends StatelessWidget {
  const _MonitoringTile({required this.entry});

  final MonitoringEventEntry entry;

  @override
  Widget build(BuildContext context) {
    final title = entry.result.region.proximityUUID ?? '全ビーコン';
    return Card(
      child: ListTile(
        leading: const Icon(Icons.sensors),
        title: Text(entry.eventLabel),
        subtitle: Text(
          '領域: $title\n${entry.stateLabel}\n${_BeaconHomePageState._formatTime(entry.timestamp)}',
        ),
      ),
    );
  }
}

class _BeaconTile extends StatelessWidget {
  const _BeaconTile({required this.beacon});

  final BeaconSnapshot beacon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.bluetooth),
        title: Text(beacon.proximityUUID),
        subtitle: Text(
          'Major ${beacon.major} / Minor ${beacon.minor}\nRSSI: ${beacon.rssi} | 距離推定: ${_BeaconHomePageState._formatDistance(beacon.accuracy)}',
        ),
        trailing: Text(_BeaconHomePageState._formatRelative(beacon.lastSeen)),
      ),
    );
  }
}
