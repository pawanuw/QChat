import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:provider/provider.dart';
import '../providers/chat_provider_web.dart';
import '../utils/app_theme.dart';
import 'chat_screen.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final TextEditingController _qrController = TextEditingController();
  bool isProcessing = false;
  MobileScannerController? _scannerController;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _scannerController = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
        formats: const [BarcodeFormat.qrCode],
      );
      _requestCameraPermission();
    }
  }

  Future<void> _requestCameraPermission() async {
    final status = await ph.Permission.camera.request();
    if (status.isGranted) {
      await _scannerController?.start();
    } else if (status.isPermanentlyDenied) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Camera permission permanently denied. Enable it in Settings.'),
          action: SnackBarAction(label: 'Settings', onPressed: _openAppSettings),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // QR Scanner placeholder for web
            if (kIsWeb) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primaryColor, width: 2),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.qr_code_scanner,
                      size: 80,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'QR Scanner',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Camera scanning not available on web.\nUse manual input below for testing.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Manual QR input for web testing
              Text(
                'Manual QR Code Input',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _qrController,
                decoration: const InputDecoration(
                  labelText: 'Paste QR Code Data',
                  hintText: 'Enter QR code content here...',
                  prefixIcon: Icon(Icons.paste),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isProcessing ? null : _processQRCode,
                      child: isProcessing 
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Connect'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _generateTestQR,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.secondaryColor,
                      ),
                      child: const Text('Test QR'),
                    ),
                  ),
                ],
              ),
            ] else ...[
              // Mobile scanner implementation
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: double.infinity,
                  height: 320,
                  child: Stack(
                    children: [
                      MobileScanner(
                        controller: _scannerController,
                        errorBuilder: (context, error, child) {
                          String message;
                          switch (error.errorCode) {
                            case MobileScannerErrorCode.permissionDenied:
                              message = 'Camera permission denied. Enable it in Settings to scan.';
                              break;
                            case MobileScannerErrorCode.controllerUninitialized:
                              message = 'Scanner not initialized yet.';
                              break;
                            case MobileScannerErrorCode.unsupported:
                              message = 'Camera not supported on this device.';
                              break;
                            default:
                              message = 'Camera error: ${error.errorCode.name}';
                          }
                          return Container(
                            color: Colors.black,
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.error_outline, color: Colors.white, size: 48),
                                const SizedBox(height: 12),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                                  child: Text(message, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
                                ),
                                const SizedBox(height: 12),
                                if (message.contains('permission'))
                                  ElevatedButton(
                                    onPressed: _openAppSettings,
                                    child: const Text('Open Settings'),
                                  ),
                              ],
                            ),
                          );
                        },
                        onDetect: (capture) async {
                          if (isProcessing) return;
                          final barcodes = capture.barcodes;
                          if (barcodes.isEmpty) return;
                          final value = barcodes.first.rawValue;
                          if (value == null || value.isEmpty) return;
                          await _scannerController?.stop();
                          _qrController.text = value;
                          await _processQRCode();
                        },
                      ),
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Row(children: [
                          IconButton(
                            icon: const Icon(Icons.flash_on, color: Colors.white),
                            onPressed: () => _scannerController?.toggleTorch(),
                          ),
                          IconButton(
                            icon: const Icon(Icons.cameraswitch, color: Colors.white),
                            onPressed: () => _scannerController?.switchCamera(),
                          ),
                        ]),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Point the camera at a QR code',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],

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
                    'How to scan:',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    kIsWeb 
                        ? '1. Get QR code data from the other person\n'
                          '2. Paste it in the text field above\n'
                          '3. Tap "Connect" to start chatting'
                        : '1. Point camera at the QR code\n'
                          '2. QR code will be scanned automatically\n'
                          '3. Chat will start once connected',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _generateTestQR() {
    final chatProvider = context.read<ChatProvider>();
    final testQR = chatProvider.generateQRData();
    _qrController.text = testQR;
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Test QR code generated! Tap "Connect" to test.'),
        backgroundColor: AppTheme.secondaryColor,
      ),
    );
  }

  Future<void> _processQRCode() async {
    final qrCode = _qrController.text.trim();
    if (qrCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter QR code data'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      isProcessing = true;
    });

  try {
      final chatProvider = context.read<ChatProvider>();
      final success = await chatProvider.connectToSession(qrCode);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connected successfully! Starting chat...'),
            backgroundColor: AppTheme.secondaryColor,
          ),
        );

        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const ChatScreen(),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid QR code or connection failed'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isProcessing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _qrController.dispose();
  _scannerController?.dispose();
    super.dispose();
  }

  void _openAppSettings() {
    ph.openAppSettings();
  }
}
