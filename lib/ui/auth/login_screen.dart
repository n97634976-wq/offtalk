import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_state_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _pinController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _lockoutTimer;
  Duration? _remainingLockout;

  @override
  void initState() {
    super.initState();
    _checkLockoutState();
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    _pinController.dispose();
    super.dispose();
  }

  void _checkLockoutState() {
    final authNotifier = ref.read(authStateProvider.notifier);
    final remaining = authNotifier.remainingLockout;
    if (remaining != null) {
      _startLockoutCountdown(remaining);
    }
  }

  void _startLockoutCountdown(Duration remaining) {
    setState(() {
      _remainingLockout = remaining;
      _errorMessage = null;
    });

    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final authNotifier = ref.read(authStateProvider.notifier);
      final newRemaining = authNotifier.remainingLockout;
      if (newRemaining == null || newRemaining.isNegative) {
        timer.cancel();
        setState(() {
          _remainingLockout = null;
        });
      } else {
        setState(() {
          _remainingLockout = newRemaining;
        });
      }
    });
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    }
    return '${seconds}s';
  }

  void _login() {
    final pin = _pinController.text;
    if (pin.length < 4) {
      setState(() => _errorMessage = "PIN must be at least 4 digits");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = ref.read(authStateProvider.notifier).login(pin);

    setState(() => _isLoading = false);

    switch (result) {
      case LoginResult.success:
        // Auth state will change to authenticated, which triggers
        // the MaterialApp in main.dart to show HomeScreen automatically
        break;

      case LoginResult.wrongPin:
        final attempts = ref.read(authStateProvider.notifier).failedAttempts;
        final attemptsUntilLock = 3 - (attempts % 3);
        _pinController.clear();
        setState(() {
          if (attemptsUntilLock == 3) {
            // Just unlocked from a lockout round, fresh 3 attempts
            _errorMessage = "Incorrect PIN. You have 3 attempts before lockout.";
          } else {
            _errorMessage = "Incorrect PIN. $attemptsUntilLock attempt${attemptsUntilLock == 1 ? '' : 's'} remaining.";
          }
        });
        break;

      case LoginResult.locked:
        _pinController.clear();
        final remaining = ref.read(authStateProvider.notifier).remainingLockout;
        if (remaining != null) {
          _startLockoutCountdown(remaining);
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider);
    final displayName = profile?['displayName'] ?? 'User';
    final isLockedOut = _remainingLockout != null;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                isLockedOut ? Icons.lock_clock : Icons.lock,
                size: 80,
                color: isLockedOut ? Colors.red : const Color(0xFF00A884),
              ),
              const SizedBox(height: 24),
              Text(
                isLockedOut ? "Account Locked" : "Welcome back, $displayName",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isLockedOut ? Colors.red : null,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              if (isLockedOut) ...[
                const Text(
                  "Too many failed attempts",
                  style: TextStyle(fontSize: 16, color: Colors.red),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.timer, size: 48, color: Colors.red),
                      const SizedBox(height: 12),
                      Text(
                        _formatDuration(_remainingLockout!),
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Please wait before trying again",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                const Text(
                  "Enter your PIN to unlock OffTalk",
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                TextField(
                  controller: _pinController,
                  decoration: InputDecoration(
                    labelText: "Encryption PIN",
                    border: const OutlineInputBorder(),
                    errorText: _errorMessage,
                    prefixIcon: const Icon(Icons.pin),
                  ),
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 6,
                  onSubmitted: (_) => _login(),
                  enabled: !_isLoading,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: const Color(0xFF00A884),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text("Unlock", style: TextStyle(fontSize: 16)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
