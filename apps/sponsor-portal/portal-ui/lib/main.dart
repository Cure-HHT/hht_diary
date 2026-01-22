// IMPLEMENTS REQUIREMENTS:
//   REQ-p00009: Sponsor-Specific Web Portals
//   REQ-p00024: Portal User Roles and Permissions
//   REQ-d00028: Portal Frontend Framework
//   REQ-d00029: Portal UI Design System
//   REQ-d00031: Identity Platform Integration
//   REQ-d00005: Sponsor Configuration Detection Implementation

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_strategy/url_strategy.dart';

import 'firebase_options.dart';
import 'flavors.dart';
import 'router/app_router.dart';
import 'services/auth_service.dart';
import 'theme/portal_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Remove # from URLs
  setPathUrlStrategy();

  // Initialize flavor from environment
  // Pass --dart-define=APP_FLAVOR=local (or dev, qa, uat, prod)
  const flavorName = String.fromEnvironment(
    'APP_FLAVOR',
    defaultValue: 'local',
  );
  final flavor = flavorFromString(flavorName) ?? Flavor.local;
  FlavorConfig.initialize(flavor);

  // Validate Firebase configuration (throws for non-local if missing)
  FlavorConfig.validateConfig();

  debugPrint('Running with flavor: ${F.name} (${F.title})');

  // Initialize Firebase with flavor-specific config
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Connect to Firebase Emulator only for local flavor (if emulator is running)
  if (F.useEmulator) {
    const emulatorHost = String.fromEnvironment(
      'FIREBASE_AUTH_EMULATOR_HOST',
      defaultValue: '',
    );
    if (emulatorHost.isNotEmpty) {
      final parts = emulatorHost.split(':');
      final host = parts[0];
      final port = int.tryParse(parts.length > 1 ? parts[1] : '9099') ?? 9099;
      try {
        await FirebaseAuth.instance.useAuthEmulator(host, port);
        debugPrint('Using Firebase Auth Emulator at $host:$port');
      } catch (e) {
        debugPrint('Failed to connect to Firebase Auth Emulator: $e');
      }
    } else {
      debugPrint(
        'WARNING: Local flavor but no FIREBASE_AUTH_EMULATOR_HOST set',
      );
      debugPrint('Using real Firebase Auth with local flavor config');
    }
  }

  runApp(const CarinaPortalApp());
}

class CarinaPortalApp extends StatelessWidget {
  const CarinaPortalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => AuthService())],
      child: MaterialApp.router(
        title: F.title,
        theme: portalTheme,
        routerConfig: appRouter,
        debugShowCheckedModeBanner: F.showBanner,
      ),
    );
  }
}
