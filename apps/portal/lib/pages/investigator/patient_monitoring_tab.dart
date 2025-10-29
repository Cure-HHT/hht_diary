// IMPLEMENTS REQUIREMENTS:
//   REQ-p00026: Patient Monitoring Dashboard
//   REQ-p00027: Questionnaire Management
//   REQ-p00028: Token Revocation and Access Control

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../config/database_config.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../theme/portal_theme.dart';

enum QuestionnaireType {
  noseHht('NOSE HHT'),
  qol('Quality of Life');

  final String displayName;
  const QuestionnaireType(this.displayName);
}

enum QuestionnaireStatus {
  notSent('Not Sent'),
  sent('Pending'),
  completed('Completed');

  final String displayName;
  const QuestionnaireStatus(this.displayName);
}

class PatientMonitoringTab extends StatefulWidget {
  const PatientMonitoringTab({super.key});

  @override
  State<PatientMonitoringTab> createState() => _PatientMonitoringTabState();
}

class _PatientMonitoringTabState extends State<PatientMonitoringTab> {
  List<Map<String, dynamic>> _patients = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  Future<void> _loadPatients() async {
    setState(() => _isLoading = true);
    try {
      final authService = context.read<AuthService>();
      final assignedSites = authService.currentUser?.assignedSites ?? [];
      final db = DatabaseConfig.getDatabaseService();

      // Get patients (filtered by assigned sites if not admin)
      final patients = await db.getPatients(
        siteIds: assignedSites.isNotEmpty ? assignedSites : null,
        includeInactive: false,
      );

      setState(() {
        _patients = patients;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading patients: $e');
      setState(() => _isLoading = false);
    }
  }

  Color _getStatusColor(Map<String, dynamic> patient) {
    final lastEntry = patient['last_diary_entry'] as String?;
    if (lastEntry == null) return StatusColors.noData;

    final lastEntryDate = DateTime.parse(lastEntry);
    final daysSince = DateTime.now().difference(lastEntryDate).inDays;

    if (daysSince <= 3) return StatusColors.active;
    if (daysSince <= 7) return StatusColors.attention;
    return StatusColors.atRisk;
  }

  String _getStatusText(Map<String, dynamic> patient) {
    final lastEntry = patient['last_diary_entry'] as String?;
    if (lastEntry == null) return 'No Data';

    final lastEntryDate = DateTime.parse(lastEntry);
    final daysSince = DateTime.now().difference(lastEntryDate).inDays;

    if (daysSince <= 3) return 'Active';
    if (daysSince <= 7) return 'Attention';
    return 'At Risk';
  }

  int _getDaysWithoutData(Map<String, dynamic> patient) {
    final lastEntry = patient['last_diary_entry'] as String?;
    if (lastEntry == null) return -1;

    final lastEntryDate = DateTime.parse(lastEntry);
    return DateTime.now().difference(lastEntryDate).inDays;
  }

  Future<void> _sendQuestionnaire(
    String patientId,
    QuestionnaireType type,
  ) async {
    try {
      final db = DatabaseConfig.getDatabaseService();
      await db.sendQuestionnaire(
        patientId: patientId,
        questionnaireType: type.name,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${type.displayName} sent to patient')),
        );
        _loadPatients();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending questionnaire: $e')),
        );
      }
    }
  }

