// Implements: DIARY-DEV-rave-edc-ingest/A — reuses the RaveClient fetch path
//   (getSites/getSubjects) but redirects the sink to events: each RAVE site
//   becomes a site_synced_from_edc edge event on the 'site' aggregate and each
//   subject a participant_synced_from_edc on the 'participant' aggregate, all
//   under AutomationInitiator(service:'edc_sync'). On full success it stamps an
//   edc_sync_succeeded on the rave_sync aggregate (resetting the lockout
//   counter). The study OIDs to scope the fetch are supplied by the caller.
import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_actions/portal_actions.dart';
import 'package:rave_integration/rave_integration.dart';

import 'rave_sync_lockout.dart';

/// Outcome of a [RaveEdcIngester.syncAll] pass.
// Implements: DIARY-DEV-rave-edc-ingest/A — carries the edge-event counts (or
//   skipped:true when the lockout gate refuses the fetch).
class SyncResult {
  const SyncResult({
    required this.sitesCount,
    required this.participantsCount,
    required this.skipped,
  });
  final int sitesCount;
  final int participantsCount;
  final bool skipped;
}

/// Pulls RAVE sites + subjects and sinks them into the portal event log as
/// edge events, gated by the [classifyLockout] decision over the
/// rave_sync_status projection. Auth failures advance the lockout counter (and
/// trip a hard lockout at threshold); network failures are transient and record
/// nothing.
// Implements: DIARY-DEV-rave-edc-ingest/A
class RaveEdcIngester {
  RaveEdcIngester({
    required this.client,
    required this.store,
    required this.studyOids,
    required this.lockoutConfig,
  });

  final RaveClient client;
  final EventStore store;
  final List<String> studyOids;
  final LockoutConfig lockoutConfig;

  static const _automation = AutomationInitiator(service: 'edc_sync');

  /// Reads the lockout gate; if not in [LockoutKind.proceed] returns a skipped
  /// result without touching the client. Otherwise fetches + sinks sites and
  /// participants, stamps edc_sync_succeeded, and returns the counts. An auth
  /// failure records a failure event (and possibly a hard lockout) then
  /// rethrows; a network failure rethrows without recording anything.
  // Implements: DIARY-DEV-rave-edc-ingest/A+D
  Future<SyncResult> syncAll({required DateTime now}) async {
    // D: consult the lockout gate BEFORE fetching.
    final status = await _readStatus();
    final decision = classifyLockout(status, now: now, config: lockoutConfig);
    if (decision.kind != LockoutKind.proceed) {
      return const SyncResult(
        sitesCount: 0,
        participantsCount: 0,
        skipped: true,
      );
    }

    try {
      final sitesCount = await _syncSites(now);
      final participantsCount = await _syncParticipants(now);
      await store.append(
        entryType: 'edc_sync_succeeded',
        aggregateType: 'rave_sync',
        aggregateId: 'rave_sync',
        eventType: 'edc_sync_succeeded',
        data: edcSyncSucceededData(
          sitesCount: sitesCount,
          participantsCount: participantsCount,
          lastSuccessAt: now.toIso8601String(),
        ),
        initiator: _automation,
      );
      return SyncResult(
        sitesCount: sitesCount,
        participantsCount: participantsCount,
        skipped: false,
      );
    } on RaveAuthenticationException catch (e) {
      // C: count the auth failure (and trip lockout at threshold), then rethrow.
      await _recordAuthFailure(now, e.reasonCode ?? 'AUTH');
      rethrow;
    } on RaveNetworkException catch (e) {
      // C: transient network failure. Record it for audit/display WITHOUT
      // advancing the lockout counter (network blips must not trip cooldown
      // or lockout), then rethrow.
      // Implements: DIARY-DEV-rave-edc-ingest/C
      await _recordSyncFailure(now, 'NETWORK', e.toString());
      rethrow;
    } on RaveException catch (e) {
      // C: catch-all for other RAVE-library failures (parse/api/incomplete) so
      // nothing EDC-side fails silently. Recorded for audit, but — like the
      // network path — it does NOT advance the lockout counter.
      // Implements: DIARY-DEV-rave-edc-ingest/C
      await _recordSyncFailure(now, 'EDC_ERROR', e.toString());
      rethrow;
    }
  }

