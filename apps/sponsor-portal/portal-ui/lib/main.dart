// IMPLEMENTS REQUIREMENTS:
//   REQ-p00009: Sponsor-Specific Web Portals
//   REQ-p00024: Portal User Roles and Permissions
//   REQ-d00028: Portal Frontend Framework
//   REQ-d00029: Portal UI Design System
//   REQ-d00031: Identity Platform Integration

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_strategy/url_strategy.dart';

import 'firebase_options.dart';
import 'router/app_router.dart';
import 'services/auth_service.dart';
import 'theme/portal_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Remove # from URLs
  setPathUrlStrategy();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Connect to Firebase Emulator in debug mode
  if (kDebugMode) {
    const emulatorHost = String.fromEnvironment(
      'FIREBASE_AUTH_EMULATOR_HOST',
      defaultValue: 'localhost:9099',
    );
    if (emulatorHost.isNotEmpty) {
      final parts = emulatorHost.split(':');
      final host = parts[0];
      final port = int.tryParse(parts.length > 1 ? parts[1] : '9099') ?? 9099;
      await FirebaseAuth.instance.useAuthEmulator(host, port);
      debugPrint('Using Firebase Auth Emulator at $host:$port');
    }
  }

  runApp(const CarinaPortalApp());
}

class CarinaPortalApp extends StatelessWidget {
  const CarinaPortalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
      ],
      child: MaterialApp.router(
        title: 'Carina Clinical Trial Portal',
        theme: portalTheme,
        routerConfig: appRouter,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
