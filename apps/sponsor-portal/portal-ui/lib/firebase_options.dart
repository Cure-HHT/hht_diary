// IMPLEMENTS REQUIREMENTS:
//   REQ-d00031: Identity Platform Integration
//   REQ-d00005: Sponsor Configuration Detection Implementation
//
// Firebase configuration for sponsor portal
// Uses FlavorConfig for environment-specific settings

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

import 'flavors.dart';

/// Firebase configuration options
///
/// Gets configuration values from FlavorConfig which is initialized
/// based on the current flavor (local, dev, qa, uat, prod).
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

  /// Web configuration - reads from FlavorConfig
  static FirebaseOptions get web {
    final values = FlavorConfig.values;
    return FirebaseOptions(
      apiKey: values.firebaseApiKey,
      appId: values.firebaseAppId,
      messagingSenderId: values.firebaseMessagingSenderId,
      projectId: values.firebaseProjectId,
      authDomain: values.firebaseAuthDomain,
    );
  }
}
