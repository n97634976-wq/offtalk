import 'dart:async';
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
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String chatId;
  final String contactName;

  const ChatScreen({super.key, required this.chatId, required this.contactName});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isWriting = false;
  bool _emojiShowing = false;
  int _selectedTtl = 0; // 0 = no self-destruct
  bool _isBlocked = false;
  Timer? _expiryTimer;

  final List<int> _ttlOptions = [0, 5, 30, 60, 300]; // seconds
  final Map<int, String> _ttlLabels = {
    0: 'Off',
    5: '5s',
    30: '30s',
    60: '1m',
    300: '5m',
  };

  @override
  void initState() {
    super.initState();
    _checkBlockStatus();
    _startExpiryTimer();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        setState(() => _emojiShowing = false);
      }
    });
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    _messageController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startExpiryTimer() {
    _expiryTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      try {
        await DatabaseHelper.instance.deleteExpiredMessages();
        if (mounted) {
          ref.invalidate(messagesProvider(widget.chatId));
        }
      } catch (_) {}
    });
  }

  Future<void> _checkBlockStatus() async {
    try {
      final blocked = await DatabaseHelper.instance.isContactBlocked(widget.chatId);
      if (mounted) setState(() => _isBlocked = blocked);
    } catch (_) {}
  }

  Future<void> _toggleBlock() async {
    try {
      if (_isBlocked) {
        await DatabaseHelper.instance.unblockContact(widget.chatId);
      } else {
        await DatabaseHelper.instance.blockContact(widget.chatId);
      }
      setState(() => _isBlocked = !_isBlocked);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isBlocked
                ? '🚫 ${widget.contactName} blocked'
                : '✅ ${widget.contactName} unblocked'),
            backgroundColor: _isBlocked ? Colors.red : Colors.green,
          ),
        );
      }
    } catch (_) {}
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    if (_isBlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Unblock this contact to send messages.")),
      );
      return;
    }

    _messageController.clear();
    setState(() => _isWriting = false);

    final profile = ref.read(userProfileProvider);
    if (profile == null) return;

    final myId = profile['phoneNumber'] as String;
    final msgId = const Uuid().v4();

    final payload = utf8.encode(text);
    final encrypted = await KeyManager.instance.encryptMessage(widget.chatId, Uint8List.fromList(payload));
    
    final msg = Message(
      id: msgId,
      chatId: widget.chatId,
      senderId: myId,
      text: text,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      direction: 0,
      deliveryStatus: 0,
      ttl: _selectedTtl,
    );

    await DatabaseHelper.instance.insertMessage(msg, []);
    
    await DatabaseHelper.instance.insertChat(Chat(
      id: widget.chatId,
      type: 0,
      lastMessageId: msgId,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    ));

    ref.invalidate(messagesProvider(widget.chatId));
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.contactName, style: const TextStyle(fontSize: 16)),
                if (_isBlocked)
                  const Text("Blocked", style: TextStyle(fontSize: 11, color: Colors.red)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.videocam), onPressed: () {}),
          IconButton(icon: const Icon(Icons.call), onPressed: () {}),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'block') _toggleBlock();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'block',
                child: Row(
                  children: [
                    Icon(
                      _isBlocked ? Icons.check_circle : Icons.block,
                      color: _isBlocked ? Colors.green : Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(_isBlocked ? "Unblock Contact" : "Block Contact"),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Blocked banner
          if (_isBlocked)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: Colors.red.withOpacity(0.1),
              child: const Text(
                "🚫 This contact is blocked. Messages will not be sent or received.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.red),
              ),
            ),

          Expanded(
            child: messagesAsync.when(
              data: (messages) {
                if (messages.isEmpty) {
                  return const Center(child: Text("Say hi! End-to-end encrypted."));
                }
                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[messages.length - 1 - index];
                    final isMe = msg.direction == 0;
                    final hasTtl = msg.ttl > 0;
                    
                    // Calculate remaining time for self-destruct
                    int? remainingSecs;
                    if (hasTtl) {
                      final expiresAt = msg.timestamp + (msg.ttl * 1000);
                      remainingSecs = ((expiresAt - DateTime.now().millisecondsSinceEpoch) / 1000).round();
                      if (remainingSecs < 0) remainingSecs = 0;
                    }

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        decoration: BoxDecoration(
                          color: isMe ? const Color(0xFF005C4B) : const Color(0xFF202C33),
                          borderRadius: BorderRadius.circular(12),
                          border: hasTtl ? Border.all(color: Colors.orange.withOpacity(0.5), width: 1) : null,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              msg.text.isNotEmpty ? msg.text : "[Encrypted Payload]",
                              style: const TextStyle(color: Colors.white, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (hasTtl) ...[
                                  Icon(Icons.timer, size: 12, color: Colors.orange[300]),
                                  const SizedBox(width: 2),
                                  Text(
                                    "${remainingSecs}s",
                                    style: TextStyle(color: Colors.orange[300], fontSize: 10),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                Text(
                                  DateFormat.Hm().format(DateTime.fromMillisecondsSinceEpoch(msg.timestamp)),
                                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                                ),
                                if (isMe) ...[
                                  const SizedBox(width: 4),
                                  Icon(
                                    msg.deliveryStatus == 0
                                        ? Icons.schedule
                                        : msg.deliveryStatus == 1
                                            ? Icons.check
                                            : Icons.done_all,
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
      child: Column(
        children: [
          // Self-destruct TTL selector
          if (_selectedTtl > 0)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.timer, size: 14, color: Colors.orange),
                  const SizedBox(width: 4),
                  Text(
                    "Self-destruct: ${_ttlLabels[_selectedTtl]}",
                    style: const TextStyle(fontSize: 12, color: Colors.orange),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => setState(() => _selectedTtl = 0),
                    child: const Icon(Icons.close, size: 14, color: Colors.orange),
                  ),
                ],
              ),
            ),
          Row(
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
                        onPressed: () {
                          FocusScope.of(context).unfocus();
                          setState(() => _emojiShowing = !_emojiShowing);
                        },
                      ),
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          focusNode: _focusNode,
                          maxLines: 4,
                          minLines: 1,
                          onChanged: (val) {
                            setState(() => _isWriting = val.isNotEmpty);
                          },
                          decoration: const InputDecoration(
                            hintText: "Message",
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      // Self-destruct timer button
                      PopupMenuButton<int>(
                        icon: Icon(
                          Icons.timer,
                          color: _selectedTtl > 0 ? Colors.orange : Colors.grey,
                          size: 22,
                        ),
                        tooltip: "Self-destruct timer",
                        onSelected: (val) => setState(() => _selectedTtl = val),
                        itemBuilder: (_) => _ttlOptions.map((ttl) {
                          return PopupMenuItem(
                            value: ttl,
                            child: Row(
                              children: [
                                Icon(
                                  ttl == 0 ? Icons.timer_off : Icons.timer,
                                  size: 18,
                                  color: ttl == _selectedTtl ? Colors.orange : Colors.grey,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _ttlLabels[ttl]!,
                                  style: TextStyle(
                                    fontWeight: ttl == _selectedTtl ? FontWeight.bold : FontWeight.normal,
                                    color: ttl == _selectedTtl ? Colors.orange : null,
                                  ),
                                ),
                                if (ttl == _selectedTtl)
                                  const Padding(
                                    padding: EdgeInsets.only(left: 8),
                                    child: Icon(Icons.check, size: 16, color: Colors.orange),
                                  ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                      IconButton(
                        icon: const Icon(Icons.attach_file),
                        color: Colors.grey,
                        onPressed: () {},
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
                  onPressed: _isWriting ? _sendMessage : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
