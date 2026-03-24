import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_state_provider.dart';
import 'contacts/pairing_screen.dart';
import 'chat/chat_list_screen.dart';
import 'profile/profile_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('OffTalk'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PairingScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              ref.read(authStateProvider.notifier).logout();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildBody()),
          Container(
            width: double.infinity,
            color: Theme.of(context).colorScheme.surfaceVariant,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: const Text(
              "OffTalk Beta v1.0.0",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: "Chats"),
          BottomNavigationBarItem(icon: Icon(Icons.hub), label: "Mesh"),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: "Map"),
        ],
      ),
      floatingActionButton: _currentIndex == 0 ? FloatingActionButton(
        onPressed: () {
          // TODO: select contact to chat
        },
        child: const Icon(Icons.message),
      ) : null,
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return const ChatListScreen();
      case 1:
        return const Center(child: Text("Mesh Monitor (Coming soon)"));
      case 2:
        return const Center(child: Text("Map (Coming soon)"));
      default:
        return const SizedBox.shrink();
    }
  }
}
