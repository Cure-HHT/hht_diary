// Verifies: DIARY-PRD-action-inventory/A  (every inventory action is registered)
// Verifies: DIARY-DEV-linking-code-lifecycle/E  (check chars match keyed HMAC)
import 'package:portal_actions/portal_actions.dart';
import 'package:test/test.dart';

void main() {
  test('registry registers every action-inventory action exactly once', () {
    final names = buildPortalActionRegistry().all.map((a) => a.name).toList();
    expect(
      names.toSet().length,
      names.length,
      reason: 'no duplicate action names',
    );
    // The catalog has one entry per ACT id PLUS the ACT-USR-007-GRANT pseudo-id
    // (the second permission AssignRoleAction declares — the grant_role
    // escalation axis), which is not a distinct registered action. Compare
    // against the action-backed ids only.
    final actionBackedActIds = portalPermissionsByActId.keys
        .where((k) => k != 'ACT-USR-007-GRANT')
        .toSet();
    expect(names.toSet(), containsAll(actionBackedActIds));
    expect(names.length, actionBackedActIds.length);
    expect(
      names.toSet(),
      containsAll(<String>['ACT-OPS-001', 'ACT-OPS-002', 'ACT-OPS-003']),
    );
  });

  test('registry declares the ops-action permissions', () {
    final declared = buildPortalActionRegistry().all
        .expand((a) => a.permissions)
        .map((p) => p.name)
        .toSet();
    expect(
      declared,
      containsAll(<String>[
        'portal.rave.unwedge',
        'portal.user.create_sysop',
        'portal.user.create_admin',
      ]),
    );
  });

  test('every registered action declares a permission from the catalog', () {
    final catalog = portalPermissionsByActId.values.toSet();
    for (final a in buildPortalActionRegistry().all) {
      for (final p in a.permissions) {
        expect(catalog, contains(p), reason: '${a.name} perm ${p.name}');
      }
    }
  });

  // Verifies: DIARY-DEV-linking-code-lifecycle/E — generateLinkingCode threaded
  //   through the registry uses the injected sponsorResolverKey so the last 2
  //   chars of the code equal checkCharsFor(code.substring(0, 8), key).
  test(
    'generateLinkingCode with injected sponsorResolverKey produces correct check chars',
    () {
      const key = 'test-sponsor-key-abc123';
      // Use the generator directly — the registry wires the same key into its
      // Actions; the unit under test here is the key-threading contract.
      final code = generateLinkingCode(prefix: 'XX', sponsorKey: key);
      expect(code.length, 10);
      final body = code.substring(0, 8);
      final checkChars = code.substring(8);
      expect(
        checkChars,
        checkCharsFor(body, key),
        reason: 'last 2 chars must be HMAC check chars for the injected key',
      );
    },
  );

  test('registry wires sponsorResolverKey into LinkParticipantAction', () {
    const key = 'wiring-test-key-xyz';
    // Verify the registry accepts and stores the key without error.
    // The Action-level check-char correctness is covered by the generator test above.
    final registry = buildPortalActionRegistry(sponsorResolverKey: key);
    final linkAction =
        registry.all.firstWhere((a) => a.name == 'ACT-PAT-001')
            as LinkParticipantAction;
    expect(linkAction.sponsorResolverKey, key);
    final reconnectAction =
        registry.all.firstWhere((a) => a.name == 'ACT-PAT-004')
            as ReconnectParticipantAction;
    expect(reconnectAction.sponsorResolverKey, key);
    final reactivateAction =
        registry.all.firstWhere((a) => a.name == 'ACT-PAT-006')
            as ReactivateParticipantAction;
    expect(reactivateAction.sponsorResolverKey, key);
  });
}
