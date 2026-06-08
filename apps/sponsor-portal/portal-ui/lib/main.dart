// IMPLEMENTS REQUIREMENTS:
//   REQ-p00009: Sponsor-Specific Web Portals
//   REQ-p00024: Portal User Roles and Permissions
//   REQ-d00028: Portal Frontend Framework
//   REQ-d00029: Portal UI Design System
//   REQ-d00031: Identity Platform Integration
//   REQ-d00005: Sponsor Configuration Detection Implementation
//   REQ-o00056: Container infrastructure for Cloud Run

import 'dart:async';
import 'dart:js_interop';

import 'package:diary_design_system/diary_design_system.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import 'package:provider/provider.dart';
import 'package:url_strategy/url_strategy.dart';

import 'config/app_config.dart';
import 'config/env_profile.dart';
import 'firebase_options.dart';
import 'router/app_router.dart';
import 'services/auth_service.dart';
import 'services/browser_lifecycle_service.dart';
import 'services/browser_storage_service.dart';
import 'services/identity_config_service.dart';
import 'services/sponsor_branding_service.dart';
import 'theme/portal_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // CUR-1280: previous builds shipped flutter_service_worker.js. PWA is
  // now disabled at build time, but a SW already installed in the
  // user's browser survives. Unregister any leftover SW on boot.
  // IMPLEMENTS: REQ-p00009 (Sponsor-Specific Web Portals must serve
  //             the latest deploy; a leftover SW shadows new main.dart.js).
  // Note: closest direct assertion is REQ-d00077-I but that REQ is
  //       scoped to the Web Diary (REQ-p01042); no portal-specific
  //       equivalent exists. Policy applied by analogy.
  unawaited(_unregisterLeftoverServiceWorkers());

  // Remove # from URLs
  setPathUrlStrategy();

  // Resolve the environment at runtime — the portal web bundle is a single
  // promotable artifact that carries no environment identity of its own.
  // Local-stack builds (which target the Firebase emulator) are detected by
  // the emulator-host build input; every deployed bundle is identical and
  // discovers its environment from the server's same-origin runtime config.
  // Implements: DIARY-OPS-single-promotable-artifact/B
  // Implements: DIARY-DEV-runtime-environment-resolution/A+C
  if (AppConfig.useEmulator) {
    // Local development: use emulator config synchronously.
    AppConfig.initializeLocal();
    debugPrint('Using local emulator configuration');
  } else {
    // Deployed environments: fetch config (and the environment name) from
    // the server.
    try {
      final config = await IdentityConfigService().fetchConfig();
      final apiBaseUrl = kDebugMode ? 'http://localhost:8084' : Uri.base.origin;

      AppConfig.initializeFromServer(config, apiBaseUrl: apiBaseUrl);
      debugPrint(
        'Identity Platform config loaded: ${config.projectId} '
        '(${EnvProfile.current.name})',
      );
    } on IdentityConfigException catch (e) {
      // CUR-1280: do NOT silently downgrade a deployed build to the emulator
      // just because the identity-config endpoint is unreachable. Surfacing a
      // clear error (rather than flipping to emulator mode) avoids opening the
      // trusted-by-locality Auth-emulator code paths in a build that may be
      // talking to a real backend, and avoids silently masking a config-server
      // outage. Emulator mode is reached only by a local-stack build that sets
      // FIREBASE_AUTH_EMULATOR_HOST.
      debugPrint('Failed to fetch Identity Platform config: $e');
      runApp(ConfigErrorApp(error: e.message));
      return;
    } catch (e) {
      debugPrint('Unexpected error fetching config: $e');
      runApp(ConfigErrorApp(error: 'Failed to load configuration: $e'));
      return;
    }
  }

  // Validate Firebase configuration
  AppConfig.validateConfig();

  debugPrint(
    'Running in environment: ${EnvProfile.current.name} '
    '(${EnvProfile.current.title})',
  );

  // Fetch sponsor branding (non-fatal: use fallback if unavailable)
  var sponsorBranding = SponsorBrandingConfig.fallback;
  try {
    sponsorBranding = await SponsorBrandingService().fetchBranding();
    debugPrint('Sponsor branding loaded: ${sponsorBranding.title}');
  } catch (e) {
    debugPrint('Sponsor branding unavailable, using fallback: $e');
  }

  // CUR-1280: on local-flavor, wipe firebaseLocalStorageDb BEFORE
  // Firebase.initializeApp.
  //
  // Firebase JS SDK auto-restores the user from IndexedDB synchronously
  // inside initializeApp + first FirebaseAuth.instance access — and that
  // restore fires `accounts:lookup` against whatever endpoint is bound at
  // that moment. flutterfire #9528: useAuthEmulator can't bind until AFTER
  // initializeApp, by which time auto-restore has already fired against
  // PRODUCTION (https://identitytoolkit.googleapis.com) and failed with
  // api-key-not-valid. Re-binding later doesn't undo the failed restore.
  //
  // We can't move useAuthEmulator earlier (it requires the initialized
  // app). So we eliminate the restore: with no state in IndexedDB,
  // initializeApp has nothing to lookup. The first auth network call is
  // an explicit signIn (where useAuthEmulator has by then bound), so all
  // subsequent ops route to the emulator cleanly.
  //
  // Cost: on local-flavor, page refresh = re-login (no IndexedDB =
  // no session restore). Acceptable for local dev; the alternative
  // ("Clear Site Data every time, randomly") is worse. Production
  // flavors are unaffected — they don't run this path.
  if (AppConfig.useEmulator) {
    await BrowserStorageService().forceClearFirebaseAuthDb();
  }

  // Initialize Firebase with flavor-specific config
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Connect to Firebase Auth Emulator for local flavor.
  //
  // Must run before any other Auth operation (including setPersistence).
  // Failures here are fatal in local flavor — falling through to real
  // Firebase produces a misleading "api-key-not-valid" error from the
  // production endpoint instead of a clear "emulator unreachable" one.
  // CUR-1264 follow-up: the previous swallow-and-debugPrint left users
  // staring at activation_page.dart's misleading translation of api-key-
  // not-valid as "Firebase Auth emulator is running (port 9099)" with no
  // actionable signal.
  if (AppConfig.useEmulator) {
    const emulatorHost = String.fromEnvironment(
      'FIREBASE_AUTH_EMULATOR_HOST',
      defaultValue: '',
    );
    if (emulatorHost.isEmpty) {
      runApp(
        const ConfigErrorApp(
          error:
              'FIREBASE_AUTH_EMULATOR_HOST is not set. The Firebase Auth '
              'emulator can only be reached when this value is baked into '
              'the build (it is read via String.fromEnvironment, not '
              'window-injected).\n\n'
              'For local-stack: rebuild the portal-final image (in the '
              'sponsor repo) with '
              '--dart-define=FIREBASE_AUTH_EMULATOR_HOST=localhost:9099.\n\n'
              'For developer flutter run: re-run with the same '
              '--dart-define flag.',
        ),
      );
      return;
    }
    final parts = emulatorHost.split(':');
    final host = parts[0];
    final port = int.tryParse(parts.length > 1 ? parts[1] : '9099') ?? 9099;
    try {
      await FirebaseAuth.instance.useAuthEmulator(host, port);
      debugPrint('[AUTH] Connected to Firebase Auth Emulator at $host:$port');
    } catch (e, st) {
      debugPrint('[AUTH] FATAL: useAuthEmulator($host, $port) failed: $e\n$st');
      runApp(
        ConfigErrorApp(
          error:
              'Could not connect Firebase Auth to the local emulator at '
              '$host:$port.\n\nUnderlying error: $e\n\nVerify the '
              'firebase-emulator container is running and reachable, '
              'then refresh this page.',
        ),
      );
      return;
    }
  }

  // CUR-1157: Do NOT call setPersistence(Persistence.LOCAL) here.
  // On Flutter web, Persistence.LOCAL maps to browserLocalPersistence
  // (localStorage), not IndexedDB as the previous comment claimed. The
  // SDK's default on web is already indexedDBLocalPersistence, which
  // survives refresh. Calling setPersistence(LOCAL) forced a migration to
  // localStorage on every load, and under Safari ITP / partitioned storage
  // / certain embed contexts that backend silently falls back to
  // in-memory — which is exactly the symptom CUR-1118 was meant to fix.

  // CUR-1157: Distinguish page refresh from a fresh tab load / post-close
  // using the Performance Navigation Timing API rather than a beforeunload
  // sessionStorage handshake.
  //
  // The previous CUR-1118 approach set a '_portalRefreshing' flag in
  // sessionStorage from a beforeunload listener and read it back on the
  // next load. That handshake is fragile:
  //   • beforeunload doesn't fire reliably on all browsers / contexts
  //     (mobile Safari, some embed contexts, abrupt unloads),
  //   • sessionStorage writes during unload can be discarded under memory
  //     pressure or BFCache transitions,
  //   • any code path that registered the listener late (initial load
  //     before BrowserLifecycleService.register, hot reload during dev,
  //     background-tab discard) misses the write entirely.
  // When the flag is missing the AuthService treats the load as a fresh
  // tab and signs out the Firebase session — the exact symptom users see.
  //
  // PerformanceNavigationTiming.type is the browser's authoritative answer
  // to "how did this document arrive?" and does not depend on prior code
  // having executed:
  //   • 'reload'        → F5 / Cmd+R / browser reload button
  //   • 'navigate'      → fresh tab, address-bar nav, link click
  //   • 'back_forward'  → BFCache restore (treat as refresh: session is
  //                       still the user's, no need to log them out)
  //   • 'prerender'     → speculative prerender (treat as fresh)
  final navEntries = web.window.performance
      .getEntriesByType('navigation')
      .toDart;
  final navType = navEntries.isNotEmpty
      ? (navEntries.first as web.PerformanceNavigationTiming).type
      : '';
  final isPageRefresh = navType == 'reload' || navType == 'back_forward';

  // Create AuthService here so the browser lifecycle service can hold a
  // direct reference before the widget tree is built.
  // REQ-d00083-A..E, REQ-p01044-J..M: inject real browser storage clearing.
  // CUR-1280: also inject the auto-recovery DB-wipe so AuthService can
  // call it without depending on package:web (keeps unit tests on VM).
  //
  // CUR-1280 (Copilot review): forceClearFirebaseAuthDb is a no-op-or-better
  // hammer for the local-emulator restore race (see firebase_emulator_helper.dart
  // for the flutterfire #9528 background). It MUST NOT fire on deployed
  // flavors — wiping firebaseLocalStorageDb in production would silently
  // log out every user on every recoverable refresh hiccup. Inject the
  // real implementation only on local flavor; deployed flavors get a
  // null-equivalent no-op so any auto-recovery path becomes signOut-only.
  final browserStorage = BrowserStorageService();
  final authService = AuthService(
    sponsorId: sponsorBranding.sponsorId,
    clearStorage: browserStorage.clearStorage,
    forceClearFirebaseAuthDb: AppConfig.useEmulator
        ? browserStorage.forceClearFirebaseAuthDb
        : () async {},
    isPageRefresh: isPageRefresh,
  );

  // REQ-d00080-G: beforeunload handler, REQ-d00080-K: visibilitychange handler,
  // REQ-p01044-D: terminate session on tab/window close.
  // Web-only: browser_lifecycle_service.dart uses dart:js_interop.
  final lifecycleService = BrowserLifecycleService()..register(authService);

  runApp(
    CarinaPortalApp(
      branding: sponsorBranding,
      authService: authService,
      lifecycleService: lifecycleService,
    ),
  );
}

