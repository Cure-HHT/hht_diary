import 'package:portal_actions/portal_actions.dart';
import 'package:portal_server_evs/portal_server_evs.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

String _referenceYaml() => loadRolePermissionsYaml(
      resolveSponsorConfigDir(const <String, String>{}),
    );

void main() {
  final declared = buildPortalActionRegistry()
      .allDeclaredPermissions
      .map((p) => p.name)
      .toSet();

  // Verifies: DIARY-DEV-role-permissions-seed/B
  test('every granted permission is a declared Action permission', () {
    final doc = loadYaml(_referenceYaml()) as YamlMap;
    final grants = doc['grants'] as YamlMap;
    for (final entry in grants.entries) {
      for (final perm in (entry.value as YamlList)) {
        expect(declared, contains(perm as String),
            reason: 'role ${entry.key} granted undeclared permission "$perm"');
      }
    }
  });

  // Verifies: CAL-PRD-role-definitions/A — the corrected matrix cells.
  group('matrix cells', () {
    late Set<String> sc, cra, admin, sysop;
    setUp(() {
      final grants =
          (loadYaml(_referenceYaml()) as YamlMap)['grants'] as YamlMap;
      Set<String> g(String r) =>
          (grants[r] as YamlList).map((e) => e as String).toSet();
      sc = g('StudyCoordinator');
      cra = g('CRA');
      admin = g('Administrator');
      sysop = g('SystemOperator');
    });

    test('FIX: Administrator cannot View Participant', () {
      expect(admin, isNot(contains('portal.participant.view')));
    });
    test('FIX: Study Coordinator can View audit log', () {
      expect(sc, contains('portal.audit.view'));
    });
    test('Administrator dropped from View Questionnaire Status', () {
      expect(admin, isNot(contains('portal.questionnaire.view_status')));
    });
    test('SC + CRA retain View Participant', () {
      expect(sc, contains('portal.participant.view'));
      expect(cra, contains('portal.participant.view'));
    });
    test('ACT-SEE-004 diary view granted to SC only (debug, reference-only)',
        () {
      expect(sc, contains('portal.diary.view_entries'));
      expect(cra, isNot(contains('portal.diary.view_entries')));
      expect(admin, isNot(contains('portal.diary.view_entries')));
      expect(sysop, isNot(contains('portal.diary.view_entries')));
    });
  });

  // Verifies: DIARY-DEV-role-permissions-seed/C — SystemOperator minimum.
  test('SystemOperator grants are a superset of the platform minimum', () {
    final grants = (loadYaml(_referenceYaml()) as YamlMap)['grants'] as YamlMap;
    final sysop =
        (grants['SystemOperator'] as YamlList).map((e) => e as String).toSet();
    expect(sysop, containsAll(kSystemOperatorMinimumPermissions));
  });
}
