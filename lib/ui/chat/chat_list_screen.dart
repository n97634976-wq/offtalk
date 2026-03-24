import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/chat_providers.dart';
import 'chat_screen.dart';
import 'package:intl/intl.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatsAsync = ref.watch(chatsProvider);
    final contactsAsync = ref.watch(contactsProvider);

    return chatsAsync.when(
      data: (chats) {
        if (chats.isEmpty) {
          return const Center(
            child: Text("No chats yet. Add a contact or scan a QR to start messaging."),
          );
        }

        return contactsAsync.when(
          data: (contacts) {
            return ListView.builder(
              itemCount: chats.length,
              itemBuilder: (context, index) {
                final chat = chats[index];
                
                // Find contact info. If group, handle differently (not fully implemented in models yet)
                final contact = contacts.firstWhere(
                  (c) => c.phoneNumber == chat.id, 
                  orElse: () => Contact(phoneNumber: chat.id, displayName: 'Unknown', publicKey: [], lastSeen: 0)
                );

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: Text(
                      contact.displayName.isNotEmpty ? contact.displayName[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(contact.displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(chat.lastMessageId != null ? "Last message..." : "No messages yet"),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        DateFormat.Hm().format(DateTime.fromMillisecondsSinceEpoch(chat.createdAt)),
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      if (chat.unreadCount > 0)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '\${chat.unreadCount}',
                            style: const TextStyle(color: Colors.white, fontSize: 10),
                          ),
                        ),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(chatId: chat.id, contactName: contact.displayName),
                      ),
                    );
                  },
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(child: Text('Error loading contacts: \$e')),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error loading chats: \$e')),
    );
  }
}
