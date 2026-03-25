import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/hive_helper.dart';
import '../../network/bluetooth_manager.dart';

class MeshStatus {
  final int connectedPeers;
  final int discoveredPeers;
  final int routeCount;
  final int pendingCount;
  final List<MapEntry<String, dynamic>> routes;
  final List<dynamic> pendingPackets;

  MeshStatus({
    this.connectedPeers = 0,
    this.discoveredPeers = 0,
    this.routeCount = 0,
    this.pendingCount = 0,
    this.routes = const [],
    this.pendingPackets = const [],
  });
}

class MeshStatusNotifier extends StateNotifier<MeshStatus> {
  Timer? _timer;

  MeshStatusNotifier() : super(MeshStatus()) {
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _refresh());
  }

  void _refresh() {
    try {
      final routes = HiveHelper.instance.getAllRoutes();
      final pending = HiveHelper.instance.getPendingQueue();
      final peers = BluetoothManager.instance;
      
      state = MeshStatus(
        connectedPeers: peers.connectedPeerCount,
        discoveredPeers: peers.discoveredPeerCount,
        routeCount: routes.length,
        pendingCount: pending.length,
        routes: routes,
        pendingPackets: pending,
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final meshStatusProvider = StateNotifierProvider<MeshStatusNotifier, MeshStatus>((ref) {
  return MeshStatusNotifier();
});
