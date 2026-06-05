import 'package:flutter_test/flutter_test.dart';
import 'package:portal_ui_evs/src/nav_sections.dart';

List<String> _labels(Iterable<NavSectionSpec> s) =>
    s.map((e) => e.label).toList();

void main() {
  group('visibleSections', () {
    // Verifies: DIARY-GUI-role-switching/E+F — the shell shows only the sections
    //   the active role holds the gating permission for.
    test(
      'an Administrator-like permission set sees every section, in order',
      () {
        final held = <String>{
          'view:users_index',
          'view:sites_index',
          'view:participant_record',
          'view:rave_sync_status',
          'portal.audit.view',
        };
        expect(_labels(visibleSections(held)), <String>[
          'User Accounts',
          'Sites',
          'Participants',
          'RAVE Sync',
          'Audit Log',
        ]);
      },
    );

    // Verifies: DIARY-GUI-role-switching/E+F
    test('a StudyCoordinator-like set hides User Accounts and Audit Log', () {
      final held = <String>{
        'view:sites_index',
        'view:participant_record',
        'view:rave_sync_status',
        'portal.participant.view',
      };
      expect(_labels(visibleSections(held)), <String>[
        'Sites',
        'Participants',
        'RAVE Sync',
      ]);
    });

    // Verifies: DIARY-GUI-role-switching/E+F — SystemOperator deliberately lacks
    //   participant_record, so Participants is hidden for it.
    test('a SystemOperator-like set hides Participants and Audit Log', () {
      final held = <String>{
        'view:users_index',
        'view:sites_index',
        'view:rave_sync_status',
      };
      expect(_labels(visibleSections(held)), <String>[
        'User Accounts',
        'Sites',
        'RAVE Sync',
      ]);
    });

    // Verifies: DIARY-GUI-role-switching/E+F
    test('no held permissions hides every section', () {
      expect(visibleSections(<String>{}), isEmpty);
    });

    // Verifies: DIARY-GUI-role-switching/E+F — visibility follows declaration
    //   order, not the order permissions happen to be held in.
    test('order follows kNavSections regardless of held-set ordering', () {
      final held = <String>{'portal.audit.view', 'view:users_index'};
      expect(_labels(visibleSections(held)), <String>[
        'User Accounts',
        'Audit Log',
      ]);
    });
  });

  group('resolveSelectedIndex', () {
    final visible = visibleSections(<String>{
      'view:sites_index',
      'view:participant_record',
      'view:rave_sync_status',
    });

    // Verifies: DIARY-GUI-role-switching/E+F
    test('returns the index of the still-visible selected label', () {
      expect(resolveSelectedIndex(visible, 'Participants'), 1);
    });

    // Verifies: DIARY-GUI-role-switching/E+F — a selection hidden by a role
    //   switch falls back to the first visible section.
    test('falls back to 0 when the selected label is no longer visible', () {
      expect(resolveSelectedIndex(visible, 'User Accounts'), 0);
    });

    // Verifies: DIARY-GUI-role-switching/E+F
    test('falls back to 0 when nothing is selected yet', () {
      expect(resolveSelectedIndex(visible, null), 0);
    });

    // Verifies: DIARY-GUI-role-switching/E+F
    test('returns -1 when no section is visible', () {
      expect(resolveSelectedIndex(const <NavSectionSpec>[], 'Sites'), -1);
    });
  });
}
