import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../models/message.dart';
import '../models/chat_session.dart';
import '../services/database_helper.dart';

class ChatProvider extends ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  
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

  // Socket connection
  IO.Socket? _socket;
  
  // User info
  String _userId = '';
  String get userId => _userId;

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

  // Load all chat sessions from database
  Future<void> _loadChatSessions() async {
    try {
      if (kIsWeb) {
        _chatSessions = List.from(_webSessions);
      } else {
        _chatSessions = await _dbHelper.getAllChatSessions();
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading chat sessions: $e');
      _chatSessions = [];
      notifyListeners();
    }
  }

  // Generate QR code data for connection
  String generateQRData() {
    final sessionId = 'session_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}';
    final qrData = {
      'sessionId': sessionId,
      'userId': _userId,
      'timestamp': DateTime.now().toIso8601String(),
    };
    return jsonEncode(qrData);
  }

  // Connect to a chat session via QR code
  Future<bool> connectToSession(String qrData) async {
    try {
      final data = jsonDecode(qrData) as Map<String, dynamic>;
      final sessionId = data['sessionId'] as String;
      final peerId = data['userId'] as String;
      
      // Create or get existing session
      ChatSession session = ChatSession(
        id: sessionId,
        peerId: peerId,
        peerName: 'Anonymous User',
        createdAt: DateTime.now(),
        isActive: true,
      );

      // Save session to database/memory
      if (kIsWeb) {
        _webSessions.add(session);
        _webMessages[sessionId] = [];
      } else {
        await _dbHelper.insertChatSession(session);
      }
      
      // Set as current session
      _currentSession = session;
      
      // Load messages for this session
      await _loadMessagesForCurrentSession();
      
      // Connect to real-time chat
      _connectToRealTimeChat(sessionId);
      
      // Reload sessions list
      await _loadChatSessions();
      
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error connecting to session: $e');
      return false;
    }
  }

  // Connect to real-time chat using socket
  void _connectToRealTimeChat(String sessionId) {
    try {
      // For demo purposes, we'll simulate real-time functionality
      // In a real app, you would connect to your server
      _isConnected = true;
      notifyListeners();
      
      // Simulate connection to demonstrate the feature
      _simulateConnection(sessionId);
    } catch (e) {
      debugPrint('Socket connection error: $e');
      _isConnected = false;
      notifyListeners();
    }
  }

  // Simulate real-time connection for demo
  void _simulateConnection(String sessionId) {
    // This simulates receiving messages from the other user
    // In a real implementation, this would be handled by socket events
    Future.delayed(const Duration(seconds: 2), () {
      if (_currentSession?.id == sessionId) {
        _receiveMessage(Message(
          content: "Hi! I just connected via QR code!",
          senderId: _currentSession!.peerId,
          chatSessionId: sessionId,
          timestamp: DateTime.now(),
          isFromMe: false,
        ));
      }
    });
  }

  // Send a message
  Future<void> sendMessage(String content) async {
    if (_currentSession == null || content.trim().isEmpty) return;

    final message = Message(
      content: content.trim(),
      senderId: _userId,
      chatSessionId: _currentSession!.id,
      timestamp: DateTime.now(),
      isFromMe: true,
    );

    // Add to local list
    _messages.add(message);
    
    // Save to database/memory
    if (kIsWeb) {
      _webMessages[_currentSession!.id]?.add(message);
    } else {
      await _dbHelper.insertMessage(message);
    }
    
    // Send via socket (simulated)
    _sendMessageViaSocket(message);
    
    notifyListeners();
  }

  void _sendMessageViaSocket(Message message) {
    // In a real app, send via socket
    // _socket?.emit('message', message.toJson());
    
    // For demo, simulate echo response
    Future.delayed(const Duration(seconds: 1), () {
      if (_currentSession != null) {
        _receiveMessage(Message(
          content: "Echo: ${message.content}",
          senderId: _currentSession!.peerId,
          chatSessionId: _currentSession!.id,
          timestamp: DateTime.now(),
          isFromMe: false,
        ));
      }
    });
  }

  // Receive a message
  void _receiveMessage(Message message) async {
    _messages.add(message);
    
    if (kIsWeb) {
      _webMessages[message.chatSessionId]?.add(message);
    } else {
      await _dbHelper.insertMessage(message);
    }
    
    notifyListeners();
  }

  // Load messages for current session
  Future<void> _loadMessagesForCurrentSession() async {
    if (_currentSession == null) return;
    
    try {
      if (kIsWeb) {
        _messages = _webMessages[_currentSession!.id] ?? [];
      } else {
        _messages = await _dbHelper.getMessagesForSession(_currentSession!.id);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading messages: $e');
      _messages = [];
      notifyListeners();
    }
  }

  // Set current session and load its messages
  Future<void> setCurrentSession(ChatSession session) async {
    _currentSession = session;
    await _loadMessagesForCurrentSession();
    
    if (session.isActive) {
      _connectToRealTimeChat(session.id);
    }
    
    notifyListeners();
  }

  // End current chat session
  Future<void> endCurrentSession() async {
    if (_currentSession == null) return;

    // Update session as inactive
    final updatedSession = _currentSession!.copyWith(isActive: false);
    
    if (kIsWeb) {
      final index = _webSessions.indexWhere((s) => s.id == updatedSession.id);
      if (index >= 0) {
        _webSessions[index] = updatedSession;
      }
    } else {
      await _dbHelper.updateChatSession(updatedSession);
    }
    
    // Disconnect socket
    _socket?.disconnect();
    _isConnected = false;
    
    // Clear current session
    _currentSession = null;
    _messages.clear();
    
    // Reload sessions
    await _loadChatSessions();
    
    notifyListeners();
  }

  // Delete a chat session
  Future<void> deleteChatSession(String sessionId) async {
    if (kIsWeb) {
      _webSessions.removeWhere((s) => s.id == sessionId);
      _webMessages.remove(sessionId);
    } else {
      await _dbHelper.deleteChatSession(sessionId);
    }
    
    if (_currentSession?.id == sessionId) {
      _currentSession = null;
      _messages.clear();
      _socket?.disconnect();
      _isConnected = false;
    }
    
    await _loadChatSessions();
    notifyListeners();
  }

  @override
  void dispose() {
    _socket?.disconnect();
    super.dispose();
  }
}
