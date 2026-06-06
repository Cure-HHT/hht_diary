// Implements: DIARY-DEV-participant-link-issuance/A+B+C+D — public `/link` edge:
//   validates a coordinator-issued linking code, mints a participant-identity
//   JWT, and atomically consumes the code (appends participant_linking_code_used
//   in the same transaction as the validation read, so single-use is atomic).
//   Reads participant_record + sites_index only to build the response. The
//   relink/device gate (B2) is implemented here (step 3b-i); only the /ingest
//   ownership check (B3) remains pending, and that lives in a different file
//   (patient_ingest_handler.dart).
import 'dart:convert';
import 'dart:io';

import 'package:event_sourcing/event_sourcing.dart';
import 'package:shelf/shelf.dart';

import 'patient_token_validator.dart';

/// Build a JSON error response `{"error": <message>}`. The diary app's
/// enrollment_service jsonDecodes every non-success body and reads
/// `errorBody['error']`, so all error paths MUST return this shape.
Response _err(int code, String message) => Response(
      code,
      body: jsonEncode(<String, Object?>{'error': message}),
      headers: const {'Content-Type': 'application/json'},
    );

/// Outcome of the in-transaction validate+consume step. On success carries the
/// minted [jwt] plus the response fields; on failure carries the HTTP
/// [statusCode] + a short [message] (and no consume event was appended).
class _LinkOutcome {
  _LinkOutcome.failure(this.statusCode, this.message)
      : success = false,
        jwt = null,
        participantId = null,
        siteId = null,
        siteName = null,
        siteNumber = null;

  _LinkOutcome.success({
    required this.jwt,
    required this.participantId,
    required this.siteId,
    required this.siteName,
    required this.siteNumber,
  })  : success = true,
        statusCode = 200,
        message = null;

  final bool success;
  final int statusCode;
  final String? message;
  final String? jwt;
  final String? participantId;
  final String? siteId;
  final String? siteName;
  final String? siteNumber;
}

