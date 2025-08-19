import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';
import '../models/message.dart';
import '../models/chat_session.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    if (kIsWeb) {
      // For web, we'll use in-memory storage for demo purposes
      // In a real app, you might use IndexedDB or other web storage
      throw UnsupportedError('SQLite is not supported on web. Use alternative storage.');
    }
    
    String path = join(await getDatabasesPath(), 'qchat.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Create messages table
    await db.execute('''
      CREATE TABLE messages(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        content TEXT NOT NULL,
        senderId TEXT NOT NULL,
        chatSessionId TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        isFromMe INTEGER NOT NULL
      )
    ''');

    // Create chat_sessions table
    await db.execute('''
      CREATE TABLE chat_sessions(
        id TEXT PRIMARY KEY,
        peerId TEXT NOT NULL,
        peerName TEXT NOT NULL,
        createdAt INTEGER NOT NULL,
        isActive INTEGER NOT NULL
      )
    ''');
  }

  // Message operations
  Future<int> insertMessage(Message message) async {
    if (kIsWeb) {
      // For web, return a dummy ID
      return DateTime.now().millisecondsSinceEpoch;
    }
    final db = await database;
    return await db.insert('messages', message.toMap());
  }

  Future<List<Message>> getMessagesForSession(String sessionId) async {
    if (kIsWeb) {
      // For web demo, return empty list
      // In a real app, implement web storage
      return [];
    }
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'messages',
      where: 'chatSessionId = ?',
      whereArgs: [sessionId],
      orderBy: 'timestamp ASC',
    );

    return List.generate(maps.length, (i) {
      return Message.fromMap(maps[i]);
    });
  }

  Future<void> deleteMessagesForSession(String sessionId) async {
    if (kIsWeb) return;
    final db = await database;
    await db.delete(
      'messages',
      where: 'chatSessionId = ?',
      whereArgs: [sessionId],
    );
  }

  // Chat session operations
  Future<void> insertChatSession(ChatSession session) async {
    if (kIsWeb) return;
    final db = await database;
    await db.insert(
      'chat_sessions',
      session.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ChatSession>> getAllChatSessions() async {
    if (kIsWeb) {
      // For web demo, return empty list
      return [];
    }
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'chat_sessions',
      orderBy: 'createdAt DESC',
    );

    return List.generate(maps.length, (i) {
      return ChatSession.fromMap(maps[i]);
    });
  }

  Future<ChatSession?> getChatSession(String sessionId) async {
    if (kIsWeb) return null;
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'chat_sessions',
      where: 'id = ?',
      whereArgs: [sessionId],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return ChatSession.fromMap(maps.first);
    }
    return null;
  }

  Future<void> updateChatSession(ChatSession session) async {
    if (kIsWeb) return;
    final db = await database;
    await db.update(
      'chat_sessions',
      session.toMap(),
      where: 'id = ?',
      whereArgs: [session.id],
    );
  }

  Future<void> deleteChatSession(String sessionId) async {
    if (kIsWeb) return;
    final db = await database;
    await db.delete(
      'chat_sessions',
      where: 'id = ?',
      whereArgs: [sessionId],
    );
    await deleteMessagesForSession(sessionId);
  }

  Future<void> close() async {
    if (kIsWeb) return;
    final db = await database;
    db.close();
  }
}
