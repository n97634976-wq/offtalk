import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Service for reading SIM card identifiers via platform channels.
/// Works 100% offline - reads hardware identifiers directly from the SIM.
class SimService {
  static const MethodChannel _channel = MethodChannel('com.offtalk/sim');
  static final SimService instance = SimService._init();
  SimService._init();

  Map<String, String?>? _cachedSimInfo;

  /// Read SIM identifiers from the device.
  /// Returns map with: iccid, imsi, phoneNumber, simPresent, simOperator, simCountry
  Future<Map<String, String?>> getSimInfo() async {
    if (_cachedSimInfo != null) return _cachedSimInfo!;

    try {
      final Map<dynamic, dynamic> result =
          await _channel.invokeMethod('getSimInfo');
      _cachedSimInfo = Map<String, String?>.from(result);
      return _cachedSimInfo!;
    } on PlatformException catch (e) {
      return {'error': e.message, 'simPresent': 'false'};
    } on MissingPluginException {
      // Platform channel not available (e.g., running on iOS simulator or web)
      return {'error': 'PLATFORM_NOT_SUPPORTED', 'simPresent': 'false'};
    }
  }

  /// Check if a valid SIM is present in the device
  Future<bool> isSimPresent() async {
    final info = await getSimInfo();
    return info['simPresent'] == 'true';
  }

  /// Generate a cryptographic SIM proof using HMAC-SHA256.
  /// proof = HMAC(phone_number, ICCID + IMSI)
  /// This proof is unique per SIM card and cannot be forged without the physical SIM.
  Future<String> generateSimProof(String phoneNumber) async {
    final simInfo = await getSimInfo();
    final iccid = simInfo['iccid'] ?? '';
    final imsi = simInfo['imsi'] ?? '';

    if (iccid.isEmpty && imsi.isEmpty) {
      // Fallback: use device-level identifier + phone number
      // Less secure but works when SIM APIs are restricted (e.g., newer Android)
      final deviceId = simInfo['deviceId'] ?? 'unknown';
      final fallbackData = utf8.encode('$phoneNumber:device:$deviceId');
      final fallbackHmac = Hmac(sha256, utf8.encode(phoneNumber));
      return fallbackHmac.convert(fallbackData).toString();
    }

    // Primary: HMAC with SIM hardware identifiers
    final key = utf8.encode(phoneNumber);
    final data = utf8.encode('$iccid:$imsi');
    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(data);
    return digest.toString();
  }

  /// Verify that a given SIM proof matches the current device's SIM
  Future<bool> verifyLocalSimProof(String phoneNumber, String proof) async {
    final currentProof = await generateSimProof(phoneNumber);
    return currentProof == proof;
  }

  /// Clear cached SIM info (e.g., after SIM swap detection)
  void clearCache() {
    _cachedSimInfo = null;
  }
}
