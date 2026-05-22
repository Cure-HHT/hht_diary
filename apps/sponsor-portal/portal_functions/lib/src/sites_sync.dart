// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00010: Schema-Driven Data Validation
//   REQ-CAL-p00011: EDC Metadata as Validation Source
//
// Sites synchronization from RAVE EDC
// Fetches sites from Medidata RAVE and syncs to local database

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:otel_common/otel_common.dart';
import 'package:rave_integration/rave_integration.dart';

import 'database.dart';
import 'rave_mock.dart';
import 'rave_sync_lockout.dart';

/// Default sync interval - sites are refreshed if older than this duration.
const defaultSyncInterval = Duration(days: 1);

/// Configuration for RAVE EDC connection.
///
/// Reads from environment variables (provided via Doppler).
/// Required variables: RAVE_UAT_URL, RAVE_UAT_USERNAME, RAVE_UAT_PWD
/// Optional: RAVE_STUDY_OID (defaults to first available study)
class RaveConfig {
  final String baseUrl;
  final String username;
  final String password;
  final String? studyOid;

  RaveConfig._({
    required this.baseUrl,
    required this.username,
    required this.password,
    this.studyOid,
  });

  /// Creates config from environment variables.
  ///
  /// Returns null if required variables are missing.
  static RaveConfig? fromEnvironment() {
    final baseUrl = Platform.environment['RAVE_UAT_URL'];
    final username = Platform.environment['RAVE_UAT_USERNAME'];
    final password = Platform.environment['RAVE_UAT_PWD'];
    final studyOid = Platform.environment['RAVE_STUDY_OID'];

    if (baseUrl == null || username == null || password == null) {
      return null;
    }

    return RaveConfig._(
      baseUrl: baseUrl,
      username: username,
      password: password,
      studyOid: studyOid,
    );
  }

  /// Whether RAVE integration is configured. True when either the live
  /// RAVE_UAT_* env vars are populated OR the dev-only RAVE_MOCK_MODE
  /// env var is set (see rave_mock.dart). Either path produces a usable
  /// RaveClient downstream.
  static bool get isConfigured {
    final mockMode = Platform.environment['RAVE_MOCK_MODE'];
    if (mockMode != null && mockMode.isNotEmpty) return true;
    return Platform.environment['RAVE_UAT_URL'] != null &&
        Platform.environment['RAVE_UAT_USERNAME'] != null &&
        Platform.environment['RAVE_UAT_PWD'] != null;
  }
}

/// Result of a sites sync operation.
class SitesSyncResult {
  final int sitesUpdated;
  final int sitesCreated;
  final int sitesDeactivated;
  final DateTime syncedAt;
  final String? error;
  final bool paused;
  final String? pausedReason;
  final DateTime? pausedUntil;

  const SitesSyncResult({
    required this.sitesUpdated,
    required this.sitesCreated,
    required this.sitesDeactivated,
    required this.syncedAt,
    this.error,
    this.paused = false,
    this.pausedReason,
    this.pausedUntil,
  });

  bool get hasError => error != null;

  Map<String, dynamic> toJson() => {
    'sites_updated': sitesUpdated,
    'sites_created': sitesCreated,
    'sites_deactivated': sitesDeactivated,
    'synced_at': syncedAt.toIso8601String(),
    if (error != null) 'error': error,
    if (paused) 'paused': true,
    if (pausedReason != null) 'paused_reason': pausedReason,
    if (pausedUntil != null) 'paused_until': pausedUntil!.toIso8601String(),
  };
}

/// Builds a SitesSyncResult that signals "paused" to callers.
// Implements: DIARY-OPS-rave-sync-cooldown/D, DIARY-OPS-rave-sync-hard-lockout/B
SitesSyncResult buildPausedSitesResult(LockoutState state) {
  final reason = state.result == LockoutCheckResult.pausedLocked
      ? 'locked'
      : 'cooldown';
  return SitesSyncResult(
    sitesUpdated: 0,
    sitesCreated: 0,
    sitesDeactivated: 0,
    syncedAt: DateTime.now().toUtc(),
    error: 'Rave sync paused ($reason)',
    paused: true,
    pausedReason: reason,
    pausedUntil: state.pausedUntil,
  );
}

