// IMPLEMENTS REQUIREMENTS:
//   REQ-d00031: Identity Platform Integration
//
// Firebase configuration for sponsor portal
// For local development, use Firebase Emulator

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Firebase configuration options
///
/// For local development with emulator, these values are placeholders.
/// For production, replace with actual Firebase project config.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        throw UnsupportedError('Android not supported for portal');
      case TargetPlatform.iOS:
        throw UnsupportedError('iOS not supported for portal');
      case TargetPlatform.macOS:
        throw UnsupportedError('macOS not supported for portal');
      case TargetPlatform.windows:
        throw UnsupportedError('Windows not supported for portal');
      case TargetPlatform.linux:
        throw UnsupportedError('Linux not supported for portal');
      default:
        throw UnsupportedError('Unsupported platform');
    }
  }

  // Web configuration for demo-sponsor-portal
  // These are placeholder values for emulator use
  // Replace with actual values from Firebase Console for production
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'demo-api-key',
    appId: '1:000000000000:web:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'demo-sponsor-portal',
    authDomain: 'demo-sponsor-portal.firebaseapp.com',
  );
}
