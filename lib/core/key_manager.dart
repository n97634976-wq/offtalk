import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:pointycastle/pointycastle.dart' as pc;
import 'database_helper.dart';

/// ─── PUBLIC KEY ENCRYPTION EXPLAINED ───────────────────────────────────────
///
/// Every OffTalk user has a **key pair**: a private key and a public key.
///
/// • The **public key** is shared openly (via QR code / NFC during pairing).
///   It is embedded inside the QR code alongside the phone number so that
///   anyone who scans it can encrypt messages *for* that user.
///
/// • The **private key** never leaves the device. It is used to *decrypt*
///   incoming messages that were encrypted with the matching public key.
///
/// Together, they enable **end-to-end encryption (E2E)**:
///   Sender encrypts with recipient's PUBLIC key  →  only the recipient's
///   PRIVATE key can decrypt. Not even relay nodes in the mesh can read it.
///
/// In a production build, this would use ECDH (Elliptic-Curve Diffie–Hellman)
/// to derive a shared session secret, providing forward secrecy.
/// ────────────────────────────────────────────────────────────────────────────

class Keypair {
  final _Key privateKey;
  final _Key publicKey;
  Keypair(this.privateKey, this.publicKey);

  /// Generate a new asymmetric key pair.
  /// In production, replace with a proper ECDH key pair (e.g. X25519).
  static Keypair generate() {
    final rng = Random.secure();
    final priv = Uint8List.fromList(List.generate(32, (_) => rng.nextInt(256)));
    final pub = Uint8List.fromList(List.generate(32, (_) => rng.nextInt(256)));
    return Keypair(_Key(priv), _Key(pub));
  }
}

class _Key {
  final Uint8List bytes;
  _Key(this.bytes);
}

class KeyManager {
  static final KeyManager instance = KeyManager._init();
  KeyManager._init();

  late Uint8List _myPrivateKey;  // NEVER leaves this device
  late Uint8List _myPublicKey;   // Shared via QR/NFC during pairing
  late String _myId;             // Phone number — acts as the user's identity
  
  bool _initialized = false;

  void init(String id, Uint8List privateKeyBytes, Uint8List publicKeyBytes) {
    _myId = id;
    _myPrivateKey = privateKeyBytes;
    _myPublicKey = publicKeyBytes;
    _initialized = true;
  }

  bool get isInitialized => _initialized;

  /// The user's public key bytes — embedded in QR codes and shared during
  /// pairing so that other users can encrypt messages destined for us.
  Uint8List get myPublicKeyBytes => _myPublicKey;

  /// Generate a new key pair for the user
  static Keypair generateKeyPair() {
    return Keypair.generate();
  }

  // ─── PBKDF2 PIN-based key derivation ────────────────────────────────

  /// Generate a random 16-byte salt for PBKDF2
  static Uint8List generateSalt() {
    final rng = Random.secure();
    return Uint8List.fromList(List.generate(16, (_) => rng.nextInt(256)));
  }

  /// Derive a 256-bit AES key from a user PIN + salt using PBKDF2-HMAC-SHA256.
  /// This is used to encrypt the local database and verify the PIN on login.
  static Uint8List deriveKeyFromPin(String pin, Uint8List salt, {int iterations = 100000}) {
    final params = pc.Pbkdf2Parameters(salt, iterations, 32); // 32 bytes = 256 bits
    final kdf = pc.KeyDerivator('SHA-256/HMAC/PBKDF2');
    kdf.init(params);
    return kdf.process(Uint8List.fromList(utf8.encode(pin)));
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
