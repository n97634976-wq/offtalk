import 'dart:typed_data';
import 'package:themis/themis.dart';
import 'database_helper.dart';

class KeyManager {
  static final KeyManager instance = KeyManager._init();
  KeyManager._init();

  late PrivateKey _myPrivateKey;
  late PublicKey _myPublicKey;
  late String _myId; // Phone number or device ID
  
  bool _initialized = false;

  void init(String id, Uint8List privateKeyBytes, Uint8List publicKeyBytes) {
    _myId = id;
    _myPrivateKey = PrivateKey(privateKeyBytes);
    _myPublicKey = PublicKey(publicKeyBytes);
    _initialized = true;
  }

  bool get isInitialized => _initialized;
  Uint8List get myPublicKeyBytes => _myPublicKey.bytes;

  /// Generate a new key pair for the user
  static Keypair generateKeyPair() {
    return Keypair.generate(KeypairType.ecdsa); // or ed25519 depending on preference
  }

  // --- Secure Session (P2P Forward Secrecy encryption) ---

  /// Encrypt a message for a specific contact using Secure Session
  Future<Uint8List> encryptMessage(String contactId, Uint8List payload) async {
    if (!_initialized) throw Exception("KeyManager not initialized");
    
    final contact = await DatabaseHelper.instance.getContact(contactId);
    if (contact == null) throw Exception("Contact not found");

    final peerPublicKey = PublicKey(contact.publicKey);
    
    // Resume session from state or create new
    final session = SecureSession(
      id: Uint8List.fromList(_myId.codeUnits),
      privateKey: _myPrivateKey,
      callbacks: SecureSessionCallback(
        onGetPublicKeyVersion: (id) => peerPublicKey, // Simple 1:1 mapping mapping for now
      ),
    );

    if (contact.sessionState != null && contact.sessionState!.isNotEmpty) {
      session.restore(contact.sessionState!);
    }

    // If session is not fully established yet, we must generate a connect request
    // However, for typical offline mesh, we assume an initial exchange happens.
    // Let's handle the simplest wrap:
    if (session.state != SecureSessionState.established) {
      // Create connection request 
      final connectRequest = session.connectRequest();
      // For this implementation, we might need a dedicated handshake phase.
      // If we are doing simple 1-packet send, we could use SecureMessage instead.
      // Since architecture requires Secure Session:
      throw Exception("Session not established. Must handshake first.");
    }

    final encrypted = session.encrypt(payload);
    
    // Save state back
    await DatabaseHelper.instance.updateContactSession(contactId, session.save());
    return encrypted;
  }

  /// Decrypt a message from a specific contact using Secure Session
  Future<Uint8List> decryptMessage(String contactId, Uint8List encryptedPayload) async {
    if (!_initialized) throw Exception("KeyManager not initialized");
    
    final contact = await DatabaseHelper.instance.getContact(contactId);
    if (contact == null) throw Exception("Contact not found");

    final peerPublicKey = PublicKey(contact.publicKey);
    final session = SecureSession(
      id: Uint8List.fromList(_myId.codeUnits),
      privateKey: _myPrivateKey,
      callbacks: SecureSessionCallback(
        onGetPublicKeyVersion: (id) => peerPublicKey,
      ),
    );

    if (contact.sessionState != null && contact.sessionState!.isNotEmpty) {
      session.restore(contact.sessionState!);
    }

    // Themis SecureSession decryption
    final decrypted = session.decrypt(encryptedPayload);
    
    await DatabaseHelper.instance.updateContactSession(contactId, session.save());
    return decrypted;
  }

  // --- Handshake Helpers (Since Secure Session needs back-and-forth) ---
  
  /// Create initial connection request to establish a Session
  Future<Uint8List> buildConnectRequest(String contactId) async {
    final contact = await DatabaseHelper.instance.getContact(contactId);
    if (contact == null) throw Exception("Contact not found");
    final session = SecureSession(
      id: Uint8List.fromList(_myId.codeUnits),
      privateKey: _myPrivateKey,
      callbacks: SecureSessionCallback(onGetPublicKeyVersion: (id) => PublicKey(contact.publicKey)),
    );
    final request = session.connectRequest();
    await DatabaseHelper.instance.updateContactSession(contactId, session.save());
    return request;
  }

  /// Process incoming negotiation packet
  Future<Uint8List?> processHandshakeOrDecrypt(String contactId, Uint8List incomingPacket) async {
    final contact = await DatabaseHelper.instance.getContact(contactId);
    if (contact == null) throw Exception("Contact not found");
    
    final session = SecureSession(
      id: Uint8List.fromList(_myId.codeUnits),
      privateKey: _myPrivateKey,
      callbacks: SecureSessionCallback(onGetPublicKeyVersion: (id) => PublicKey(contact.publicKey)),
    );
    if (contact.sessionState != null && contact.sessionState!.isNotEmpty) {
      session.restore(contact.sessionState!);
    }

    final unwrapped = session.unwrap(incomingPacket);
    await DatabaseHelper.instance.updateContactSession(contactId, session.save());
    
    if (unwrapped is UnwrapResultSend) {
      // Need to send this payload back to peer to continue handshake
      return unwrapped.data;
    } else if (unwrapped is UnwrapResultReceive) {
      // Decrypted successfully
      return unwrapped.data;
    }
    return null;
  }

  // --- Secure Cell (Symmetric encryption e.g. for group keys or DB payloads) ---

  /// Encrypt data with a symmetric passphrase (e.g. user PIN derived key)
  Uint8List symmetricEncrypt(String password, Uint8List payload) {
    final cell = SecureCell.sealWithPassphrase(password);
    return cell.encrypt(payload);
  }

  /// Decrypt data with symmetric passphrase
  Uint8List symmetricDecrypt(String password, Uint8List encryptedData) {
    final cell = SecureCell.sealWithPassphrase(password);
    return cell.decrypt(encryptedData);
  }
}