/// Unregister any service worker registrations left over from a previous
/// deploy. PWA is disabled at build time
/// (deployment/docker/portal-final.Dockerfile: --pwa-strategy=none),
/// but an SW already in the browser persists until explicitly removed.
///
/// IMPLEMENTS REQUIREMENTS:
///   REQ-p00009 (always serve the latest deploy)
///   REQ-p01044-M (no participant data recoverable from the browser after
///                 logout — SW caches could otherwise persist)
///
/// Note: REQ-d00077-H/I/N states the explicit "SHALL disable SW" /
/// "SHALL unregister existing SW" policy but is scoped to the Web Diary
/// (implements REQ-p01042). No portal-specific equivalent exists; we
/// apply the same policy by analogy to the portal here.
Future<void> _unregisterLeftoverServiceWorkers() async {
  if (!kIsWeb) return;
  final List<web.ServiceWorkerRegistration> regs;
  try {
    regs = (await web.window.navigator.serviceWorker.getRegistrations().toDart)
        .toDart
        .toList();
  } catch (_) {
    // ServiceWorker API unavailable — nothing to do.
    return;
  }
  for (final reg in regs) {
    try {
      await reg.unregister().toDart;
    } catch (e) {
      // Best-effort: a single registration's failure to unregister
      // (security error, internal browser error) must not block boot.
      // Log so it doesn't vanish silently.
      debugPrint('[main] serviceWorker.unregister failed: $e');
    }
  }
}

class CarinaPortalApp extends StatefulWidget {
  final SponsorBrandingConfig branding;
  final AuthService authService;
  final BrowserLifecycleService lifecycleService;

  const CarinaPortalApp({
    super.key,
    required this.branding,
    required this.authService,
    required this.lifecycleService,
  });

  @override
  State<CarinaPortalApp> createState() => _CarinaPortalAppState();
}

class _CarinaPortalAppState extends State<CarinaPortalApp> {
  @override
  void dispose() {
    widget.lifecycleService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>.value(value: widget.authService),
        Provider<SponsorBrandingConfig>.value(value: widget.branding),
      ],
      child: EnvironmentBanner(
        show: EnvProfile.current.showBanner,
        flavorName: EnvProfile.current.name,
        child: MaterialApp.router(
          title: widget.branding.title,
          theme: portalTheme,
          routerConfig: appRouter,
          debugShowCheckedModeBanner: EnvProfile.current.showBanner,
        ),
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
                  onPressed: () => web.window.location.reload(),
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
