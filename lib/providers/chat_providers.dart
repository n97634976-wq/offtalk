import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/database_helper.dart';
import '../models/models.dart';

final chatsProvider = FutureProvider<List<Chat>>((ref) async {
  return await DatabaseHelper.instance.getAllChats();
});

final contactsProvider = FutureProvider<List<Contact>>((ref) async {
  return await DatabaseHelper.instance.getAllContacts();
});

// A family provider to fetch messages for a specific chat ID
final messagesProvider = FutureProvider.family<List<Message>, String>((ref, chatId) async {
  final maps = await DatabaseHelper.instance.getMessagesForChat(chatId);
  return maps.map((m) => Message(
    id: m['id'],
    chatId: m['chat_id'],
    senderId: m['sender_id'],
    text: '', // Text needs decryption, for now keeping Empty to show flow.
              // A real implementation would decrypt the `encrypted_payload` here via KeyManager.
    timestamp: m['timestamp'],
    direction: m['direction'],
    deliveryStatus: m['delivery_status'],
    mediaPath: m['media_path'],
    mediaType: m['media_type'],
    ttl: m['ttl'],
  )).toList();
});
