import 'package:flutter/material.dart';
import '../../core/hive_helper.dart';
import '../../network/bluetooth_manager.dart';

class MeshMonitorScreen extends StatefulWidget {
  const MeshMonitorScreen({super.key});

  @override
  State<MeshMonitorScreen> createState() => _MeshMonitorScreenState();
}

class _MeshMonitorScreenState extends State<MeshMonitorScreen> {
  List<MapEntry<String, dynamic>> _routes = [];
  List<dynamic> _pendingPackets = [];
  int _connectedPeers = 0;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _isRefreshing = true);
    try {
      final routes = HiveHelper.instance.getAllRoutes();
      final pending = HiveHelper.instance.getPendingQueue();
      final peers = BluetoothManager.instance;

      setState(() {
        _routes = routes;
        _pendingPackets = pending;
        _connectedPeers = peers.connectedPeerCount;
        _isRefreshing = false;
      });
    } catch (_) {
      setState(() => _isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Status Cards Row
          Row(
            children: [
              Expanded(
                child: _StatusCard(
                  icon: Icons.bluetooth_connected,
                  label: "BLE Peers",
                  value: "$_connectedPeers",
                  color: _connectedPeers > 0 ? Colors.green : Colors.grey,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatusCard(
                  icon: Icons.route,
                  label: "Routes",
                  value: "${_routes.length}",
                  color: _routes.isNotEmpty ? Colors.blue : Colors.grey,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatusCard(
                  icon: Icons.pending_actions,
                  label: "Queued",
                  value: "${_pendingPackets.length}",
                  color: _pendingPackets.isNotEmpty ? Colors.orange : Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Network Status
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.wifi_tethering,
                        color: _connectedPeers > 0 ? Colors.green : Colors.red),
                    const SizedBox(width: 8),
                    Text(
                      _connectedPeers > 0
                          ? "Mesh Active — $_connectedPeers peer${_connectedPeers == 1 ? '' : 's'}"
                          : "No Mesh Peers Found",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _connectedPeers > 0 ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _connectedPeers > 0
                      ? "Messages will be routed through the mesh network."
                      : "Enable Bluetooth and be near other OffTalk users to form a mesh.",
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Routing Table
          Text("Routing Table",
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (_routes.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text("No routes discovered yet",
                    style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            ...List.generate(_routes.length, (i) {
              final route = _routes[i];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.device_hub),
                  title: Text(route.key, style: const TextStyle(fontSize: 13)),
                  subtitle: Text(
                    "Next hop: ${route.value.nextHop} • ${route.value.hopCount} hop${route.value.hopCount == 1 ? '' : 's'}",
                  ),
                  trailing: Text(
                    "${((DateTime.now().millisecondsSinceEpoch - route.value.timestamp) / 1000).round()}s ago",
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ),
              );
            }),

          const SizedBox(height: 24),

          // Pending Queue
          Text("Pending Queue (Store & Forward)",
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (_pendingPackets.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text("No pending packets",
                    style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            ...List.generate(_pendingPackets.length, (i) {
              final pkt = _pendingPackets[i];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.outbox, color: Colors.orange),
                  title: Text("To: ${pkt.destinationId}",
                      style: const TextStyle(fontSize: 13)),
                  subtitle: Text("TTL: ${pkt.ttl} • ${pkt.payload.length} bytes"),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatusCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: TextStyle(fontSize: 11, color: color)),
        ],
      ),
    );
  }
}
