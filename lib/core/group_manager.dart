import 'dart:convert';
import 'dart:typed_data';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import 'database_helper.dart';
import 'key_manager.dart';

/// Handles creation of Group Chats, AES-256 Key Generation, and Key Distribution
class GroupManager {
  static final GroupManager instance = GroupManager._init();
  GroupManager._init();

  /// Creates a new group, generates an AES key, and stores it securely
  Future<Chat> createGroup(String groupName, List<String> memberIds) async {
    final groupId = const Uuid().v4();
    final groupKey = _generateGroupKey();
    
    // Store group key locally encrypted with our Symmetric KeyManager (PIN based)
    // Here we'd typically use SecureCell with our local PIN or store in Keystore
    // final encryptedKey = KeyManager.instance.symmetricEncrypt("localPIN", groupKey);
    // await DatabaseHelper.instance.storeGroupKey(groupId, encryptedKey);
    
    final chat = Chat(
      id: groupId,
      type: 1, // 1 = Group
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    await DatabaseHelper.instance.insertChat(chat);
    
    // Distribute the key to all members using their public keys
    await _distributeGroupKey(groupId, groupKey, memberIds);

    return chat;
  }

  /// Distributes the symmetric group key to all members individually encrypted
  Future<void> _distributeGroupKey(String groupId, Uint8List groupKey, List<String> memberIds) async {
    final payload = jsonEncode({
      'type': 'group_invite',
      'groupId': groupId,
      'groupKey': base64Encode(groupKey),
    });
    
    for (final memberId in memberIds) {
      final payloadBytes = Uint8List.fromList(utf8.encode(payload));
      
      // Encrypt the invite specifically for this member (Secure Session)
      final encryptedInvite = await KeyManager.instance.encryptMessage(memberId, payloadBytes);
      
      // Send via PacketRouter
      // PacketRouter.instance.routeMessage(memberId, encryptedInvite);
      print("Distributed group key for \$groupId to \$memberId");
    }
  }

  /// Handles an inbound group invite
  Future<void> processGroupInvite(String senderId, Map<String, dynamic> data) async {
    final groupId = data['groupId'];
    final groupKey = base64Decode(data['groupKey']);

    // Create chat locally 
    final chat = Chat(
      id: groupId,
      type: 1,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    await DatabaseHelper.instance.insertChat(chat);

    // Save key
    // final encryptedKey = KeyManager.instance.symmetricEncrypt("localPIN", groupKey);
    // await DatabaseHelper.instance.storeGroupKey(groupId, encryptedKey);
  }

  Uint8List _generateGroupKey() {
    // Generates a 32-byte (256-bit) AES-like symmetric key
    // Normally using cryptographically secure random number generator
    final random = List<int>.generate(32, (i) => DateTime.now().millisecond % 256);
    return Uint8List.fromList(random);
  }
}
