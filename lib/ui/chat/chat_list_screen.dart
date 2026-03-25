import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/chat_providers.dart';
import '../../models/models.dart';
import 'chat_screen.dart';
import 'package:intl/intl.dart';

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  String _searchQuery = '';
  bool _isSearching = false;

  @override
  Widget build(BuildContext context) {
    final chatsAsync = ref.watch(chatsProvider);
    final contactsAsync = ref.watch(contactsProvider);

    return Column(
      children: [
        // ── Search Bar ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: TextField(
            onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
            onTap: () => setState(() => _isSearching = true),
            decoration: InputDecoration(
              hintText: 'Search chats...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _isSearching
                  ? IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() {
                        _searchQuery = '';
                        _isSearching = false;
                        FocusScope.of(context).unfocus();
                      }),
                    )
                  : null,
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
          ),
        ),

        // ── Chat List ──
        Expanded(
          child: chatsAsync.when(
            data: (chats) {
              if (chats.isEmpty) {
                return const Center(
                  child: Text("No chats yet. Add a contact or scan a QR to start messaging."),
                );
              }

              return contactsAsync.when(
                data: (contacts) {
                  // Filter chats by search query
                  final displayChats = chats.where((chat) {
                    if (_searchQuery.isEmpty) return true;
                    final contact = contacts.firstWhere(
                      (c) => c.phoneNumber == chat.id,
                      orElse: () => Contact(phoneNumber: chat.id, displayName: 'Unknown', publicKey: Uint8List.fromList([]), lastSeen: 0),
                    );
                    return contact.displayName.toLowerCase().contains(_searchQuery) ||
                        contact.phoneNumber.toLowerCase().contains(_searchQuery);
                  }).toList();

                  if (displayChats.isEmpty) {
                    return const Center(child: Text("No matching chats found."));
                  }

                  return ListView.builder(
                    itemCount: displayChats.length,
                    itemBuilder: (context, index) {
                      final chat = displayChats[index];
                      final contact = contacts.firstWhere(
                        (c) => c.phoneNumber == chat.id,
                        orElse: () => Contact(phoneNumber: chat.id, displayName: 'Unknown', publicKey: Uint8List.fromList([]), lastSeen: 0),
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
                                  '${chat.unreadCount}',
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
                error: (e, st) => Center(child: Text('Error loading contacts: $e')),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('Error loading chats: $e')),
          ),
        ),
      ],
    );
  }
}
