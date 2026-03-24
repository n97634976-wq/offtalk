import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../core/hive_helper.dart';

/// Manages Bluetooth LE discovery and simulated RFCOMM connections
/// Note: flutter_blue_plus handles BLE scanning and GATT connections. 
/// True Bluetooth Classic RFCOMM on Android would typically use another plugin,
/// but as per architecture limits, we'll build the mesh layer on top of BLE characteristics.
class BluetoothManager {
  static final BluetoothManager instance = BluetoothManager._init();
  BluetoothManager._init();

  final String _serviceUuid = "4d657368-5461-6c6b-2d4e-6574776f726b"; // "OffTalk-Network"
  final Map<String, BluetoothDevice> _connectedPeers = {};
  
  Function(String peerId, Uint8List data)? onDataReceived;
  Function(String peerId)? onPeerConnected;
  Function(String peerId)? onPeerDisconnected;

  int get connectedPeerCount => _connectedPeers.length;

  String? _myNetworkId;

  Future<void> init() async {
    final profile = HiveHelper.instance.getSetting('profile');
    if (profile == null) return;
    _myNetworkId = profile['phoneNumber'];

    // Check if Bluetooth is supported/on
    if (await FlutterBluePlus.isSupported == false) {
      print("Bluetooth not supported by this device");
      return;
    }

    var state = await FlutterBluePlus.adapterState.first;
    if (state == BluetoothAdapterState.on) {
      _startScanning();
    } else {
      FlutterBluePlus.adapterState.listen((state) {
        if (state == BluetoothAdapterState.on) {
          _startScanning();
        }
      });
    }
  }

  void _startScanning() {
    FlutterBluePlus.startScan(
      withServices: [Guid(_serviceUuid)],
      continuousUpdates: true,
      continuousDivisor: 2,
    );

    FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult r in results) {
        // Simple logic: connect to all broadcasting our service
        if (!_connectedPeers.values.any((d) => d.remoteId == r.device.remoteId)) {
          _connectToDevice(r.device);
        }
      }
    });
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect(autoConnect: true);
      _connectedPeers[device.remoteId.str] = device;
      
      // Discover services to find the specific MTU and Characteristic for I/O
      List<BluetoothService> services = await device.discoverServices();
      BluetoothService? meshService;
      for (var s in services) {
        if (s.uuid.toString() == _serviceUuid) {
          meshService = s;
          break;
        }
      }

      if (meshService != null) {
        // Subscribe to notifications/indications on the characteristic
        // Example: hardcoded characteristic UUID for Rx
        var rxChar = meshService.characteristics.firstWhere((c) => c.uuid.toString().startsWith("rx"));
        await rxChar.setNotifyValue(true);
        rxChar.onValueReceived.listen((value) {
          if (onDataReceived != null) {
            onDataReceived!(device.remoteId.str, Uint8List.fromList(value));
          }
        });
      }

      if (onPeerConnected != null) {
        onPeerConnected!(device.remoteId.str);
      }

      device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _connectedPeers.remove(device.remoteId.str);
          if (onPeerDisconnected != null) {
            onPeerDisconnected!(device.remoteId.str);
          }
        }
      });
    } catch (e) {
      print("Connection failed: \$e");
    }
  }

  Future<void> sendData(String peerRemoteId, Uint8List data) async {
    final device = _connectedPeers[peerRemoteId];
    if (device == null) return;

    // Retrieve the Tx characteristic to write to
    // In a real GATT server, we'd have MTU logic for large payloads.
    try {
      List<BluetoothService> services = await device.discoverServices();
      var meshService = services.firstWhere((s) => s.uuid.toString() == _serviceUuid);
      var txChar = meshService.characteristics.firstWhere((c) => c.uuid.toString().startsWith("tx"));
      
      // Example basic write (assuming MTU is large enough or chunking is handled)
      await txChar.write(data, withoutResponse: true);
    } catch (e) {
      print("Failed to send data over BLE: \$e");
    }
  }

  Future<void> broadcastData(Uint8List data) async {
    for (final peerId in _connectedPeers.keys) {
      await sendData(peerId, data);
    }
  }
}
