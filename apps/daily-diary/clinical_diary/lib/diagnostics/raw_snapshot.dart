import 'package:clinical_diary/diagnostics/health_context.dart';
import 'package:event_sourcing/event_sourcing.dart' show FifoEntry, StoredEvent;

/// Builds the PHI-free structured `raw` appendix for the health snapshot.
///
/// Each top-level section is built inside its own try/catch so a throwing
/// section degrades to `{'error': '<message>'}` and never aborts the whole
/// appendix. The appendix NEVER serializes event payload bodies
/// ([StoredEvent.data]) or metadata — only headers.
// Implements: DIARY-DEV-device-health-checks/D
// Implements: DIARY-PRD-device-health-diagnostics/C
Future<Map<String, Object?>> buildRawAppendix(HealthProbeContext ctx) async {
  final out = <String, Object?>{};

  out['device'] = await _section(() async {
    final v = ctx.version;
    return <String, Object?>{
      'id': ctx.deviceId,
      'appVersion': v.appVersion,
      'buildNumber': v.buildNumber,
      'platform': v.platform,
      'os': v.os,
    };
  });

  out['clock'] = await _section(() async {
    final c = ctx.clock;
    return <String, Object?>{
      'deviceNow': c.deviceNow.toIso8601String(),
      'ianaZone': c.ianaZone,
      'utcOffsetMinutes': c.utcOffsetMinutes,
    };
  });

  out['store'] = await _section(() async {
    return <String, Object?>{
      'sequenceCounter': await ctx.backend.readSequenceCounter(),
    };
  });

  out['destinations'] = await _section(() async {
    final dests = <Object?>[];
    for (final id in ctx.destinationIds) {
      final fillCursor = await ctx.backend.readFillCursor(id);
      final fifoDepth = (await ctx.backend.listFifoEntries(id)).length;
      final head = await ctx.backend.readFifoHead(id);
      dests.add(<String, Object?>{
        'id': id,
        'fillCursor': fillCursor,
        'fifoDepth': fifoDepth,
        'head': head == null ? null : _headJson(head),
      });
    }
    return dests;
  });

  out['recentEventHeaders'] = await _section(() async {
    final events = await ctx.backend.findAllEvents(limit: 50);
    return events.map(_eventHeaderJson).toList();
  });

  return out;
}

/// Runs [build], returning its value or `{'error': '<message>'}` if it throws.
Future<Object?> _section(Future<Object?> Function() build) async {
  try {
    return await build();
  } catch (e) {
    return <String, Object?>{'error': e.toString()};
  }
}

Map<String, Object?> _headJson(FifoEntry head) => <String, Object?>{
  'entryId': head.entryId,
  'finalStatus': head.finalStatus?.toString(),
  'sequenceRange': <String, Object?>{
    'firstSeq': head.sequenceRange.firstSeq,
    'lastSeq': head.sequenceRange.lastSeq,
  },
  'attempts': head.attempts
      .map(
        (a) => <String, Object?>{
          'attemptedAt': a.attemptedAt.toIso8601String(),
          'outcome': a.outcome,
          'error': a.errorMessage,
          'httpStatus': a.httpStatus,
        },
      )
      .toList(),
};

/// Headers only — NEVER includes `data` or `metadata`.
Map<String, Object?> _eventHeaderJson(StoredEvent e) => <String, Object?>{
  'eventId': e.eventId,
  'entryType': e.entryType,
  'aggregateId': e.aggregateId,
  'sequenceNumber': e.sequenceNumber,
  'clientTimestamp': e.clientTimestamp.toIso8601String(),
  'eventHash': e.eventHash,
  'previousEventHash': e.previousEventHash,
};
