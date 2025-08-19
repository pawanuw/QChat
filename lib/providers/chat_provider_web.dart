import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  // Unread notifications (in-memory)
  final List<Message> _unreadMessages = [];
  List<Message> get unreadMessages => List.unmodifiable(_unreadMessages);
  int get unreadCount => _unreadMessages.length;

  // Track last seen timestamp per chat (milliseconds since epoch)
  final Map<String, int> _lastSeenMsPerChat = {};
  static const _lastSeenPrefsKeyPrefix = 'lastSeenMsPerChat_';

  // Message listeners per chat for unread tracking
  final Map<String, StreamSubscription> _messageSubscriptions = {};
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _chatsSubscription;

  ChatProvider() {
    _init();
  }

  Future<void> _init() async {
    // Load or generate persistent anonymous user id
    _userId = await UserIdHelper.getUserId();
    // Ensure we're authenticated for Firestore rules
    await _ensureAuth();
    // Load persisted last-seen map for this user
    await _loadLastSeenFromPrefs();
  await _loadChatSessions();
  _startChatsListener();
    // Consider as connected when a session is active
    _isConnected = _currentSession != null;
    notifyListeners();
  }

  Future<void> _loadLastSeenFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_lastSeenPrefsKeyPrefix$_userId');
      if (raw != null && raw.isNotEmpty) {
        final Map<String, dynamic> map = jsonDecode(raw) as Map<String, dynamic>;
        _lastSeenMsPerChat
          ..clear()
          ..addAll(map.map((k, v) => MapEntry(k, (v is int) ? v : int.tryParse(v.toString()) ?? 0)));
      }
    } catch (e) {
      debugPrint('Failed to load lastSeen prefs: $e');
    }
  }

  Future<void> _saveLastSeenToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_lastSeenPrefsKeyPrefix$_userId', jsonEncode(_lastSeenMsPerChat));
    } catch (e) {
      debugPrint('Failed to save lastSeen prefs: $e');
    }
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
      // Ensure unread listeners for existing sessions
      for (final s in _chatSessions) {
        _ensureChatListener(s.id);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading chat sessions: $e');
    }
  }

  // Listen to chats collection to discover sessions involving this user
  void _startChatsListener() {
    _chatsSubscription?.cancel();
    _chatsSubscription = FirebaseFirestore.instance
        .collection('chats')
        .where('participants', arrayContains: _userId)
        .snapshots()
        .listen((snapshot) {
      final List<ChatSession> sessions = [];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final participants = (data['participants'] as List?)?.map((e) => e.toString()).toList() ?? [];
        if (participants.isEmpty) continue;
        final peerId = participants.firstWhere((p) => p != _userId, orElse: () => 'peer');
        DateTime createdAt;
        final createdField = data['createdAt'] ?? data['lastMessageAt'];
        if (createdField is Timestamp) {
          createdAt = createdField.toDate();
        } else if (createdField is DateTime) {
          createdAt = createdField;
        } else {
          createdAt = DateTime.now();
        }
        final peerName = peerId.length >= 4
            ? 'User ${peerId.substring(peerId.length - 4)}'
            : 'User $peerId';
        final session = ChatSession(
          id: doc.id,
          peerId: peerId,
          peerName: peerName,
          createdAt: createdAt,
          isActive: true,
        );
        sessions.add(session);
      }

      // Merge into in-memory sessions
      _webSessions
        ..clear()
        ..addAll(sessions);
      _chatSessions = List.from(_webSessions);
      for (final s in _chatSessions) {
        _ensureChatListener(s.id);
      }
      notifyListeners();
    }, onError: (e) {
      debugPrint('Chats listener error: $e');
    });
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

  // Start unread tracking for this chat
  _ensureChatListener(sessionId);
      
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
  // Mark as read when opening the chat
  markChatAsRead(session.id);
  // Ensure listener exists for unread tracking
  _ensureChatListener(session.id);
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

      // Update parent chat metadata so recipient devices discover/update the chat list
      final chatDoc = FirebaseFirestore.instance.collection('chats').doc(chatId);
      await chatDoc.set({
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessageText': text,
        'participants': FieldValue.arrayUnion([
          senderId,
          if (_currentSession?.peerId != null) _currentSession!.peerId,
        ]),
      }, SetOptions(merge: true));
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

  // Clean up unread tracking for this chat
  _messageSubscriptions.remove(sessionId)?.cancel();
  _lastSeenMsPerChat.remove(sessionId);
  _unreadMessages.removeWhere((m) => m.chatSessionId == sessionId);
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

  // Internal: setup a listener on latest messages for unread tracking
  void _ensureChatListener(String chatId) {
    if (_messageSubscriptions.containsKey(chatId)) return;
    final sub = FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestampMs', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isEmpty) return;
      final doc = snapshot.docs.first;
      final data = doc.data();
      final senderId = (data['senderId'] ?? '').toString();
      final text = (data['text'] ?? '').toString();
      final tsMs = (data['timestampMs'] ?? 0);
      final timestampMs = tsMs is int ? tsMs : (tsMs is num ? tsMs.toInt() : 0);
      final lastSeen = _lastSeenMsPerChat[chatId] ?? 0;

      // On first event after subscribing (no lastSeen), seed and ignore to prevent backfill
      if (lastSeen == 0) {
        _lastSeenMsPerChat[chatId] = timestampMs > 0
            ? timestampMs
            : DateTime.now().millisecondsSinceEpoch;
  _saveLastSeenToPrefs();
        return;
      }

      // Ignore if from me or not newer than last seen
      if (senderId == _userId || timestampMs <= lastSeen) return;

      // If currently viewing this chat, mark as seen immediately
      if (_currentSession?.id == chatId) {
  _lastSeenMsPerChat[chatId] = DateTime.now().millisecondsSinceEpoch;
  _saveLastSeenToPrefs();
        return;
      }

      // Add to unread if not already present
      final timeField = data['timestamp'];
      DateTime time;
      if (timeField is Timestamp) {
        time = timeField.toDate();
      } else if (timeField is DateTime) {
        time = timeField;
      } else if (timestampMs > 0) {
        time = DateTime.fromMillisecondsSinceEpoch(timestampMs);
      } else {
        time = DateTime.now();
      }
      final message = Message(
        content: text,
        senderId: senderId,
        chatSessionId: chatId,
        timestamp: time,
        isFromMe: false,
      );

      // Deduplicate by same chatId + text + timestampMs
      final already = _unreadMessages.any((m) =>
          m.chatSessionId == chatId &&
          m.content == message.content &&
          m.timestamp.millisecondsSinceEpoch == message.timestamp.millisecondsSinceEpoch);
      if (!already) {
        _unreadMessages.add(message);
  // Move the last-seen forward only when user actually views or explicitly marks read;
  // keep as-is so multiple messages remain marked until read.
        notifyListeners();
      }
    });
    _messageSubscriptions[chatId] = sub;
  }

  // Public API: mark all as read
  void markAllAsRead() {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final s in _webSessions) {
      _lastSeenMsPerChat[s.id] = now;
    }
    _unreadMessages.clear();
  _saveLastSeenToPrefs();
    notifyListeners();
  }

  // Public API: mark a chat as read
  void markChatAsRead(String chatId) {
    _lastSeenMsPerChat[chatId] = DateTime.now().millisecondsSinceEpoch;
    _unreadMessages.removeWhere((m) => m.chatSessionId == chatId);
  _saveLastSeenToPrefs();
    notifyListeners();
  }

  @override
  void dispose() {
  _chatsSubscription?.cancel();
    for (final sub in _messageSubscriptions.values) {
      sub.cancel();
    }
    _messageSubscriptions.clear();
    super.dispose();
  }
}
