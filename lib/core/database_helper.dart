import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:path/path.dart';
import '../models/models.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  
  // Note: In production, this PIN/key should be securely retrieved from KeyStore/Keychain
  // or generated via PBKDF2 from a user PIN.
  String? _dbPassword;

  DatabaseHelper._init();

  void setPassword(String password) {
    _dbPassword = password;
  }

  Future<Database> get database async {
    if (_dbPassword == null) throw Exception("DB Password not set");
    if (_database != null) return _database!;
    _database = await _initDB('offtalk.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      password: _dbPassword,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE contacts (
        id TEXT PRIMARY KEY,
        display_name TEXT,
        public_key BLOB,
        session_state BLOB,
        is_blocked INTEGER DEFAULT 0,
        last_seen INTEGER,
        created_at INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE chats (
        id TEXT PRIMARY KEY,
        type INTEGER,
        last_message_id TEXT,
        unread_count INTEGER DEFAULT 0,
        created_at INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE chat_contacts (
        chat_id TEXT,
        contact_id TEXT,
        PRIMARY KEY (chat_id, contact_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE messages (
        id TEXT PRIMARY KEY,
        chat_id TEXT,
        sender_id TEXT,
        plain_text TEXT,
        encrypted_payload BLOB,
        timestamp INTEGER,
        direction INTEGER,
        delivery_status INTEGER,
        media_path TEXT,
        media_type TEXT,
        ttl INTEGER
      )
    ''');
  }

  // Contact Operations
  Future<void> insertContact(Contact contact) async {
    final db = await instance.database;
    await db.insert('contacts', contact.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }
  
  Future<Contact?> getContact(String id) async {
    final db = await instance.database;
    final maps = await db.query('contacts', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) {
      return Contact(
        phoneNumber: maps.first['id'] as String,
        displayName: maps.first['display_name'] as String,
        publicKey: maps.first['public_key'] as dynamic,
        sessionState: maps.first['session_state'] as dynamic,
        lastSeen: maps.first['last_seen'] as int,
        isBlocked: maps.first['is_blocked'] as int,
      );
    }
    return null;
  }

  Future<List<Contact>> getAllContacts() async {
    final db = await instance.database;
    final maps = await db.query('contacts');
    return maps.map((c) => Contact(
      phoneNumber: c['id'] as String,
      displayName: c['display_name'] as String,
      publicKey: c['public_key'] as dynamic,
      sessionState: c['session_state'] as dynamic,
      lastSeen: c['last_seen'] as int,
      isBlocked: c['is_blocked'] as int,
    )).toList();
  }

  Future<void> updateContactSession(String id, dynamic sessionState) async {
    final db = await instance.database;
    await db.update('contacts', {'session_state': sessionState}, where: 'id = ?', whereArgs: [id]);
  }

  // Chat Operations
  Future<void> insertChat(Chat chat) async {
    final db = await instance.database;
    await db.insert('chats', chat.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Link a contact to a chat (for direct chats, one contact per chat)
  Future<void> linkContactToChat(String chatId, String contactId) async {
    final db = await instance.database;
    await db.insert('chat_contacts', {
      'chat_id': chatId,
      'contact_id': contactId,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  /// Find or create a direct chat with a contact.
  /// Returns the chat ID.
  Future<String> getOrCreateDirectChat(String contactId) async {
    final db = await instance.database;
    // Check if a direct chat already exists with this contact
    final existing = await db.rawQuery(
      'SELECT c.id FROM chats c '
      'INNER JOIN chat_contacts cc ON c.id = cc.chat_id '
      'WHERE c.type = 0 AND cc.contact_id = ?',
      [contactId],
    );
    if (existing.isNotEmpty) {
      return existing.first['id'] as String;
    }
    // Create a new direct chat
    final chatId = contactId; // use contactId as chatId for 1-1 chats
    await db.insert('chats', {
      'id': chatId,
      'type': 0,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await linkContactToChat(chatId, contactId);
    return chatId;
  }

  Future<List<Chat>> getAllChats() async {
    final db = await instance.database;
    final maps = await db.query('chats', orderBy: 'created_at DESC');
    return maps.map((c) => Chat(
      id: c['id'] as String,
      type: c['type'] as int,
      lastMessageId: c['last_message_id'] as String?,
      unreadCount: c['unread_count'] as int,
      createdAt: c['created_at'] as int,
    )).toList();
  }

  // Message Operations
  // Store both the plaintext (for local display) and the encrypted payload.
  // The plaintext is stored locally and never transmitted; only encrypted
  // payloads travel over the mesh network.
  Future<void> insertMessage(Message msg, dynamic encryptedPayload) async {
    final db = await instance.database;
    final map = msg.toMap();
    map['plain_text'] = msg.text;
    map['encrypted_payload'] = encryptedPayload;
    await db.insert('messages', map, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getMessagesForChat(String chatId) async {
    final db = await instance.database;
    return await db.query('messages', where: 'chat_id = ?', whereArgs: [chatId], orderBy: 'timestamp ASC');
  }

  Future<void> updateMessageStatus(String id, int status) async {
    final db = await instance.database;
    await db.update('messages', {'delivery_status': status}, where: 'id = ?', whereArgs: [id]);
  }

  // Contact Blocking
  Future<void> blockContact(String id) async {
    final db = await instance.database;
    await db.update('contacts', {'is_blocked': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> unblockContact(String id) async {
    final db = await instance.database;
    await db.update('contacts', {'is_blocked': 0}, where: 'id = ?', whereArgs: [id]);
  }

  Future<bool> isContactBlocked(String id) async {
    final db = await instance.database;
    final maps = await db.query('contacts', where: 'id = ? AND is_blocked = 1', whereArgs: [id]);
    return maps.isNotEmpty;
  }

  // Self-Destruct Messages
  Future<void> deleteExpiredMessages() async {
    final db = await instance.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    // Delete messages where timestamp + (ttl * 1000ms) < now
    await db.rawDelete(
      'DELETE FROM messages WHERE ttl > 0 AND (timestamp + ttl * 1000) < ?',
      [now],
    );
  }

  Future<void> deleteMessage(String id) async {
    final db = await instance.database;
    await db.delete('messages', where: 'id = ?', whereArgs: [id]);
  }
}
