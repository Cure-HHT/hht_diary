// Verifies: DIARY-DEV-sponsor-branding-source/A — the sponsor_branding view
//   materializes the latest sponsor_branding_configured event per sponsor.
import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_actions/portal_actions.dart';
import 'package:portal_service/portal_service.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:test/test.dart';

void main() {
  test('sponsorBrandingSpec viewName + interest filter', () {
    expect(sponsorBrandingSpec.viewName, 'sponsor_branding');
    expect(
      sponsorBrandingSpec.interest.eventTypes,
      contains('sponsor_branding_configured'),
    );
    expect(
      sponsorBrandingSpec.interest.aggregateTypes,
      contains('sponsor_branding'),
    );
  });

  test('sponsor_branding folds latest config per sponsor', () async {
    final db = await databaseFactoryMemory.openDatabase('sb-1');
    final store = await openPortalEventStore(
      backend: SembastBackend(database: db),
    );
    const payload = SponsorBrandingConfiguredPayload(
      sponsorId: 'reference',
      title: 'Reference Study',
      assets: [
        BrandingAsset(
          role: 'logo',
          uri: '/api/v1/sponsor/branding/asset/logo',
          sha256: 'abc',
          contentType: 'image/png',
          byteLength: 10,
        ),
      ],
    );
    await store.append(
      entryType: 'sponsor_branding_configured',
      aggregateType: 'sponsor_branding',
      aggregateId: 'reference',
      eventType: 'sponsor_branding_configured',
      data: payload.toJson(),
      initiator: const AutomationInitiator(service: 'test'),
    );

    final rows = await store.backend.findViewRows('sponsor_branding');
    expect(rows, hasLength(1));
    expect(rows.single['sponsorId'], 'reference');
    expect(rows.single['title'], 'Reference Study');
    expect(rows.single['assets'], isA<List>());
  });
}