/// Computes SHA-256 hash of content for integrity verification.
///
/// This function is exposed for testing purposes.
String computeContentHash(List<RaveSite> sites) {
  // Sort sites by OID for consistent hashing
  final sortedSites = List<RaveSite>.from(sites)
    ..sort((a, b) => a.oid.compareTo(b.oid));

  // Create a canonical representation of sites data
  final buffer = StringBuffer();
  for (final site in sortedSites) {
    buffer.write(
      '${site.oid}|${site.name}|${site.studySiteNumber}|${site.isActive};',
    );
  }

  final bytes = utf8.encode(buffer.toString());
  final digest = sha256.convert(bytes);
  return digest.toString();
}

/// Logs a sync event to the edc_sync_log table.
///
/// Records all sync operations with timestamps, content hashes, and results
/// for audit trail and compliance tracking.
Future<void> logSyncEvent({
  required String sourceSystem,
  required String operation,
  required SitesSyncResult result,
  required String contentHash,
  int? durationMs,
  Map<String, dynamic>? metadata,
}) async {
  final db = Database.instance;
  const serviceContext = UserContext.service;

  await db.executeWithContext(
    '''
    INSERT INTO edc_sync_log (
      sync_timestamp, source_system, operation,
      sites_created, sites_updated, sites_deactivated,
      content_hash, duration_ms, success, error_message, metadata
    )
    VALUES (
      @syncTimestamp, @sourceSystem, @operation,
      @sitesCreated, @sitesUpdated, @sitesDeactivated,
      @contentHash, @durationMs, @success, @errorMessage, @metadata::jsonb
    )
    ''',
    parameters: {
      'syncTimestamp': result.syncedAt,
      'sourceSystem': sourceSystem,
      'operation': operation,
      'sitesCreated': result.sitesCreated,
      'sitesUpdated': result.sitesUpdated,
      'sitesDeactivated': result.sitesDeactivated,
      'contentHash': contentHash,
      'durationMs': durationMs,
      'success': !result.hasError,
      'errorMessage': result.error,
      'metadata': jsonEncode(metadata ?? {}),
    },
    context: serviceContext,
  );
}

/// Retrieves recent sync events for monitoring and debugging.
///
/// Returns a list of sync events including chain_hash for integrity verification.
Future<List<Map<String, dynamic>>> getRecentSyncEvents({
  int limit = 10,
  String? sourceSystem,
}) async {
  final db = Database.instance;
  const serviceContext = UserContext.service;

  final whereClause = sourceSystem != null
      ? 'WHERE source_system = @sourceSystem'
      : '';

  final result = await db.executeWithContext(
    '''
    SELECT
      sync_id, sync_timestamp, source_system, operation,
      sites_created, sites_updated, sites_deactivated,
      content_hash, chain_hash, duration_ms, success, error_message, metadata
    FROM edc_sync_log
    $whereClause
    ORDER BY sync_id DESC
    LIMIT @limit
    ''',
    parameters: {
      'limit': limit,
      if (sourceSystem != null) 'sourceSystem': sourceSystem,
    },
    context: serviceContext,
  );

  return result
      .map(
        (row) => {
          'sync_id': row[0],
          'sync_timestamp': row[1],
          'source_system': row[2],
          'operation': row[3],
          'sites_created': row[4],
          'sites_updated': row[5],
          'sites_deactivated': row[6],
          'content_hash': row[7],
          'chain_hash': row[8],
          'duration_ms': row[9],
          'success': row[10],
          'error_message': row[11],
          'metadata': row[12],
        },
      )
      .toList();
}

