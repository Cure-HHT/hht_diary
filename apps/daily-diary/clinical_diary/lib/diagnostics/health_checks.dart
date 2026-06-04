import 'package:clinical_diary/diagnostics/health_context.dart';
import 'package:clinical_diary/diagnostics/health_model.dart';

/// A single device-health check: given the probe context, produce one
/// [Finding]. May throw; [runChecks] guards each invocation.
typedef HealthCheck = Future<Finding> Function(HealthProbeContext);

/// A named, registry-listed [HealthCheck].
class RegisteredCheck {
  const RegisteredCheck(this.id, this.run);

  final String id;
  final HealthCheck run;
}

/// Threshold above which an unsynced backlog is flagged as a warning.
const int _kBacklogWarnThreshold = 200;

/// Probe key the [_storeWritable] check writes/reads to confirm the local
/// store is writable. Never collides with a real destination id.
const String _kStoreProbeId = '__health_probe__';

/// The v1 set of on-demand device-health checks, run in declaration order.
const List<RegisteredCheck> kDefaultChecks = [
  RegisteredCheck('fifo.wedged', _fifoWedged),
  RegisteredCheck('fifo.backlog', _fifoBacklog),
  RegisteredCheck('chain.contiguity', _chainContiguity),
  RegisteredCheck('store.writable', _storeWritable),
  RegisteredCheck('auth.link', _authLink),
];

/// Runs every check in [checks], guarding each so a throwing check degrades
/// to a `warn` [Finding] rather than aborting the batch.
// Implements: DIARY-DEV-device-health-checks/A
Future<List<Finding>> runChecks(
  HealthProbeContext ctx, {
  List<RegisteredCheck> checks = kDefaultChecks,
}) async {
  final findings = <Finding>[];
  for (final r in checks) {
    try {
      findings.add(await r.run(ctx));
    } catch (e) {
      // Implements: DIARY-DEV-device-health-checks/C
      findings.add(
        Finding(
          id: r.id,
          severity: HealthSeverity.warn,
          detail: 'check errored: $e',
          at: ctx.clock.deviceNow,
        ),
      );
    }
  }
  return findings;
}

// Implements: DIARY-DEV-device-health-checks/B
Future<Finding> _fifoWedged(HealthProbeContext ctx) async {
  final w = await ctx.backend.wedgedFifos();
  if (w.isNotEmpty) {
    final first = w.first;
    final extra = w.length > 1 ? ' (and ${w.length - 1} more)' : '';
    return Finding(
      id: 'fifo.wedged',
      severity: HealthSeverity.blocking,
      detail:
          'destination ${first.destinationId} wedged: '
          '${first.lastError}$extra',
      at: ctx.clock.deviceNow,
    );
  }
  return Finding(
    id: 'fifo.wedged',
    severity: HealthSeverity.ok,
    detail: 'no wedged FIFO',
    at: ctx.clock.deviceNow,
  );
}

// Implements: DIARY-DEV-device-health-checks/B
Future<Finding> _fifoBacklog(HealthProbeContext ctx) async {
  if (!ctx.everLinked) {
    return Finding(
      id: 'fifo.backlog',
      severity: HealthSeverity.ok,
      detail: 'pre-enrollment; sync intentionally local',
      at: ctx.clock.deviceNow,
    );
  }
  final seq = await ctx.backend.readSequenceCounter();
  var maxBacklog = 0;
  var worstDest = '';
  for (final id in ctx.destinationIds) {
    final cursor = await ctx.backend.readFillCursor(id);
    if (cursor < 0) continue; // never enqueued; nothing to be behind on
    final backlog = seq - cursor;
    if (backlog > maxBacklog) {
      maxBacklog = backlog;
      worstDest = id;
    }
  }
  if (maxBacklog > _kBacklogWarnThreshold) {
    return Finding(
      id: 'fifo.backlog',
      severity: HealthSeverity.warn,
      detail: 'destination $worstDest is $maxBacklog events behind',
      at: ctx.clock.deviceNow,
    );
  }
  return Finding(
    id: 'fifo.backlog',
    severity: HealthSeverity.ok,
    detail: 'backlog within bounds ($maxBacklog events)',
    at: ctx.clock.deviceNow,
  );
}

// Implements: DIARY-DEV-device-health-checks/B
Future<Finding> _chainContiguity(HealthProbeContext ctx) async {
  final evs = await ctx.backend.findAllEvents();
  for (var i = 1; i < evs.length; i++) {
    if (evs[i].previousEventHash != evs[i - 1].eventHash) {
      return Finding(
        id: 'chain.contiguity',
        severity: HealthSeverity.blocking,
        detail: 'chain break before seq ${evs[i].sequenceNumber}',
        at: ctx.clock.deviceNow,
      );
    }
  }
  return Finding(
    id: 'chain.contiguity',
    severity: HealthSeverity.ok,
    detail: 'chain intact (${evs.length} events)',
    at: ctx.clock.deviceNow,
  );
}

// Implements: DIARY-DEV-device-health-checks/B
Future<Finding> _storeWritable(HealthProbeContext ctx) async {
  const probe = _kStoreProbeId;
  try {
    await ctx.backend.writeFillCursor(probe, 1);
    final rb = await ctx.backend.readFillCursor(probe);
    if (rb == 1) {
      return Finding(
        id: 'store.writable',
        severity: HealthSeverity.ok,
        detail: 'local store writable',
        at: ctx.clock.deviceNow,
      );
    }
    return Finding(
      id: 'store.writable',
      severity: HealthSeverity.blocking,
      detail: 'store readback mismatch (got $rb)',
      at: ctx.clock.deviceNow,
    );
  } catch (e) {
    return Finding(
      id: 'store.writable',
      severity: HealthSeverity.blocking,
      detail: 'local store not writable: $e',
      at: ctx.clock.deviceNow,
    );
  }
}

// Implements: DIARY-DEV-device-health-checks/B
Future<Finding> _authLink(HealthProbeContext ctx) async {
  if (!ctx.everLinked) {
    return Finding(
      id: 'auth.link',
      severity: HealthSeverity.info,
      detail: 'not yet linked (pre-enrollment)',
      at: ctx.clock.deviceNow,
    );
  }
  if (ctx.linked && ctx.tokenLive) {
    return Finding(
      id: 'auth.link',
      severity: HealthSeverity.ok,
      detail: 'linked, token live',
      at: ctx.clock.deviceNow,
    );
  }
  return Finding(
    id: 'auth.link',
    severity: HealthSeverity.warn,
    detail: ctx.linked
        ? 'token expired or unrefreshable'
        : 'link state inconsistent',
    at: ctx.clock.deviceNow,
  );
}