/// Build the patient-facing `/link` handler over [eventStore]. Dependencies are
/// injected so this module lifts cleanly into a dedicated diary-server node when
/// the edge/core split lands (mirrors [patientIngestHandler]).
Handler patientLinkHandler({
  required EventStore eventStore,
  String? sponsorId,
}) {
  final sid = sponsorId ?? Platform.environment['SPONSOR_ID'];
  return (Request request) async {
    // 1. Parse the body; reject unparseable JSON or a missing/blank code.
    final String rawCode;
    final String? appUuid;
    try {
      final decoded = jsonDecode(await request.readAsString());
      if (decoded is! Map) return _err(400, 'malformed request body');
      final code = decoded['code'];
      if (code is! String || code.trim().isEmpty) {
        return _err(400, 'missing linking code');
      }
      rawCode = code;
      final uuid = decoded['appUuid'];
      appUuid = uuid is String ? uuid : null;
    } catch (_) {
      return _err(400, 'malformed request body');
    }

    // 2. Normalize: strip the display dash/spaces; stored codes are uppercase.
    final normalizedCode =
        rawCode.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (normalizedCode.isEmpty) {
      return _err(400, 'missing linking code');
    }

    // 3. Validate + consume atomically inside one transaction. The decision
    //    (status + response fields) is returned OUT of the body; the
    //    consume append happens ONLY on the success path.
    final outcome = await eventStore.runTransaction<_LinkOutcome>(
      (txn, collector) async {
        final backend = eventStore.backend;

        // 3a. Look up the code. `where:` filtering is unreliable for arbitrary
        //     view columns across backends, so read all rows + filter in Dart.
        final codeRows = await backend.findViewRowsInTxn(txn, 'linking_codes');
        Map<String, dynamic>? codeRow;
        for (final row in codeRows) {
          if (row['linking_code'] == normalizedCode) {
            codeRow = row;
            break;
          }
        }
        if (codeRow == null) {
          return _LinkOutcome.failure(400, 'invalid or unknown code');
        }

        final status = codeRow['status'];
        if (status == 'used') {
          // Wording matters: the diary app distinguishes a device-relink
          // rejection (B2, message contains "already linked") from a
          // code-already-used 409 by substring. Keep "already linked" OUT here.
          return _LinkOutcome.failure(409, 'This code has already been used.');
        }
        if (status == 'revoked') {
          return _LinkOutcome.failure(410, 'code revoked');
        }
        // Explicitly require 'active'; any other (e.g. a future 'suspended')
        // is invalid rather than silently falling through to consume.
        if (status != 'active') {
          return _LinkOutcome.failure(400, 'invalid or unknown code');
        }

        // Active but expired -> 410.
        final expiresRaw = codeRow['expires_at'];
        if (expiresRaw is String) {
          final expiresAt = DateTime.tryParse(expiresRaw)?.toUtc();
          if (expiresAt != null && expiresAt.isBefore(DateTime.now().toUtc())) {
            return _LinkOutcome.failure(410, 'code expired');
          }
        }

        // 3b. Active + unexpired: continue.
        final participantId = codeRow['participant_id'] as String?;
        if (participantId == null) {
          return _LinkOutcome.failure(500, 'corrupt linking code record');
        }
        final siteId = codeRow['site_id'] as String?;

        // 3b-i. Relink/device gate. Read the participant's current link state
        //   from participant_record (merged by participant_linking_code_used /
        //   participant_linking_code_issued). A participant still bound to a
        //   device (a non-null stored app_uuid) must not be silently re-linked
        //   to a DIFFERENT device. Allowed: an explicit disconnect (status
        //   'disconnected' clears the binding for reconnect), the same app_uuid
        //   re-presenting (factory-reset continuity), not-yet-connected (no
        //   stored app_uuid -> first link), or no appUuid submitted (the gate
        //   intentionally allows this: back-compat for app versions that don't
        //   send appUuid).
        //
        //   We gate on the stored app_uuid rather than on
        //   mobile_linking_status == 'connected' alone: a coordinator re-issue
        //   appends participant_linking_code_issued, whose merge re-stamps
        //   mobile_linking_status to 'linking_in_progress' while leaving the
        //   bound app_uuid intact — so the participant is still device-bound
        //   even though the latest status is no longer literally 'connected'.
        //   Only an explicit 'disconnected' status releases the binding.
        //
        //   Runs only for an otherwise-valid active code, so expired/used/
        //   unknown codes still return their own status above.
        // Implements: DIARY-DEV-relink-device-gate/A+B+C
        {
          final precs =
              await backend.findViewRowsInTxn(txn, 'participant_record');
          Map<String, dynamic>? precRow;
          for (final row in precs) {
            if (row['aggregateId'] == participantId ||
                row['participant_id'] == participantId) {
              precRow = row;
              break;
            }
          }
          final storedStatus = precRow?['mobile_linking_status'] as String?;
          final storedAppUuid = precRow?['app_uuid'] as String?;
          final boundToDevice =
              storedAppUuid != null && storedStatus != 'disconnected';
          if (boundToDevice && appUuid != null && storedAppUuid != appUuid) {
            return _LinkOutcome.failure(
              409,
              'This device is already linked to a different participant '
              'device.',
            );
          }
        }

        // 3c. Read site info for the response (participant_record is read for
        //     B2's relink gate later; not needed for the B1 response itself).
        String? siteName;
        String? siteNumber;
        if (siteId != null) {
          final siteRows = await backend.findViewRowsInTxn(txn, 'sites_index');
          for (final row in siteRows) {
            if (row['site_id'] == siteId) {
              siteName = row['site_name'] as String?;
              siteNumber = row['site_number'] as String?;
              break;
            }
          }
        }

        // 3d. Mint the participant-identity JWT.
        final jwt = createPatientJwt(
          authCode: normalizedCode,
          userId: participantId,
        );

        // 3e. Consume the code: append participant_linking_code_used. This both
        //     marks linking_codes[code].status='used' (atomic single-use) and
        //     merges mobile_linking_status/app_uuid into participant_record.
        await eventStore.appendInTxn(
          txn,
          entryType: 'participant_linking_code_used',
          aggregateId: participantId,
          aggregateType: 'participant',
          eventType: 'participant_linking_code_used',
          data: <String, Object?>{
            'linking_code': normalizedCode,
            'participant_id': participantId,
            'app_uuid': appUuid,
            'used_at': DateTime.now().toUtc().toIso8601String(),
            'status': 'used',
            'mobile_linking_status': 'connected',
          },
          initiator: const AutomationInitiator(service: 'patient-link'),
          flowToken: null,
          metadata: null,
          security: null,
          checkpointReason: null,
          changeReason: null,
          dedupeByContent: false,
          collector: collector,
        );

        return _LinkOutcome.success(
          jwt: jwt,
          participantId: participantId,
          siteId: siteId,
          siteName: siteName,
          siteNumber: siteNumber,
        );
      },
    );

    // 4. Map the outcome to an HTTP response.
    if (!outcome.success) {
      return _err(outcome.statusCode, outcome.message ?? 'request failed');
    }
    final participantId = outcome.participantId;

    // 4a. Compose the sponsor-settings batch (set-once-at-link). The diary applies
    //     these through its EXISTING sponsor-settings path; they are recorded
    //     source=sponsor, locked=true on device. The batch carries branding
    //     identity (title + logo sha256/role) plus the clinical.* / ui.*
    //     configuration parameters from the event-sourced portal_settings store.
    //     Empty list when nothing is materialized — the link still succeeds.
    // Implements: DIARY-DEV-sponsor-branding-source/B
    // Implements: DIARY-DEV-sponsor-config-source/B+C
    final brandingSettings = await _sponsorSettingsBatch(eventStore, sid);

    return Response.ok(
      jsonEncode(<String, Object?>{
        'success': true,
        'jwt': outcome.jwt,
        'userId': participantId,
        'participantId': participantId,
        'linkingCode': normalizedCode,
        'siteId': outcome.siteId,
        'siteName': outcome.siteName,
        'siteNumber': outcome.siteNumber,
        'studyParticipantId': participantId,
        'sitePhoneNumber': null,
        'sponsor_settings': brandingSettings,
      }),
      headers: const {'Content-Type': 'application/json'},
    );
  };
}

