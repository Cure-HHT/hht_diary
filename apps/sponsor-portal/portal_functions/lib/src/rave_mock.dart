// Local-development mock for the Rave EDC client.
//
// Activated by setting the env var `RAVE_MOCK_MODE` to one of:
//
//   ok           — every call returns canned fixtures (1 study, 3 sites,
//                  3 subjects). Drives the success path of the lockout
//                  state machine (counter resets, banner stays clean).
//   auth_fail    — every call throws RaveAuthenticationException with a
//                  fake reasonCode. Drives the cooldown/lockout/Unwedge
//                  flow end-to-end without a live Rave endpoint.
//   network_fail — every call throws RaveNetworkException. Useful for
//                  verifying that network errors do NOT count toward the
//                  auth-failure counter (DIARY-DEV-rave-auth-failure-
//                  classification/B).
//
// When RAVE_MOCK_MODE is set, the regular RAVE_UAT_* env vars are not
// required — RaveConfig.isConfigured treats the mock as a configured Rave
// for gating purposes, and sites_sync / patients_sync construct a
// MockRaveClient instead of the real one.
//
// Mock state can be flipped by restarting the portal_server with a
// different RAVE_MOCK_MODE value. (For a richer side-channel-toggleable
// mock, see the follow-up note in the spec.)
//
// This file is shipped to production but only activates when the env var
// is set — production deployments leave RAVE_MOCK_MODE unset.

import 'package:rave_integration/rave_integration.dart';

const String _mockStudyOid = 'MOCK-STUDY-001';

/// Implements [RaveClient] in-process with canned responses controlled
/// by [mode]. See file header for the mode vocabulary.
class MockRaveClient implements RaveClient {
  /// One of `ok` | `auth_fail` | `network_fail`. Unknown values throw a
  /// generic [RaveException] so a typo in the env var is loud rather
  /// than silently behaving like one of the modes.
  final String mode;

  @override
  final String baseUrl = 'mock://rave';
  @override
  final String username = 'mock';
  @override
  final String password = 'mock';

  MockRaveClient(this.mode);

  /// Throws the configured failure for failure modes; returns for `ok`;
  /// throws RaveException for unknown modes.
  void _maybeFail() {
    switch (mode) {
      case 'ok':
        return;
      case 'auth_fail':
        throw const RaveAuthenticationException(
          reasonCode: 'MOCK_AUTH_FAIL',
          serverMessage: 'mock: rejecting credentials per RAVE_MOCK_MODE',
        );
      case 'network_fail':
        throw RaveNetworkException('mock: simulated network failure');
      default:
        // RaveException is sealed — use the closest concrete subtype.
        throw RaveApiException(
          'Unknown RAVE_MOCK_MODE="$mode" (expected ok | auth_fail | network_fail)',
          statusCode: 0,
        );
    }
  }

  @override
  Future<String> getVersion() async {
    _maybeFail();
    return '2024.1.0-mock';
  }

  @override
  Future<String> getStudies() async {
    _maybeFail();
    return '<ODM><Study OID="$_mockStudyOid"/></ODM>';
  }

  @override
  Future<List<RaveSite>> getSites({String? studyOid}) async {
    _maybeFail();
    return const [
      RaveSite(
        oid: 'MOCK-001',
        name: 'Mock Site 001 (development)',
        isActive: true,
        studySiteNumber: '001',
        studyOid: _mockStudyOid,
      ),
      RaveSite(
        oid: 'MOCK-002',
        name: 'Mock Site 002 (development)',
        isActive: true,
        studySiteNumber: '002',
        studyOid: _mockStudyOid,
      ),
      RaveSite(
        oid: 'MOCK-003',
        name: 'Mock Site 003 (development)',
        isActive: true,
        studySiteNumber: '003',
        studyOid: _mockStudyOid,
      ),
    ];
  }

  @override
  Future<List<RaveSubject>> getSubjects({required String studyOid}) async {
    _maybeFail();
    return const [
      RaveSubject(
        subjectKey: 'MOCK-001-001',
        siteOid: 'MOCK-001',
        siteNumber: '001',
      ),
      RaveSubject(
        subjectKey: 'MOCK-001-002',
        siteOid: 'MOCK-001',
        siteNumber: '001',
      ),
      RaveSubject(
        subjectKey: 'MOCK-002-001',
        siteOid: 'MOCK-002',
        siteNumber: '002',
      ),
    ];
  }

  @override
  void close() {}
}
