import 'dart:convert';
import 'dart:typed_data';
import '../network/packet_router.dart';
import '../models/models.dart';
import 'package:uuid/uuid.dart';

class SOSManager {
  static final SOSManager instance = SOSManager._init();
  SOSManager._init();

  Function(String peerId, double lat, double lng)? onSosReceived;

  Future<void> triggerSOS(double lat, double lng) async {
    final payload = jsonEncode({
      'type': 'sos',
      'lat': lat,
      'lng': lng,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    
    // Broadcast special SOS packet (destinationId = "BROADCAST")
    PacketRouter.instance.routeMessage("BROADCAST", Uint8List.fromList(utf8.encode(payload)));
  }

  void processIncomingSOS(String sourceId, Map<String, dynamic> data) {
    if (onSosReceived != null) {
      onSosReceived!(sourceId, data['lat'], data['lng']);
    }
  }
}
