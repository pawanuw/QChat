class ChatSession {
  final String id;
  final String peerId;
  final String peerName;
  final DateTime createdAt;
  final bool isActive;

  ChatSession({
    required this.id,
    required this.peerId,
    required this.peerName,
    required this.createdAt,
    required this.isActive,
  });

  // Convert ChatSession to Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'peerId': peerId,
      'peerName': peerName,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'isActive': isActive ? 1 : 0,
    };
  }

  // Create ChatSession from Map (from database)
  factory ChatSession.fromMap(Map<String, dynamic> map) {
    return ChatSession(
      id: map['id'],
      peerId: map['peerId'],
      peerName: map['peerName'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      isActive: map['isActive'] == 1,
    );
  }

  // Create a copy with updated values
  ChatSession copyWith({
    String? id,
    String? peerId,
    String? peerName,
    DateTime? createdAt,
    bool? isActive,
  }) {
    return ChatSession(
      id: id ?? this.id,
      peerId: peerId ?? this.peerId,
      peerName: peerName ?? this.peerName,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
    );
  }
}
