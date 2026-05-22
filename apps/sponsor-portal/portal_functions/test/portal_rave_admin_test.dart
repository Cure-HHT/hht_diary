// Verifies: DIARY-OPS-rave-alert-notification/C+D
//
// Unit tests for portal_rave_admin's pure message builders. The handler
// itself is exercised by integration_test/rave_lockout_test.dart (needs
// DB + portal_users fixtures); here we cover the alert-content contract
// without standing up any of that.

import 'package:portal_functions/portal_functions.dart';
import 'package:test/test.dart';

void main() {
  group('buildUnwedgeConfirmationSlackMessage', () {
    test('successful probe formats as "probe OK" with env + email', () {
      final msg = buildUnwedgeConfirmationSlackMessage(
        env: 'qa',
        userEmail: 'alice@example.com',
        probeOk: true,
      );
      expect(msg, contains('[qa]'));
      expect(msg, contains('Rave unwedged by alice@example.com'));
      expect(msg, contains('probe OK'));
      expect(msg, isNot(contains('FAIL')));
    });

    test('failed probe formats as "probe FAIL: <error>"', () {
      final msg = buildUnwedgeConfirmationSlackMessage(
        env: 'dev',
        userEmail: 'bob@example.com',
        probeOk: false,
        probeError: 'invalid_grant',
      );
      expect(msg, contains('[dev]'));
      expect(msg, contains('Rave unwedged by bob@example.com'));
      expect(msg, contains('probe FAIL: invalid_grant'));
    });

    test('failed probe with null error falls back to "unknown"', () {
      final msg = buildUnwedgeConfirmationSlackMessage(
        env: 'uat',
        userEmail: 'carol@example.com',
        probeOk: false,
      );
      expect(msg, contains('probe FAIL: unknown'));
    });

    test('successful probe uses :white_check_mark: emoji', () {
      final msg = buildUnwedgeConfirmationSlackMessage(
        env: 'qa',
        userEmail: 'alice@example.com',
        probeOk: true,
      );
      expect(msg, startsWith(':white_check_mark:'));
    });

    test('failed probe uses :x: emoji (not a success marker)', () {
      // Operators scan Slack visually — a success emoji on a failed Unwedge
      // is misleading. The failure emoji must be distinct.
      final msg = buildUnwedgeConfirmationSlackMessage(
        env: 'qa',
        userEmail: 'alice@example.com',
        probeOk: false,
        probeError: 'whatever',
      );
      expect(msg, startsWith(':x:'));
      expect(msg, isNot(contains(':white_check_mark:')));
    });
  });
}
