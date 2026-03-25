import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:local_auth/local_auth.dart';
import '../core/hive_helper.dart';
import '../core/database_helper.dart';
import '../core/key_manager.dart';
import '../providers/app_state_provider.dart';
import '../services/sim_service.dart';
import '../services/number_registry.dart';
import 'home_screen.dart';
import 'dart:typed_data';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _step = 0;
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  final _pinController = TextEditingController();

  bool _isLoading = false;
  bool _simDetected = false;
  String? _simStatus;

  void _nextStep() => setState(() => _step++);

  Future<void> _requestPermissions() async {
    await [
      Permission.bluetooth,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.location,
      Permission.camera,
      Permission.microphone,
      Permission.phone, // Required for SIM reading on Android
    ].request();

    // Check SIM after permissions granted
    await _detectSim();
    _nextStep();
  }

  Future<void> _detectSim() async {
    try {
      final simPresent = await SimService.instance.isSimPresent();
      final simInfo = await SimService.instance.getSimInfo();
      setState(() {
        _simDetected = simPresent;
        if (simPresent) {
          _simStatus = '✅ SIM detected (${simInfo['simOperator'] ?? 'Unknown carrier'})';
          // Auto-fill phone number if available
          if (simInfo['phoneNumber'] != null && simInfo['phoneNumber']!.isNotEmpty) {
            _phoneController.text = simInfo['phoneNumber']!;
          }
        } else {
          _simStatus = '⚠️ No SIM detected. Identity binding will use device ID.';
        }
      });
    } catch (_) {
      setState(() {
        _simDetected = false;
        _simStatus = '⚠️ Could not read SIM. Identity binding will use device ID.';
      });
    }
  }

  Future<void> _completeOnboarding() async {
    final phone = _phoneController.text.trim();
    final name = _nameController.text.trim();
    final pin = _pinController.text;

    if (phone.isEmpty) {
      _showError("Please enter your phone number");
      return;
    }
    if (name.isEmpty) {
      _showError("Please enter your display name");
      return;
    }
    if (pin.length < 4) {
      _showError("PIN must be at least 4 digits");
      return;
    }

    setState(() => _isLoading = true);

    // Check for duplicate phone number in existing contacts
    try {
      final existingContacts = await DatabaseHelper.instance.getAllContacts();
      final duplicate = existingContacts.any((c) => c.phoneNumber == phone);
      if (duplicate && context.mounted) {
        setState(() => _isLoading = false);
        final proceed = await _showDuplicateDialog(phone);
        if (proceed != true) return;
        setState(() => _isLoading = true);
      }
    } catch (_) {
      // DB not initialized yet during first onboarding, skip check
    }

    // Generate SIM proof for identity binding
    String simProof;
    try {
      simProof = await SimService.instance.generateSimProof(phone);
    } catch (_) {
      simProof = AuthNotifier.hashPin('$phone:${DateTime.now().millisecondsSinceEpoch}');
    }

    // Generate keys
    final keypair = await KeyManager.generateKeyPair();
    final hashedPin = AuthNotifier.hashPin(pin);

    final profile = {
      'phoneNumber': phone,
      'displayName': name,
      'pin': hashedPin,
      'simProof': simProof,
      'privateKey': keypair.privateKey.toList(),
      'publicKey': keypair.publicKey.toList(),
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    };

    // Save to Hive
    await HiveHelper.instance.setSetting('profile', profile);

    // Register in local number registry (queues for DHT sync when online)
    await NumberRegistry.instance.registerNumber(
      phoneNumber: phone,
      simProof: simProof,
      publicKey: keypair.publicKey,
    );

    // Init DB password (use raw PIN for SQLCipher)
    DatabaseHelper.instance.setPassword(pin);
    // Init KeyManager
    KeyManager.instance.init(
      phone,
      keypair.privateKey,
      keypair.publicKey,
    );

    setState(() => _isLoading = false);

    ref.read(authStateProvider.notifier).onboardingComplete();

    if (context.mounted) {
      // Ask for Biometric Unlock if supported
      try {
        final localAuth = LocalAuthentication();
        final canCheck = await localAuth.canCheckBiometrics;
        final isSupported = await localAuth.isDeviceSupported();
        if (canCheck && isSupported && context.mounted) {
           final enableBiometrics = await showDialog<bool>(
             context: context,
             builder: (_) => AlertDialog(
               title: const Text("Enable Biometric Unlock?"),
               content: const Text("Would you like to unlock OffTalk using your fingerprint or Face ID instead of typing your PIN every time?"),
               actions: [
                 TextButton(
                   onPressed: () => Navigator.pop(context, false),
                   child: const Text("No thanks"),
                 ),
                 TextButton(
                   onPressed: () => Navigator.pop(context, true),
                   child: const Text("Yes, Enable"),
                 ),
               ],
             ),
           );
           if (enableBiometrics == true) {
             await HiveHelper.instance.setSetting('biometricEnabled', true);
             await HiveHelper.instance.setSetting('biometric_pin', pin); // store raw pin for unlocking later
           }
        }
      } catch (_) {}

      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      }
    }
  }

  void _showError(String msg) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<bool?> _showDuplicateDialog(String phone) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Duplicate Identity"),
        content: Text(
          'Phone "$phone" already exists locally.\n'
          'This could mean impersonation on the mesh.\n\n'
          'Continue anyway?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Continue Anyway"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              const Icon(Icons.hub, size: 80, color: Color(0xFF00A884)),
              const SizedBox(height: 24),
              const Text(
                "Welcome to OffTalk",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                "Secure, serverless messaging",
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              if (_step == 0) ...[
                const Text(
                  "OffTalk requires Bluetooth, Location, and other permissions to build the peer-to-peer mesh network.",
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _requestPermissions,
                  icon: const Icon(Icons.security),
                  label: const Text("Grant Permissions"),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: const Color(0xFF00A884),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],

              if (_step == 1) ...[
                // SIM status indicator
                if (_simStatus != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _simDetected
                          ? Colors.green.withOpacity(0.1)
                          : Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _simDetected
                            ? Colors.green.withOpacity(0.3)
                            : Colors.orange.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _simDetected ? Icons.sim_card : Icons.sim_card_alert,
                          color: _simDetected ? Colors.green : Colors.orange,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _simStatus!,
                            style: TextStyle(
                              fontSize: 13,
                              color: _simDetected ? Colors.green : Colors.orange,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                TextField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: "Phone Number",
                    hintText: "+91 98765 43210",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: "Display Name",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _pinController,
                  decoration: const InputDecoration(
                    labelText: "Encryption PIN (4-6 digits)",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.pin),
                  ),
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 6,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.blue),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Your identity is bound to your SIM card. This prevents impersonation on the mesh network.",
                          style: TextStyle(fontSize: 12, color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _completeOnboarding,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: const Color(0xFF00A884),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text("Get Started", style: TextStyle(fontSize: 16)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