/// Result of chain integrity verification.
class ChainVerificationResult {
  final int totalRecords;
  final int validRecords;
  final int invalidRecords;
  final bool chainIntact;
  final int? firstInvalidSyncId;
  final DateTime checkedAt;

  const ChainVerificationResult({
    required this.totalRecords,
    required this.validRecords,
    required this.invalidRecords,
    required this.chainIntact,
    this.firstInvalidSyncId,
    required this.checkedAt,
  });

  Map<String, dynamic> toJson() => {
    'total_records': totalRecords,
    'valid_records': validRecords,
    'invalid_records': invalidRecords,
    'chain_intact': chainIntact,
    if (firstInvalidSyncId != null) 'first_invalid_sync_id': firstInvalidSyncId,
    'checked_at': checkedAt.toIso8601String(),
  };
}

/// Verifies the integrity of the EDC sync log chain.
///
/// Returns a [ChainVerificationResult] indicating whether the chain is intact.
/// A broken chain indicates potential tampering with sync log records.
Future<ChainVerificationResult> verifySyncLogChain() async {
  final db = Database.instance;
  const serviceContext = UserContext.service;

  final result = await db.executeWithContext(
    'SELECT * FROM check_edc_sync_chain_status()',
    context: serviceContext,
  );

  if (result.isEmpty) {
    return ChainVerificationResult(
      totalRecords: 0,
      validRecords: 0,
      invalidRecords: 0,
      chainIntact: true,
      checkedAt: DateTime.now().toUtc(),
    );
  }

  final row = result.first;
  return ChainVerificationResult(
    totalRecords: row[0] as int,
    validRecords: row[1] as int,
    invalidRecords: row[2] as int,
    chainIntact: row[3] as bool,
    firstInvalidSyncId: row[4] as int?,
    checkedAt: row[5] as DateTime,
  );
}

/// Checks if sites need to be synced from EDC.
///
/// Returns true if:
/// - No sites exist in the database
/// - Most recent sync is older than [syncInterval]
Future<bool> shouldSyncSites({
  Duration syncInterval = defaultSyncInterval,
}) async {
  final db = Database.instance;
  const serviceContext = UserContext.service;

  // Check if any sites exist and when they were last synced
  final result = await db.executeWithContext('''
    SELECT
      COUNT(*) as count,
      MAX(edc_synced_at) as last_sync
    FROM sites
  ''', context: serviceContext);

  if (result.isEmpty) {
    return true;
  }

  final count = result.first[0] as int;
  final lastSync = result.first[1] as DateTime?;

  // No sites - definitely sync
  if (count == 0) {
    return true;
  }

  // No sync timestamp - sync to establish baseline
  if (lastSync == null) {
    return true;
  }

  // Check if sync is stale
  final now = DateTime.now().toUtc();
  final age = now.difference(lastSync);
  return age > syncInterval;
}

