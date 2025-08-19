class Message {
  final int? id;
  final String content;
  final String senderId;
  final String chatSessionId;
  final DateTime timestamp;
  final bool isFromMe;

  Message({
    this.id,
    required this.content,
    required this.senderId,
    required this.chatSessionId,
    required this.timestamp,
    required this.isFromMe,
  });

  // Convert Message to Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'senderId': senderId,
      'chatSessionId': chatSessionId,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'isFromMe': isFromMe ? 1 : 0,
    };
  }

  // Create Message from Map (from database)
  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id'],
      content: map['content'],
      senderId: map['senderId'],
      chatSessionId: map['chatSessionId'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
      isFromMe: map['isFromMe'] == 1,
    );
  }

  // Create Message from JSON (for network communication)
  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      content: json['content'],
      senderId: json['senderId'],
      chatSessionId: json['chatSessionId'],
      timestamp: DateTime.parse(json['timestamp']),
      isFromMe: false, // Received messages are not from me
    );
  }

  // Convert Message to JSON for network communication
  Map<String, dynamic> toJson() {
    return {
      'content': content,
      'senderId': senderId,
      'chatSessionId': chatSessionId,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
