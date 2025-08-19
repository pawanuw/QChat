import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider_web.dart';
import '../utils/app_theme.dart';
import 'qr_generator_screen.dart';
import 'qr_scanner_screen.dart';
import 'chat_screen.dart';
import 'unread_notifications_screen.dart';
import '../models/chat_session.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QChat'),
        actions: [
          // Notifications button with unread badge
          Consumer<ChatProvider>(
            builder: (context, chatProvider, _) {
              final unreadCount = chatProvider.unreadCount;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    tooltip: 'Unread messages',
                    onPressed: () async {
                      // Navigate to unread notifications list
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const UnreadNotificationsScreen(),
                        ),
                      );
                      // Do not auto-clear on return; badge updates reactively
                    },
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 12,
                      top: 12,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Welcome section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 80,
                  color: AppTheme.primaryColor.withOpacity(0.7),
                ),
                const SizedBox(height: 16),
                Text(
                  'Welcome to QChat',
                  style: Theme.of(context).textTheme.headlineLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Connect instantly with QR codes',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          // Action buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const QRGeneratorScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.qr_code),
                    label: const Text('Generate QR'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const QRScannerScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Scan QR'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.secondaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Recent chats section
          Expanded(
            child: Consumer<ChatProvider>(
              builder: (context, chatProvider, child) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'Recent Chats',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: chatProvider.chatSessions.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.chat_outlined,
                                    size: 64,
                                    color: AppTheme.subtitleColor,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No chats yet',
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Generate or scan a QR code to start chatting',
                                    style: Theme.of(context).textTheme.bodyMedium,
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: chatProvider.chatSessions.length,
                              itemBuilder: (context, index) {
                                final session = chatProvider.chatSessions[index];
                                return _buildChatSessionCard(context, session);
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatSessionCard(BuildContext context, ChatSession session) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: session.isActive ? AppTheme.secondaryColor : AppTheme.subtitleColor,
          child: Icon(
            session.isActive ? Icons.chat : Icons.chat_outlined,
            color: Colors.white,
          ),
        ),
        title: Align(
          alignment: Alignment.centerLeft,
          child: Text(session.peerName),
        ),
        // Remove subtitle and status dot for a cleaner list per request
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'delete') {
                  await context.read<ChatProvider>().deleteChatSession(session.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Chat deleted')),
                    );
                  }
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        onTap: () async {
          await context.read<ChatProvider>().setCurrentSession(session);
          if (context.mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ChatScreen(),
              ),
            );
          }
        },
      ),
    );
  }
  // Info dialog removed per request
}
