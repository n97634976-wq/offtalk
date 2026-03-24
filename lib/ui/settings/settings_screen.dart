import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/hive_helper.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _darkMode = false;
  String _selectedLanguage = 'en';

  @override
  void initState() {
    super.initState();
    _darkMode = HiveHelper.instance.getSetting('darkMode', defaultValue: false);
    _selectedLanguage = HiveHelper.instance.getSetting('language', defaultValue: 'en');
  }

  void _toggleDarkMode(bool value) async {
    setState(() => _darkMode = value);
    await HiveHelper.instance.setSetting('darkMode', value);
    // TODO: Notify Theme Provider
  }

  void _changeLanguage(String langCode) async {
    setState(() => _selectedLanguage = langCode);
    await HiveHelper.instance.setSetting('language', langCode);
    // TODO: Notify Locale Provider
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text("Dark Mode"),
            value: _darkMode,
            onChanged: _toggleDarkMode,
          ),
          ListTile(
            title: const Text("Language"),
            subtitle: Text(_selectedLanguage.toUpperCase()),
            trailing: const Icon(Icons.language),
            onTap: () {
              // Show dialog to pick language (English, Hindi, Malayalam, Tamil, Bengali)
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
          ListTile(
            title: const Text("Encrypted Backup"),
            subtitle: const Text("Export your keys and chats securely"),
            leading: const Icon(Icons.backup),
            onTap: () {
              // TODO: Backup logic
            },
          ),
          ListTile(
            title: const Text("Restore Backup"),
            leading: const Icon(Icons.restore),
            onTap: () {
              // TODO: Restore logic
            },
          ),
        ],
      ),
    );
  }
}
