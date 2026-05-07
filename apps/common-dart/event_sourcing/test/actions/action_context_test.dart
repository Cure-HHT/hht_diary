import 'package:event_sourcing/src/actions/action_context.dart';
import 'package:event_sourcing/src/actions/principal.dart';
import 'package:event_sourcing/src/security/security_details.dart';
import 'package:test/test.dart';

void main() {
  group('ActionContext', () {
    test('REQ-d00166: bundles principal, security, and timestamp', () {
      final ctx = ActionContext(
        principal: const Principal.anonymous(),
        security: const SecurityDetails(),
        requestStartedAt: DateTime.parse('2026-04-22T12:00:00Z'),
      );
      expect(ctx.principal, isA<AnonymousPrincipal>());
      expect(ctx.security, isA<SecurityDetails>());
      expect(ctx.requestStartedAt, DateTime.parse('2026-04-22T12:00:00Z'));
    });
  });
}
