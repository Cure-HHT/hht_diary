// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00063: EDC Patient Ingestion
//   REQ-CAL-p00073: Patient Status Definitions
//
// Patient synchronization from RAVE EDC
// Fetches subjects from Medidata RAVE and syncs to local patients table

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:otel_common/otel_common.dart';
import 'package:rave_integration/rave_integration.dart';

import 'database.dart';
import 'rave_mock.dart';
import 'rave_sync_lockout.dart';
import 'sites_sync.dart' show RaveConfig, defaultSyncInterval;

/// Result of a patients sync operation.
class PatientsSyncResult {
  final int patientsCreated;
  final int patientsUpdated;
  final DateTime syncedAt;
  final String? error;
  final bool paused;
  final String? pausedReason;
  final DateTime? pausedUntil;

  const PatientsSyncResult({
    required this.patientsCreated,
    required this.patientsUpdated,
    required this.syncedAt,
    this.error,
    this.paused = false,
    this.pausedReason,
    this.pausedUntil,
  });

  bool get hasError => error != null;

  Map<String, dynamic> toJson() => {
    'patients_created': patientsCreated,
    'patients_updated': patientsUpdated,
    'synced_at': syncedAt.toIso8601String(),
    if (error != null) 'error': error,
    if (paused) 'paused': true,
    if (pausedReason != null) 'paused_reason': pausedReason,
    if (pausedUntil != null) 'paused_until': pausedUntil!.toIso8601String(),
  };
}

/// Builds a PatientsSyncResult that signals "paused" to callers.
// Implements: DIARY-OPS-rave-sync-cooldown/D, DIARY-OPS-rave-sync-hard-lockout/B
PatientsSyncResult buildPausedPatientsResult(LockoutState state) {
  final reason = state.result == LockoutCheckResult.pausedLocked
      ? 'locked'
      : 'cooldown';
  return PatientsSyncResult(
    patientsCreated: 0,
    patientsUpdated: 0,
    syncedAt: DateTime.now().toUtc(),
    error: 'Rave sync paused ($reason)',
    paused: true,
    pausedReason: reason,
    pausedUntil: state.pausedUntil,
  );
}

/// Computes SHA-256 hash of subject content for integrity verification.
///
/// This function is exposed for testing purposes.
String computePatientContentHash(List<RaveSubject> subjects) {
  // Sort subjects by subjectKey for consistent hashing
  final sorted = List<RaveSubject>.from(subjects)
    ..sort((a, b) => a.subjectKey.compareTo(b.subjectKey));

  final buffer = StringBuffer();
  for (final subject in sorted) {
    buffer.write(
      '${subject.subjectKey}|${subject.siteOid}|${subject.siteNumber};',
    );
  }

  final bytes = utf8.encode(buffer.toString());
  final digest = sha256.convert(bytes);
  return digest.toString();
}

/// Checks if patients need to be synced from EDC.
///
/// Returns true if:
/// - No patients exist in the database
/// - Most recent sync is older than [syncInterval]
Future<bool> shouldSyncPatients({
  Duration syncInterval = defaultSyncInterval,
}) async {
  final db = Database.instance;
  const serviceContext = UserContext.service;

  final result = await db.executeWithContext('''
    SELECT
      COUNT(*) as count,
      MAX(edc_synced_at) as last_sync
    FROM patients
  ''', context: serviceContext);

  if (result.isEmpty) {
    return true;
  }

  final count = result.first[0] as int;
  final lastSync = result.first[1] as DateTime?;

  if (count == 0) {
    return true;
  }

  if (lastSync == null) {
    return true;
  }

  final now = DateTime.now().toUtc();
  final age = now.difference(lastSync);
  return age > syncInterval;
}

