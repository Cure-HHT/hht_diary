// Verifies: DIARY-GUI-portal-session-expiry/A
import 'package:flutter_test/flutter_test.dart';
import 'package:portal_ui_evs/src/session_config.dart';

void main() {
  test('parseSessionConfig reads idle + warning seconds', () {
    final cfg = parseSessionConfig(const {
      'idleSeconds': 720,
      'warningSeconds': 45,
    });
    expect(cfg.idle, const Duration(seconds: 720));
    expect(cfg.warning, const Duration(seconds: 45));
  });

  test('parseSessionConfig falls back on missing fields', () {
    final cfg = parseSessionConfig(const {});
    expect(cfg.idle, SessionTimeoutConfig.fallback.idle);
    expect(cfg.warning, SessionTimeoutConfig.fallback.warning);
  });
}
