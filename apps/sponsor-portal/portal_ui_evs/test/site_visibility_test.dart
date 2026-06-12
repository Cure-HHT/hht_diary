import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portal_screens/portal_screens.dart';
import 'package:portal_ui_evs/src/site_visibility.dart';

void main() {
  const sites = <SiteRowView>[
    SiteRowView(number: '001', name: 'Dev Site One', id: 'site-1'),
    SiteRowView(number: '002', name: 'Dev Site Two', id: 'site-2'),
    SiteRowView(number: '003', name: 'Dev Site Three', id: 'site-3'),
  ];

  test('site-class value wildcard (Administrator) sees every site', () {
    final visible = visibleSiteRows(
      sites: sites,
      scopeAssignments: const [
        ScopeAssignment(scope: ValueWildcardScope(class_: 'site')),
        ScopeAssignment(
          scope: BoundScope(class_: 'tier', value: 'staff'),
        ),
      ],
    );
    expect(visible, hasLength(3));
  });

  test('total wildcard sees every site', () {
    final visible = visibleSiteRows(
      sites: sites,
      scopeAssignments: const [ScopeAssignment(scope: TotalWildcardScope())],
    );
    expect(visible, hasLength(3));
  });

  test('site-bound role (CRA) sees exactly its bound sites', () {
    final visible = visibleSiteRows(
      sites: sites,
      scopeAssignments: const [
        ScopeAssignment(
          scope: BoundScope(class_: 'site', value: 'site-2'),
        ),
      ],
    );
    expect(visible.map((s) => s.id), ['site-2']);
  });

  test('non-site scopes grant nothing: no site coverage -> no sites', () {
    final visible = visibleSiteRows(
      sites: sites,
      scopeAssignments: const [
        ScopeAssignment(
          scope: BoundScope(class_: 'tier', value: 'staff'),
        ),
        ScopeAssignment(
          scope: BoundScope(class_: 'participant', value: 'P-1'),
        ),
      ],
    );
    expect(visible, isEmpty);
  });

  test('a tier value-wildcard is NOT a site wildcard', () {
    final visible = visibleSiteRows(
      sites: sites,
      scopeAssignments: const [
        ScopeAssignment(scope: ValueWildcardScope(class_: 'tier')),
        ScopeAssignment(
          scope: BoundScope(class_: 'site', value: 'site-1'),
        ),
      ],
    );
    expect(visible.map((s) => s.id), ['site-1']);
  });
}
