import 'package:portal_service/portal_service.dart';
import 'package:test/test.dart';

void main() {
  test('registry builds with site + participant-contained-in-site', () {
    final reg = buildPortalScopeRegistry();
    expect(reg.byName('site'), isNotNull);
    final participant = reg.byName('participant');
    expect(participant, isNotNull);
    expect(participant!.containedIn!.parentClass, 'site');
    expect(participant.containedIn!.projection, 'participant_site_index');
    expect(reg.isAncestor('site', 'participant'), isTrue);
  });
}
