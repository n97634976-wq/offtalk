import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:share_plus/share_plus.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart' as android_nfc;
import 'package:nfc_manager/nfc_manager_ios.dart' as ios_nfc;
import 'package:ndef_record/ndef_record.dart';
import '../../models/models.dart';
import '../../core/database_helper.dart';
import '../../providers/app_state_provider.dart';
import '../../services/number_registry.dart';

class PairingScreen extends ConsumerStatefulWidget {
  const PairingScreen({super.key});

  @override
  ConsumerState<PairingScreen> createState() => _PairingScreenState();
}
class _PairingScreenState extends ConsumerState<PairingScreen> {
  bool _isScanning = false;
  final MobileScannerController _scannerController = MobileScannerController();
  final _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _startNfcListening();
  }

  void _startNfcListening() async {
    bool isAvailable = await NfcManager.instance.isAvailable();
    if (isAvailable) {
      NfcManager.instance.startSession(
        pollingOptions: {NfcPollingOption.iso14443, NfcPollingOption.iso15693, NfcPollingOption.iso18092},
        onDiscovered: (NfcTag tag) async {
        try {
          dynamic ndef;
          if (Platform.isAndroid) {
            ndef = android_nfc.NdefAndroid.from(tag);
          } else if (Platform.isIOS) {
            ndef = ios_nfc.NdefIos.from(tag);
          }
          if (ndef != null && ndef.cachedMessage != null && ndef.cachedMessage.records.isNotEmpty) {
            String payload =
                utf8.decode(ndef.cachedMessage.records.first.payload);
            _processInviteData(payload);
          }
        } catch (e) {
          print("NFC Error: \$e");
        }
        NfcManager.instance.stopSession();
      });
    }
  }

  void _transmitNfc(String payload) async {
    bool isAvailable = await NfcManager.instance.isAvailable();
    if (isAvailable) {
      NfcManager.instance.startSession(
        pollingOptions: {NfcPollingOption.iso14443, NfcPollingOption.iso15693, NfcPollingOption.iso18092},
        onDiscovered: (NfcTag tag) async {
        dynamic ndef;
        if (Platform.isAndroid) {
          ndef = android_nfc.NdefAndroid.from(tag);
        } else if (Platform.isIOS) {
          ndef = ios_nfc.NdefIos.from(tag);
        }
        if (ndef != null && ndef.isWritable) {
          NdefMessage message = NdefMessage(records: [
            NdefRecord(
              typeNameFormat: TypeNameFormat.media,
              type: Uint8List.fromList(utf8.encode('text/plain')),
              identifier: Uint8List.fromList([]),
              payload: Uint8List.fromList(utf8.encode(payload)),
            )
          ]);
          await ndef.writeNdefMessage(message);
          NfcManager.instance.stopSession();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('NFC transmitted')),
            );
          }
        }
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('NFC not available on this device.')),
        );
      }
    }
  }

  Future<void> _handleScan(BarcodeCapture capture) async {
    for (final barcode in capture.barcodes) {
      if (barcode.rawValue != null) {
        _processInviteData(barcode.rawValue!);
      }
    }
  }

  void _processInviteData(String rawData) async {
    try {
      final data = jsonDecode(rawData);
      if (data['phoneNumber'] == null || data['publicKey'] == null) return;

      _scannerController.stop();

      final phone = data['phoneNumber'] as String;
      final publicKeyBytes = base64Decode(data['publicKey']);
      final simProof = data['simProof'] as String?;

      // Verify SIM proof if provided (prevents impersonation)
      if (simProof != null) {
        final result = NumberRegistry.instance.verifyContact(
          phoneNumber: phone,
          claimedSimProof: simProof,
        );

        if (result == VerificationResult.mismatch && mounted) {
          final proceed = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              icon: const Icon(Icons.warning, color: Colors.red, size: 48),
              title: const Text("⚠️ Identity Mismatch"),
              content: Text(
                'The phone number "$phone" was previously registered by a different SIM card.\n\n'
                'This could indicate impersonation!\n\n'
                'Do you still want to add this contact?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text("Reject"),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text("Add Anyway (Risky)"),
                ),
              ],
            ),
          );
          if (proceed != true) {
            _scannerController.start();
            return;
          }
        }
      }

      // Check for duplicate public key
      try {
        final existingContacts =
            await DatabaseHelper.instance.getAllContacts();
        final duplicateKey = existingContacts.any(
          (c) => c.publicKey != null &&
              _bytesEqual(c.publicKey, publicKeyBytes),
        );
        final duplicatePhone =
            existingContacts.any((c) => c.phoneNumber == phone);

        if ((duplicateKey || duplicatePhone) && mounted) {
          final action = duplicateKey ? "public key" : "phone number";
          final proceed = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              icon: const Icon(Icons.person_add_disabled,
                  color: Colors.orange, size: 48),
              title: const Text("Duplicate Contact"),
              content: Text(
                'A contact with this $action already exists.\n\n'
                'Would you like to update the existing contact?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text("Cancel"),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text("Update"),
                ),
              ],
            ),
          );
          if (proceed != true) {
            _scannerController.start();
            return;
          }
        }
      } catch (_) {}

      final contact = Contact(
        phoneNumber: phone,
        displayName: data['displayName'] ?? phone,
        publicKey: publicKeyBytes,
        lastSeen: DateTime.now().millisecondsSinceEpoch,
      );

      await DatabaseHelper.instance.insertContact(contact);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Added ${contact.displayName} to contacts!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      // invalid payload
    }
  }

  bool _bytesEqual(dynamic a, dynamic b) {
    if (a == null || b == null) return false;
    final listA = a is List<int> ? a : List<int>.from(a);
    final listB = b is List<int> ? b : List<int>.from(b);
    if (listA.length != listB.length) return false;
    for (int i = 0; i < listA.length; i++) {
      if (listA[i] != listB[i]) return false;
    }
    return true;
  }

  void _addByPhone() {
    if (_phoneController.text.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Request sent to ${_phoneController.text} via DHT'),
        ),
      );
      _phoneController.clear();
    }
  }

  @override
  void dispose() {
    _scannerController.dispose();
    NfcManager.instance.stopSession();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider);
    if (profile == null) return const Scaffold(body: SizedBox());

    // Include SIM proof in QR data for verification during pairing
    final qrData = jsonEncode({
      'phoneNumber': profile['phoneNumber'],
      'displayName': profile['displayName'],
      'publicKey': base64Encode(List<int>.from(profile['publicKey'])),
      if (profile['simProof'] != null) 'simProof': profile['simProof'],
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Add Contact')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Scanner Toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Scan QR Code",
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Switch(
                  value: _isScanning,
                  onChanged: (val) {
                    setState(() {
                      _isScanning = val;
                      if (_isScanning) {
                        _scannerController.start();
                      } else {
                        _scannerController.stop();
                      }
                    });
                  },
                ),
              ],
            ),
            if (_isScanning)
              Container(
                height: 300,
                clipBehavior: Clip.hardEdge,
                decoration:
                    BoxDecoration(borderRadius: BorderRadius.circular(16)),
                child: MobileScanner(
                    controller: _scannerController, onDetect: _handleScan),
              )
            else ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16)),
                child: QrImageView(
                    data: qrData, version: QrVersions.auto, size: 200.0),
              ),
              const SizedBox(height: 8),
              const Text("Show QR to scan",
                  style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_user,
                        size: 14, color: Colors.green),
                    SizedBox(width: 4),
                    Text(
                      "SIM-bound identity included",
                      style: TextStyle(fontSize: 11, color: Colors.green),
                    ),
                  ],
                ),
              ),
            ],
            const Divider(height: 48),

            // Link & NFC sharing
            const Text("Invite Options",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.share, size: 32),
                      onPressed: () {
                        Share.share(
                            'Join me on OffTalk! My public ID is: \$qrData');
                      },
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const Text("Share Link"),
                  ],
                ),
                Column(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.nfc, size: 32),
                      onPressed: () => _transmitNfc(qrData),
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const Text("NFC Bump"),
                  ],
                ),
              ],
            ),

            const Divider(height: 48),

            // Number entry
            const Text("Add by Phone Number",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      hintText: "Enter number...",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addByPhone,
                  child: const Text("Request"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
