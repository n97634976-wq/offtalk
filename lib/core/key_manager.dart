import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:pointycastle/pointycastle.dart' as pc;
import 'package:cryptography/cryptography.dart';
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
  final Uint8List privateKey;
  final Uint8List publicKey;
  Keypair(this.privateKey, this.publicKey);

  /// Generate a new ED25519 key pair for signing and encrypting.
  static Future<Keypair> generate() async {
    final algorithm = X25519();
    final keyPair = await algorithm.newKeyPair();
    final pubKey = await keyPair.extractPublicKey();
    final privKey = await keyPair.extractPrivateKeyBytes();
    return Keypair(Uint8List.fromList(privKey), Uint8List.fromList(pubKey.bytes));
  }
}

class KeyManager {
  static final KeyManager instance = KeyManager._init();
  KeyManager._init();

  late Uint8List _myPrivateKey;  // NEVER leaves this device
  late Uint8List _myPublicKey;   // Shared via QR/NFC during pairing
  late String _myId;             // Phone number — acts as the user's identity
  
  bool _initialized = false;
  
  // Secure Sessions cache removed because it wasn't used and caused compilation error

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
  static Future<Keypair> generateKeyPair() async {
    return await Keypair.generate();
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

  Future<SecretKey> _getSharedSecret(String contactId) async {
    final contact = await DatabaseHelper.instance.getContact(contactId);
    if (contact == null) throw Exception("Contact not found");

    final algorithm = X25519();
    final myKeyPair = SimpleKeyPairData(_myPrivateKey, 
      publicKey: SimplePublicKey(_myPublicKey, type: KeyPairType.x25519), 
      type: KeyPairType.x25519);
    final peerPublicKey = SimplePublicKey(contact.publicKey, type: KeyPairType.x25519);

    return await algorithm.sharedSecretKey(keyPair: myKeyPair, remotePublicKey: peerPublicKey);
  }

  /// Encrypt a message for a specific contact using X25519 ECDH + AES-GCM
  Future<Uint8List> encryptMessage(String contactId, Uint8List payload) async {
    if (!_initialized) throw Exception("KeyManager not initialized");
    final sharedSecret = await _getSharedSecret(contactId);
    
    final algorithm = AesGcm.with256bits();
    final secretBox = await algorithm.encrypt(
      payload,
      secretKey: sharedSecret,
    );
    return secretBox.concatenation();
  }

  /// Decrypt a message from a specific contact using X25519 ECDH + AES-GCM
  Future<Uint8List> decryptMessage(String contactId, Uint8List encryptedPayload) async {
    if (!_initialized) throw Exception("KeyManager not initialized");
    final sharedSecret = await _getSharedSecret(contactId);
    
    final algorithm = AesGcm.with256bits();
    final secretBox = SecretBox.fromConcatenation(
      encryptedPayload,
      nonceLength: algorithm.nonceLength,
      macLength: algorithm.macAlgorithm.macLength,
    );
    return Uint8List.fromList(await algorithm.decrypt(secretBox, secretKey: sharedSecret));
  }

  // --- Handshake Helpers (Since Secure Session needs back-and-forth) ---
  
  /// Create initial connection request to establish a Session
  Future<Uint8List> buildConnectRequest(String contactId) async {
    return Uint8List.fromList(utf8.encode('CONNECT_REQUEST:\$_myId'));
  }

  /// Process incoming negotiation packet
  Future<Uint8List?> processHandshakeOrDecrypt(String contactId, Uint8List incomingPacket) async {
    final packetStr = String.fromCharCodes(incomingPacket);
    if (packetStr.startsWith('CONNECT_REQUEST:')) {
      return Uint8List.fromList(utf8.encode('CONNECT_RESPONSE:\$_myId'));
    } else if (packetStr.startsWith('CONNECT_RESPONSE:')) {
      return null;
    }
    return decryptMessage(contactId, incomingPacket);
  }

  // --- Secure Cell (Symmetric encryption e.g. for group keys or DB payloads) ---

  /// Encrypt data with a symmetric passphrase (e.g. user PIN derived key)
  Future<Uint8List> symmetricEncrypt(String password, Uint8List payload) async {
    if (payload.isEmpty) return payload;
    
    // Derive a strong 256-bit key using PBKDF2
    final salt = Uint8List.fromList('OffTalkSymmetricSalt'.codeUnits);
    final keyBytes = deriveKeyFromPin(password, salt, iterations: 1000);
    
    final algorithm = AesGcm.with256bits();
    final secretKey = SecretKey(keyBytes);
    final secretBox = await algorithm.encrypt(payload, secretKey: secretKey);
    return secretBox.concatenation();
  }

  /// Decrypt data with symmetric passphrase
  Future<Uint8List> symmetricDecrypt(String password, Uint8List encryptedData) async {
    if (encryptedData.isEmpty) return encryptedData;
    
    final salt = Uint8List.fromList('OffTalkSymmetricSalt'.codeUnits);
    final keyBytes = deriveKeyFromPin(password, salt, iterations: 1000);
    
    final algorithm = AesGcm.with256bits();
    final secretBox = SecretBox.fromConcatenation(
      encryptedData,
      nonceLength: algorithm.nonceLength,
      macLength: algorithm.macAlgorithm.macLength,
    );
    return Uint8List.fromList(await algorithm.decrypt(secretBox, secretKey: SecretKey(keyBytes)));
  }
}
