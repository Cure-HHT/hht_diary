// test/permissions/bootstrap_action_permissions_test.dart
// Verifies: REQ-d00178-B (bootstrap sequence). End-to-end: well-formed YAML
// + valid declared perms -> PolicyReady; mismatched yaml -> PolicyFailSafe;
// idempotent re-runs.
import 'package:event_sourcing/event_sourcing.dart';
import 'package:event_sourcing/src/permissions/authorization_policy_bootstrap.dart';
import 'package:event_sourcing/src/permissions/bootstrap_action_permissions.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_support/sembast_event_store_harness.dart';

void main() {
  group('bootstrapActionPermissions', () {
    late EventStore eventStore;

    setUp(() async {
      eventStore = await buildInMemoryEventStore();
    });

    test(
      'REQ-d00178-B: clean yaml + matching declared perms -> PolicyReady, ready answers permitted',
      () async {
        const yaml = '''
roles:
  - admin
grants:
  admin:
    - user.invite
''';
        final boot = await bootstrapActionPermissions(
          eventStore: eventStore,
          declaredPermissions: <Permission>{
            const Permission('user.invite', scope: ScopeClass.global),
          },
          yamlSource: yaml,
        );
        expect(boot, isA<PolicyReady>());
        expect(boot.isReady, isTrue);

        final policy = boot.policy;
        const p = Principal.user(
          userId: 'u',
          roles: {'admin'},
          activeRole: 'admin',
        );
        final d = await policy.isPermitted(
          p,
          const Permission('user.invite', scope: ScopeClass.global),
        );
        expect(d, isA<Allow>());
      },
    );

    test(
      'REQ-d00178-B: yaml refers to undeclared permission -> PolicyFailSafe',
      () async {
        const yaml = '''
roles:
  - admin
grants:
  admin:
    - user.unknown
''';
        final boot = await bootstrapActionPermissions(
          eventStore: eventStore,
          declaredPermissions: <Permission>{
            const Permission('user.invite', scope: ScopeClass.global),
          },
          yamlSource: yaml,
        );
        expect(boot, isA<PolicyFailSafe>());
        expect(boot.isReady, isFalse);
        expect(boot.errors, isNotEmpty);

        // FailSafe denies everything.
        const p = Principal.user(
          userId: 'u',
          roles: {'admin'},
          activeRole: 'admin',
        );
        final d = await boot.policy.isPermitted(
          p,
          const Permission('user.invite', scope: ScopeClass.global),
        );
        expect(d, isA<Deny>());
        expect((d as Deny).reason, DenyReason.bootstrapFailure);
      },
    );

    test(
      'REQ-d00178-B: re-bootstrap with same yaml is idempotent (no new events)',
      () async {
        const yaml = '''
roles:
  - admin
grants:
  admin:
    - user.invite
''';
        final declared = <Permission>{
          const Permission('user.invite', scope: ScopeClass.global),
        };
        await bootstrapActionPermissions(
          eventStore: eventStore,
          declaredPermissions: declared,
          yamlSource: yaml,
        );
        final eventsBefore = await eventStore.backend.findAllEvents(
          limit: 1000,
        );
        await bootstrapActionPermissions(
          eventStore: eventStore,
          declaredPermissions: declared,
          yamlSource: yaml,
        );
        final eventsAfter = await eventStore.backend.findAllEvents(limit: 1000);
        expect(eventsAfter.length, eventsBefore.length);
      },
    );

    test(
      'REQ-d00178-B: requires exactly one of yamlPath or yamlSource',
      () async {
        expect(
          () => bootstrapActionPermissions(
            eventStore: eventStore,
            declaredPermissions: const <Permission>{},
          ),
          throwsArgumentError,
        );
        expect(
          () => bootstrapActionPermissions(
            eventStore: eventStore,
            declaredPermissions: const <Permission>{},
            yamlPath: '/tmp/x.yaml',
            yamlSource: 'roles: []\ngrants: {}',
          ),
          throwsArgumentError,
        );
      },
    );
  });
}
