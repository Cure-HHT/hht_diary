// // IMPLEMENTS REQUIREMENTS:
// //   REQ-d00028: Portal Frontend Framework
// //   REQ-p00009: Sponsor-Specific Web Portals
//
// import 'database_service.dart';
//
// //BAD IDEA - no DB access from client
// /// Supabase database service for production and UAT environments
// class SQLDatabaseService implements DatabaseService {
//   //BAD IDEA - no DB access from client
//   // final SupabaseClient _client;
//
//   SQLDatabaseService({
//     required String url,
//     required String anonKey,
//   }) //BAD IDEA - no DB access from client
//   // : _client = SupabaseClient(url, anonKey);
//
//   @override
//   Future<Map<String, dynamic>?> signInWithEmail(
//     String email,
//     String password,
//   ) async {
//     // final response = await _client.auth.signInWithPassword(
//     //   email: email,
//     //   password: password,
//     // );
//     //
//     // if (response.user == null) return null;
//     //
//     // // Fetch portal user details from database
//     // final userData =
//     //     await _client.from('portal_users').select().eq('email', email).single();
//     //
//     // return userData;
//     return {};
//   }
//
//   @override
//   Future<void> signOut() async {
//     //BAD IDEA - no DB access from client
//     // await _client.auth.signOut();
//   }
//
//   @override
//   Future<Map<String, dynamic>?> getCurrentUser() async {
//     //BAD IDEA - no DB access from client
//     // final user = _client.auth.currentUser;
//     // if (user == null || user.email == null) return null;
//     //
//     // // Fetch portal user details from database
//     // final userData = await _client
//     //     .from('portal_users')
//     //     .select()
//     //     .eq('email', user.email!)
//     //     .single();
//     //
//     // return userData;
//     return {};
//   }
//
//   @override
//   Future<List<Map<String, dynamic>>> getSites({List<String>? siteIds}) async {
//     // var query = _client.from('sites').select();
//     //
//     // if (siteIds != null && siteIds.isNotEmpty) {
//     //   query = query.inFilter('site_id', siteIds);
//     // }
//     //
//     // final response = await query;
//     // return List<Map<String, dynamic>>.from(response);
//     return [];
//   }
//
//   @override
//   Future<List<Map<String, dynamic>>> getPortalUsers() async {
//     // final response = await _client.from('portal_users').select();
//     // return List<Map<String, dynamic>>.from(response);
//     return [];
//   }
//
//   @override
//   Future<Map<String, dynamic>> createPortalUser({
//     required String email,
//     required String name,
//     required String role,
//     List<String>? assignedSites,
//   }) async {
//     // final response = await _client
//     //     .from('portal_users')
//     //     .insert({
//     //       'email': email,
//     //       'name': name,
//     //       'role': role,
//     //       'assigned_sites': assignedSites,
//     //     })
//     //     .select()
//     //     .single();
//     //
//     // return response;
//     return {};
//   }
//
//   @override
//   Future<void> revokeUserAccess(String userId) async {
//     // await _client
//     //     .from('portal_users')
//     //     .update({'is_active': false}).eq('id', userId);
//   }
//
//   @override
//   Future<List<Map<String, dynamic>>> getPatients({
//     List<String>? siteIds,
//     bool includeInactive = false,
//   }) async {
//     // var query = _client.from('patients').select('*, sites(site_name)');
//     //
//     // if (!includeInactive) {
//     //   query = query.eq('is_active', true);
//     // }
//     //
//     // if (siteIds != null && siteIds.isNotEmpty) {
//     //   query = query.inFilter('site_id', siteIds);
//     // }
//     //
//     // final response = await query;
//     // return List<Map<String, dynamic>>.from(response);
//     return [];
//   }
//
//   @override
//   Future<Map<String, dynamic>> enrollPatient({
//     required String patientId,
//     required String siteId,
//   }) async {
//     // final response = await _client
//     //     .from('patients')
//     //     .insert({
//     //       'patient_id': patientId,
//     //       'site_id': siteId,
//     //     })
//     //     .select('*, sites(site_name)')
//     //     .single();
//     //
//     // return response;
//     return {};
//   }
//
//   @override
//   Future<void> sendQuestionnaire({
//     required String patientId,
//     required String questionnaireType,
//   }) async {
//     // await _client.from('questionnaires').insert({
//     //   'patient_id': patientId,
//     //   'questionnaire_type': questionnaireType,
//     //   'status': 'pending',
//     // });
//   }
//
//   @override
//   Future<void> resendQuestionnaire(String questionnaireId) async {
//     // await _client
//     //     .from('questionnaires')
//     //     .update({'sent_at': DateTime.now().toIso8601String()}).eq(
//     //         'id', questionnaireId);
//   }
//
//   @override
//   Future<void> acknowledgeQuestionnaire(String questionnaireId) async {
//     // await _client
//     //     .from('questionnaires')
//     //     .update({'status': 'acknowledged'}).eq('id', questionnaireId);
//   }
// }