/// Composes the `/link` sponsor-settings batch: the materialized sponsor branding
/// identity (title + logo sha256/role) for [sid] plus the `clinical.*` / `ui.*`
/// configuration parameters from the `portal_settings` store. Each entry is a
/// `{key, value, locked: true}` map the diary applies via its
/// `apply_sponsor_settings` action. Returns `[]` when nothing is materialized.
// Implements: DIARY-DEV-sponsor-branding-source/B
// Implements: DIARY-DEV-sponsor-config-source/B+C
Future<List<Map<String, Object?>>> _sponsorSettingsBatch(
  EventStore eventStore,
  String? sid,
) async {
  final settings = <Map<String, Object?>>[];

  // --- branding.* : title + logo asset identity (sha256 + role), never bytes ---
  final brandingRows =
      await eventStore.backend.findViewRows('sponsor_branding');
  Map<String, Object?>? branding;
  for (final r in brandingRows) {
    if (sid == null || r['sponsorId'] == sid) {
      branding = r;
      break;
    }
  }
  if (branding != null) {
    final title = branding['title'];
    if (title != null) {
      settings.add(<String, Object?>{
        'key': 'branding.title',
        'value': title,
        'locked': true,
      });
    }
    final assets = (branding['assets'] as List? ?? const [])
        .map((a) => (a as Map).cast<String, Object?>());
    for (final a in assets) {
      if (a['role'] == 'logo') {
        settings.add(<String, Object?>{
          'key': 'branding.logoSha256',
          'value': a['sha256'],
          'locked': true,
        });
        settings.add(<String, Object?>{
          'key': 'branding.logoRole',
          'value': 'logo',
          'locked': true,
        });
        break;
      }
    }
  }

  // --- clinical.* + ui.* : the per-deployment configuration parameters ---
  const configPrefixes = <String>['clinical.', 'ui.'];
  final settingRows = await eventStore.backend.findViewRows('portal_settings');
  for (final r in settingRows) {
    final key = r['key'];
    if (key is String && configPrefixes.any(key.startsWith)) {
      settings.add(<String, Object?>{
        'key': key,
        'value': r['value'],
        'locked': true,
      });
    }
  }

  return settings;
}
