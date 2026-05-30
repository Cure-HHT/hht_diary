// IMPLEMENTS REQUIREMENTS:
//   REQ-d00028: Portal Frontend Framework

import 'database_service.dart';

/// Local/mock database service for testing without Supabase
class LocalDatabaseService implements DatabaseService {
  // Mock data storage
  final List<Map<String, dynamic>> _sites = [
    {
      'site_id': 'site-001',
      'site_name': 'Test Site Alpha',
      'site_number': '001',
      'is_active': true,
    },
    {
      'site_id': 'site-002',
      'site_name': 'Test Site Beta',
      'site_number': '002',
      'is_active': true,
    },
  ];

  final List<Map<String, dynamic>> _portalUsers = [
    {
      'id': 'admin-001',
      'email': 'admin@test.com',
      'name': 'Test Admin',
      'role': 'admin',
      'is_active': true,
      'created_at': DateTime.now().toIso8601String(),
    },
    {
      'id': 'investigator-001',
      'email': 'investigator@test.com',
      'name': 'Test Investigator',
      'role': 'investigator',
      'assigned_sites': ['site-001'],
      'is_active': true,
      'created_at': DateTime.now().toIso8601String(),
    },
  ];

  final List<Map<String, dynamic>> _participants = [
    {
      'participant_id': '001-0000001',
      'site_id': 'site-001',
      'linking_code': 'AB3D5-FG7H9',
      'is_active': true,
      'last_login': null,
      'last_diary_entry': null,
      'created_at': DateTime.now()
          .subtract(const Duration(days: 2))
          .toIso8601String(),
      'sites': {'site_name': 'Test Site Alpha'},
      'questionnaires': [],
    },
  ];

  final List<Map<String, dynamic>> _questionnaires = [];

  Map<String, dynamic>? _currentUser;

  @override
  Future<Map<String, dynamic>?> signInWithEmail(
    String email,
    String password,
  ) async {
    // Mock authentication - accept any password for test users
    final user = _portalUsers.firstWhere(
      (u) => u['email'] == email && u['is_active'] == true,
      orElse: () => throw Exception('Invalid credentials'),
    );

    _currentUser = user;
    return user;
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
  }

  @override
  Future<Map<String, dynamic>?> getCurrentUser() async {
    return _currentUser;
  }

  @override
  Future<List<Map<String, dynamic>>> getSites({List<String>? siteIds}) async {
    if (siteIds == null || siteIds.isEmpty) {
      return List.from(_sites);
    }
    return _sites.where((site) => siteIds.contains(site['site_id'])).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getPortalUsers() async {
    return List.from(_portalUsers);
  }

  @override
  Future<Map<String, dynamic>> createPortalUser({
    required String email,
    required String name,
    required String role,
    List<String>? assignedSites,
  }) async {
    final newUser = {
      'id': 'user-${DateTime.now().millisecondsSinceEpoch}',
      'email': email,
      'name': name,
      'role': role,
      'assigned_sites': assignedSites,
      'is_active': true,
      'linking_code': _generateLinkingCode(),
      'created_at': DateTime.now().toIso8601String(),
    };
    _portalUsers.add(newUser);
    return newUser;
  }

  @override
  Future<void> revokeUserAccess(String userId) async {
    final user = _portalUsers.firstWhere((u) => u['id'] == userId);
    user['is_active'] = false;
  }

  @override
  Future<List<Map<String, dynamic>>> getParticipants({
    List<String>? siteIds,
    bool includeInactive = false,
  }) async {
    var participants = _participants;

    if (!includeInactive) {
      participants = participants.where((p) => p['is_active'] == true).toList();
    }

    if (siteIds != null && siteIds.isNotEmpty) {
      participants = participants
          .where((p) => siteIds.contains(p['site_id']))
          .toList();
    }

    return List.from(participants);
  }

  @override
  Future<Map<String, dynamic>> enrollParticipant({
    required String participantId,
    required String siteId,
  }) async {
    final newParticipant = {
      'participant_id': participantId,
      'site_id': siteId,
      'linking_code': _generateLinkingCode(),
      'is_active': true,
      'last_login': null,
      'last_diary_entry': null,
      'created_at': DateTime.now().toIso8601String(),
      'sites': {
        'site_name': _sites.firstWhere(
          (s) => s['site_id'] == siteId,
        )['site_name'],
      },
      'questionnaires': [],
    };
    _participants.add(newParticipant);
    return newParticipant;
  }

  @override
  Future<void> sendQuestionnaire({
    required String participantId,
    required String questionnaireType,
  }) async {
    final questionnaire = {
      'id': 'q-${DateTime.now().millisecondsSinceEpoch}',
      'participant_id': participantId,
      'questionnaire_type': questionnaireType,
      'status': 'pending',
      'sent_at': DateTime.now().toIso8601String(),
      'completed_at': null,
    };
    _questionnaires.add(questionnaire);

    // Add to participant's questionnaires
    final participant = _participants.firstWhere(
      (p) => p['participant_id'] == participantId,
    );
    (participant['questionnaires'] as List).add(questionnaire);
  }

  @override
  Future<void> resendQuestionnaire(String questionnaireId) async {
    final q = _questionnaires.firstWhere((q) => q['id'] == questionnaireId);
    q['sent_at'] = DateTime.now().toIso8601String();
  }

  @override
  Future<void> acknowledgeQuestionnaire(String questionnaireId) async {
    final q = _questionnaires.firstWhere((q) => q['id'] == questionnaireId);
    q['status'] = 'acknowledged';
  }

  String _generateLinkingCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    var code = '';
    for (var i = 0; i < 10; i++) {
      if (i == 5) code += '-';
      code += chars[(random + i) % chars.length];
    }
    return code;
  }
}
