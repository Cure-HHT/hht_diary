import 'dart:async';
import 'dart:io';

import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_actions/portal_actions.dart';

/// Post-commit reactor on `participant_linking_code_issued` that keeps a
/// participant's set of linking codes consistent:
///
///  - Supersession (B): when a participant is issued a new code, any *prior*
///    active code for that participant is revoked, so only the newest code is
///    usable.
///  - Collision self-heal (D): in the astronomically-rare case that two
///    participants are issued the *same* code, the second one is detected
///    (via the per-participant `participant_record` view, since the code-keyed
///    `linking_codes` view hides the collision) and self-healed: the colliding
///    code is revoked for the later participant and a fresh unique code is
///    re-issued carrying the full issued contract.
class LinkingCodeLifecycleReactor {
  LinkingCodeLifecycleReactor({
    required this.eventStore,
    required this.backend,
    this.linkingPrefix = 'XX',
    this.sponsorDiscoveryKey = '',
  });

  final EventStore eventStore;
  final StorageBackend backend;
  final String linkingPrefix;
  final String sponsorDiscoveryKey;

  StreamSubscription<Update<StoredEvent>>? _sub;

  void start() {
    _sub = eventStore
        .subscribe<StoredEvent>(
      const SubscriptionFilter(eventTypes: {'participant_linking_code_issued'}),
      const Events(),
    )
        .listen((update) {
      if (update is Delta<StoredEvent>) {
        // Fire-and-forget with a catchError backstop: a reactor failure must
        // NEVER surface as an unhandled async exception that crashes the server.
        unawaited(
            handleIssued(update.value).catchError((Object e, StackTrace st) {
          stderr.writeln('LinkingCodeLifecycleReactor.handleIssued failed '
              '(continuing): $e\n$st');
        }));
      }
    }, onError: (Object e, StackTrace st) {
      stderr.writeln('LinkingCodeLifecycleReactor subscription error '
          '(continuing): $e\n$st');
    });
  }

  Future<void> handleIssued(StoredEvent event) async {
    final newCode = event.data['linking_code'] as String?;
    if (newCode == null) return;
    final participantId = event.aggregateId;

    await _supersedePriorCodes(participantId, newCode);
    await _healIfCollision(participantId, newCode, event);
  }

  /// Supersession (B): scan `linking_codes` — it keeps every distinct code as a
  /// separate row — and revoke any *other* still-active code held by this
  /// participant, leaving only [newCode] active.
  // Implements: DIARY-DEV-linking-code-lifecycle/B
  Future<void> _supersedePriorCodes(
      String participantId, String newCode) async {
    final rows = await backend.findViewRows('linking_codes');
    final priorCodes = <String>[
      for (final row in rows)
        if (row['participant_id'] == participantId &&
            row['status'] == 'active' &&
            row['linking_code'] is String &&
            row['linking_code'] != newCode)
          row['linking_code']! as String,
    ];
    for (final code in priorCodes) {
      await _appendRevoked(participantId, code, 'superseded');
    }
  }

  /// Collision self-heal (D): scan `participant_record` (NOT `linking_codes`) —
  /// two participants issued the SAME code map to the same `linking_codes` key,
  /// so the code-keyed view hides the collision; `participant_record` is keyed
  /// by participant and carries each participant's current code + status. If
  /// another participant currently holds [newCode] as active, revoke it for this
  /// participant and re-issue a fresh unique code carrying the full contract.
  // Implements: DIARY-DEV-linking-code-lifecycle/D
  Future<void> _healIfCollision(
    String participantId,
    String newCode,
    StoredEvent event,
  ) async {
    final precs = await backend.findViewRows('participant_record');
    final collision = precs.any((row) =>
        row['linking_code'] == newCode &&
        row['aggregateId'] != participantId &&
        row['status'] == 'active');
    if (!collision) return;

    await _appendRevoked(participantId, newCode, 'collision');

    final freshCode = await _generateUniqueCode();
    final data = event.data;
    await eventStore.append(
      entryType: 'participant_linking_code_issued',
      aggregateType: 'participant',
      aggregateId: participantId,
      eventType: 'participant_linking_code_issued',
      data: <String, Object?>{
        'linking_code': freshCode,
        'participant_id': participantId,
        'site_id': data['site_id'],
        'generated_by': data['generated_by'],
        'expires_at': data['expires_at'],
        'purpose': data['purpose'] ?? 'link',
        'status': 'active',
        'mobile_linking_status': 'linking_in_progress',
      },
      initiator: const AutomationInitiator(service: 'linking-code-lifecycle'),
    );
  }

  /// Generate a linking code that does not collide with any code already in the
  /// `linking_codes` view.
  Future<String> _generateUniqueCode() async {
    final rows = await backend.findViewRows('linking_codes');
    final existing = <String>{
      for (final row in rows)
        if (row['linking_code'] is String) row['linking_code']! as String,
    };
    String candidate;
    do {
      candidate = generateLinkingCode(
        prefix: linkingPrefix,
        sponsorKey: sponsorDiscoveryKey,
      );
    } while (existing.contains(candidate));
    return candidate;
  }

  Future<void> _appendRevoked(
    String participantId,
    String code,
    String reason,
  ) =>
      eventStore.append(
        entryType: 'participant_linking_code_revoked',
        aggregateType: 'participant',
        aggregateId: participantId,
        eventType: 'participant_linking_code_revoked',
        data: <String, Object?>{
          'linking_code': code,
          'participant_id': participantId,
          'reason': reason,
          'status': 'revoked',
        },
        initiator: const AutomationInitiator(service: 'linking-code-lifecycle'),
      );

  Future<void> stop() => _sub?.cancel() ?? Future<void>.value();
}
