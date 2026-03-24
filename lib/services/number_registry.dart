import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import '../core/hive_helper.dart';
import 'sim_service.dart';

/// Manages phone number registration and verification using a local-first approach.
/// Phase 1: SIM binding (100% offline, prevents impersonation)
/// Phase 2: DHT registry (requires internet for global uniqueness, defers when offline)
class NumberRegistry {
  static final NumberRegistry instance = NumberRegistry._init();
  NumberRegistry._init();

  bool _isOnline = false;

  /// Register a phone number with SIM proof.
  /// Stores locally first, queues for DHT sync when internet is available.
  Future<RegistrationResult> registerNumber({
    required String phoneNumber,
    required String simProof,
    required Uint8List publicKey,
  }) async {
    final entry = RegistryEntry(
      phoneNumber: phoneNumber,
      simProof: simProof,
      publicKey: publicKey,
      timestamp: DateTime.now(),
    );

    // Always store locally first
    await _storeLocalRegistration(phoneNumber, entry);

    if (_isOnline) {
      // Queue for DHT sync (DHT implementation placeholder)
      // In production: query DHT, check for conflicts, register
      return RegistrationResult.success;
    } else {
      // Store in pending queue for later sync
      await _queuePendingRegistration(phoneNumber, entry);
      return RegistrationResult.pendingSync;
    }
  }

  /// Verify a contact's identity by comparing SIM proofs.
  /// Works 100% offline using locally exchanged proofs.
  VerificationResult verifyContact({
    required String phoneNumber,
    required String claimedSimProof,
  }) {
    final localEntry = _getLocalRegistration(phoneNumber);

    if (localEntry == null) {
      // First time seeing this number - accept and store
      return VerificationResult.unverified;
    }

    if (localEntry.simProof == claimedSimProof) {
      return VerificationResult.verified;
    } else {
      // SIM proof mismatch! Potential impersonation
      return VerificationResult.mismatch;
    }
  }

  /// Check if a phone number is already registered locally
  bool isNumberRegistered(String phoneNumber) {
    final key = _hashPhoneNumber(phoneNumber);
    final data = HiveHelper.instance.getSetting('registry_$key');
    return data != null;
  }

  /// Get local registration for a phone number
  RegistryEntry? _getLocalRegistration(String phoneNumber) {
    final key = _hashPhoneNumber(phoneNumber);
    final data = HiveHelper.instance.getSetting('registry_$key');
    if (data == null) return null;
    return RegistryEntry.fromJson(Map<String, dynamic>.from(data));
  }

  /// Store registration locally
  Future<void> _storeLocalRegistration(
      String phoneNumber, RegistryEntry entry) async {
    final key = _hashPhoneNumber(phoneNumber);
    await HiveHelper.instance.setSetting('registry_$key', entry.toJson());
  }

  /// Queue registration for DHT sync when internet becomes available
  Future<void> _queuePendingRegistration(
      String phoneNumber, RegistryEntry entry) async {
    final pending = HiveHelper.instance.getSetting('pending_registrations');
    final list =
        pending != null ? List<Map<String, dynamic>>.from(pending) : [];
    list.add({
      'phoneNumber': phoneNumber,
      'entry': entry.toJson(),
    });
    await HiveHelper.instance.setSetting('pending_registrations', list);
  }

  /// Sync pending registrations when internet becomes available
  Future<void> syncPendingRegistrations() async {
    if (!_isOnline) return;

    final pending = HiveHelper.instance.getSetting('pending_registrations');
    if (pending == null) return;

    final list = List<Map<String, dynamic>>.from(pending);
    for (final item in list) {
      // DHT registration would happen here in production
      // For now, just mark as synced locally
      final entry = RegistryEntry.fromJson(
          Map<String, dynamic>.from(item['entry']));
      await _storeLocalRegistration(item['phoneNumber'], entry);
    }

    // Clear pending queue
    await HiveHelper.instance.setSetting('pending_registrations', []);
  }

  /// Set online status (called by connectivity monitor)
  void setOnline(bool online) {
    final wasOffline = !_isOnline;
    _isOnline = online;
    if (online && wasOffline) {
      // Just came online, sync pending registrations
      syncPendingRegistrations();
    }
  }

  String _hashPhoneNumber(String phoneNumber) {
    final bytes = utf8.encode(phoneNumber);
    return sha256.convert(bytes).toString().substring(0, 16);
  }
}

/// A registration entry stored locally and in DHT
class RegistryEntry {
  final String phoneNumber;
  final String simProof;
  final Uint8List publicKey;
  final DateTime timestamp;

  RegistryEntry({
    required this.phoneNumber,
    required this.simProof,
    required this.publicKey,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'phoneNumber': phoneNumber,
        'simProof': simProof,
        'publicKey': publicKey.toList(),
        'timestamp': timestamp.millisecondsSinceEpoch,
      };

  factory RegistryEntry.fromJson(Map<String, dynamic> json) => RegistryEntry(
        phoneNumber: json['phoneNumber'],
        simProof: json['simProof'],
        publicKey: Uint8List.fromList(List<int>.from(json['publicKey'])),
        timestamp:
            DateTime.fromMillisecondsSinceEpoch(json['timestamp']),
      );
}

enum RegistrationResult {
  success,
  conflict,
  pendingSync,
}

enum VerificationResult {
  verified,
  mismatch,
  unverified,
}
