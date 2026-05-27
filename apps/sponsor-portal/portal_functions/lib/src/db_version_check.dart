// Startup DB-schema-version check for the portal server.
// Per CLAUDE.md §1: per-function Implements: annotations only — no file-header
// IMPLEMENTS block.

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

  final found = await readDbVersion();
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
        ':warning: [portal-server] DB schema version behind — '
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
