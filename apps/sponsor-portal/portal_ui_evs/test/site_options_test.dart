// Verifies: DIARY-PRD-user-account-site-assignment/C+D — the Administrator's
// user dialogs must load the Site list so any Site can be assigned. CUR-1599:
// the sites_index ViewBuilder was ungated and subscribed before the effective
// authorization was ready; the denied subscription was swallowed (ViewBuilder
// exposes no error state) and the control hung on "Loading sites…" forever.
// The PermissionGate defers the subscription until permissions load and gives
// an unauthorized viewer a settled (non-loading) empty list rather than a hang.
import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portal_screens/portal_screens.dart';
import 'package:portal_ui_evs/src/site_options.dart';
import 'package:reaction/reaction.dart';
import 'package:reaction_widgets/reaction_widgets.dart';
import 'package:reaction_widgets_testing/reaction_widgets_testing.dart';

FakeReaction _viewer({required bool canViewSites}) => FakeReaction(
  initialAuthStatus: Authenticated(
    principal: Principal.user(
      userId: 'admin-1',
      roles: const {'Administrator'},
      activeRole: 'Administrator',
    ),
  ),
  initialPermission: EffectiveAuthorization(
    activeRole: 'Administrator',
    rolePermissions: {
      if (canViewSites) Permission('portal.site.view'),
    },
    scopeAssignments: const <ScopeAssignment>[],
  ),
);

Future<({List<SiteOptionView> sites, bool loading})> _pump(
  WidgetTester tester,
  FakeReaction fake,
) async {
  late List<SiteOptionView> observedSites;
  late bool observedLoading;
  await tester.pumpWidget(
    ReActionScope(
      scope: fake,
      child: MaterialApp(
        home: Scaffold(
          body: SiteOptionsView(
            builder: (context, sites, loading) {
              observedSites = sites;
              observedLoading = loading;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return (sites: observedSites, loading: observedLoading);
}

void main() {
  testWidgets(
    'authorized viewer loads sorted sites and settles (not loading)',
    (tester) async {
      final fake = _viewer(canViewSites: true);
      await _pump(tester, fake);
      fake.emitViewUpdate<SiteOptionView>(
        'sites_index',
        const Snapshot<SiteOptionView>(
          value: SiteOptionView(id: 's2', number: '002', name: 'Beta'),
          sequence: 1,
        ),
      );
      fake.emitViewUpdate<SiteOptionView>(
        'sites_index',
        const Snapshot<SiteOptionView>(
          value: SiteOptionView(id: 's1', number: '001', name: 'Alpha'),
          sequence: 2,
        ),
      );
      fake.emitViewUpdate<SiteOptionView>(
        'sites_index',
        const EndOfReplay<SiteOptionView>(sequence: 2),
      );
      final result = await _pump(tester, fake);
      expect(result.loading, isFalse);
      expect(result.sites.map((s) => s.number), ['001', '002']);
    },
  );

  testWidgets(
    'viewer without portal.site.view gets a settled empty list, never hangs',
    (tester) async {
      final fake = _viewer(canViewSites: false);
      final result = await _pump(tester, fake);
      // Regression (CUR-1599): the fallback must be settled, NOT an endless
      // "Loading sites…" spinner.
      expect(result.loading, isFalse);
      expect(result.sites, isEmpty);
    },
  );
}
