import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/message.dart';
import '../models/chat_session.dart';
import '../utils/user_id.dart';

class ChatProvider extends ChangeNotifier {
  // User ID for this device
  String _userId = '';
  String get userId => _userId;

  // Current chat session
  ChatSession? _currentSession;
  ChatSession? get currentSession => _currentSession;

  // Messages for current session (legacy local list, not used with Firestore stream)
  List<Message> _messages = [];
  List<Message> get messages => _messages;

  // All chat sessions
  List<ChatSession> _chatSessions = [];
  List<ChatSession> get chatSessions => _chatSessions;

  // Local in-memory chat sessions list for UI
  final List<ChatSession> _webSessions = [];

  // Connection status
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  // Last error message for diagnostics (read-only)
  String? _lastError;
  String? get lastError => _lastError;

  ChatProvider() {
    _init();
  }

  Future<void> _init() async {
    // Load or generate persistent anonymous user id
    _userId = await UserIdHelper.getUserId();
    // Ensure we're authenticated for Firestore rules
    await _ensureAuth();
    await _loadChatSessions();
    // Consider as connected when a session is active
    _isConnected = _currentSession != null;
    notifyListeners();
  }

  Future<void> _ensureAuth() async {
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }
    } catch (e) {
      // Capture error so UI can surface it
      _lastError = 'Auth error: $e';
      debugPrint(_lastError);
      notifyListeners();
    }
  }

  // Load all chat sessions
  Future<void> _loadChatSessions() async {
    try {
      _chatSessions = List.from(_webSessions);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading chat sessions: $e');
    }
  }

  // Generate QR code data for pairing: share only our userId
  String generateQRCode() {
    return _userId;
  }

  // Generate QR code data (alias for compatibility)
  String generateQRData() => generateQRCode();

  // Process scanned QR code
  Future<bool> processQRCode(String qrData) async {
    try {
      // Accept either raw userId or JSON with userId
      String partnerId;
      try {
        final data = jsonDecode(qrData) as Map<String, dynamic>;
        partnerId = (data['userId'] ?? '').toString();
      } catch (_) {
        partnerId = qrData;
      }

      if (partnerId.isEmpty || partnerId == _userId) return false;

      await startChatSession(partnerId);
      return true;
    } catch (e) {
      debugPrint('Error processing QR code: $e');
      return false;
    }
  }

  // Connect to session via QR code (alias for processQRCode)
  Future<bool> connectToSession(String qrData) async {
    return await processQRCode(qrData);
  }

  // Start a new chat session
  Future<void> startChatSession(String partnerId) async {
    try {
      final sessionId = _composeChatId(_userId, partnerId);
      
      final session = ChatSession(
        id: sessionId,
        peerId: partnerId,
        peerName: partnerId.length >= 4
            ? 'User ${partnerId.substring(partnerId.length - 4)}'
            : 'User $partnerId',
        createdAt: DateTime.now(),
        isActive: true,
      );

      // Save to in-memory storage
      if (_webSessions.indexWhere((s) => s.id == sessionId) == -1) {
        _webSessions.add(session);
      }
      
      _currentSession = session;
      _messages = [];
      
      _chatSessions = List.from(_webSessions);
      _isConnected = true;

      // Ensure a chat document exists in Firestore so the peer can discover it
      try {
        final chatDoc = FirebaseFirestore.instance.collection('chats').doc(sessionId);
        await chatDoc.set({
          'participants': [_userId, partnerId],
          'createdAt': FieldValue.serverTimestamp(),
          'initiator': _userId,
          'lastMessageAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        _lastError = 'Failed to create chat doc: $e';
        debugPrint(_lastError);
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error starting chat session: $e');
    }
  }

  // Load messages for a specific session
  Future<void> loadMessages(String sessionId) async {
    try {
      _currentSession = _chatSessions.firstWhere((s) => s.id == sessionId);
      _isConnected = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading messages: $e');
    }
  }

  // Set current session (for compatibility)
  Future<void> setCurrentSession(ChatSession session) async {
    await loadMessages(session.id);
  }

  // Send a message to Firestore
  Future<void> sendMessage(String chatId, String text, String senderId) async {
    _lastError = null;
    await _ensureAuth();
    try {
      final messagesRef = FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages');

      await messagesRef.add({
        'senderId': senderId,
        'text': text,
        // Server timestamp for authoritative time
        'timestamp': FieldValue.serverTimestamp(),
        // Client-side milliseconds for immediate ordering in UI
        'timestampMs': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      _lastError = 'Send failed: $e';
      debugPrint(_lastError);
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  // Stream messages from Firestore
  Stream<QuerySnapshot<Map<String, dynamic>>> getMessages(String chatId) {
    return FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        // Order by client timestamp to avoid null serverTimestamp gaps
        .orderBy('timestampMs', descending: false)
        .snapshots();
  }

  // No echo simulation when using Firestore

  // Disconnect from current session
  void disconnect() {
    _isConnected = false;
    _currentSession = null;
    _messages = [];
    notifyListeners();
  }

  // End current session
  Future<void> endCurrentSession() async {
    disconnect();
  }

  // Get partner ID for current session
  String? getPartnerId() {
    return _currentSession?.peerId;
  }

  // Delete a chat session
  Future<void> deleteSession(String sessionId) async {
    try {
      _webSessions.removeWhere((s) => s.id == sessionId);
      
      if (_currentSession?.id == sessionId) {
        _currentSession = null;
        _messages = [];
        _isConnected = false;
      }
      
      _chatSessions = List.from(_webSessions);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting session: $e');
    }
  }

  // Delete a chat session (alias for compatibility)
  Future<void> deleteChatSession(String sessionId) async {
    await deleteSession(sessionId);
  }

  // Clear all data
  void clearAllData() {
    _webSessions.clear();
    _chatSessions.clear();
    _messages.clear();
    _currentSession = null;
    _isConnected = false;
    notifyListeners();
  }

  // Compose a deterministic chat id for two users
  String _composeChatId(String a, String b) {
    final sorted = [a, b]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }
}
