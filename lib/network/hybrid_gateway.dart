import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'packet_router.dart';
import 'libp2p_manager.dart';
import '../models/models.dart';

/// Bridging local mesh and internet (publish/fetch from DHT)
class HybridGateway {
  static final HybridGateway instance = HybridGateway._init();
  HybridGateway._init();

  bool _hasInternet = false;

  void init() {
    _checkConnectivity();
    Connectivity().onConnectivityChanged.listen((result) {
      if (result.contains(ConnectivityResult.mobile) || result.contains(ConnectivityResult.wifi)) {
        _hasInternet = true;
      } else {
        _hasInternet = false;
      }
    });
  }

  /// Called by PacketRouter when a packet cannot reach its destination locally.
  Future<bool> attemptOverlayRelay(Packet packet) async {
    if (!_hasInternet) return false;
    
    // We have internet! Try to send it via libp2p
    final success = await Libp2pManager.instance.sendViaOverlay(packet.destinationId, packet.payload);
    
    if (success) {
      print("Gateway: Successfully relayed packet to internet overlay.");
      return true;
    }
    return false;
  }

  /// Called periodically to fetch messages from the DHT for local offline peers we know about.
  Future<void> syncForLocalMesh(List<String> knownLocalPeers) async {
    if (!_hasInternet) return;
    
    for (final peerId in knownLocalPeers) {
      // 1. Check DHT for messages intended for `peerId`
      // 2. Download them
      // 3. Inject them into local mesh via PacketRouter
      
      /* Example:
      final messages = await Libp2pManager.instance.fetchMessagesFor(peerId);
      for(var msg in messages) {
         PacketRouter.instance.routeMessage(peerId, msg.payload);
      }
      */
    }
  }
}
