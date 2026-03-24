import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../providers/chat_providers.dart';
import '../../providers/app_state_provider.dart';
import '../../core/database_helper.dart';
import '../../models/models.dart';
import '../../core/key_manager.dart';
import '../../network/packet_router.dart';
import 'dart:convert';
import 'dart:typed_data';

class ChatScreen extends ConsumerStatefulWidget {
  final String chatId;
  final String contactName;

  const ChatScreen({super.key, required this.chatId, required this.contactName});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageController = TextEditingController();
  bool _isWriting = false;

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    setState(() => _isWriting = false);

    final profile = ref.read(userProfileProvider);
    if (profile == null) return;

    final myId = profile['phoneNumber'] as String;
    final msgId = const Uuid().v4();

    // The text will be wrapped and encrypted.
    // For this demonstration, we simulate the encryption.
    final payload = utf8.encode(text);
    final encrypted = await KeyManager.instance.encryptMessage(widget.chatId, Uint8List.fromList(payload));
    
    // In a full implementation, the `Message` object only stores metadata and text locally
    // but the `encrypted_payload` is stored in DB to be sent to the peer.
    final msg = Message(
      id: msgId,
      chatId: widget.chatId,
      senderId: myId,
      text: text,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      direction: 0, // 0 = sent
      deliveryStatus: 0, // 0 = pending
    );

    // Save message locally
    await DatabaseHelper.instance.insertMessage(msg, []); 
    
    // Update chat last message
    await DatabaseHelper.instance.insertChat(Chat(
      id: widget.chatId,
      type: 0,
      lastMessageId: msgId,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    ));

    // Force Riverpod to refresh the messages provider for this chat
    ref.invalidate(messagesProvider(widget.chatId));

    // Hand off to PacketRouter
    PacketRouter.instance.routeMessage(widget.chatId, encrypted);
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(messagesProvider(widget.chatId));

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white24,
              child: Text(
                widget.contactName.isNotEmpty ? widget.contactName[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(width: 8),
            Text(widget.contactName),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.videocam), onPressed: () {}),
          IconButton(icon: const Icon(Icons.call), onPressed: () {}),
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              data: (messages) {
                if (messages.isEmpty) {
                  return const Center(child: Text("Say hi! End-to-end encrypted."));
                }
                return ListView.builder(
                  reverse: true, // typical for chat list showing newest at bottom
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[messages.length - 1 - index];
                    final isMe = msg.direction == 0;
                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        decoration: BoxDecoration(
                          color: isMe ? const Color(0xFF005C4B) : const Color(0xFF202C33), // WhatsApp dark chat bubbles
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              msg.text.isNotEmpty ? msg.text : "[Encrypted/Media Payload]", 
                              style: const TextStyle(color: Colors.white, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  DateFormat.Hm().format(DateTime.fromMillisecondsSinceEpoch(msg.timestamp)),
                                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                                ),
                                if (isMe) ...[
                                  const SizedBox(width: 4),
                                  Icon(
                                    msg.deliveryStatus == 0 ? Icons.schedule : 
                                    msg.deliveryStatus == 1 ? Icons.check : 
                                    Icons.done_all,
                                    size: 14,
                                    color: msg.deliveryStatus == 3 ? Colors.blue : Colors.white54,
                                  ),
                                ]
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error: \$e')),
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark 
                    ? const Color(0xFF2A3942) 
                    : Colors.grey[200],
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.emoji_emotions_outlined),
                    color: Colors.grey,
                    onPressed: () {},
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      maxLines: 4,
                      minLines: 1,
                      onChanged: (val) {
                        setState(() {
                          _isWriting = val.isNotEmpty;
                        });
                      },
                      decoration: const InputDecoration(
                        hintText: "Message",
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.attach_file),
                    color: Colors.grey,
                    onPressed: () {
                      // Show bottom sheet for images/files/location
                    },
                  ),
                  if (!_isWriting)
                    IconButton(
                      icon: const Icon(Icons.camera_alt),
                      color: Colors.grey,
                      onPressed: () {},
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: const Color(0xFF00A884),
            radius: 24,
            child: IconButton(
              icon: Icon(_isWriting ? Icons.send : Icons.mic),
              color: Colors.white,
              onPressed: _isWriting ? _sendMessage : null, // Future: Handle voice recording
            ),
          ),
        ],
      ),
    );
  }
}
