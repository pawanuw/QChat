import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/message.dart';
import '../models/chat_session.dart';

class ChatProvider extends ChangeNotifier {
  // User ID for this device
  String _userId = '';
  String get userId => _userId;

  // Current chat session
  ChatSession? _currentSession;
  ChatSession? get currentSession => _currentSession;

  // Messages for current session
  List<Message> _messages = [];
  List<Message> get messages => _messages;

  // All chat sessions
  List<ChatSession> _chatSessions = [];
  List<ChatSession> get chatSessions => _chatSessions;

  // Web-compatible in-memory storage
  final Map<String, List<Message>> _webMessages = {};
  final List<ChatSession> _webSessions = [];

  // Connection status
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  ChatProvider() {
    _generateUserId();
    _loadChatSessions();
  }

  void _generateUserId() {
    // Generate a unique user ID for this device
    _userId = 'user_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}';
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

  // Generate QR code data for pairing
  String generateQRCode() {
    return jsonEncode({
      'userId': _userId,
      'action': 'pair',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // Generate QR code data (alias for compatibility)
  String generateQRData() {
    return generateQRCode();
  }

  // Process scanned QR code
  Future<bool> processQRCode(String qrData) async {
    try {
      final data = jsonDecode(qrData) as Map<String, dynamic>;
      
      if (data['action'] == 'pair') {
        final partnerId = data['userId'] as String;
        
        if (partnerId != _userId) {
          await startChatSession(partnerId);
          return true;
        }
      }
      return false;
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
      final sessionId = 'chat_${_userId}_${partnerId}_${DateTime.now().millisecondsSinceEpoch}';
      
      final session = ChatSession(
        id: sessionId,
        peerId: partnerId,
        peerName: 'User ${partnerId.substring(partnerId.length - 4)}',
        createdAt: DateTime.now(),
        isActive: true,
      );

      // Save to in-memory storage
      _webSessions.add(session);
      _webMessages[sessionId] = [];
      
      _currentSession = session;
      _messages = [];
      
      _chatSessions = List.from(_webSessions);
      _isConnected = true;
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error starting chat session: $e');
    }
  }

  // Load messages for a specific session
  Future<void> loadMessages(String sessionId) async {
    try {
      _currentSession = _chatSessions.firstWhere((s) => s.id == sessionId);
      _messages = List.from(_webMessages[sessionId] ?? []);
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

  // Send a message
  Future<void> sendMessage(String content) async {
    if (_currentSession == null) return;

    try {
      final message = Message(
        content: content,
        senderId: _userId,
        chatSessionId: _currentSession!.id,
        timestamp: DateTime.now(),
        isFromMe: true,
      );

      // Save to in-memory storage
      if (_webMessages[_currentSession!.id] == null) {
        _webMessages[_currentSession!.id] = [];
      }
      _webMessages[_currentSession!.id]!.add(message);
      
      _messages.add(message);
      
      // Simulate echo message for demo purposes
      _simulateEchoMessage(content);
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error sending message: $e');
    }
  }

  // Simulate an echo response for demo
  void _simulateEchoMessage(String originalContent) {
    if (_currentSession == null) return;

    Future.delayed(const Duration(seconds: 1), () {
      final echoMessage = Message(
        content: 'Echo: $originalContent',
        senderId: _currentSession!.peerId,
        chatSessionId: _currentSession!.id,
        timestamp: DateTime.now(),
        isFromMe: false,
      );

      if (_webMessages[_currentSession!.id] != null) {
        _webMessages[_currentSession!.id]!.add(echoMessage);
        _messages.add(echoMessage);
        
        notifyListeners();
      }
    });
  }

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
      _webMessages.remove(sessionId);
      
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
    _webMessages.clear();
    _chatSessions.clear();
    _messages.clear();
    _currentSession = null;
    _isConnected = false;
    notifyListeners();
  }
}
