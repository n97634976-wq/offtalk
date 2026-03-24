import 'package:hive_flutter/hive_flutter.dart';
import 'dart:convert';
import '../models/models.dart';

class HiveHelper {
  static final HiveHelper instance = HiveHelper._init();
  HiveHelper._init();

  late Box<String> routingTableBox;
  late Box<String> pendingQueueBox;
  late Box<dynamic> settingsBox;
  late Box<int> processedPacketsBox;

  Future<void> init() async {
    await Hive.initFlutter();
    
    // In production, encrypt Hive with a secure key generated and stored in Keystore
    // For this example, we proceed with standard boxes given SQLCipher handles the main data.
    // Ensure routing, pending, and settings are opened.
    
    routingTableBox = await Hive.openBox<String>('routing_table');
    pendingQueueBox = await Hive.openBox<String>('pending_queue');
    settingsBox = await Hive.openBox<dynamic>('settings');
    // LRU cache for duplicate elimination (size ~1000)
    processedPacketsBox = await Hive.openBox<int>('processed_packets');
  }

  // Routing Table
  Future<void> updateRoute(String destinationId, RouteEntry entry) async {
    await routingTableBox.put(destinationId, jsonEncode(entry.toJson()));
  }

  RouteEntry? getRoute(String destinationId) {
    final data = routingTableBox.get(destinationId);
    if (data == null) return null;
    return RouteEntry.fromJson(jsonDecode(data));
  }

  List<MapEntry<String, RouteEntry>> getAllRoutes() {
    return routingTableBox.toMap().entries.map((e) {
      return MapEntry(e.key.toString(), RouteEntry.fromJson(jsonDecode(e.value)));
    }).toList();
  }

  // Pending Queue (Store-and-forward)
  Future<void> enqueuePacket(Packet packet) async {
    final key = packet.id;
    await pendingQueueBox.put(key, jsonEncode(packet.toJson()));
  }

  Future<void> dequeuePacket(String packetId) async {
    await pendingQueueBox.delete(packetId);
  }

  List<Packet> getPendingQueue() {
    return pendingQueueBox.values.map((v) => Packet.fromJson(jsonDecode(v))).toList();
  }

  // Duplicate Elimination Cache
  bool isPacketProcessed(String packetId) {
    return processedPacketsBox.containsKey(packetId);
  }

  Future<void> markPacketProcessed(String packetId) async {
    await processedPacketsBox.put(packetId, DateTime.now().millisecondsSinceEpoch);
    // Keep size around 1000
    if (processedPacketsBox.length > 1000) {
      final keys = processedPacketsBox.keys.toList();
      await processedPacketsBox.delete(keys.first);
    }
  }

  // Settings
  Future<void> setSetting(String key, dynamic value) async {
    await settingsBox.put(key, value);
  }

  dynamic getSetting(String key, {dynamic defaultValue}) {
    return settingsBox.get(key, defaultValue: defaultValue);
  }
}
