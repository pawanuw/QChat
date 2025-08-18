import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'providers/chat_provider_web.dart';
import 'utils/app_theme.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
  options: const FirebaseOptions(
    apiKey: "AIzaSyAWQEFgK4VfYSJocUT8XBkwyZcqQ1ULtFU",
    authDomain: "qchat-chat-app.firebaseapp.com",
    projectId: "qchat-chat-app",
    storageBucket: "qchat-chat-app.firebasestorage.app",
    messagingSenderId: "684837269700",
    appId: "1:684837269700:web:c34668fdb2c9d049a81991",
  ),
);
  runApp(const QChatApp());
}

class QChatApp extends StatelessWidget {
  const QChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ChatProvider()),
      ],
      child: MaterialApp(
        title: 'QChat',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const HomeScreen(),
      ),
    );
  }
}
