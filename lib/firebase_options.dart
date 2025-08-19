// File generated manually to mirror FlutterFire CLI structure.
// Provides DefaultFirebaseOptions.currentPlatform for Firebase.initializeApp.

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  DefaultFirebaseOptions._();

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macOS.\n'
          'To configure, run the FlutterFire CLI or add macOS options here.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for Windows.\n'
          'To configure, run the FlutterFire CLI or add Windows options here.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for Linux.\n'
          'To configure, run the FlutterFire CLI or add Linux options here.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // Web configuration (from lib/main.dart)
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAWQEFgK4VfYSJocUT8XBkwyZcqQ1ULtFU',
    appId: '1:684837269700:web:c34668fdb2c9d049a81991',
    messagingSenderId: '684837269700',
    projectId: 'qchat-chat-app',
    authDomain: 'qchat-chat-app.firebaseapp.com',
    storageBucket: 'qchat-chat-app.firebasestorage.app',
  );

  // Android configuration (from android/app/google-services.json)
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDnfyajknMunHO-8Ql2P1igxu2oWJCqrk4',
    appId: '1:684837269700:android:4d33b771e0bac727a81991',
    messagingSenderId: '684837269700',
    projectId: 'qchat-chat-app',
    storageBucket: 'qchat-chat-app.firebasestorage.app',
  );

  // iOS configuration (from ios/Runner/GoogleService-Info.plist)
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDMCFNtLD1e6Aj-hyUk-7hOPKTqvsTi_cc',
    appId: '1:684837269700:ios:727b72d8c44fa043a81991',
    messagingSenderId: '684837269700',
    projectId: 'qchat-chat-app',
    storageBucket: 'qchat-chat-app.firebasestorage.app',
    iosBundleId: 'com.example.qChat',
  );
}
