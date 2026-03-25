import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import '../../providers/app_state_provider.dart';
import '../../core/hive_helper.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    if (profile == null) return const Scaffold(body: Center(child: Text("No Profile")));

    final phoneNumber = profile['phoneNumber'] ?? '';
    final displayName = profile['displayName'] ?? '';
    final publicKeyBytes = List<int>.from(profile['publicKey']);
    final publicKeyBase64 = base64Encode(publicKeyBytes);
    final simProof = profile['simProof'];
    final hasSim = simProof != null && simProof.toString().isNotEmpty;

    final qrData = jsonEncode({
      'phoneNumber': phoneNumber,
      'displayName': displayName,
      'publicKey': publicKeyBase64,
      if (hasSim) 'simProof': simProof,
    });

    return Scaffold(
      appBar: AppBar(title: const Text("My Profile")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Text(
                displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                style: const TextStyle(fontSize: 40, color: Colors.white),
              ),
            ),
            const SizedBox(height: 16),
            Text(displayName, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(phoneNumber, style: const TextStyle(fontSize: 18, color: Colors.grey)),

            // SIM Binding Status Badge
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: hasSim
                    ? Colors.green.withOpacity(0.1)
                    : Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: hasSim
                      ? Colors.green.withOpacity(0.3)
                      : Colors.orange.withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    hasSim ? Icons.verified_user : Icons.shield_outlined,
                    size: 16,
                    color: hasSim ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    hasSim ? "SIM-Bound Identity ✓" : "Device-Only Identity",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: hasSim ? Colors.green : Colors.orange,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 200.0,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            const Text("Scan this to add me on OffTalk", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 32),
            ListTile(
              title: const Text("Public Key"),
              subtitle: Text(
                publicKeyBase64,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: IconButton(
                icon: const Icon(Icons.copy),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: publicKeyBase64));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Public key copied to clipboard!"),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),

            // ── Support & Report Section ──
            const Text(
              "Support & Feedback",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.bug_report, color: Colors.red),
                title: const Text("Report a Bug"),
                subtitle: const Text("n97634976.wq@gmail.com"),
                onTap: () async {
                  final uri = Uri(
                    scheme: 'mailto',
                    path: 'n97634976.wq@gmail.com',
                    query: 'subject=OffTalk Bug Report&body=Please describe the issue:',
                  );
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  }
                },
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.favorite, color: Colors.pink),
                title: const Text("Help Build OffTalk"),
                subtitle: const Text("Contribute on GitHub"),
                onTap: () async {
                  final uri = Uri.parse('https://github.com/n97634976-wq/offtalk');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
            ),

            const SizedBox(height: 24),
            Text(
              "OffTalk v1.0.0-beta",
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }
}
