import 'package:portal_actions/portal_actions.dart';
import 'package:portal_service/portal_service.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  test('every granted permission name is a declared action permission', () {
    final declared = buildPortalActionRegistry().allDeclaredPermissions
        .map((p) => p.name)
        .toSet();
    final doc = loadYaml(portalRoleSeedYaml) as YamlMap;
    final grants = doc['grants'] as YamlMap;
    for (final entry in grants.entries) {
      for (final perm in (entry.value as YamlList)) {
        expect(
          declared,
          contains(perm as String),
          reason: 'seed grants undeclared permission "$perm" to ${entry.key}',
        );
      }
    }
  });

  test('declares the 4 roles', () {
    final doc = loadYaml(portalRoleSeedYaml) as YamlMap;
    final roles = (doc['roles'] as YamlList).cast<String>().toSet();
    expect(roles, {
      'StudyCoordinator',
      'CRA',
      'Administrator',
      'SystemOperator',
    });
  });

  test('SystemOperator holds only ops perms; CRA holds no mutations', () {
    final doc = loadYaml(portalRoleSeedYaml) as YamlMap;
    final grants = doc['grants'] as YamlMap;
    final sysop = (grants['SystemOperator'] as YamlList).cast<String>().toSet();
    expect(sysop, {
      'portal.rave.unwedge',
      'portal.user.create_sysop',
      'portal.user.create_admin',
    });
    final cra = (grants['CRA'] as YamlList).cast<String>().toSet();
    expect(cra.any((p) => p.contains('.link') || p.contains('.send')), isFalse);
  });
}
