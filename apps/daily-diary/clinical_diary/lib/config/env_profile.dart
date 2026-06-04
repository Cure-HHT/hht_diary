// lib/config/env_profile.dart
// Implements: DIARY-DEV-runtime-environment-resolution/C
import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show AssetBundle, rootBundle;

/// Deployment environment. `local` targets a developer's local diary-server.
enum AppEnv { local, dev, qa, uat, prod }

/// The single source of truth for environment-derived behavior, resolved at
/// runtime from a bundled pointer asset (see [load]) rather than a
/// compile-time constant.
class EnvProfile {
  const EnvProfile({
    required this.env,
    required this.apiBase,
    required this.title,
    required this.showBanner,
    required this.showDevTools,
    required this.showResetData,
  });

  final AppEnv env;
  final String apiBase;
  final String title;
  final bool showBanner;
  final bool showDevTools;
  final bool showResetData;

  String get name => env.name;

  /// Affordances that fabricate, bulk-inject, or export diary records are
  /// permitted only outside prod. Single validated gate.
  // Implements: DIARY-DEV-runtime-environment-resolution/D
  bool get dangerousAffordancesEnabled => env != AppEnv.prod;

  static const _registry = <AppEnv, EnvProfile>{
    AppEnv.local: EnvProfile(
      env: AppEnv.local,
      // Local dev points at portal_server_evs — the integrated portal+ingest
      // node that serves both /api/v1/user/link and /ingest (default PORT 8084,
      // see apps/sponsor-portal/portal_server_evs/bin/server.dart) — so the
      // link + native sync loop runs end-to-end against one process.
      apiBase: 'http://localhost:8084',
      title: 'CureHHT Tracker LOCAL',
      showBanner: true,
      showDevTools: true,
      showResetData: true,
    ),
    AppEnv.dev: EnvProfile(
      env: AppEnv.dev,
      // EVS: the diary backend is folded into portal_server_evs, deployed as the
      // `portal-service` Cloud Run service, which serves the diary's endpoints
      // (/api/v1/user/link, /api/v1/user/state, /api/v1/ingest/batch). The legacy
      // diary-service is retired (CUR-1437). dev/qa/uat target portal-service;
      // prod is intentionally left pointing at the retired diary-service below
      // (prod EVS cutover is a separate, deliberate step).
      apiBase: 'https://portal-service-qxn6yntj5a-od.a.run.app',
      title: 'CureHHT Tracker DEV',
      showBanner: true,
      showDevTools: true,
      showResetData: true,
    ),
    AppEnv.qa: EnvProfile(
      env: AppEnv.qa,
      // EVS portal-service (see AppEnv.dev note).
      apiBase: 'https://portal-service-wwacxic3ua-od.a.run.app',
      title: 'CureHHT Tracker QA',
      showBanner: true,
      showDevTools: true,
      showResetData: true,
    ),
    AppEnv.uat: EnvProfile(
      env: AppEnv.uat,
      // EVS portal-service (see AppEnv.dev note).
      apiBase: 'https://portal-service-xlo7pf2uua-od.a.run.app',
      title: 'CureHHT Tracker',
      showBanner: false,
      showDevTools: false,
      showResetData: true,
    ),
    AppEnv.prod: EnvProfile(
      env: AppEnv.prod,
      apiBase: 'https://diary-server.europe-west9.run.app',
      title: 'CureHHT Tracker',
      showBanner: false,
      showDevTools: false,
      showResetData: false,
    ),
  };

  static EnvProfile forEnv(AppEnv env) => _registry[env]!;

  /// The active profile, set once during bootstrap. Defaults to dev so any
  /// access before [load] (e.g. in widget tests) is safe.
  static EnvProfile current = _registry[AppEnv.dev]!;

  /// Resolve the active environment from the bundled pointer asset.
  /// Returns the dev profile if the asset is missing, unreadable, or names
  /// an unknown environment.
  // Implements: DIARY-DEV-runtime-environment-resolution/A+B
  static Future<EnvProfile> load({AssetBundle? bundle}) async {
    final b = bundle ?? rootBundle;
    try {
      final raw = await b.loadString('assets/config/env.json');
      final name = (jsonDecode(raw) as Map<String, dynamic>)['env'] as String?;
      final env = AppEnv.values.firstWhere(
        (e) => e.name == name,
        orElse: () => AppEnv.dev,
      );
      return forEnv(env);
    } catch (e) {
      debugPrint(
        'EnvProfile.load: could not read env pointer, defaulting to dev ($e)',
      );
      return forEnv(AppEnv.dev);
    }
  }
}
