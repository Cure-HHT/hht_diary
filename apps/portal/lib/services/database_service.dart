// IMPLEMENTS REQUIREMENTS:
//   REQ-d00028: Portal Frontend Framework
//   REQ-p00003: Separate Database Per Sponsor

/// Abstract database service interface
/// Allows switching between production database and local mock (testing)
abstract class DatabaseService {
  // Auth methods
  Future<Map<String, dynamic>?> signInWithEmail(String email, String password);
  Future<void> signOut();
  Future<Map<String, dynamic>?> getCurrentUser();

  // Sites methods
  Future<List<Map<String, dynamic>>> getSites({List<String>? siteIds});

  // Portal users methods
  Future<List<Map<String, dynamic>>> getPortalUsers();
  Future<Map<String, dynamic>> createPortalUser({
    required String email,
    required String name,
    required String role,
    List<String>? assignedSites,
  });
  Future<void> revokeUserAccess(String userId);

  // Patients methods
  Future<List<Map<String, dynamic>>> getPatients({
    List<String>? siteIds,
    bool includeInactive = false,
  });
  Future<Map<String, dynamic>> enrollPatient({
    required String patientId,
    required String siteId,
  });

  // Questionnaires methods
  Future<void> sendQuestionnaire({
    required String patientId,
    required String questionnaireType,
  });
  Future<void> resendQuestionnaire(String questionnaireId);
  Future<void> acknowledgeQuestionnaire(String questionnaireId);
}
