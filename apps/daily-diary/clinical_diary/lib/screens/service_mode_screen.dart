import 'package:clinical_diary/diagnostics/health_checks.dart';
import 'package:clinical_diary/diagnostics/health_context.dart';
import 'package:clinical_diary/diagnostics/health_model.dart';
import 'package:clinical_diary/diagnostics/raw_snapshot.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// On-demand, PHI-free device health diagnostics ("Service Mode").
///
/// Reached via the tap-version-7x easter egg. Runs the health-check battery
/// and builds the raw appendix exactly once when opened — there is no
/// steady-state cost. Renders severity-tagged findings and offers copy / share
/// so the artifact can travel out-of-band (the wedge-able event FIFO cannot
/// carry it) up the participant -> sponsor -> vendor escalation chain.
// Implements: DIARY-PRD-device-health-diagnostics/A+B — on-demand export
//   reachable without network/sign-in/link; describes device health conditions
//   (including a wedged sync queue).
// Implements: DIARY-GUI-service-mode-entry/B — each finding carries a severity
//   indication and a human-readable detail.
class ServiceModeScreen extends StatefulWidget {
  const ServiceModeScreen({
    required this.contextBuilder,
    this.onShare,
    super.key,
  });

  /// Resolves the probe context on demand (reads backend, enrollment, version,
  /// clock). Async; invoked once when the screen opens.
  final Future<HealthProbeContext> Function() contextBuilder;

  /// Test seam for the share action; defaults to the platform share sheet.
  final Future<void> Function(String text)? onShare;

  @override
  State<ServiceModeScreen> createState() => _ServiceModeScreenState();
}

class _ServiceModeScreenState extends State<ServiceModeScreen> {
  HealthSnapshot? _snapshot;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    try {
      final ctx = await widget.contextBuilder();
      // runChecks / buildRawAppendix guard each check and each section
      // internally; this outer catch only handles a failure to build the
      // context at all (e.g. a dead backend), so the screen never crashes.
      final findings = await runChecks(ctx);
      final raw = await buildRawAppendix(ctx);
      if (!mounted) return;
      setState(() {
        _snapshot = HealthSnapshot(
          findings: findings,
          raw: raw,
          capturedAt: ctx.clock.deviceNow,
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Diagnostics copied to clipboard')),
    );
  }

  // Implements: DIARY-PRD-device-health-diagnostics/D — share the export
  //   through the device's standard sharing facilities.
  Future<void> _share(String text) async {
    final share = widget.onShare ?? _defaultShare;
    await share(text);
  }

  static Future<void> _defaultShare(String text) async {
    await SharePlus.instance.share(ShareParams(text: text));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Service Mode')),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_error != null) {
      return _ErrorState(error: _error!);
    }
    final snapshot = _snapshot;
    if (snapshot == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return _Report(
      snapshot: snapshot,
      // Implements: DIARY-GUI-service-mode-entry/C — copy and share controls
      //   over the single text artifact.
      onCopy: () => _copy(snapshot.render()),
      onShare: () => _share(snapshot.render()),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, color: Colors.red, size: 48),
          const SizedBox(height: 12),
          const Text(
            'Diagnostics unavailable',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          SelectableText('$error', textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _Report extends StatelessWidget {
  const _Report({
    required this.snapshot,
    required this.onCopy,
    required this.onShare,
  });

  final HealthSnapshot snapshot;
  final VoidCallback onCopy;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _OverallHeader(snapshot: snapshot),
              const SizedBox(height: 8),
              const Divider(),
              for (final f in snapshot.findings) _FindingTile(finding: f),
              const SizedBox(height: 8),
              ExpansionTile(
                title: const Text('Raw appendix (PHI-free)'),
                childrenPadding: const EdgeInsets.all(12),
                children: [
                  SelectableText(
                    snapshot.render(),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onCopy,
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onShare,
                    icon: const Icon(Icons.share),
                    label: const Text('Share'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _OverallHeader extends StatelessWidget {
  const _OverallHeader({required this.snapshot});

  final HealthSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final sev = snapshot.overall;
    return Row(
      children: [
        Icon(_severityIcon(sev), color: _severityColor(sev), size: 32),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Overall: ${sev.name.toUpperCase()}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                'Captured ${snapshot.capturedAt.toIso8601String()}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FindingTile extends StatelessWidget {
  const _FindingTile({required this.finding});

  final Finding finding;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(
        _severityIcon(finding.severity),
        color: _severityColor(finding.severity),
      ),
      title: Text(finding.id),
      subtitle: Text(finding.detail),
      trailing: Text(
        finding.severity.name.toUpperCase(),
        style: TextStyle(
          color: _severityColor(finding.severity),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

IconData _severityIcon(HealthSeverity sev) {
  switch (sev) {
    case HealthSeverity.blocking:
      return Icons.error;
    case HealthSeverity.warn:
      return Icons.warning_amber;
    case HealthSeverity.info:
      return Icons.info_outline;
    case HealthSeverity.ok:
      return Icons.check_circle;
  }
}

Color _severityColor(HealthSeverity sev) {
  switch (sev) {
    case HealthSeverity.blocking:
      return Colors.red.shade600;
    case HealthSeverity.warn:
      return Colors.orange.shade700;
    case HealthSeverity.info:
      return Colors.blue.shade600;
    case HealthSeverity.ok:
      return Colors.green.shade600;
  }
}
