import 'dart:io';
import 'dart:typed_data';
import 'package:wifi_iot/wifi_iot.dart';
import 'package:permission_handler/permission_handler.dart';

class WifiDirectManager {
  static final WifiDirectManager instance = WifiDirectManager._init();
  WifiDirectManager._init();

  bool _isSupported = false;

  Future<void> init() async {
    // WiFi Direct is primarily Android
    if (!Platform.isAndroid) return;

    if (await Permission.location.request().isGranted) {
      _isSupported = await WiFiForIoTPlugin.isWiFiAPEnabled() ?? false;
      // In a real implementation, we would register broadcast receivers to scan for 
      // Wi-Fi Direct peers, connect, and establish a Socket connection for high bandwidth.
    }
  }

  /// Sends a large file over a Wi-Fi Direct socket.
  Future<void> sendLargePayload(String peerAddress, Uint8List payload) async {
    if (!_isSupported) return;
    try {
      final socket = await Socket.connect(peerAddress, 8888, timeout: const Duration(seconds: 5));
      // length prefix framing
      final lengthBytes = ByteData(4)..setUint32(0, payload.length);
      socket.add(lengthBytes.buffer.asUint8List());
      socket.add(payload);
      await socket.flush();
      socket.destroy();
    } catch (e) {
      print("Wi-Fi Direct send failed: \$e");
    }
  }

  /// Starts a server socket on port 8888 for incoming Wi-Fi Direct transfers.
  Future<void> startServer(Function(Uint8List) onPayloadReceived) async {
    if (!_isSupported) return;
    try {
      final serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, 8888);
      serverSocket.listen((client) {
        // Very basic framing read: skip the length bytes for brevity in this demo
        List<int> buffer = [];
        client.listen((data) {
          buffer.addAll(data);
        }, onDone: () {
          // Received full payload
          if (buffer.length > 4) {
            final payload = Uint8List.fromList(buffer.sublist(4));
            onPayloadReceived(payload);
          }
        });
      });
    } catch (e) {
      print("Wi-Fi Direct server failed: \$e");
    }
  }
}
