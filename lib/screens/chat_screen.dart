import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/chat_provider_web.dart';
import '../models/message.dart';
import '../utils/app_theme.dart';
import '../utils/user_id.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Auto-scroll to bottom when new messages arrive
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, child) {
        final session = chatProvider.currentSession;

        if (session == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Chat')),
            body: const Center(
              child: Text('No active chat session'),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(session.peerName),
            actions: [
              PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'end_chat') {
                    _showEndChatDialog(context, chatProvider);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'end_chat',
                    child: Row(
                      children: [
                        Icon(Icons.exit_to_app, color: Colors.red),
                        SizedBox(width: 8),
                        Text('End Chat'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              if (!chatProvider.isConnected)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  color: Colors.orange,
                  child: const Text(
                    'Connection lost - messages will be sent when reconnected',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),

              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: chatProvider.getMessages(session.id),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red, size: 40),
                              const SizedBox(height: 12),
                              Text(
                                'Could not load messages. ${snapshot.error}',
                                textAlign: TextAlign.center,
                              ),
                              if (chatProvider.lastError != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  chatProvider.lastError!,
                                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return _buildEmptyMessagesView();
                    }

                    final docs = snapshot.data!.docs;
                    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                    final sections = _groupMessagesByDate(session.id, chatProvider.userId, docs);

                    return CustomScrollView(
                      controller: _scrollController,
                      slivers: [
                        const SliverToBoxAdapter(child: SizedBox(height: 8)),
                        for (final section in sections) ...[
                          SliverPersistentHeader(
                            pinned: true,
                            delegate: _DateHeaderDelegate(
                              label: _labelForDate(section.date),
                              backgroundColor: Colors.transparent,
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final message = section.messages[index];
                                  return _buildMessageBubble(message);
                                },
                                childCount: section.messages.length,
                              ),
                            ),
                          ),
                        ],
                        const SliverToBoxAdapter(child: SizedBox(height: 16)),
                      ],
                    );
                  },
                ),
              ),

              _buildMessageInput(chatProvider),
            ],
          ),
        );
      },
    );
  }

  // Helpers for date headers
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _labelForDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (target == today) return 'Today';
    if (target == yesterday) return 'Yesterday';
    return DateFormat('MM/yy').format(date);
  }

  // Group Firestore docs into date-based sections
  List<_MessageSection> _groupMessagesByDate(
    String sessionId,
    String currentUserId,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final List<_MessageSection> sections = [];
    for (final doc in docs) {
      final data = doc.data();
      final senderId = (data['senderId'] ?? '').toString();
      final text = (data['text'] ?? '').toString();

      final ts = data['timestamp'];
      final tsMs = data['timestampMs'];
      DateTime time;
      if (ts is Timestamp) {
        time = ts.toDate();
      } else if (ts is DateTime) {
        time = ts;
      } else if (ts is num) {
        time = DateTime.fromMillisecondsSinceEpoch(ts.toInt());
      } else if (tsMs is int) {
        time = DateTime.fromMillisecondsSinceEpoch(tsMs);
      } else if (tsMs is num) {
        time = DateTime.fromMillisecondsSinceEpoch(tsMs.toInt());
      } else {
        time = DateTime.now();
      }

      final msg = Message(
        content: text,
        senderId: senderId,
        chatSessionId: sessionId,
        timestamp: time,
        isFromMe: senderId == currentUserId,
      );

      if (sections.isEmpty) {
        sections.add(_MessageSection(date: time, messages: [msg]));
      } else {
        final last = sections.last;
        if (_isSameDay(last.date, time)) {
          last.messages.add(msg);
        } else {
          sections.add(_MessageSection(date: time, messages: [msg]));
        }
      }
    }
    return sections;
  }

  Widget _buildEmptyMessagesView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.chat_bubble_outline,
            size: 80,
            color: AppTheme.subtitleColor,
          ),
          const SizedBox(height: 16),
          Text(
            'Start the conversation!',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: AppTheme.subtitleColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Send your first message below',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Message message) {
    final isFromMe = message.isFromMe;
    final time = DateFormat('HH:mm').format(message.timestamp);

    return Align(
      alignment: isFromMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment: isFromMe 
              ? CrossAxisAlignment.end 
              : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: isFromMe 
                    ? AppTheme.primaryColor 
                    : AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(20).copyWith(
                  bottomRight: isFromMe 
                      ? const Radius.circular(4) 
                      : const Radius.circular(20),
                  bottomLeft: !isFromMe 
                      ? const Radius.circular(4) 
                      : const Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                message.content,
                style: TextStyle(
                  color: isFromMe ? Colors.white : AppTheme.textColor,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                time,
                style: const TextStyle(
                  color: AppTheme.subtitleColor,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput(ChatProvider chatProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                hintText: 'Type a message...',
                border: InputBorder.none,
              ),
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _sendMessage(chatProvider),
            ),
          ),
          const SizedBox(width: 12),
          FloatingActionButton.small(
            onPressed: () => _sendMessage(chatProvider),
            backgroundColor: AppTheme.primaryColor,
            child: const Icon(Icons.send, color: Colors.white),
          ),
        ],
      ),
    );
  }

  void _sendMessage(ChatProvider chatProvider) async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    // Clear input immediately for better UX
    _messageController.clear();

    // Send message using Firestore
    final session = chatProvider.currentSession;
    if (session == null) return;
    final userId = await UserIdHelper.getUserId();
    try {
      await chatProvider.sendMessage(session.id, text, userId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    // Scroll to bottom to show new message
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });

  // Optional feedback if not connected (kept for UX)
  if (!chatProvider.isConnected && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message queued - will send when connected'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _showEndChatDialog(BuildContext context, ChatProvider chatProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Chat'),
        content: const Text(
          'Are you sure you want to end this chat? The conversation will be saved but the connection will be closed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              await chatProvider.endCurrentSession();
              if (context.mounted) {
                Navigator.popUntil(context, (route) => route.isFirst);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Chat ended'),
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('End Chat'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

// Section model for grouping messages by date
class _MessageSection {
  final DateTime date;
  final List<Message> messages;

  _MessageSection({required this.date, required this.messages});
}

// Sliver delegate to render a pinned date label like WhatsApp
class _DateHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String label;
  final Color backgroundColor;

  _DateHeaderDelegate({required this.label, this.backgroundColor = Colors.transparent});

  @override
  double get minExtent => 36;

  @override
  double get maxExtent => 36;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: backgroundColor,
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: AppTheme.subtitleColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _DateHeaderDelegate oldDelegate) {
    return oldDelegate.label != label || oldDelegate.backgroundColor != backgroundColor;
  }
}
