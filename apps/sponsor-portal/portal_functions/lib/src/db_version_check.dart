// Startup DB-schema-version check for the portal server.
// Per CLAUDE.md §1: per-function Implements: annotations only — no file-header
// IMPLEMENTS block.

import 'dart:io' show Platform;

import 'package:meta/meta.dart';
import 'package:otel_common/otel_common.dart';

import 'database.dart';
import 'rave_sync_lockout.dart' show notifySlack;

// ---------------------------------------------------------------------------
// Process-global state
// ---------------------------------------------------------------------------

int _expectedMinVersion = 0;
int? _foundDbVersion;
bool _schemaStale = false;
bool _alertSent = false;

/// True when the DB schema version is below [_expectedMinVersion].
bool get isSchemaStale => _schemaStale;

/// The schema version found at startup (null before [checkSchemaVersion] runs).
int? get foundDbVersion => _foundDbVersion;

/// The minimum expected schema version supplied at startup.
int get expectedMinDbVersion => _expectedMinVersion;

/// Resets all module-level state.  Call in test setUp/tearDown.
@visibleForTesting
void resetDbVersionCheckState() {
  _expectedMinVersion = 0;
  _foundDbVersion = null;
  _schemaStale = false;
  _alertSent = false;
}

/// Force-sets the stale flag without running the DB check. Test-only.
@visibleForTesting
void setSchemaStaleForTesting({required bool stale}) {
  _schemaStale = stale;
}

// ---------------------------------------------------------------------------
// Alert identity prefix
// ---------------------------------------------------------------------------

/// Builds the bracketed identity prefix for the schema-version Slack alerts so
/// on-call can tell at a glance which environment and deploy emitted them.
///
/// The Cloud Run container is given `SPONSOR_ID`, `ENVIRONMENT`,
/// `PORTAL_DEPLOY_SEQ` and `PORTAL_DEPLOY_SHA` by the sponsor deploy workflow.
/// All segments are best-effort: a local or test run with none of them set
/// yields the bare `[portal-server]` tag (matching the legacy format).
///
/// Example (all vars set): `[portal-server | callisto/DEV | deploy #418 (a1b2c3d)]`
// Implements: DIARY-DEV-schema-version-check/D
String schemaAlertPrefix([Map<String, String>? environment]) {
  final env = environment ?? Platform.environment;
  final parts = <String>['portal-server'];

  final sponsor = env['SPONSOR_ID']?.trim();
  final envName = env['ENVIRONMENT']?.trim();
  final idParts = <String>[
    if (sponsor != null && sponsor.isNotEmpty) sponsor,
    if (envName != null && envName.isNotEmpty) envName.toUpperCase(),
  ];
  if (idParts.isNotEmpty) parts.add(idParts.join('/'));

  final seq = env['PORTAL_DEPLOY_SEQ']?.trim();
  final sha = env['PORTAL_DEPLOY_SHA']?.trim();
  if (seq != null && seq.isNotEmpty) {
    final shaSuffix = (sha != null && sha.isNotEmpty) ? ' ($sha)' : '';
    parts.add('deploy #$seq$shaSuffix');
  } else if (sha != null && sha.isNotEmpty) {
    parts.add('deploy ($sha)');
  }

  return '[${parts.join(' | ')}]';
}

// ---------------------------------------------------------------------------
// Core check
// ---------------------------------------------------------------------------

/// Checks the live database schema version against [expectedMinVersion].
///
/// Parameters:
/// - [expectedMinVersion] — the build-time-baked minimum acceptable version.
/// - [readDbVersion] — injectable reader; production callers use
///   [productionDbVersionReader].  Inject a stub for unit tests.
/// - [sendAlert] — injectable Slack notifier; defaults to [notifySlack].
///   Inject a captured callback in unit tests.
///
/// If `found < expectedMinVersion`:
///   - sets the process-global [isSchemaStale] flag to `true`.
///   - logs an ERROR via [logWithTrace].
///   - calls [sendAlert] exactly once (subsequent calls are no-ops for the
///     alert, but the stale flag and log are set unconditionally).
// Implements: DIARY-DEV-schema-version-check/A+B+C
Future<void> checkSchemaVersion({
  required int expectedMinVersion,
  required Future<int> Function() readDbVersion,
  Future<void> Function(String)? sendAlert,
}) async {
  _expectedMinVersion = expectedMinVersion;

  int found;
  try {
    found = await readDbVersion();
  } catch (e) {
    // DB unreachable or schema_migrations missing (e.g. bootstrap window).
    // Treat as "schema unknown / behind" so the server serves 503 instead of
    // crash-looping. Alert fires once so on-call is notified.
    found = -1;
    _foundDbVersion = found;
    _schemaStale = true;

    logWithTrace(
      'ERROR',
      'Database schema version check failed — treating schema as behind',
      labels: {
        'db_schema_stale': 'true',
        'db_version_check_error': e.toString(),
      },
    );

    if (!_alertSent) {
      _alertSent = true;
      final alert = sendAlert ?? notifySlack;
      await alert(
        ':warning: ${schemaAlertPrefix()} DB schema version check FAILED — '
        'could not read schema_migrations ($e). '
        'Server is serving 503 until the DB is reachable.',
      );
    }
    return;
  }

  _foundDbVersion = found;

  if (found < expectedMinVersion) {
    _schemaStale = true;

    logWithTrace(
      'ERROR',
      'Database schema version behind',
      labels: {
        'db_schema_stale': 'true',
        'db_version_expected': '$expectedMinVersion',
        'db_version_found': '$found',
      },
    );

    if (!_alertSent) {
      _alertSent = true;
      final alert = sendAlert ?? notifySlack;
      await alert(
        ':warning: ${schemaAlertPrefix()} DB schema version behind — '
        'expected >= $expectedMinVersion, found $found. '
        'Deploy pending migrations before serving traffic.',
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Production DB reader
// ---------------------------------------------------------------------------

/// Production implementation of the [readDbVersion] callback.
/// Runs `SELECT COALESCE(MAX(id), 0) FROM schema_migrations` via the
/// singleton [Database.instance] using service context (no RLS needed
/// for this read-only schema query; no user context exists at startup).
// Implements: DIARY-DEV-schema-version-check/A
Future<int> productionDbVersionReader() async {
  final result = await Database.instance.executeWithContext(
    'SELECT COALESCE(MAX(id), 0) FROM schema_migrations',
    context: UserContext.service,
  );
  if (result.isEmpty) return 0;
  return (result.first[0] as int?) ?? 0;
}
