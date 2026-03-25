import 'dart:convert';
import 'dart:typed_data';

class Packet {
  final String id;
  final String sourceId;
  final String destinationId;
  final Uint8List payload;
  final Uint8List? senderPublicKey;
  int ttl;
  final int timestamp;
  final List<String> path;

  Packet({
    required this.id,
    required this.sourceId,
    required this.destinationId,
    required this.payload,
    this.senderPublicKey,
    this.ttl = 5,
    required this.timestamp,
    this.path = const [],
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'sourceId': sourceId,
    'destinationId': destinationId,
    'payload': payload,
    if (senderPublicKey != null) 'senderPublicKey': senderPublicKey,
    'ttl': ttl,
    'timestamp': timestamp,
    'path': path,
  };

  factory Packet.fromJson(Map<String, dynamic> json) => Packet(
    id: json['id'],
    sourceId: json['sourceId'],
    destinationId: json['destinationId'],
    payload: json['payload'] is String ? base64Decode(json['payload']) : Uint8List.fromList(List<int>.from(json['payload'])),
    senderPublicKey: json['senderPublicKey'] != null 
        ? (json['senderPublicKey'] is String ? base64Decode(json['senderPublicKey']) : Uint8List.fromList(List<int>.from(json['senderPublicKey']))) 
        : null,
    ttl: json['ttl'],
    timestamp: json['timestamp'],
    path: List<String>.from(json['path'] ?? []),
  );
}

class Message {
  final String id;
  final String chatId;
  final String senderId;
  final String text; // Will be empty if only media
  final int timestamp;
  final int direction; // 0 = sent, 1 = received
  int deliveryStatus; // 0=pending, 1=sent, 2=delivered, 3=read
  final String? mediaPath;
  final String? mediaType;
  final int ttl;

  Message({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.text,
    required this.timestamp,
    required this.direction,
    required this.deliveryStatus,
    this.mediaPath,
    this.mediaType,
    this.ttl = 5,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'chat_id': chatId,
    'sender_id': senderId,
    'timestamp': timestamp,
    'direction': direction,
    'delivery_status': deliveryStatus,
    'media_path': mediaPath,
    'media_type': mediaType,
    'ttl': ttl,
    // Note: encrypted_payload is handled separately in DB layer
  };
}

class Contact {
  final String phoneNumber;
  final String displayName;
  final Uint8List publicKey;
  Uint8List? sessionState;
  final int lastSeen;
  int isBlocked;

  Contact({
    required this.phoneNumber,
    required this.displayName,
    required this.publicKey,
    this.sessionState,
    required this.lastSeen,
    this.isBlocked = 0,
  });

  Map<String, dynamic> toMap() => {
    'id': phoneNumber,
    'display_name': displayName,
    'public_key': publicKey,
    'session_state': sessionState,
    'is_blocked': isBlocked,
    'last_seen': lastSeen,
  };
}

class Chat {
  final String id;
  final int type; // 0 = direct, 1 = group
  String? lastMessageId;
  int unreadCount;
  final int createdAt;

  Chat({
    required this.id,
    required this.type,
    this.lastMessageId,
    this.unreadCount = 0,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'type': type,
    'last_message_id': lastMessageId,
    'unread_count': unreadCount,
    'created_at': createdAt,
  };
}

class RouteEntry {
  final String nextHop;
  final int hopCount;
  final int timestamp;

  RouteEntry({
    required this.nextHop,
    required this.hopCount,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'nextHop': nextHop,
    'hopCount': hopCount,
    'timestamp': timestamp,
  };

  factory RouteEntry.fromJson(Map<String, dynamic> json) => RouteEntry(
    nextHop: json['nextHop'],
    hopCount: json['hopCount'],
    timestamp: json['timestamp'],
  );
}