  /// Fetches sites per study OID and appends one site_synced_from_edc edge
  /// event per site. Returns the number of sites sunk.
  // Implements: DIARY-DEV-rave-edc-ingest/A+B
  Future<int> _syncSites(DateTime now) async {
    var count = 0;
    final syncedAt = now.toIso8601String();
    for (final studyOid in studyOids) {
      final sites = await client.getSites(studyOid: studyOid);
      for (final site in sites) {
        final payload = SiteSyncedFromEdcPayload(
          siteId: site.oid,
          siteName: site.name,
          siteNumber: site.studySiteNumber ?? site.oid,
          isActive: site.isActive,
          studyOid: site.studyOid ?? studyOid,
          edcSyncedAt: syncedAt,
        );
        // B: dedupeByContent makes a re-sync of unchanged sites a no-op.
        await store.append(
          entryType: 'site_synced_from_edc',
          aggregateType: 'site',
          aggregateId: site.oid,
          eventType: 'site_synced_from_edc',
          data: payload.toJson(),
          initiator: _automation,
          dedupeByContent: true,
        );
        count++;
      }
    }
    return count;
  }

  /// Fetches subjects per study OID and appends one participant_synced_from_edc
  /// edge event per subject. Returns the number of participants sunk.
  // Implements: DIARY-DEV-rave-edc-ingest/A+B
  Future<int> _syncParticipants(DateTime now) async {
    var count = 0;
    for (final studyOid in studyOids) {
      final subjects = await client.getSubjects(studyOid: studyOid);
      for (final subject in subjects) {
        // B: dedupeByContent makes a re-sync of unchanged subjects a no-op.
        await store.append(
          entryType: 'participant_synced_from_edc',
          aggregateType: 'participant',
          aggregateId: subject.subjectKey,
          eventType: 'participant_synced_from_edc',
          data: <String, Object?>{
            'participant_id': subject.subjectKey,
            'site_id': subject.siteOid,
          },
          initiator: _automation,
          dedupeByContent: true,
        );
        count++;
      }
    }
    return count;
  }

  /// Increments the lockout counter from the current rave_sync_status row and
  /// appends a rave_auth_failed event carrying the new value; if the new value
  /// reaches the configured threshold, also appends a
  /// rave_hard_lockout_triggered event.
  // Implements: DIARY-DEV-rave-edc-ingest/C+D
  Future<void> _recordAuthFailure(DateTime now, String reasonCode) async {
    final status = await _readStatus();
    final current = (status['consecutive_auth_failures'] as int?) ?? 0;
    final next = current + 1;
    final failedAt = now.toIso8601String();
    await store.append(
      entryType: 'rave_auth_failed',
      aggregateType: 'rave_sync',
      aggregateId: 'rave_sync',
      eventType: 'rave_auth_failed',
      data: raveAuthFailedData(
        consecutiveAuthFailures: next,
        reasonCode: reasonCode,
        failedAt: failedAt,
      ),
      initiator: _automation,
    );
    if (next >= lockoutConfig.threshold) {
      await store.append(
        entryType: 'rave_hard_lockout_triggered',
        aggregateType: 'rave_sync',
        aggregateId: 'rave_sync',
        eventType: 'rave_hard_lockout_triggered',
        data: raveHardLockoutData(lockedAt: failedAt),
        initiator: _automation,
      );
    }
  }

  /// Appends an edc_sync_failed event recording a non-auth sync failure for
  /// audit/display. Writes only last_sync_error_at + reason_code (+ message);
  /// does NOT touch consecutive_auth_failures or last_failure_at, so the
  /// lockout gate is unaffected.
  // Implements: DIARY-DEV-rave-edc-ingest/C
  Future<void> _recordSyncFailure(
    DateTime now,
    String reasonCode,
    String message,
  ) async {
    await store.append(
      entryType: 'edc_sync_failed',
      aggregateType: 'rave_sync',
      aggregateId: 'rave_sync',
      eventType: 'edc_sync_failed',
      data: edcSyncFailedData(
        reasonCode: reasonCode,
        failedAt: now.toIso8601String(),
        message: message,
      ),
      initiator: _automation,
    );
  }

  /// Reads the single-row rave_sync_status projection; empty map when absent.
  // Implements: DIARY-DEV-rave-edc-ingest/D
  Future<Map<String, Object?>> _readStatus() async {
    final rows = await store.backend.findViewRows('rave_sync_status');
    return rows.isEmpty
        ? <String, Object?>{}
        : Map<String, Object?>.from(rows.single);
  }
}
