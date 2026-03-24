import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'database_helper.dart';

class Keypair {
  final _Key privateKey;
  final _Key publicKey;
  Keypair(this.privateKey, this.publicKey);

  static Keypair generate() {
    // Basic mock key generation for the PoC
    final priv = List.generate(32, (i) => i % 255);
    final pub = List.generate(32, (i) => (i + 1) % 255);
    return Keypair(_Key(Uint8List.fromList(priv)), _Key(Uint8List.fromList(pub)));
  }
}

class _Key {
  final Uint8List bytes;
  _Key(this.bytes);
}

class KeyManager {
  static final KeyManager instance = KeyManager._init();
  KeyManager._init();

  late Uint8List _myPrivateKey;
  late Uint8List _myPublicKey;
  late String _myId; // Phone number or device ID
  
  bool _initialized = false;

  void init(String id, Uint8List privateKeyBytes, Uint8List publicKeyBytes) {
    _myId = id;
    _myPrivateKey = privateKeyBytes;
    _myPublicKey = publicKeyBytes;
    _initialized = true;
  }

  bool get isInitialized => _initialized;
  Uint8List get myPublicKeyBytes => _myPublicKey;

  /// Generate a new key pair for the user
  static Keypair generateKeyPair() {
    return Keypair.generate();
  }

  // --- Secure Session (P2P Forward Secrecy encryption) ---

  /// Basic XOR encryption for the PoC since Themis is unavailable
  Uint8List _xorPayload(Uint8List payload, Uint8List key) {
    if (key.isEmpty) return payload;
    final result = Uint8List(payload.length);
    for (int i = 0; i < payload.length; i++) {
      result[i] = payload[i] ^ key[i % key.length];
    }
    return result;
  }

  /// Encrypt a message for a specific contact using Secure Session
  Future<Uint8List> encryptMessage(String contactId, Uint8List payload) async {
    if (!_initialized) throw Exception("KeyManager not initialized");
    
    final contact = await DatabaseHelper.instance.getContact(contactId);
    if (contact == null) throw Exception("Contact not found");

    // Mock encryption logic using XOR with public key
    final encrypted = _xorPayload(payload, contact.publicKey);
    return encrypted;
  }

  /// Decrypt a message from a specific contact using Secure Session
  Future<Uint8List> decryptMessage(String contactId, Uint8List encryptedPayload) async {
    if (!_initialized) throw Exception("KeyManager not initialized");
    
    final contact = await DatabaseHelper.instance.getContact(contactId);
    if (contact == null) throw Exception("Contact not found");

    // Mock decryption logic using XOR with public key
    final decrypted = _xorPayload(encryptedPayload, contact.publicKey);
    return decrypted;
  }

  // --- Handshake Helpers (Since Secure Session needs back-and-forth) ---
  
  /// Create initial connection request to establish a Session
  Future<Uint8List> buildConnectRequest(String contactId) async {
    final contact = await DatabaseHelper.instance.getContact(contactId);
    if (contact == null) throw Exception("Contact not found");
    return Uint8List.fromList(utf8.encode('CONNECT_REQUEST:\$_myId'));
  }

  /// Process incoming negotiation packet
  Future<Uint8List?> processHandshakeOrDecrypt(String contactId, Uint8List incomingPacket) async {
    final contact = await DatabaseHelper.instance.getContact(contactId);
    if (contact == null) throw Exception("Contact not found");
    
    final packetStr = String.fromCharCodes(incomingPacket);
    if (packetStr.startsWith('CONNECT_REQUEST:')) {
      // Mock response
      return Uint8List.fromList(utf8.encode('CONNECT_RESPONSE:\$_myId'));
    } else if (packetStr.startsWith('CONNECT_RESPONSE:')) {
      // Handshake complete
      return null;
    }
    
    // Normal payload
    return decryptMessage(contactId, incomingPacket);
  }

  // --- Secure Cell (Symmetric encryption e.g. for group keys or DB payloads) ---

  /// Encrypt data with a symmetric passphrase (e.g. user PIN derived key)
  Uint8List symmetricEncrypt(String password, Uint8List payload) {
    final key = utf8.encode(password);
    return _xorPayload(payload, Uint8List.fromList(key));
  }

  /// Decrypt data with symmetric passphrase
  Uint8List symmetricDecrypt(String password, Uint8List encryptedData) {
    final key = utf8.encode(password);
    return _xorPayload(encryptedData, Uint8List.fromList(key));
  }
}
