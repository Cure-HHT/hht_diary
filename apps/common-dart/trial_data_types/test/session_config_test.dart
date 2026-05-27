// IMPLEMENTS REQUIREMENTS:
//   REQ-p01073: Session Management
//
// Verifies: REQ-p01073-A/B/E — readiness gate, message, timeout window

import 'package:test/test.dart';
import 'package:trial_data_types/trial_data_types.dart';

void main() {
  group('SessionConfig.fromJson', () {
    test('parses fully-specified config', () {
      final c = SessionConfig.fromJson({
        'readinessCheck': true,
        'readinessMessage': 'Are you ready to start?',
        'estimatedMinutes': '10-12',
        'sessionTimeoutMinutes': 30,
        'timeoutWarningMinutes': 5,
      });

      expect(c.readinessCheck, isTrue);
      expect(c.readinessMessage, 'Are you ready to start?');
      expect(c.estimatedMinutes, '10-12');
      expect(c.sessionTimeoutMinutes, 30);
      expect(c.timeoutWarningMinutes, 5);
    });

    test('applies defaults for missing fields', () {
      final c = SessionConfig.fromJson(<String, dynamic>{});
      expect(c.readinessCheck, isTrue); // default true
      expect(c.readinessMessage, ''); // default ''
      expect(c.estimatedMinutes, ''); // default ''
      expect(c.sessionTimeoutMinutes, 30); // default 30
      expect(c.timeoutWarningMinutes, isNull); // optional
    });

    test('readinessCheck respects explicit false', () {
      final c = SessionConfig.fromJson({'readinessCheck': false});
      expect(c.readinessCheck, isFalse);
    });

    test(
      'zero/negative timeout values pass through (validation is upstream)',
      () {
        // Documents current behaviour: SessionConfig does NOT validate ranges.
        // Domain validation is expected in the calling layer.
        final zero = SessionConfig.fromJson({'sessionTimeoutMinutes': 0});
        expect(zero.sessionTimeoutMinutes, 0);
        // TODO(REQ-p01073-E): if validation is added later, replace these
        // expectations with throwsA assertions.
      },
    );
  });
}
