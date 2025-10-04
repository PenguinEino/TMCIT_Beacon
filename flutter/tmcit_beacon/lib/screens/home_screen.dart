import 'package:flutter/material.dart';
import '../services/beacon_service.dart';
import '../widgets/scan_tab.dart';
import '../widgets/beacon_list_tab.dart';

class HomeScreen extends StatefulWidget {
  final BeaconService beaconService;

  const HomeScreen({super.key, required this.beaconService});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TMCIT Beacon Scanner'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.radar), text: 'スキャン'),
            Tab(icon: Icon(Icons.list), text: 'ビーコン一覧'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          ScanTab(beaconService: widget.beaconService),
          BeaconListTab(beaconService: widget.beaconService),
        ],
      ),
    );
  }
}
