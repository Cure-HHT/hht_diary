import 'package:clinical_diary/diagnostics/health_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final at = DateTime.utc(2026, 6, 4, 12, 0, 0);

  group('HealthSnapshot.overall', () {
    // Verifies: DIARY-DEV-device-health-checks/D — overall is the worst severity.
    test('returns the worst (lowest-rank) severity among findings', () {
      final snap = HealthSnapshot(
        findings: [
          Finding(id: 'a', severity: HealthSeverity.info, detail: 'i', at: at),
          Finding(
            id: 'b',
            severity: HealthSeverity.blocking,
            detail: 'b',
            at: at,
          ),
          Finding(id: 'c', severity: HealthSeverity.warn, detail: 'w', at: at),
        ],
        raw: const {},
        capturedAt: at,
      );
      expect(snap.overall, HealthSeverity.blocking);
    });
  });

  // Verifies: DIARY-DEV-device-health-checks/D — empty findings is ok.
  test('overall is ok when there are no findings', () {
    final snap = HealthSnapshot(
      findings: const [],
      raw: const {},
      capturedAt: at,
    );
    expect(snap.overall, HealthSeverity.ok);
  });

  // Verifies: DIARY-DEV-device-health-checks/D — rank ordering blocking=0 worst.
  test('rank orders blocking worst, ok best', () {
    expect(HealthSeverity.blocking.rank, 0);
    expect(HealthSeverity.blocking.rank < HealthSeverity.warn.rank, isTrue);
    expect(HealthSeverity.warn.rank < HealthSeverity.info.rank, isTrue);
    expect(HealthSeverity.info.rank < HealthSeverity.ok.rank, isTrue);
  });

  group('HealthSnapshot.render', () {
    // Verifies: DIARY-GUI-service-mode-entry/C — render is a text blob with header.
    test('contains report header, overall, and each finding id+severity', () {
      final snap = HealthSnapshot(
        findings: [
          Finding(
            id: 'fifo.wedged',
            severity: HealthSeverity.blocking,
            detail: 'destination d wedged: boom',
            at: at,
          ),
          Finding(
            id: 'auth.link',
            severity: HealthSeverity.ok,
            detail: 'linked, token live',
            at: at,
          ),
        ],
        raw: const {'k': 1},
        capturedAt: at,
      );
      final out = snap.render();
      expect(out, contains('DEVICE HEALTH REPORT'));
      expect(out, contains('overall: BLOCKING'));
      expect(out, contains('fifo.wedged'));
      expect(out, contains('BLOCKING'));
      expect(out, contains('auth.link'));
      expect(out, contains('OK'));
      expect(out, contains('FINDINGS'));
      expect(out, contains('RAW APPENDIX'));
    });

    // Verifies: DIARY-GUI-service-mode-entry/C — raw appendix is rendered, no PHI 'data' key.
    test('renders raw appendix with the raw map and no "data" key', () {
      final snap = HealthSnapshot(
        findings: const [],
        raw: const {'k': 1},
        capturedAt: at,
      );
      final out = snap.render();
      expect(out, contains('RAW APPENDIX'));
      expect(out, contains('"k": 1'));
      expect(out, isNot(contains('"data"')));
    });
  });
}
