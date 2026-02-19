// IMPLEMENTS REQUIREMENTS:
//   REQ-p00009: Sponsor-Specific Web Portals
//   REQ-p00024: Portal User Roles and Permissions
//   REQ-d00028: Portal Frontend Framework
//   REQ-d00029: Portal UI Design System
//   REQ-d00031: Identity Platform Integration
//   REQ-d00005: Sponsor Configuration Detection Implementation
//   REQ-o00056: Container infrastructure for Cloud Run

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_strategy/url_strategy.dart';

import 'firebase_options.dart';
import 'flavors.dart';
import 'router/app_router.dart';
import 'services/auth_service.dart';
import 'services/identity_config_service.dart';
import 'services/sponsor_branding_service.dart';
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

  debugPrint('Starting portal with flavor: ${flavor.name}');

  // Initialize configuration based on flavor
  if (flavor == Flavor.local) {
    // Local development: use emulator config synchronously
    FlavorConfig.initializeLocal();
    debugPrint('Using local emulator configuration');
  } else {
    // Deployed environments: fetch config from server
    try {
      final config = await IdentityConfigService().fetchConfig();
      final apiBaseUrl = kDebugMode ? 'http://localhost:8080' : Uri.base.origin;

      FlavorConfig.initializeWithConfig(flavor, config, apiBaseUrl: apiBaseUrl);
      debugPrint('Identity Platform config loaded: ${config.projectId}');
    } on IdentityConfigException catch (e) {
      debugPrint('Failed to fetch Identity Platform config: $e');

      if (kDebugMode) {
        // In debug mode, fall back to emulator with warning
        debugPrint('WARNING: Falling back to emulator config for development');
        FlavorConfig.initializeWithEmulatorFallback(flavor);
      } else {
        // In release mode, show error app
        runApp(ConfigErrorApp(error: e.message));
        return;
      }
    } catch (e) {
      debugPrint('Unexpected error fetching config: $e');

      if (kDebugMode) {
        debugPrint('WARNING: Falling back to emulator config for development');
        FlavorConfig.initializeWithEmulatorFallback(flavor);
      } else {
        runApp(ConfigErrorApp(error: 'Failed to load configuration: $e'));
        return;
      }
    }
  }

  // Validate Firebase configuration
  FlavorConfig.validateConfig();

  debugPrint('Running with flavor: ${F.name} (${F.title})');

  // Fetch sponsor branding (non-fatal: use fallback if unavailable)
  var sponsorBranding = SponsorBrandingConfig.fallback;
  try {
    sponsorBranding = await SponsorBrandingService().fetchBranding();
    debugPrint('Sponsor branding loaded: ${sponsorBranding.title}');
  } catch (e) {
    debugPrint('Sponsor branding unavailable, using fallback: $e');
  }

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

  runApp(CarinaPortalApp(branding: sponsorBranding));
}

class CarinaPortalApp extends StatelessWidget {
  final SponsorBrandingConfig branding;

  const CarinaPortalApp({super.key, required this.branding});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        Provider<SponsorBrandingConfig>.value(value: branding),
      ],
      child: MaterialApp.router(
        title: branding.title,
        theme: portalTheme,
        routerConfig: appRouter,
        debugShowCheckedModeBanner: F.showBanner,
      ),
    );
  }
}

/// Error app shown when configuration fails to load in release mode
///
/// Provides a user-friendly error message with retry option.
class ConfigErrorApp extends StatelessWidget {
  final String error;

  const ConfigErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Configuration Error',
      theme: portalTheme,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 24),
                const Text(
                  'Configuration Error',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text(
                  error,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    // Reload the page to retry
                    // ignore: avoid_dynamic_calls
                    // HTML reload equivalent for web
                    debugPrint('Retry requested - user should refresh page');
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh Page'),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Please contact your administrator if this problem persists.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