  Future<void> _acknowledgeCompletion(String questionnaireId) async {
    try {
      final db = DatabaseConfig.getDatabaseService();
      await db.acknowledgeQuestionnaire(questionnaireId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Questionnaire acknowledged')),
        );
        _loadPatients();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error acknowledging: $e')),
        );
      }
    }
  }

  Future<void> _revokePatientToken(String patientId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revoke Patient Access'),
        content: const Text(
          'Are you sure you want to revoke this patient\'s mobile app access? '
          'This is typically done for lost or stolen devices.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        // TODO: Add revokePatientToken to DatabaseService
        // For now, patients remain active in local database
        debugPrint('Patient token revocation not yet implemented');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Feature not yet implemented')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error revoking token: $e')),
          );
        }
      }
    }
  }

  Map<String, dynamic>? _getLatestQuestionnaire(
    List<dynamic>? questionnaires,
    QuestionnaireType type,
  ) {
    if (questionnaires == null) return null;

    final typeQuests = questionnaires
        .where((q) => q['questionnaire_type'] == type.name)
        .toList();

    if (typeQuests.isEmpty) return null;

    typeQuests.sort((a, b) {
      final aTime = a['sent_at'] ?? a['created_at'];
      final bTime = b['sent_at'] ?? b['created_at'];
      return bTime.compareTo(aTime);
    });

    return typeQuests.first;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final activeToday =
        _patients.where((p) => _getStatusText(p) == 'Active').length;
    final requiresFollowup = _patients
        .where((p) => ['Attention', 'At Risk'].contains(_getStatusText(p)))
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Patient Monitoring',
            style: Theme.of(context).textTheme.displaySmall,
          ),
        ),
        // Summary cards
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total Patients'),
                        Text(
                          '${_patients.length}',
                          style: Theme.of(context).textTheme.displayMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Active Today'),
                        Text(
                          '$activeToday',
                          style: Theme.of(context).textTheme.displayMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Requires Follow-up'),
                        Text(
                          '$requiresFollowup',
                          style: Theme.of(context)
                              .textTheme
                              .displayMedium
                              ?.copyWith(
                                color: requiresFollowup > 0
                                    ? StatusColors.attention
                                    : null,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Patient ID')),
                  DataColumn(label: Text('Site')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Days\nWithout Data')),
                  DataColumn(label: Text('NOSE HHT')),
                  DataColumn(label: Text('Quality of Life')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: _patients.map((patient) {
                  final siteName = patient['sites']?['site_name'] ?? 'Unknown';
                  final daysWithout = _getDaysWithoutData(patient);
                  final questionnaires = patient['questionnaires'] as List?;

                  final noseQuest = _getLatestQuestionnaire(
                    questionnaires,
                    QuestionnaireType.noseHht,
                  );
                  final qolQuest = _getLatestQuestionnaire(
                    questionnaires,
                    QuestionnaireType.qol,
                  );

                  return DataRow(
                    cells: [
                      DataCell(Text(patient['patient_id'] ?? '')),
                      DataCell(Text(siteName)),
                      DataCell(
                        Chip(
                          label: Text(_getStatusText(patient)),
                          backgroundColor: _getStatusColor(patient),
                        ),
                      ),
                      DataCell(Text(daysWithout >= 0 ? '$daysWithout' : 'Never')),
                      DataCell(_buildQuestionnaireCell(
                        patient['patient_id'],
                        QuestionnaireType.noseHht,
                        noseQuest,
                      )),
                      DataCell(_buildQuestionnaireCell(
                        patient['patient_id'],
                        QuestionnaireType.qol,
                        qolQuest,
                      )),
                      DataCell(
                        IconButton(
                          icon: const Icon(Icons.block),
                          onPressed: () =>
                              _revokePatientToken(patient['patient_id']),
                          tooltip: 'Revoke Token',
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionnaireCell(
    String patientId,
    QuestionnaireType type,
    Map<String, dynamic>? questionnaire,
  ) {
    if (questionnaire == null) {
      return TextButton(
        onPressed: () => _sendQuestionnaire(patientId, type),
        child: const Text('Send'),
      );
    }

    final status = questionnaire['status'] as String;
    final completedAt = questionnaire['completed_at'] as String?;

    if (status == QuestionnaireStatus.completed.name && completedAt != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat.yMd().format(DateTime.parse(completedAt)),
            style: const TextStyle(fontSize: 12),
          ),
          TextButton(
            onPressed: () => _acknowledgeCompletion(questionnaire['id']),
            child: const Text('Acknowledge'),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Pending', style: TextStyle(fontSize: 12)),
        TextButton(
          onPressed: () => _sendQuestionnaire(patientId, type),
          child: const Text('Resend'),
        ),
      ],
    );
  }
}
