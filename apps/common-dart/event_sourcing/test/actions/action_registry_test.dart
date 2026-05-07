import 'package:event_sourcing/event_sourcing.dart' show EventDraft;
import 'package:event_sourcing/src/actions/action.dart';
import 'package:event_sourcing/src/actions/action_context.dart';
import 'package:event_sourcing/src/actions/action_registry.dart';
import 'package:event_sourcing/src/actions/execution_result.dart';
import 'package:event_sourcing/src/actions/idempotency.dart';
import 'package:event_sourcing/src/actions/permission.dart';
import 'package:event_sourcing/src/actions/scope_class.dart';
import 'package:test/test.dart';

class _A extends Action<Map<String, Object?>, void> {
  _A(this.name, this.permissions);

  @override
  final String name;

  @override
  final Set<Permission> permissions;

  @override
  String get description => '';

  @override
  Idempotency get idempotency => Idempotency.none;

  @override
  Map<String, Object?> parseInput(Map<String, Object?> raw) => raw;

  @override
  void validate(Map<String, Object?> input) {}

  @override
  Future<ExecutionResult<void>> execute(
    Map<String, Object?> input,
    ActionContext ctx,
  ) async => const ExecutionResult<void>(result: null, events: <EventDraft>[]);
}

void main() {
  group('ActionRegistry', () {
    test('REQ-d00167-A: register stores the action', () {
      final r = ActionRegistry()
        ..register(_A('a', {const Permission('p1', scope: ScopeClass.global)}));
      expect(r.lookup('a'), isNotNull);
    });

    test('REQ-d00167-A: duplicate name throws ArgumentError', () {
      final r = ActionRegistry()
        ..register(_A('a', {const Permission('p1', scope: ScopeClass.global)}));
      expect(
        () => r.register(
          _A('a', {const Permission('p2', scope: ScopeClass.global)}),
        ),
        throwsArgumentError,
      );
    });

    test('REQ-d00167-B: lookup of unknown name returns null', () {
      final r = ActionRegistry();
      expect(r.lookup('nope'), isNull);
    });

    test('REQ-d00167-C: allDeclaredPermissions is the union', () {
      final r = ActionRegistry()
        ..register(
          _A('a', {
            const Permission('p1', scope: ScopeClass.global),
            const Permission('p2', scope: ScopeClass.global),
          }),
        )
        ..register(
          _A('b', {
            const Permission('p2', scope: ScopeClass.global),
            const Permission('p3', scope: ScopeClass.global),
          }),
        );
      expect(r.allDeclaredPermissions, {
        const Permission('p1', scope: ScopeClass.global),
        const Permission('p2', scope: ScopeClass.global),
        const Permission('p3', scope: ScopeClass.global),
      });
    });

    test('all returns every registered action in insertion order', () {
      final r = ActionRegistry()
        ..register(_A('a', const <Permission>{}))
        ..register(_A('b', const <Permission>{}));
      final names = r.all.map((a) => a.name).toList();
      expect(names, ['a', 'b']);
    });
  });
}