/// Synchronizes sites from RAVE EDC to the local database.
///
/// This function:
/// 1. Connects to RAVE and fetches all sites for the configured study
/// 2. Upserts each site to the database
/// 3. Marks sites not in RAVE response as inactive
/// 4. Logs the sync event with timestamps and content hash
///
/// Optional parameters for testing:
/// - [testClient]: Injected RaveClient for unit testing
/// - [testStudyOid]: Override study OID for testing
/// - [skipLogging]: Skip database logging for unit tests without DB
///
/// Returns a [SitesSyncResult] with counts of changes made.
Future<SitesSyncResult> syncSitesFromEdc({
  RaveClient? testClient,
  String? testStudyOid,
  bool skipLogging = false,
  AuthFailureSource authFailureSource = AuthFailureSource.normalSync,
}) async {
  final startTime = DateTime.now();

  // Use test client or create from environment config
  RaveClient? client = testClient;
  String? studyOid = testStudyOid;

  if (client == null) {
    // Dev override: RAVE_MOCK_MODE bypasses RAVE_UAT_* requirement and
    // returns a MockRaveClient. See rave_mock.dart for the mode vocabulary.
    final mockMode = Platform.environment['RAVE_MOCK_MODE'];
    if (mockMode != null && mockMode.isNotEmpty) {
      client = MockRaveClient(mockMode);
      studyOid = Platform.environment['RAVE_STUDY_OID'];
    } else {
      final config = RaveConfig.fromEnvironment();
      if (config == null) {
        final result = SitesSyncResult(
          sitesUpdated: 0,
          sitesCreated: 0,
          sitesDeactivated: 0,
          syncedAt: DateTime.now().toUtc(),
          error: 'RAVE configuration not available',
        );
        // Log configuration error (use empty hash since no content)
        if (!skipLogging) {
          await _logSyncResult(result, '', startTime, studyOid: null);
        }
        return result;
      }
      client = RaveClient(
        baseUrl: config.baseUrl,
        username: config.username,
        password: config.password,
      );
      studyOid = config.studyOid;
    }
  }

  List<RaveSite> raveSites = [];
  String contentHash = '';

  try {
    // Fetch sites from RAVE
    raveSites = await client.getSites(studyOid: studyOid);

    // Compute content hash for integrity verification
    contentHash = computeContentHash(raveSites);

    if (raveSites.isEmpty) {
      final result = SitesSyncResult(
        sitesUpdated: 0,
        sitesCreated: 0,
        sitesDeactivated: 0,
        syncedAt: DateTime.now().toUtc(),
        error: 'No sites returned from RAVE - check permissions',
      );
      if (!skipLogging) {
        await _logSyncResult(
          result,
          contentHash,
          startTime,
          studyOid: studyOid,
        );
      }
      return result;
    }

    final db = Database.instance;
    const serviceContext = UserContext.service;
    final syncedAt = DateTime.now().toUtc();

    var created = 0;
    var updated = 0;

    // Get existing site IDs for deactivation tracking
    final existingResult = await db.executeWithContext(
      'SELECT site_id FROM sites WHERE is_active = true',
      context: serviceContext,
    );
    final existingSiteIds = existingResult.map((r) => r[0] as String).toSet();
    final syncedSiteIds = <String>{};

    // Rave-wins reconciliation for the `site_number` unique constraint.
    //
    // Rave is the source of truth for site identity (OID + number + active),
    // but site_name is locally-curated (Rave returns boring "Site 001"
    // strings; admins assign human names like "County General Hospital").
    // When Rave reassigns site_number 001 from OID Y to OID X, we want X
    // to inherit Y's curated site_name AND we have to free the site_number
    // slot before the upsert can succeed.
    //
    // Strategy: build a {site_number -> existing site_name} map for any
    // incoming number currently held by a DIFFERENT OID, then deactivate
    // those stale rows and rename their site_number to a deterministic
    // 'OLD-…' tombstone (frees the unique constraint). The map is used
    // below to seed the INSERT for the new OID with the inherited name.
    // The old row stays (patients / audit rows still FK to it) — just
    // deactivated and tombstoned.
    final incomingNumbers = raveSites
        .map((s) => s.studySiteNumber ?? s.oid)
        .toList();
    final incomingOids = raveSites.map((s) => s.oid).toList();
    final inheritedNames = <String, String>{}; // site_number -> site_name
    if (incomingNumbers.isNotEmpty) {
      // Capture site_name from each stale row BEFORE we deactivate them.
      final stale = await db.executeWithContext(
        '''
        SELECT site_number, site_name FROM sites
        WHERE site_number = ANY(@incomingNumbers)
          AND NOT (site_id = ANY(@incomingOids))
        ''',
        parameters: {
          'incomingNumbers': incomingNumbers,
          'incomingOids': incomingOids,
        },
        context: serviceContext,
      );
      for (final row in stale) {
        inheritedNames[row[0] as String] = row[1] as String;
      }

      // Deactivate the stale rows and free the site_number slot.
      await db.executeWithContext(
        '''
        UPDATE sites
        SET is_active = false,
            site_number = 'OLD-' || site_id || '-' || site_number,
            edc_synced_at = @syncedAt,
            updated_at = now()
        WHERE site_number = ANY(@incomingNumbers)
          AND NOT (site_id = ANY(@incomingOids))
        ''',
        parameters: {
          'incomingNumbers': incomingNumbers,
          'incomingOids': incomingOids,
          'syncedAt': syncedAt,
        },
        context: serviceContext,
      );
    }

    // Upsert each site from RAVE.
    //
    // ON CONFLICT (site_id) DO UPDATE deliberately omits `site_name` —
    // that column is locally-curated and Rave is NOT authoritative for it.
    // The INSERT path uses the inherited name from a same-site_number
    // tombstoned row if one existed, otherwise the name Rave gave us
    // (acts as a placeholder until an admin sets a real one).
    for (final site in raveSites) {
      final siteId = site.oid;
      final siteNumber = site.studySiteNumber ?? site.oid;
      final siteName = inheritedNames[siteNumber] ?? site.name;
      final isActive = site.isActive;

      syncedSiteIds.add(siteId);

      final upsertResult = await db.executeWithContext(
        '''
        INSERT INTO sites (
          site_id, site_name, site_number, is_active,
          edc_oid, edc_synced_at, created_at, updated_at
        )
        VALUES (
          @siteId, @siteName, @siteNumber, @isActive,
          @edcOid, @syncedAt, now(), now()
        )
        ON CONFLICT (site_id) DO UPDATE SET
          site_number = EXCLUDED.site_number,
          is_active = EXCLUDED.is_active,
          edc_oid = EXCLUDED.edc_oid,
          edc_synced_at = EXCLUDED.edc_synced_at,
          updated_at = now()
        RETURNING (xmax = 0) as is_insert
        ''',
        parameters: {
          'siteId': siteId,
          'siteName': siteName,
          'siteNumber': siteNumber,
          'isActive': isActive,
          'edcOid': site.oid,
          'syncedAt': syncedAt,
        },
        context: serviceContext,
      );

      if (upsertResult.isNotEmpty) {
        final isInsert = upsertResult.first[0] as bool;
        if (isInsert) {
          created++;
        } else {
          updated++;
        }
      }
    }

    // Deactivate sites that were not in the RAVE response
    final sitesToDeactivate = existingSiteIds.difference(syncedSiteIds);
    var deactivated = 0;

    if (sitesToDeactivate.isNotEmpty) {
      final deactivateResult = await db.executeWithContext(
        '''
        UPDATE sites
        SET is_active = false, updated_at = now(), edc_synced_at = @syncedAt
        WHERE site_id = ANY(@siteIds)
        AND is_active = true
        RETURNING site_id
        ''',
        parameters: {
          'siteIds': sitesToDeactivate.toList(),
          'syncedAt': syncedAt,
        },
        context: serviceContext,
      );
      deactivated = deactivateResult.length;
    }

    final result = SitesSyncResult(
      sitesUpdated: updated,
      sitesCreated: created,
      sitesDeactivated: deactivated,
      syncedAt: syncedAt,
    );

    // Log successful sync
    if (!skipLogging) {
      await _logSyncResult(
        result,
        contentHash,
        startTime,
        studyOid: studyOid,
        siteCount: raveSites.length,
      );
    }

    // Implements: DIARY-OPS-rave-sync-cooldown/C
    if (!skipLogging) {
      try {
        await recordSyncSuccess();
      } catch (logErr) {
        print('[WARN] Failed to record rave sync success: $logErr');
      }
    }
    return result;
  } on RaveAuthenticationException catch (e) {
    // Implements: DIARY-DEV-rave-auth-failure-classification/A+C
    if (!skipLogging) {
      try {
        await recordAuthFailure(
          reasonCode: e.reasonCode,
          source: authFailureSource,
        );
      } catch (logErr) {
        print('[WARN] Failed to record rave auth failure: $logErr');
      }
    }
    final errorMessage =
        'RAVE authentication failed - invalid credentials or locked account'
        '${e.detailSuffix}';
    if (!skipLogging) {
      logWithTrace(
        'ERROR',
        'RAVE authentication failed',
        labels: {
          'rave_auth_failed': 'true',
          'rave_reason_code': e.reasonCode ?? 'unknown',
          'source': 'sites_sync',
        },
      );
    }
    final result = SitesSyncResult(
      sitesUpdated: 0,
      sitesCreated: 0,
      sitesDeactivated: 0,
      syncedAt: DateTime.now().toUtc(),
      error: errorMessage,
    );
    if (!skipLogging) {
      await _logSyncResult(result, contentHash, startTime, studyOid: studyOid);
    }
    return result;
  } on RaveNetworkException catch (e) {
    final result = SitesSyncResult(
      sitesUpdated: 0,
      sitesCreated: 0,
      sitesDeactivated: 0,
      syncedAt: DateTime.now().toUtc(),
      error: 'RAVE network error: ${e.message}',
    );
    if (!skipLogging) {
      await _logSyncResult(result, contentHash, startTime, studyOid: studyOid);
    }
    return result;
  } on RaveException catch (e) {
    final result = SitesSyncResult(
      sitesUpdated: 0,
      sitesCreated: 0,
      sitesDeactivated: 0,
      syncedAt: DateTime.now().toUtc(),
      error: 'RAVE error: ${e.message}',
    );
    if (!skipLogging) {
      await _logSyncResult(result, contentHash, startTime, studyOid: studyOid);
    }
    return result;
  } finally {
    // Only close if we created the client (not injected for testing)
    if (testClient == null) {
      client.close();
    }
  }
}

