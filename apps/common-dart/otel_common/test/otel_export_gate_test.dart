// Verifies: CUR-1322 — OTLP export is gated on a configured collector endpoint
// so a no-collector deployment does not emit Connection-refused export errors.

import 'package:otel_common/otel_common.dart';
import 'package:test/test.dart';

void main() {
  group('otelExportEnabled', () {
    test('disabled when no OTLP endpoint is configured', () {
      expect(otelExportEnabled(const {}), isFalse);
      expect(otelExportEnabled(const {'ENVIRONMENT': 'uat'}), isFalse);
    });

    test('enabled when the general OTLP endpoint is configured', () {
      expect(
        otelExportEnabled(const {
          'OTEL_EXPORTER_OTLP_ENDPOINT': 'http://collector:4318',
        }),
        isTrue,
      );
    });

    test('enabled when a signal-specific OTLP endpoint is configured', () {
      expect(
        otelExportEnabled(const {
          'OTEL_EXPORTER_OTLP_METRICS_ENDPOINT': 'http://c:4318/v1/metrics',
        }),
        isTrue,
      );
      expect(
        otelExportEnabled(const {
          'OTEL_EXPORTER_OTLP_TRACES_ENDPOINT': 'http://c:4318/v1/traces',
        }),
        isTrue,
      );
      expect(
        otelExportEnabled(const {
          'OTEL_EXPORTER_OTLP_LOGS_ENDPOINT': 'http://c:4318/v1/logs',
        }),
        isTrue,
      );
    });

    test(
      'disabled when OTEL_SDK_DISABLED is truthy, even with an endpoint',
      () {
        for (final v in const ['true', 'TRUE', '1', 'yes', 'on']) {
          expect(
            otelExportEnabled({
              'OTEL_SDK_DISABLED': v,
              'OTEL_EXPORTER_OTLP_ENDPOINT': 'http://collector:4318',
            }),
            isFalse,
            reason: 'OTEL_SDK_DISABLED=$v should force-disable export',
          );
        }
      },
    );

    test('enabled when OTEL_SDK_DISABLED is falsey and an endpoint is set', () {
      expect(
        otelExportEnabled(const {
          'OTEL_SDK_DISABLED': 'false',
          'OTEL_EXPORTER_OTLP_ENDPOINT': 'http://collector:4318',
        }),
        isTrue,
      );
    });

    test('disabled when the endpoint value is blank', () {
      expect(
        otelExportEnabled(const {'OTEL_EXPORTER_OTLP_ENDPOINT': '   '}),
        isFalse,
      );
    });
  });
}
