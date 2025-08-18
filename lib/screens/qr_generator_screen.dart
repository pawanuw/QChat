import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../providers/chat_provider_web.dart';
import '../utils/app_theme.dart';
import 'chat_screen.dart';

class QRGeneratorScreen extends StatefulWidget {
  const QRGeneratorScreen({super.key});

  @override
  State<QRGeneratorScreen> createState() => _QRGeneratorScreenState();
}

class _QRGeneratorScreenState extends State<QRGeneratorScreen> {
  String qrData = '';
  bool isWaitingForConnection = false;

  @override
  void initState() {
    super.initState();
    _generateQRCode();
  }

  void _generateQRCode() {
    final chatProvider = context.read<ChatProvider>();
    setState(() {
      qrData = chatProvider.generateQRData();
      isWaitingForConnection = true;
    });

    // Start checking for connections (simulated)
    _checkForConnection();
  }

  void _checkForConnection() {
    // In a real app, you would listen for incoming connections
    // For demo purposes, we'll simulate a connection after 10 seconds
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted && isWaitingForConnection) {
        _simulateIncomingConnection();
      }
    });
  }

  void _simulateIncomingConnection() async {
    if (!mounted) return;

    // Simulate someone scanning our QR code
    final chatProvider = context.read<ChatProvider>();
    final success = await chatProvider.connectToSession(qrData);

    if (success && mounted) {
      setState(() {
        isWaitingForConnection = false;
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Someone connected! Starting chat...'),
          backgroundColor: AppTheme.secondaryColor,
        ),
      );

      // Navigate to chat screen
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const ChatScreen(),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Generate QR Code'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _generateQRCode,
            tooltip: 'Generate new QR code',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
            // QR Code display
            Card(
              elevation: 8,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    if (qrData.isNotEmpty)
                      QrImageView(
                        data: qrData,
                        version: QrVersions.auto,
                        size: 250.0,
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.primaryColor,
                      )
                    else
                      Container(
                        width: 250,
                        height: 250,
                        decoration: BoxDecoration(
                          color: AppTheme.backgroundColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Text(
                      'QR Code for Chat',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Instructions
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: AppTheme.primaryColor,
                    size: 32,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'How to connect:',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '1. Show this QR code to the other person\n'
                    '2. They should scan it with their QChat app\n'
                    '3. Chat will start automatically once connected',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Connection status
            if (isWaitingForConnection)
              Column(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Waiting for someone to scan...',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Keep this screen open',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              )
            else
              Column(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: AppTheme.secondaryColor,
                    size: 48,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Connected!',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppTheme.secondaryColor,
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 24),
          ],
        ),
      ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Back'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: _generateQRCode,
                child: const Text('New QR Code'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
