import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../core/hive_helper.dart';

/// Manages Bluetooth LE discovery and GATT connections for the mesh network.
///
/// How it works:
/// 1. On init(), we check BLE support and adapter state.
/// 2. We start scanning for devices advertising our service UUID.
/// 3. When a device is found, we connect and subscribe to its Rx characteristic.
/// 4. Data received from peers triggers the onDataReceived callback.
/// 5. To send data, we write to the peer's Tx characteristic.
///
/// Note: BLE has a ~20-byte MTU by default; REQUEST a larger MTU (512) after
/// connecting. For messages > MTU, the flutter_blue_plus library handles
/// chunking transparently when using `write()` with `allowLongWrite: true`.
class BluetoothManager {
  static final BluetoothManager instance = BluetoothManager._init();
  BluetoothManager._init();

  final String _serviceUuid = "4d657368-5461-6c6b-2d4e-6574776f726b"; // "OffTalk-Network"
  final Map<String, BluetoothDevice> _connectedPeers = {};
  
  /// Discovered (but not yet connected) peers from BLE scan
  final Map<String, ScanResult> _discoveredPeers = {};
  
  Function(String peerId, Uint8List data)? onDataReceived;
  Function(String peerId)? onPeerConnected;
  Function(String peerId)? onPeerDisconnected;

  /// Number of peers we are currently connected to via GATT
  int get connectedPeerCount => _connectedPeers.length;
  
  /// Number of peers discovered during BLE scan (including unconnected)
  int get discoveredPeerCount => _discoveredPeers.length;
  
  /// Get a snapshot of discovered peer addresses and names
  Map<String, String> get discoveredPeers {
    return _discoveredPeers.map((key, value) => MapEntry(
      key, 
      value.device.platformName.isNotEmpty 
        ? value.device.platformName 
        : 'Unknown Device',
    ));
  }

  String? _myNetworkId;
  bool _isScanning = false;

  Future<void> init() async {
    final profile = HiveHelper.instance.getSetting('profile');
    if (profile == null) return;
    _myNetworkId = profile['phoneNumber'];

    // Check if Bluetooth is supported
    if (await FlutterBluePlus.isSupported == false) {
      print("Bluetooth not supported by this device");
      return;
    }

    // Turn on Bluetooth if it's off (Android only)
    try {
      await FlutterBluePlus.turnOn();
    } catch (_) {
      // iOS doesn't support turnOn; user must enable manually
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
    if (_isScanning) return;
    _isScanning = true;

    // Start a continuous scan. On Android, this requires BLUETOOTH_SCAN +
    // ACCESS_FINE_LOCATION permissions (declared in AndroidManifest.xml and
    // requested at runtime by the onboarding screen).
    FlutterBluePlus.startScan(
      withServices: [Guid(_serviceUuid)],
      continuousUpdates: true,
      continuousDivisor: 2,
      androidUsesFineLocation: true,
    );

    FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult r in results) {
        final remoteId = r.device.remoteId.str;
        
        // Track all discovered peers
        _discoveredPeers[remoteId] = r;
        
        // Connect if not already connected
        if (!_connectedPeers.containsKey(remoteId)) {
          _connectToDevice(r.device);
        }
      }
    });
  }
  
  /// Stop scanning (e.g., when the app goes to background)
  void stopScanning() {
    FlutterBluePlus.stopScan();
    _isScanning = false;
  }
  
  /// Restart scanning (e.g., when returning to foreground)
  void restartScanning() {
    _discoveredPeers.clear();
    _isScanning = false;
    _startScanning();
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect(autoConnect: true, mtu: null);
      
      // Request a larger MTU for bigger payloads (Android auto-negotiates on iOS)
      try {
        await device.requestMtu(512);
      } catch (_) {}
      
      _connectedPeers[device.remoteId.str] = device;
      
      // Discover services to find the specific characteristic for I/O
      List<BluetoothService> services = await device.discoverServices();
      BluetoothService? meshService;
      for (var s in services) {
        if (s.uuid.toString() == _serviceUuid) {
          meshService = s;
          break;
        }
      }

      if (meshService != null) {
        // Subscribe to notifications/indications on the Rx characteristic
        for (var c in meshService.characteristics) {
          if (c.properties.notify || c.properties.indicate) {
            await c.setNotifyValue(true);
            c.onValueReceived.listen((value) {
              if (onDataReceived != null) {
                onDataReceived!(device.remoteId.str, Uint8List.fromList(value));
              }
            });
            break; // Use the first notifiable characteristic
          }
        }
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
      print("Connection failed: $e");
    }
  }

  Future<void> sendData(String peerRemoteId, Uint8List data) async {
    final device = _connectedPeers[peerRemoteId];
    if (device == null) return;

    try {
      List<BluetoothService> services = await device.discoverServices();
      var meshService = services.firstWhere((s) => s.uuid.toString() == _serviceUuid);
      
      // Find the first writable characteristic
      for (var c in meshService.characteristics) {
        if (c.properties.write || c.properties.writeWithoutResponse) {
          await c.write(data, withoutResponse: c.properties.writeWithoutResponse);
          break;
        }
      }
    } catch (e) {
      print("Failed to send data over BLE: $e");
    }
  }

  Future<void> broadcastData(Uint8List data) async {
    for (final peerId in _connectedPeers.keys.toList()) {
      await sendData(peerId, data);
    }
  }
  
  /// Disconnect and clean up all BLE resources
  void dispose() {
    stopScanning();
    for (var device in _connectedPeers.values) {
      try {
        device.disconnect();
      } catch (_) {}
    }
    _connectedPeers.clear();
    _discoveredPeers.clear();
  }
}
