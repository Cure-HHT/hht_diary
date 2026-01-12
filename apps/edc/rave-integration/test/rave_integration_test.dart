import 'package:rave_integration/rave_integration.dart';
import 'package:test/test.dart';

void main() {
  group('OdmParser', () {
    group('validateComplete', () {
      test('accepts valid complete ODM', () {
        const xml = '''
<?xml version="1.0" encoding="utf-8"?>
<ODM ODMVersion="1.3" FileType="Snapshot">
  <AdminData>
    <Location OID="12345" Name="Site1" LocationType="Site" />
  </AdminData>
</ODM>''';
        // Should not throw
        expect(() => OdmParser.validateComplete(xml), returnsNormally);
      });

      test('throws on incomplete ODM (missing closing tag)', () {
        const xml = '''
<?xml version="1.0" encoding="utf-8"?>
<ODM ODMVersion="1.3" FileType="Snapshot">
  <AdminData>
    <Location OID="12345" Name="Site1" LocationType="Site" />
  </AdminData>''';
        expect(
          () => OdmParser.validateComplete(xml),
          throwsA(isA<RaveIncompleteResponseException>()),
        );
      });

      test('accepts ODM with trailing whitespace', () {
        const xml = '''
<?xml version="1.0" encoding="utf-8"?>
<ODM>
  <AdminData />
</ODM>
   ''';
        expect(() => OdmParser.validateComplete(xml), returnsNormally);
      });
    });

    group('parseSites', () {
      test('parses single site with all attributes', () {
        const xml = '''
<?xml version="1.0" encoding="utf-8"?>
<ODM ODMVersion="1.3" FileType="Snapshot" xmlns:mdsol="http://www.mdsol.com/ns/odm/metadata">
  <AdminData>
    <Location OID="DEV_999-001" Name="Site 001" LocationType="Site" mdsol:Active="Yes">
      <MetaDataVersionRef StudyOID="TER-1754-C01(APPDEV)" MetaDataVersionOID="31" EffectiveDate="2025-01-01" mdsol:StudySiteNumber="001"/>
    </Location>
  </AdminData>
</ODM>''';

        final sites = OdmParser.parseSites(xml);

        expect(sites, hasLength(1));
        expect(sites[0].oid, equals('DEV_999-001'));
        expect(sites[0].name, equals('Site 001'));
        expect(sites[0].isActive, isTrue);
        expect(sites[0].studySiteNumber, equals('001'));
        expect(sites[0].studyOid, equals('TER-1754-C01(APPDEV)'));
        expect(sites[0].metaDataVersionOid, equals('31'));
        expect(sites[0].effectiveDate, equals(DateTime(2025, 1, 1)));
      });

      test('parses multiple sites', () {
        const xml = '''
<?xml version="1.0" encoding="utf-8"?>
<ODM ODMVersion="1.3" xmlns:mdsol="http://www.mdsol.com/ns/odm/metadata">
  <AdminData>
    <Location OID="12345" Name="ActiveSite" LocationType="Site" mdsol:Active="Yes">
      <MetaDataVersionRef StudyOID="Mediflex(Prod)" MetaDataVersionOID="28" mdsol:StudySiteNumber="1"/>
    </Location>
    <Location OID="55555" Name="InactiveSite" LocationType="Site" mdsol:Active="No">
      <MetaDataVersionRef StudyOID="Mediflex(Prod)" MetaDataVersionOID="19" mdsol:StudySiteNumber="2"/>
    </Location>
    <Location OID="99999" Name="ActiveSite2" LocationType="Site" mdsol:Active="Yes">
      <MetaDataVersionRef StudyOID="Mediflex(Prod)" MetaDataVersionOID="28" mdsol:StudySiteNumber="70"/>
    </Location>
  </AdminData>
</ODM>''';

        final sites = OdmParser.parseSites(xml);

        expect(sites, hasLength(3));
        expect(sites[0].oid, equals('12345'));
        expect(sites[0].isActive, isTrue);
        expect(sites[1].oid, equals('55555'));
        expect(sites[1].isActive, isFalse);
        expect(sites[2].oid, equals('99999'));
        expect(sites[2].studySiteNumber, equals('70'));
      });

      test('handles empty AdminData', () {
        const xml = '''
<?xml version="1.0" encoding="utf-8"?>
<ODM ODMVersion="1.3">
  <AdminData>
  </AdminData>
</ODM>''';

        final sites = OdmParser.parseSites(xml);
        expect(sites, isEmpty);
      });

      test('ignores non-Site location types', () {
        const xml = '''
<?xml version="1.0" encoding="utf-8"?>
<ODM ODMVersion="1.3">
  <AdminData>
    <Location OID="sponsor" Name="Sponsor HQ" LocationType="Sponsor" />
    <Location OID="site1" Name="Site 1" LocationType="Site" />
  </AdminData>
</ODM>''';

        final sites = OdmParser.parseSites(xml);
        expect(sites, hasLength(1));
        expect(sites[0].oid, equals('site1'));
      });

      test('handles site without MetaDataVersionRef', () {
        const xml = '''
<?xml version="1.0" encoding="utf-8"?>
<ODM ODMVersion="1.3" xmlns:mdsol="http://www.mdsol.com/ns/odm/metadata">
  <AdminData>
    <Location OID="orphan" Name="Orphan Site" LocationType="Site" mdsol:Active="Yes">
    </Location>
  </AdminData>
</ODM>''';

        final sites = OdmParser.parseSites(xml);
        expect(sites, hasLength(1));
        expect(sites[0].oid, equals('orphan'));
        expect(sites[0].studySiteNumber, isNull);
        expect(sites[0].studyOid, isNull);
      });

      test('throws RaveParseException on malformed XML', () {
        // XML that passes completeness check but is internally malformed
        const xml = '<ODM><AdminData><invalid></ODM>';
        expect(
          () => OdmParser.parseSites(xml),
          throwsA(isA<RaveParseException>()),
        );
      });

      test('throws RaveIncompleteResponseException on unclosed ODM', () {
        const xml = '<not valid xml';
        expect(
          () => OdmParser.parseSites(xml),
          throwsA(isA<RaveIncompleteResponseException>()),
        );
      });
    });

    group('isEmpty', () {
      test('returns true for ODM with no AdminData', () {
        const xml = '''
<?xml version="1.0" encoding="utf-8"?>
<ODM ODMVersion="1.3">
</ODM>''';
        expect(OdmParser.isEmpty(xml), isTrue);
      });

      test('returns true for AdminData with no Locations', () {
        const xml = '''
<?xml version="1.0" encoding="utf-8"?>
<ODM ODMVersion="1.3">
  <AdminData>
  </AdminData>
</ODM>''';
        expect(OdmParser.isEmpty(xml), isTrue);
      });

      test('returns false when Locations exist', () {
        const xml = '''
<?xml version="1.0" encoding="utf-8"?>
<ODM ODMVersion="1.3">
  <AdminData>
    <Location OID="1" Name="Site" LocationType="Site" />
  </AdminData>
</ODM>''';
        expect(OdmParser.isEmpty(xml), isFalse);
      });

      test('returns true on invalid XML', () {
        expect(OdmParser.isEmpty('<invalid'), isTrue);
      });
    });
  });

  group('RaveSite', () {
    test('toString includes key fields', () {
      const site = RaveSite(
        oid: 'OID123',
        name: 'Test Site',
        isActive: true,
        studySiteNumber: '42',
      );
      expect(site.toString(), contains('OID123'));
      expect(site.toString(), contains('Test Site'));
      expect(site.toString(), contains('42'));
    });

    test('equality based on key fields', () {
      const site1 = RaveSite(oid: 'OID123', name: 'Test Site', isActive: true);
      const site2 = RaveSite(oid: 'OID123', name: 'Test Site', isActive: true);
      const site3 = RaveSite(oid: 'OID456', name: 'Test Site', isActive: true);

      expect(site1, equals(site2));
      expect(site1, isNot(equals(site3)));
    });
  });
}
