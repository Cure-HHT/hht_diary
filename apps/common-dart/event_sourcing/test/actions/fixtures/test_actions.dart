import 'package:event_sourcing/event_sourcing.dart' show EventDraft;
import 'package:event_sourcing/src/actions/action.dart';
import 'package:event_sourcing/src/actions/action_context.dart';
import 'package:event_sourcing/src/actions/authorization_decision.dart'
    show Allow, AuthorizationDecision;
import 'package:event_sourcing/src/actions/authorization_policy.dart'
    show AuthorizationPolicy;
import 'package:event_sourcing/src/actions/execution_result.dart';
import 'package:event_sourcing/src/actions/idempotency.dart';
import 'package:event_sourcing/src/actions/permission.dart';
import 'package:event_sourcing/src/actions/principal.dart' show Principal;
import 'package:event_sourcing/src/actions/scope_class.dart';

/// Always-succeeds, emits one event.
class HelloAction extends Action<Map<String, Object?>, String> {
  @override
  String get name => 'hello';

  @override
  String get description => 'Say hello.';

  @override
  Set<Permission> get permissions => {
    const Permission('test.hello', scope: ScopeClass.global),
  };

  @override
  Idempotency get idempotency => Idempotency.none;

  @override
  Map<String, Object?> parseInput(Map<String, Object?> raw) =>
      <String, Object?>{'who': raw['who'] as String};

  @override
  void validate(Map<String, Object?> input) {}

  @override
  Future<ExecutionResult<String>> execute(
    Map<String, Object?> input,
    ActionContext ctx,
  ) async {
    return ExecutionResult<String>(
      result: 'Hello, ${input['who']}',
      events: <EventDraft>[
        EventDraft(
          aggregateId: 'greeting-${input['who']}',
          aggregateType: 'greeting',
          entryType: 'greeting',
          eventType: 'hello.said',
          data: <String, dynamic>{'who': input['who']},
        ),
      ],
    );
  }
}

/// Throws on parse.
class BadParseAction extends HelloAction {
  @override
  String get name => 'bad_parse';

  @override
  Map<String, Object?> parseInput(Map<String, Object?> raw) {
    throw ArgumentError('parse failure');
  }
}

/// Throws on validate.
class BadValidateAction extends HelloAction {
  @override
  String get name => 'bad_validate';

  @override
  void validate(Map<String, Object?> input) {
    throw StateError('validate failure');
  }
}

/// Throws on execute.
class BadExecuteAction extends HelloAction {
  @override
  String get name => 'bad_execute';

  @override
  Future<ExecutionResult<String>> execute(
    Map<String, Object?> input,
    ActionContext ctx,
  ) async {
    throw StateError('execute failure');
  }
}

/// Idempotency.required action.
class RequiredKeyAction extends HelloAction {
  @override
  String get name => 'requires_key';

  @override
  Idempotency get idempotency => Idempotency.required;
}

/// Action with TWO permissions, for testing first-deny short-circuit.
class TwoPermissionAction extends HelloAction {
  @override
  String get name => 'two_perms';

  @override
  Set<Permission> get permissions => {
    const Permission('test.first', scope: ScopeClass.global),
    const Permission('test.second', scope: ScopeClass.global),
  };
}

/// Emits 3 events on execute. Used in Stage 8 atomic-persist tests.
class MultiEventAction extends HelloAction {
  @override
  String get name => 'multi_event';

  @override
  Future<ExecutionResult<String>> execute(
    Map<String, Object?> input,
    ActionContext ctx,
  ) async {
    return const ExecutionResult<String>(
      result: 'multi',
      events: <EventDraft>[
        EventDraft(
          aggregateId: 'multi-agg',
          aggregateType: 'greeting',
          entryType: 'greeting',
          eventType: 'hello.said',
          data: <String, dynamic>{'who': 'alpha'},
        ),
        EventDraft(
          aggregateId: 'multi-agg',
          aggregateType: 'greeting',
          entryType: 'greeting',
          eventType: 'hello.said',
          data: <String, dynamic>{'who': 'beta'},
        ),
        EventDraft(
          aggregateId: 'multi-agg',
          aggregateType: 'greeting',
          entryType: 'greeting',
          eventType: 'hello.said',
          data: <String, dynamic>{'who': 'gamma'},
        ),
      ],
    );
  }
}

/// Authorization policy that allows every request. Used in Stage 6 tests
/// to verify the all-Allow path falls through to Stage 7.
class AlwaysAllowPolicy extends AuthorizationPolicy {
  const AlwaysAllowPolicy();

  @override
  Future<AuthorizationDecision> isPermitted(
    Principal principal,
    Permission permission,
  ) async => const Allow();

  @override
  Future<Set<Permission>> permissionsFor(Principal principal) async =>
      const <Permission>{};
}
