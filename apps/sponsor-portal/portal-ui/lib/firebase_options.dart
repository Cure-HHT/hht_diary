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
        // macOS native Firebase SDK requires Apple platform app ID format (:ios:)
        return apple;
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

  /// Apple platform configuration (macOS/iOS) - reads from FlavorConfig
  ///
  /// The native Firebase SDK on Apple platforms requires an Apple-format
  /// app ID (`:ios:` instead of `:web:`). All other credentials are
  /// project-level and identical across platforms.
  static FirebaseOptions get apple {
    final values = FlavorConfig.values;
    // Convert web app ID format to Apple format for native SDK compatibility
    final appleAppId = values.firebaseAppId.replaceFirst(':web:', ':ios:');
    return FirebaseOptions(
      apiKey: values.firebaseApiKey,
      appId: appleAppId,
      messagingSenderId: values.firebaseMessagingSenderId,
      projectId: values.firebaseProjectId,
      authDomain: values.firebaseAuthDomain,
      iosBundleId: 'com.example.sponsorPortalUi',
    );
  }
}
