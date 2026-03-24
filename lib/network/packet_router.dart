import 'dart:convert';
import 'dart:typed_data';
import '../models/models.dart';
import '../core/hive_helper.dart';
import '../core/database_helper.dart';
import 'bluetooth_manager.dart';
import 'package:uuid/uuid.dart';

class PacketRouter {
  static final PacketRouter instance = PacketRouter._init();
  PacketRouter._init();

  String? _myId;

  void init(String myId) {
    _myId = myId;
    BluetoothManager.instance.onDataReceived = _onBluetoothDataReceived;
    BluetoothManager.instance.onPeerConnected = _onPeerConnected;
  }

  /// Sends a message payload to a destination, routing it over the mesh.
  Future<void> routeMessage(String destinationId, Uint8List encryptedPayload) async {
    if (_myId == null) throw Exception("Router not initialized");

    final packet = Packet(
      id: const Uuid().v4(),
      sourceId: _myId!,
      destinationId: destinationId,
      payload: encryptedPayload,
      ttl: 5,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      path: [_myId!],
    );

    await _processOutgoingPacket(packet);
  }

  Future<void> _processOutgoingPacket(Packet packet) async {
    // 1. Mark as processed so we don't route it again if echoed back
    await HiveHelper.instance.markPacketProcessed(packet.id);

    // 2. Check routing table
    final route = HiveHelper.instance.getRoute(packet.destinationId);

    if (route != null && (DateTime.now().millisecondsSinceEpoch - route.timestamp < 3600000)) {
      // 3a. We have a fresh route, send to next hop
      await BluetoothManager.instance.sendData(route.nextHop, _serializePacket(packet));
    } else {
      // 3b. Broadcast to all neighbors (flooding)
      await BluetoothManager.instance.broadcastData(_serializePacket(packet));
    }

    // 4. Also stash in pending queue for store-and-forward just in case
    await HiveHelper.instance.enqueuePacket(packet);
  }

  void _onBluetoothDataReceived(String peerId, Uint8List data) async {
    try {
      final packet = _deserializePacket(data);

      // Duplicate elimination
      if (HiveHelper.instance.isPacketProcessed(packet.id)) return;
      await HiveHelper.instance.markPacketProcessed(packet.id);

      // Update routing table - we know how to reach sourceId via peerId (hopCount = path.length)
      if (packet.sourceId != _myId) {
        await HiveHelper.instance.updateRoute(
          packet.sourceId, 
          RouteEntry(
            nextHop: peerId, 
            hopCount: packet.path.length, 
            timestamp: DateTime.now().millisecondsSinceEpoch
          )
        );
      }

      if (packet.destinationId == _myId) {
        // Packet is for me!
        await _deliverPayload(packet);
        // We received it, remove from pending if we had it
        await HiveHelper.instance.dequeuePacket(packet.id);
        
        // TODO: Send delivery receipt back
      } else {
        // Forwarding
        packet.ttl -= 1;
        if (packet.ttl > 0 && !packet.path.contains(_myId)) {
          packet.path.add(_myId!);
          await _processOutgoingPacket(packet);
        }
      }
    } catch (e) {
      print("Failed to route incoming packet: \$e");
    }
  }

  Future<void> _deliverPayload(Packet packet) async {
    // A real implementation would pass this up to a MessageHandler
    // which handles decryption via KeyManager and DB insertion.
    print("Received packet from \${packet.sourceId}");
    // We would insert into DB to trigger UI updates:
    // await DatabaseHelper.instance.insertMessage(...)
  }

  void _onPeerConnected(String peerId) async {
    // Whenever a new peer connects, try to flush the store-and-forward queue
    final pending = HiveHelper.instance.getPendingQueue();
    for (var packet in pending) {
      // Very naive retry logic - broadcast everything pending
      await BluetoothManager.instance.sendData(peerId, _serializePacket(packet));
    }
  }

  Uint8List _serializePacket(Packet p) {
    return Uint8List.fromList(utf8.encode(jsonEncode(p.toJson())));
  }

  Packet _deserializePacket(Uint8List data) {
    return Packet.fromJson(jsonDecode(utf8.decode(data)));
  }
}
