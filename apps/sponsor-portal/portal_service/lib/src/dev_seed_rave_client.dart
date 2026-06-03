// Implements: DIARY-DEV-rave-edc-ingest/A — dev seeding path: a fixed-fixture
//   RaveClient so the reactive portal server boots a populated sites_index /
//   participant_record locally (no live RAVE creds). Decouples portal_server_evs
//   from the legacy portal_functions package; the real RaveClient is used
//   whenever live RAVE_UAT_* env is present.
import 'package:rave_integration/rave_integration.dart';

/// In-memory [RaveClient] returning a small fixed fixture (3 sites, 4 subjects
/// under study OID `DEV-STUDY`) so a credential-less local boot still
/// materializes the sites/participant views. Fetch methods return the fixtures;
/// connectivity probes return trivial values; any other [RaveClient] member is
/// unreachable on this dev path and routes through [noSuchMethod].
// Implements: DIARY-DEV-rave-edc-ingest/A
class DevSeedRaveClient implements RaveClient {
  DevSeedRaveClient();

  /// The study OID the fixtures are scoped to.
  static const String studyOid = 'DEV-STUDY';

  static const List<RaveSite> _sites = <RaveSite>[
    RaveSite(
      oid: 'site-1',
      name: 'Dev Site One',
      isActive: true,
      studySiteNumber: '001',
      studyOid: studyOid,
    ),
    RaveSite(
      oid: 'site-2',
      name: 'Dev Site Two',
      isActive: true,
      studySiteNumber: '002',
      studyOid: studyOid,
    ),
    RaveSite(
      oid: 'site-3',
      name: 'Dev Site Three',
      isActive: true,
      studySiteNumber: '003',
      studyOid: studyOid,
    ),
  ];

  static const List<RaveSubject> _subjects = <RaveSubject>[
    RaveSubject(
      subjectKey: 'DEV-001-001',
      siteOid: 'site-1',
      siteNumber: '001',
    ),
    RaveSubject(
      subjectKey: 'DEV-001-002',
      siteOid: 'site-1',
      siteNumber: '001',
    ),
    RaveSubject(
      subjectKey: 'DEV-002-001',
      siteOid: 'site-2',
      siteNumber: '002',
    ),
    RaveSubject(
      subjectKey: 'DEV-003-001',
      siteOid: 'site-3',
      siteNumber: '003',
    ),
  ];

  @override
  Future<List<RaveSite>> getSites({String? studyOid}) async => _sites;

  @override
  Future<List<RaveSubject>> getSubjects({required String studyOid}) async =>
      _subjects;

  @override
  Future<String> getVersion() async => 'dev-seed';

  @override
  Future<String> getStudies() async => '<Studies/>';

  @override
  void close() {}

  // RaveClient is a concrete class; this dev seed only needs the fetch +
  // connectivity surface above. Any other member (e.g. private HTTP helpers)
  // is unreachable on the dev path.
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
