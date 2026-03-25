import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/hive_helper.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _darkMode = false;
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;
  bool _screenshotProtection = false;
  String _selectedLanguage = 'en';

  @override
  void initState() {
    super.initState();
    _darkMode = HiveHelper.instance.getSetting('darkMode', defaultValue: false);
    _selectedLanguage = HiveHelper.instance.getSetting('language', defaultValue: 'en');
    _biometricEnabled = HiveHelper.instance.getSetting('biometricEnabled', defaultValue: false);
    _screenshotProtection = HiveHelper.instance.getSetting('screenshotProtection', defaultValue: false);
    _checkBiometricSupport();
  }

  Future<void> _checkBiometricSupport() async {
    try {
      final auth = LocalAuthentication();
      final canCheck = await auth.canCheckBiometrics;
      final isSupported = await auth.isDeviceSupported();
      setState(() => _biometricAvailable = canCheck && isSupported);
    } catch (_) {}
  }

  void _toggleDarkMode(bool value) async {
    setState(() => _darkMode = value);
    await HiveHelper.instance.setSetting('darkMode', value);
    // Force rebuild to pick up theme change
    ref.invalidate(themeModeProvider);
  }

  void _toggleBiometric(bool value) async {
    if (value) {
      // Verify biometric before enabling
      final auth = LocalAuthentication();
      try {
        final authenticated = await auth.authenticate(
          localizedReason: 'Verify your identity to enable biometric unlock',
          options: const AuthenticationOptions(stickyAuth: true, biometricOnly: true),
        );
        if (!authenticated) return;
      } catch (_) {
        return;
      }
    }
    setState(() => _biometricEnabled = value);
    await HiveHelper.instance.setSetting('biometricEnabled', value);
  }

  void _toggleScreenshotProtection(bool value) async {
    setState(() => _screenshotProtection = value);
    await HiveHelper.instance.setSetting('screenshotProtection', value);
    // Note: FLAG_SECURE needs a platform channel to take effect at runtime
  }

  void _changeLanguage(String langCode) async {
    setState(() => _selectedLanguage = langCode);
    await HiveHelper.instance.setSetting('language', langCode);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: ListView(
        children: [
          // ── Appearance ──
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text("Appearance", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          SwitchListTile(
            title: const Text("Dark Mode"),
            subtitle: const Text("Switch between light and dark theme"),
            secondary: const Icon(Icons.dark_mode),
            value: _darkMode,
            onChanged: _toggleDarkMode,
          ),
          ListTile(
            title: const Text("Language"),
            subtitle: Text(_selectedLanguage.toUpperCase()),
            leading: const Icon(Icons.language),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => SimpleDialog(
                  title: const Text('Select Language'),
                  children: [
                    SimpleDialogOption(onPressed: () { _changeLanguage('en'); Navigator.pop(context); }, child: const Text('English')),
                    SimpleDialogOption(onPressed: () { _changeLanguage('hi'); Navigator.pop(context); }, child: const Text('Hindi')),
                    SimpleDialogOption(onPressed: () { _changeLanguage('ml'); Navigator.pop(context); }, child: const Text('Malayalam')),
                    SimpleDialogOption(onPressed: () { _changeLanguage('ta'); Navigator.pop(context); }, child: const Text('Tamil')),
                    SimpleDialogOption(onPressed: () { _changeLanguage('bn'); Navigator.pop(context); }, child: const Text('Bengali')),
                  ],
                ),
              );
            },
          ),
          const Divider(),

          // ── Security ──
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text("Security", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          if (_biometricAvailable)
            SwitchListTile(
              title: const Text("Biometric Unlock"),
              subtitle: const Text("Use fingerprint or face to unlock"),
              secondary: const Icon(Icons.fingerprint),
              value: _biometricEnabled,
              onChanged: _toggleBiometric,
            ),
          SwitchListTile(
            title: const Text("Screenshot Protection"),
            subtitle: const Text("Prevent screenshots in chats"),
            secondary: const Icon(Icons.screenshot),
            value: _screenshotProtection,
            onChanged: _toggleScreenshotProtection,
          ),
          const Divider(),

          // ── Data ──
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text("Data", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          ListTile(
            title: const Text("Encrypted Backup"),
            subtitle: const Text("Export your keys and chats securely"),
            leading: const Icon(Icons.backup),
            onTap: () {},
          ),
          ListTile(
            title: const Text("Restore Backup"),
            leading: const Icon(Icons.restore),
            onTap: () {},
          ),
          const Divider(),

          // ── Support ──
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text("Support", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          ListTile(
            title: const Text("Report a Bug"),
            subtitle: const Text("n97634976.wq@gmail.com"),
            leading: const Icon(Icons.bug_report, color: Colors.red),
            onTap: () async {
              final uri = Uri(
                scheme: 'mailto',
                path: 'n97634976.wq@gmail.com',
                query: 'subject=OffTalk Bug Report&body=Describe the bug here...',
              );
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
              }
            },
          ),
          ListTile(
            title: const Text("GitHub Repository"),
            subtitle: const Text("n97634976-wq/offtalk"),
            leading: const Icon(Icons.code),
            onTap: () async {
              final uri = Uri.parse('https://github.com/n97634976-wq/offtalk');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),
        ],
      ),
    );
  }
}

/// Provider to read the dark mode setting reactively
final themeModeProvider = Provider<ThemeMode>((ref) {
  final isDark = HiveHelper.instance.getSetting('darkMode', defaultValue: false);
  return isDark == true ? ThemeMode.dark : ThemeMode.light;
});