/// Synchronizes patients from RAVE EDC to the local database.
///
/// This function:
/// 1. Connects to RAVE and fetches all subjects for the configured study
/// 2. Upserts each patient to the database
/// 3. New patients get mobile_linking_status = 'not_connected'
/// 4. Existing patients: updates edc_synced_at and site_id only (preserves linking status)
/// 5. Logs the sync event with counts in metadata JSONB
///
/// Optional parameters for testing:
/// - [testClient]: Injected RaveClient for unit testing
/// - [testStudyOid]: Override study OID for testing
/// - [skipLogging]: Skip database logging for unit tests without DB
///
/// Returns a [PatientsSyncResult] with counts of changes made.
Future<PatientsSyncResult> syncPatientsFromEdc({
  RaveClient? testClient,
  String? testStudyOid,
  bool skipLogging = false,
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
      studyOid =
          testStudyOid ??
          Platform.environment['RAVE_STUDY_OID'] ??
          'MOCK-STUDY-001';
    } else {
      final config = RaveConfig.fromEnvironment();
      if (config == null) {
        final result = PatientsSyncResult(
          patientsCreated: 0,
          patientsUpdated: 0,
          syncedAt: DateTime.now().toUtc(),
          error: 'RAVE configuration not available',
        );
        if (!skipLogging) {
          await _logPatientSyncResult(result, '', startTime, studyOid: null);
        }
        return result;
      }
      client = RaveClient(
        baseUrl: config.baseUrl,
        username: config.username,
        password: config.password,
      );
      studyOid = testStudyOid ?? config.studyOid;
    }
  }

  // studyOid is required for the subjects endpoint
  if (studyOid == null || studyOid.isEmpty) {
    final result = PatientsSyncResult(
      patientsCreated: 0,
      patientsUpdated: 0,
      syncedAt: DateTime.now().toUtc(),
      error: 'RAVE_STUDY_OID is required for patient sync',
    );
    if (!skipLogging) {
      await _logPatientSyncResult(result, '', startTime, studyOid: null);
    }
    if (testClient == null) {
      client.close();
    }
    return result;
  }

  List<RaveSubject> subjects = [];
  String contentHash = '';

  try {
    // Fetch subjects from RAVE
    subjects = await client.getSubjects(studyOid: studyOid);

    // Compute content hash for integrity verification
    contentHash = computePatientContentHash(subjects);

    if (subjects.isEmpty) {
      final result = PatientsSyncResult(
        patientsCreated: 0,
        patientsUpdated: 0,
        syncedAt: DateTime.now().toUtc(),
        error: 'No subjects returned from RAVE - check permissions',
      );
      if (!skipLogging) {
        await _logPatientSyncResult(
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
    var skipped = 0;

    // Upsert each subject as a patient
    for (final subject in subjects) {
      final patientId = subject.subjectKey;
      final siteId = subject.siteOid;

      try {
        final upsertResult = await db.executeWithContext(
          '''
          INSERT INTO patients (
            patient_id, site_id, edc_subject_key,
            mobile_linking_status, edc_synced_at,
            created_at, updated_at
          )
          VALUES (
            @patientId, @siteId, @edcSubjectKey,
            'not_connected', @syncedAt,
            now(), now()
          )
          ON CONFLICT (patient_id) DO UPDATE SET
            site_id = EXCLUDED.site_id,
            edc_synced_at = EXCLUDED.edc_synced_at,
            updated_at = now()
          RETURNING (xmax = 0) as is_insert
          ''',
          parameters: {
            'patientId': patientId,
            'siteId': siteId,
            'edcSubjectKey': subject.subjectKey,
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
      } catch (e) {
        // Skip patients with invalid site references (FK violation)
        print('[WARN] Skipping patient $patientId (site $siteId): $e');
        skipped++;
      }
    }

    if (skipped > 0) {
      print('[PATIENTS_SYNC] Skipped $skipped patients with unknown sites');
    }

    final result = PatientsSyncResult(
      patientsCreated: created,
      patientsUpdated: updated,
      syncedAt: syncedAt,
    );

    if (!skipLogging) {
      await _logPatientSyncResult(
        result,
        contentHash,
        startTime,
        studyOid: studyOid,
        patientCount: subjects.length,
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
        await recordAuthFailure(reasonCode: e.reasonCode);
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
          'source': 'patients_sync',
        },
      );
    }
    final result = PatientsSyncResult(
      patientsCreated: 0,
      patientsUpdated: 0,
      syncedAt: DateTime.now().toUtc(),
      error: errorMessage,
    );
    if (!skipLogging) {
      await _logPatientSyncResult(
        result,
        contentHash,
        startTime,
        studyOid: studyOid,
      );
    }
    return result;
  } on RaveNetworkException catch (e) {
    final result = PatientsSyncResult(
      patientsCreated: 0,
      patientsUpdated: 0,
      syncedAt: DateTime.now().toUtc(),
      error: 'RAVE network error: ${e.message}',
    );
    if (!skipLogging) {
      await _logPatientSyncResult(
        result,
        contentHash,
        startTime,
        studyOid: studyOid,
      );
    }
    return result;
  } on RaveException catch (e) {
    final result = PatientsSyncResult(
      patientsCreated: 0,
      patientsUpdated: 0,
      syncedAt: DateTime.now().toUtc(),
      error: 'RAVE error: ${e.message}',
    );
    if (!skipLogging) {
      await _logPatientSyncResult(
        result,
        contentHash,
        startTime,
        studyOid: studyOid,
      );
    }
    return result;
  } finally {
    if (testClient == null) {
      client.close();
    }
  }
}

/// Internal helper to log patient sync results to edc_sync_log.
///
/// Uses PATIENTS_SYNC operation and stores patient counts in metadata JSONB
/// since edc_sync_log columns are sites-specific.
Future<void> _logPatientSyncResult(
  PatientsSyncResult result,
  String contentHash,
  DateTime startTime, {
  String? studyOid,
  int? patientCount,
}) async {
  final durationMs = DateTime.now().difference(startTime).inMilliseconds;

  // Build a SitesSyncResult adapter for the shared logSyncEvent function
  // We pass patient counts via metadata since edc_sync_log columns are sites-specific
  try {
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
        0, 0, 0,
        @contentHash, @durationMs, @success, @errorMessage, @metadata::jsonb
      )
      ''',
      parameters: {
        'syncTimestamp': result.syncedAt,
        'sourceSystem': 'RAVE',
        'operation': 'PATIENTS_SYNC',
        'contentHash': contentHash.isEmpty ? 'no-content' : contentHash,
        'durationMs': durationMs,
        'success': !result.hasError,
        'errorMessage': result.error,
        'metadata': jsonEncode({
          'patients_created': result.patientsCreated,
          'patients_updated': result.patientsUpdated,
          if (studyOid != null) 'study_oid': studyOid,
          if (patientCount != null) 'patient_count': patientCount,
        }),
      },
      context: serviceContext,
    );
  } catch (e) {
    // Log error but don't fail the sync operation
    print('[WARN] Failed to log patient sync event: $e');
  }
}

/// Syncs patients if needed, based on sync interval.
///
/// This is the main entry point for the patients handler.
/// It checks if a sync is needed and performs it if so.
Future<PatientsSyncResult?> syncPatientsIfNeeded({
  Duration syncInterval = defaultSyncInterval,
}) async {
  if (!RaveConfig.isConfigured) {
    return null;
  }

  // Implements: DIARY-OPS-rave-sync-cooldown/D, DIARY-OPS-rave-sync-hard-lockout/B
  //
  // Wrap checkLockout in try/catch: if migration 013 hasn't been applied
  // yet (incremental rollout, env in a weird state, etc.) the SELECT
  // against rave_sync_lockout throws and we don't want that to take down
  // the entire /participants handler. Treat any failure as "proceed" —
  // the gate is defense-in-depth, not a hard prerequisite for serving.
  LockoutState? state;
  try {
    state = await checkLockout();
  } catch (e) {
    print('[WARN] checkLockout failed (proceeding without gate): $e');
  }
  if (state != null && state.isPaused) {
    final result = buildPausedPatientsResult(state);
    // Audit: record the skip in edc_sync_log.
    try {
      final db = Database.instance;
      await db.executeWithContext(
        '''
        INSERT INTO edc_sync_log (
          sync_timestamp, source_system, operation,
          sites_created, sites_updated, sites_deactivated,
          content_hash, duration_ms, success, error_message, metadata
        )
        VALUES (
          @syncTimestamp, 'RAVE', 'PATIENTS_SYNC',
          0, 0, 0,
          'no-content', 0, false, @errorMessage, @metadata::jsonb
        )
        ''',
        parameters: {
          'syncTimestamp': result.syncedAt,
          'errorMessage': result.error,
          'metadata': jsonEncode({'rave_lockout_skipped': true}),
        },
        context: UserContext.service,
      );
    } catch (e) {
      print('[WARN] Failed to log paused sync skip: $e');
    }
    return result;
  }

  final needsSync = await shouldSyncPatients(syncInterval: syncInterval);
  if (!needsSync) {
    return null;
  }

  return syncPatientsFromEdc();
}
