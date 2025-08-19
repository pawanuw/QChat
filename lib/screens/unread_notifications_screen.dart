import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider_web.dart';
import '../models/message.dart';
import 'chat_screen.dart';
import '../utils/app_theme.dart';

class UnreadNotificationsScreen extends StatelessWidget {
  const UnreadNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          Consumer<ChatProvider>(
            builder: (context, provider, _) => TextButton(
              onPressed: provider.unreadCount > 0
                  ? () => provider.markAllAsRead()
                  : null,
              child: Text(
                'Mark all read',
                style: TextStyle(
                  color: provider.unreadCount > 0 ? Colors.white : Colors.white70,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Consumer<ChatProvider>(
        builder: (context, provider, _) {
          final unread = provider.unreadMessages;
          if (unread.isEmpty) {
            return _buildEmpty();
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: unread.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final msg = unread[index];
              return _NotificationTile(message: msg);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_none, size: 72, color: AppTheme.subtitleColor),
          SizedBox(height: 12),
          Text('You\'re all caught up!'),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final Message message;
  const _NotificationTile({required this.message});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<ChatProvider>();
    String title;
    try {
      final session = provider.chatSessions.firstWhere(
        (s) => s.id == message.chatSessionId,
      );
      title = session.peerName;
    } catch (_) {
      title = 'New message';
    }
    return Card(
      elevation: 1,
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: AppTheme.primaryColor,
          child: Icon(Icons.chat, color: Colors.white),
        ),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(message.content, maxLines: 2, overflow: TextOverflow.ellipsis),
        onTap: () async {
          // Open the relevant chat and mark as read
          try {
            final session = provider.chatSessions.firstWhere((s) => s.id == message.chatSessionId);
            await provider.setCurrentSession(session); // also marks chat as read
            if (context.mounted) {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChatScreen()),
              );
            }
          } catch (_) {
            // If session isn't found, just mark as read to clear the item
            provider.markChatAsRead(message.chatSessionId);
          }
        },
      ),
    );
  }
}
