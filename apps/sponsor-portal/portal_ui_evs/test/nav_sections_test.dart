import 'package:flutter_test/flutter_test.dart';
import 'package:portal_ui_evs/src/nav_sections.dart';

List<String> _labels(Iterable<NavSectionSpec> s) =>
    s.map((e) => e.label).toList();

void main() {
  group('visibleSections', () {
    // Verifies: DIARY-GUI-role-switching/E+F — the shell shows only the sections
    //   the active role holds the gating permission for. Phase 6.5 ships User
    //   Accounts + Audit Log on the redesigned dashboard; Sites / Participants /
    //   RAVE Sync return when their own redesign round lands.
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
          'Audit Log',
        ]);
      },
    );

    // Verifies: DIARY-GUI-role-switching/E+F
    test('a StudyCoordinator-like set has no Phase-6.5 sections', () {
      final held = <String>{
        'view:sites_index',
        'view:participant_record',
        'view:rave_sync_status',
        'portal.participant.view',
      };
      expect(visibleSections(held), isEmpty);
    });

    // Verifies: DIARY-GUI-role-switching/E+F — SystemOperator holds
    //   view:users_index but not portal.audit.view, so it sees only User
    //   Accounts in the Phase-6.5 nav strip.
    test('a SystemOperator-like set sees only User Accounts', () {
      final held = <String>{
        'view:users_index',
        'view:sites_index',
        'view:rave_sync_status',
      };
      expect(_labels(visibleSections(held)), <String>['User Accounts']);
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
      'view:users_index',
      'portal.audit.view',
    });

    // Verifies: DIARY-GUI-role-switching/E+F
    test('returns the index of the still-visible selected label', () {
      expect(resolveSelectedIndex(visible, 'Audit Log'), 1);
    });

    // Verifies: DIARY-GUI-role-switching/E+F — a selection hidden by a role
    //   switch falls back to the first visible section.
    test('falls back to 0 when the selected label is no longer visible', () {
      expect(resolveSelectedIndex(visible, 'Sites'), 0);
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
