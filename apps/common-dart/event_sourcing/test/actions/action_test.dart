import 'package:event_sourcing/event_sourcing.dart'
    show EventDraft, SecurityDetails;
import 'package:event_sourcing/src/actions/action.dart';
import 'package:event_sourcing/src/actions/action_context.dart';
import 'package:event_sourcing/src/actions/execution_result.dart';
import 'package:event_sourcing/src/actions/idempotency.dart';
import 'package:event_sourcing/src/actions/permission.dart';
import 'package:event_sourcing/src/actions/principal.dart';
import 'package:event_sourcing/src/actions/scope_class.dart';
import 'package:test/test.dart';

class _NoOpAction extends Action<Map<String, Object?>, String> {
  @override
  String get name => 'noop';

  @override
  String get description => 'A no-op for testing.';

  @override
  Set<Permission> get permissions => {
    const Permission('test.noop', scope: ScopeClass.global),
  };

  @override
  Idempotency get idempotency => Idempotency.none;

  @override
  Map<String, Object?> parseInput(Map<String, Object?> raw) => raw;

  @override
  void validate(Map<String, Object?> input) {}

  @override
  Future<ExecutionResult<String>> execute(
    Map<String, Object?> input,
    ActionContext ctx,
  ) async => const ExecutionResult(result: 'ok', events: <EventDraft>[]);
}

class _CustomTtlAction extends _NoOpAction {
  @override
  Duration get idempotencyTtl => const Duration(minutes: 5);
}

void main() {
  group('Action', () {
    test('REQ-d00166-A: subclass exposes required getters', () {
      final a = _NoOpAction();
      expect(a.name, 'noop');
      expect(a.description, contains('no-op'));
      expect(a.permissions, hasLength(1));
      expect(a.idempotency, Idempotency.none);
    });

    test('REQ-d00166-A: parseInput returns the typed input', () {
      final a = _NoOpAction();
      final input = a.parseInput(<String, Object?>{'k': 'v'});
      expect(input['k'], 'v');
    });

    test(
      'REQ-d00166-D: execute returns ExecutionResult with events list',
      () async {
        final a = _NoOpAction();
        final ctx = ActionContext(
          principal: const Principal.anonymous(),
          security: const SecurityDetails(),
          requestStartedAt: DateTime.now(),
        );
        final r = await a.execute(<String, Object?>{}, ctx);
        expect(r.result, 'ok');
        expect(r.events, isEmpty);
      },
    );

    test('REQ-d00170-F: default idempotencyTtl is 24 hours', () {
      final a = _NoOpAction();
      expect(a.idempotencyTtl, const Duration(hours: 24));
    });

    test('REQ-d00170-F: subclass can override idempotencyTtl', () {
      final a = _CustomTtlAction();
      expect(a.idempotencyTtl, const Duration(minutes: 5));
    });
  });
}
