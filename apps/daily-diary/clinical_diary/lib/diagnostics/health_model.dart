import 'dart:convert';

/// Severity of a device-health [Finding], declared worst-to-best so that
/// [HealthSeverity.blocking] has the lowest [rank] (0) and is the worst.
enum HealthSeverity {
  blocking,
  warn,
  info,
  ok;

  /// Numeric rank; lower is worse. `blocking == 0`.
  int get rank => index;
}

/// A single device-health observation produced by one check.
class Finding {
  const Finding({
    required this.id,
    required this.severity,
    required this.detail,
    required this.at,
  });

  final String id;
  final HealthSeverity severity;
  final String detail;
  final DateTime at;
}

/// An immutable, PHI-free snapshot of device health: the list of [findings],
/// a structured PHI-free [raw] appendix, and the capture instant.
class HealthSnapshot {
  const HealthSnapshot({
    required this.findings,
    required this.raw,
    required this.capturedAt,
  });

  final List<Finding> findings;
  final Map<String, Object?> raw;
  final DateTime capturedAt;

  /// The worst (lowest-rank) severity among [findings]; [HealthSeverity.ok]
  /// when there are no findings.
  HealthSeverity get overall {
    var worst = HealthSeverity.ok;
    for (final f in findings) {
      if (f.severity.rank < worst.rank) worst = f.severity;
    }
    return worst;
  }

  /// Render a single human- and machine-readable PHI-free text blob.
  // Implements: DIARY-DEV-device-health-checks/D
  // Implements: DIARY-GUI-service-mode-entry/C
  String render() {
    final buf = StringBuffer()
      ..writeln('DEVICE HEALTH REPORT')
      ..writeln('capturedAt: ${capturedAt.toIso8601String()}')
      ..writeln('overall: ${overall.name.toUpperCase()}')
      ..writeln()
      ..writeln('FINDINGS');
    for (final f in findings) {
      buf.writeln('  ${f.id}  ${f.severity.name.toUpperCase()}  ${f.detail}');
    }
    buf
      ..writeln()
      ..writeln('RAW APPENDIX (PHI-free)')
      ..write(const JsonEncoder.withIndent('  ').convert(raw));
    return buf.toString();
  }
}
