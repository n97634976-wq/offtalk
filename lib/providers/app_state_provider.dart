import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/database_helper.dart';
import '../core/hive_helper.dart';
import '../core/key_manager.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'package:crypto/crypto.dart';

enum AuthState {
  loading,
  unauthenticated, // No profile exists (needs onboarding)
  locked,          // Profile exists, but DB/keys are locked (needs PIN)
  authenticated,   // User is fully logged in
}

enum LoginResult {
  success,
  wrongPin,
  locked,
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(AuthState.loading) {
    _init();
  }

  int _failedAttempts = 0;
  DateTime? _lockoutUntil;

  void _init() {
    final profile = HiveHelper.instance.getSetting('profile');
    if (profile != null) {
      // Restore lockout state from Hive
      final lockoutData = HiveHelper.instance.getSetting('lockout_state');
      if (lockoutData != null) {
        _failedAttempts = lockoutData['failedAttempts'] ?? 0;
        final lockoutMs = lockoutData['lockoutUntil'];
        if (lockoutMs != null && lockoutMs > 0) {
          _lockoutUntil = DateTime.fromMillisecondsSinceEpoch(lockoutMs);
          // Check if lockout has expired
          if (DateTime.now().isAfter(_lockoutUntil!)) {
            _lockoutUntil = null;
            // Keep failed attempts count so next failure escalates
          }
        }
      }
      state = AuthState.locked;
    } else {
      state = AuthState.unauthenticated;
    }
  }

  /// Hash PIN using SHA-256 for secure storage comparison
  static String hashPin(String pin) {
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Get remaining lockout duration (null if not locked out)
  Duration? get remainingLockout {
    if (_lockoutUntil == null) return null;
    final remaining = _lockoutUntil!.difference(DateTime.now());
    if (remaining.isNegative) {
      _lockoutUntil = null;
      return null;
    }
    return remaining;
  }

  /// Get number of failed attempts
  int get failedAttempts => _failedAttempts;

  /// Calculate lockout duration based on number of failures
  /// 3 failures = 30 min, 6 = 60 min, 9 = 120 min, etc.
  Duration _getLockoutDuration(int attempts) {
    final lockoutRounds = (attempts / 3).floor(); // 1, 2, 3, ...
    if (lockoutRounds <= 0) return Duration.zero;
    // 30 min * 2^(round-1) → 30, 60, 120, 240, ...
    final minutes = 30 * (1 << (lockoutRounds - 1));
    return Duration(minutes: minutes);
  }

  /// Persist lockout state to Hive so app restart doesn't bypass it
  Future<void> _persistLockoutState() async {
    await HiveHelper.instance.setSetting('lockout_state', {
      'failedAttempts': _failedAttempts,
      'lockoutUntil': _lockoutUntil?.millisecondsSinceEpoch ?? 0,
    });
  }

  LoginResult login(String pin) {
    // Check if currently locked out
    if (_lockoutUntil != null && DateTime.now().isBefore(_lockoutUntil!)) {
      return LoginResult.locked;
    }

    final profile = HiveHelper.instance.getSetting('profile');
    if (profile == null) return LoginResult.wrongPin;

    // Compare PIN: support both hashed and legacy plain-text PINs
    final storedPin = profile['pin'] as String;
    final inputHash = hashPin(pin);
    final isCorrect = (storedPin == inputHash) || (storedPin == pin);

    if (!isCorrect) {
      _failedAttempts++;

      // Check if we've hit a lockout threshold (every 3 failures)
      if (_failedAttempts % 3 == 0) {
        final lockoutDuration = _getLockoutDuration(_failedAttempts);
        _lockoutUntil = DateTime.now().add(lockoutDuration);
      }

      _persistLockoutState();
      return _lockoutUntil != null && DateTime.now().isBefore(_lockoutUntil!)
          ? LoginResult.locked
          : LoginResult.wrongPin;
    }

    // Success! Reset lockout state
    _failedAttempts = 0;
    _lockoutUntil = null;
    _persistLockoutState();

    // Store raw PIN for biometric unlock (secured by Hive encryption)
    HiveHelper.instance.setSetting('biometric_pin', pin);

    // PIN is correct, unlock DB and KeyManager
    DatabaseHelper.instance.setPassword(pin);

    final privateKeyList = List<int>.from(profile['privateKey']);
    final publicKeyList = List<int>.from(profile['publicKey']);
    
    KeyManager.instance.init(
      profile['phoneNumber'],
      _toUint8List(privateKeyList),
      _toUint8List(publicKeyList),
    );

    state = AuthState.authenticated;
    return LoginResult.success;
  }

  void logout() {
    DatabaseHelper.instance.setPassword(""); 
    state = AuthState.locked;
  }

  void onboardingComplete() {
    state = AuthState.authenticated;
  }
}

final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

final userProfileProvider = Provider<Map<String, dynamic>?>((ref) {
  final profile = HiveHelper.instance.getSetting('profile');
  if (profile == null) return null;
  return Map<String, dynamic>.from(profile);
});

Uint8List _toUint8List(List<int> list) {
  final byteData = ByteData(list.length);
  for (var i = 0; i < list.length; i++) {
    byteData.setUint8(i, list[i]);
  }
  return byteData.buffer.asUint8List();
}
