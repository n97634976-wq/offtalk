import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/mesh_status_provider.dart';

class MeshMonitorScreen extends ConsumerWidget {
  const MeshMonitorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final status = ref.watch(meshStatusProvider);

    return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Status Cards Row
          Row(
            children: [
              Expanded(
                child: _StatusCard(
                  icon: Icons.bluetooth_connected,
                  label: "BLE Peers",
                  value: "${status.connectedPeers}",
                  color: status.connectedPeers > 0 ? Colors.green : Colors.grey,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatusCard(
                  icon: Icons.route,
                  label: "Routes",
                  value: "${status.routeCount}",
                  color: status.routeCount > 0 ? Colors.blue : Colors.grey,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatusCard(
                  icon: Icons.pending_actions,
                  label: "Queued",
                  value: "${status.pendingCount}",
                  color: status.pendingCount > 0 ? Colors.orange : Colors.grey,
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
                        color: status.connectedPeers > 0 ? Colors.green : Colors.red),
                    const SizedBox(width: 8),
                    Text(
                      status.connectedPeers > 0
                          ? "Mesh Active — ${status.connectedPeers} peer${status.connectedPeers == 1 ? '' : 's'}"
                          : "No Mesh Peers Found",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: status.connectedPeers > 0 ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  status.connectedPeers > 0
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
          if (status.routeCount == 0)
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
            ...List.generate(status.routeCount, (i) {
              final route = status.routes[i];
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
          if (status.pendingCount == 0)
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
            ...List.generate(status.pendingCount, (i) {
              final pkt = status.pendingPackets[i];
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
