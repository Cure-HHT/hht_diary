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
        // Portal is web-first but macOS desktop is used for integration tests.
        // Same FlavorConfig credentials apply — Firebase Auth is project-level.
        return web;
      case TargetPlatform.windows:
        throw UnsupportedError('Windows not supported for portal');
      case TargetPlatform.linux:
        // Portal is web-first but Linux desktop is used for CI integration tests.
        return web;
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
