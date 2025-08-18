import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../providers/chat_provider_web.dart';
import '../utils/app_theme.dart';

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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Generate QR Code'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Center(
            // Keep content nicely centered on wide screens while filling on mobile
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
            // QR Code display
            SizedBox(
              width: double.infinity,
              child: Card(
                elevation: 8,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
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

            // Simple hint
            Text(
              'Share this QR. The other device scans to start a chat.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),

            const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
  ),
    );
  }
}
