// IMPLEMENTS REQUIREMENTS:
//   REQ-p00024: Portal User Roles and Permissions
//   REQ-p00029: Auditor Dashboard and Data Export

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../config/supabase_config.dart';
import '../../services/auth_service.dart';
import '../../widgets/portal_app_bar.dart';
import '../../widgets/portal_drawer.dart';
import '../../theme/portal_theme.dart';

class AuditorDashboardPage extends StatefulWidget {
  const AuditorDashboardPage({super.key});

  @override
  State<AuditorDashboardPage> createState() => _AuditorDashboardPageState();
}

class _AuditorDashboardPageState extends State<AuditorDashboardPage> {
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _patients = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final usersResponse =
          await SupabaseConfig.client.from('portal_users').select();
      final patientsResponse = await SupabaseConfig.client
          .from('patients')
          .select('*, sites(site_name), questionnaires(*)')
          .order('created_at', ascending: false);

      setState(() {
        _users = List<Map<String, dynamic>>.from(usersResponse);
        _patients = List<Map<String, dynamic>>.from(patientsResponse);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading data: $e');
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

  void _exportDatabase() {
    // Stub for future implementation
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Database'),
        content: const Text(
          'Database export functionality will be implemented in a future release. '
          'This will allow you to export all trial data for compliance reviews.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();

    // Check authentication and role
    if (!authService.isAuthenticated ||
        !authService.hasRole(UserRole.auditor)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/login');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_isLoading) {
      return const Scaffold(
        appBar: PortalAppBar(title: 'Auditor Dashboard'),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final activePatients =
        _patients.where((p) => _getStatusText(p) == 'Active').length;

    return Scaffold(
      appBar: const PortalAppBar(title: 'Auditor Dashboard'),
      drawer: const PortalDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Audit mode indicator
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                border: Border.all(color: Colors.amber.shade700),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.visibility, color: Colors.amber.shade700),
                  const SizedBox(width: 8),
                  Text(
                    'AUDIT MODE - Read-Only Access',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Summary cards
            Row(
              children: [
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total Users'),
                          Text(
                            '${_users.length}',
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
                          const Text('Active Patients'),
                          Text(
                            '$activePatients',
                            style: Theme.of(context).textTheme.displayMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Export button
            FilledButton.icon(
              onPressed: _exportDatabase,
              icon: const Icon(Icons.download),
              label: const Text('Export Database'),
            ),
            const SizedBox(height: 24),
            // Portal Users section
            Text(
              'Portal Users',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: 8),
            Card(
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Name')),
                  DataColumn(label: Text('Email')),
                  DataColumn(label: Text('Role')),
                  DataColumn(label: Text('Status')),
                ],
                rows: _users.map((user) {
                  final isActive = user['is_active'] ?? true;
                  return DataRow(
                    cells: [
                      DataCell(Text(user['name'] ?? 'N/A')),
                      DataCell(Text(user['email'] ?? '')),
                      DataCell(Text(user['role'] ?? '')),
                      DataCell(
                        Chip(
                          label: Text(isActive ? 'Active' : 'Revoked'),
                          backgroundColor:
                              isActive ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),
            // Patients section
            Text(
              'Patients',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: 8),
            Card(
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Patient ID')),
                  DataColumn(label: Text('Site')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Days Without Data')),
                  DataColumn(label: Text('Enrolled')),
                ],
                rows: _patients.map((patient) {
                  final siteName = patient['sites']?['site_name'] ?? 'Unknown';
                  final daysWithout = _getDaysWithoutData(patient);
                  final enrolled = patient['created_at'] as String;

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
                      DataCell(
                          Text(daysWithout >= 0 ? '$daysWithout' : 'Never')),
                      DataCell(Text(
                        DateFormat.yMd().format(DateTime.parse(enrolled)),
                      )),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