/// Internal helper to log sync results.
Future<void> _logSyncResult(
  SitesSyncResult result,
  String contentHash,
  DateTime startTime, {
  String? studyOid,
  int? siteCount,
}) async {
  final durationMs = DateTime.now().difference(startTime).inMilliseconds;

  try {
    await logSyncEvent(
      sourceSystem: 'RAVE',
      operation: 'SITES_SYNC',
      result: result,
      contentHash: contentHash.isEmpty ? 'no-content' : contentHash,
      durationMs: durationMs,
      metadata: {
        if (studyOid != null) 'study_oid': studyOid,
        if (siteCount != null) 'site_count': siteCount,
      },
    );
  } catch (e) {
    // Log error but don't fail the sync operation
    print('[WARN] Failed to log sync event: $e');
  }
}

/// Syncs sites if needed, based on sync interval.
///
/// This is the main entry point for the sites handler.
/// It checks if a sync is needed and performs it if so.
Future<SitesSyncResult?> syncSitesIfNeeded({
  Duration syncInterval = defaultSyncInterval,
}) async {
  if (!RaveConfig.isConfigured) {
    // RAVE not configured - skip sync silently
    return null;
  }

  // Implements: DIARY-OPS-rave-sync-cooldown/D, DIARY-OPS-rave-sync-hard-lockout/B
  final state = await checkLockout();
  if (state.isPaused) {
    final result = buildPausedSitesResult(state);
    // Audit: record the skip in edc_sync_log.
    try {
      await logSyncEvent(
        sourceSystem: 'RAVE',
        operation: 'SITES_SYNC',
        result: result,
        contentHash: 'no-content',
        metadata: {'rave_lockout_skipped': true},
      );
    } catch (e) {
      print('[WARN] Failed to log paused sync skip: $e');
    }
    return result;
  }

  final needsSync = await shouldSyncSites(syncInterval: syncInterval);
  if (!needsSync) {
    return null;
  }

  return syncSitesFromEdc();
}
