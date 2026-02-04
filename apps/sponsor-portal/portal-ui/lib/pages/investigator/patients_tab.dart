// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00063: EDC Patient Ingestion
//   REQ-CAL-p00073: Patient Status Definitions
//   REQ-CAL-p00019: Link New Patient Workflow
//   REQ-CAL-p00049: Mobile Linking Codes
//   REQ-p00024: Portal User Roles and Permissions
//   REQ-p70007: Linking Code Lifecycle Management
//   REQ-CAL-p00020: Patient Disconnection Workflow
//   REQ-CAL-p00021: Patient Reconnection Workflow
//   REQ-CAL-p00066: Status Change Reason Field
//   REQ-CAL-p00064: Mark Patient as Not Participating
//
// Study Coordinator Patients Tab - site-scoped patient dashboard with
// search, status filtering, and contextual actions

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../widgets/disconnect_patient_dialog.dart';
import '../../widgets/link_patient_dialog.dart';
import '../../widgets/patient_actions_dialog.dart';
import '../../widgets/reactivate_patient_dialog.dart';

/// Status filter for the patients tab
enum PatientStatusFilter {
  all('All'),
  notConnected('Not Connected'),
  active('Active'),
  inactive('Inactive');

  final String label;
  const PatientStatusFilter(this.label);
}

/// Model for a patient in the Study Coordinator view
class _PatientData {
  final String patientId;
  final String siteId;
  final String edcSubjectKey;
  final String mobileLinkingStatus;
  final DateTime? edcSyncedAt;
  final String siteName;
  final String siteNumber;

  _PatientData({
    required this.patientId,
    required this.siteId,
    required this.edcSubjectKey,
    required this.mobileLinkingStatus,
    this.edcSyncedAt,
    required this.siteName,
    required this.siteNumber,
  });

  factory _PatientData.fromJson(Map<String, dynamic> json) {
    return _PatientData(
      patientId: json['patient_id'] as String,
      siteId: json['site_id'] as String,
      edcSubjectKey: json['edc_subject_key'] as String,
      mobileLinkingStatus: json['mobile_linking_status'] as String,
      edcSyncedAt: json['edc_synced_at'] != null
          ? DateTime.parse(json['edc_synced_at'] as String)
          : null,
      siteName: json['site_name'] as String,
      siteNumber: json['site_number'] as String,
    );
  }

  /// Categorize the patient for filter tabs
  PatientStatusFilter get statusCategory {
    switch (mobileLinkingStatus) {
      case 'not_connected':
        return PatientStatusFilter.notConnected;
      case 'connected':
      case 'linking_in_progress':
        return PatientStatusFilter.active;
      case 'disconnected':
      case 'not_participating':
        return PatientStatusFilter.inactive;
      default:
        return PatientStatusFilter.notConnected;
    }
  }
}

/// Site info from assigned_sites response
class _SiteInfo {
  final String siteId;
  final String siteName;
  final String siteNumber;

  _SiteInfo({
    required this.siteId,
    required this.siteName,
    required this.siteNumber,
  });

  factory _SiteInfo.fromJson(Map<String, dynamic> json) {
    return _SiteInfo(
      siteId: json['site_id'] as String,
      siteName: json['site_name'] as String,
      siteNumber: json['site_number'] as String,
    );
  }
}

/// Study Coordinator Patients Tab widget
class StudyCoordinatorPatientsTab extends StatefulWidget {
  /// Creates a StudyCoordinatorPatientsTab.
  ///
  /// The [apiClient] parameter is optional and intended for testing.
  /// If not provided, a new ApiClient will be created internally.
  const StudyCoordinatorPatientsTab({super.key, this.apiClient});

  /// Optional ApiClient for dependency injection (used in tests)
  final ApiClient? apiClient;

  @override
  State<StudyCoordinatorPatientsTab> createState() =>
      _StudyCoordinatorPatientsTabState();
}

class _StudyCoordinatorPatientsTabState
    extends State<StudyCoordinatorPatientsTab> {
  List<_PatientData>? _patients;
  List<_SiteInfo> _assignedSites = [];
  bool _isLoading = true;
  String? _error;
  PatientStatusFilter _activeFilter = PatientStatusFilter.all;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPatients() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final authService = context.read<AuthService>();
    final apiClient = widget.apiClient ?? ApiClient(authService);

    final response = await apiClient.get('/api/v1/portal/patients');

    if (!mounted) return;

    if (response.isSuccess && response.data != null) {
      final data = response.data as Map<String, dynamic>;
      final patientsJson = data['patients'] as List<dynamic>? ?? [];
      final patients = patientsJson
          .map((p) => _PatientData.fromJson(p as Map<String, dynamic>))
          .toList();

      // Parse assigned sites if present
      final sitesJson = data['assigned_sites'] as List<dynamic>? ?? [];
      final sites = sitesJson
          .map((s) => _SiteInfo.fromJson(s as Map<String, dynamic>))
          .toList();

      setState(() {
        _patients = patients;
        _assignedSites = sites;
        _isLoading = false;
      });
    } else {
      setState(() {
        _error = response.error ?? 'Failed to load patients';
        _isLoading = false;
      });
    }
  }

  /// Get patients filtered by current status filter and search query
  List<_PatientData> get _filteredPatients {
    if (_patients == null) return [];
    var filtered = _patients!.toList();

    // Apply status filter
    if (_activeFilter != PatientStatusFilter.all) {
      filtered = filtered
          .where((p) => p.statusCategory == _activeFilter)
          .toList();
    }

    // Apply search query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((p) {
        return p.patientId.toLowerCase().contains(query) ||
            p.siteName.toLowerCase().contains(query) ||
            p.siteNumber.toLowerCase().contains(query);
      }).toList();
    }

    return filtered;
  }

  /// Count patients by status category
  int _countByStatus(PatientStatusFilter filter) {
    if (_patients == null) return 0;
    if (filter == PatientStatusFilter.all) return _patients!.length;
    return _patients!.where((p) => p.statusCategory == filter).length;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _buildErrorState(theme);
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // My Sites section
          if (_assignedSites.isNotEmpty) ...[
            _buildMySitesSection(theme),
            const SizedBox(height: 24),
          ],

          // Patient Summary header with search
          _buildPatientSummaryHeader(theme),
          const SizedBox(height: 16),

          // Status filter tabs
          _buildStatusFilterTabs(theme),
          const SizedBox(height: 16),

          // Patient data table
          Expanded(child: _buildPatientTable(theme)),
        ],
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
          const SizedBox(height: 16),
          Text('Error loading patients', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            _error!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _loadPatients,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildMySitesSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'My Sites',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _assignedSites.map((site) {
            return Chip(
              avatar: Icon(
                Icons.location_city,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              label: Text('${site.siteNumber} - ${site.siteName}'),
              side: BorderSide(
                color: theme.colorScheme.primary.withValues(alpha: 0.3),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPatientSummaryHeader(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Patient Summary',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_patients?.length ?? 0} patients across ${_assignedSites.length} sites',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        // Search bar
        SizedBox(
          width: 300,
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search patients...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              isDense: true,
            ),
            onChanged: (value) {
              setState(() => _searchQuery = value);
            },
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          onPressed: _loadPatients,
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh patients',
        ),
      ],
    );
  }

  Widget _buildStatusFilterTabs(ThemeData theme) {
    return Row(
      children: PatientStatusFilter.values.map((filter) {
        final count = _countByStatus(filter);
        final isActive = _activeFilter == filter;

        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: FilterChip(
            selected: isActive,
            label: Text('${filter.label} ($count)'),
            onSelected: (_) {
              setState(() => _activeFilter = filter);
            },
            selectedColor: theme.colorScheme.primaryContainer,
            checkmarkColor: theme.colorScheme.primary,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPatientTable(ThemeData theme) {
    final filtered = _filteredPatients;

    if (filtered.isEmpty) {
      return _buildEmptyFilterState(theme);
    }

    return Card(
      child: SingleChildScrollView(
        child: SizedBox(
          width: double.infinity,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(
              theme.colorScheme.surfaceContainerHighest,
            ),
            columns: const [
              DataColumn(label: Text('Patient ID')),
              DataColumn(label: Text('Site')),
              DataColumn(label: Text('Mobile Linking')),
              DataColumn(label: Text('Actions')),
            ],
            rows: filtered
                .map((patient) => _buildPatientRow(patient, theme))
                .toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyFilterState(ThemeData theme) {
    final hasPatients = _patients != null && _patients!.isNotEmpty;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasPatients ? Icons.filter_list_off : Icons.person_outline,
            size: 64,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            hasPatients ? 'No Matching Patients' : 'No Patients Available',
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            hasPatients
                ? 'Try adjusting your search or filter criteria.'
                : 'Patients will appear here once synced from the EDC system.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  DataRow _buildPatientRow(_PatientData patient, ThemeData theme) {
    return DataRow(
      cells: [
        // Patient ID
        DataCell(
          Text(
            patient.patientId,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        // Site
        DataCell(Text('${patient.siteNumber} - ${patient.siteName}')),
        // Mobile Linking Status
        DataCell(_buildLinkingStatusChip(patient.mobileLinkingStatus, theme)),
        // Actions
        DataCell(_buildActionButton(patient, theme)),
      ],
    );
  }

  Widget _buildLinkingStatusChip(String status, ThemeData theme) {
    final (label, color, icon) = switch (status) {
      'connected' => (
        'Connected',
        theme.colorScheme.primary,
        Icons.check_circle,
      ),
      'linking_in_progress' => (
        'Pending',
        theme.colorScheme.tertiary,
        Icons.hourglass_top,
      ),
      'disconnected' => (
        'Disconnected',
        theme.colorScheme.error,
        Icons.link_off,
      ),
      'not_participating' => (
        'Not Participating',
        theme.colorScheme.outline,
        Icons.person_off,
      ),
      _ => (
        'Not Connected',
        theme.colorScheme.outline,
        Icons.remove_circle_outline,
      ),
    };

    return Chip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(label, style: TextStyle(fontSize: 12, color: color)),
      side: BorderSide(color: color.withValues(alpha: 0.3)),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildActionButton(_PatientData patient, ThemeData theme) {
    final authService = context.read<AuthService>();
    final apiClient = ApiClient(authService);

    switch (patient.mobileLinkingStatus) {
      case 'not_connected':
        return TextButton.icon(
          onPressed: () => _linkPatient(patient, apiClient),
          icon: const Icon(Icons.link, size: 16),
          label: const Text('Link Patient'),
          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
        );
      case 'linking_in_progress':
        return TextButton.icon(
          onPressed: () => _showLinkingCode(patient, apiClient),
          icon: const Icon(Icons.qr_code, size: 16),
          label: const Text('Show Code'),
          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
        );
      case 'connected':
        // REQ-CAL-p00073: Connected patients can only be disconnected.
        // Code regeneration is NOT available for connected patients.
        return TextButton.icon(
          onPressed: () => _disconnectPatient(patient, apiClient),
          icon: Icon(Icons.link_off, size: 16, color: theme.colorScheme.error),
          label: Text(
            'Disconnect',
            style: TextStyle(color: theme.colorScheme.error),
          ),
          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
        );
      case 'disconnected':
        return TextButton.icon(
          onPressed: () => _openPatientActions(patient, apiClient),
          icon: const Icon(Icons.more_horiz, size: 16),
          label: const Text('Actions'),
          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
        );
      case 'not_participating':
        return TextButton.icon(
          onPressed: () => _reactivatePatient(patient, apiClient),
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Reactivate'),
          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  /// Opens the LinkPatientDialog to generate a new linking code
  Future<void> _linkPatient(_PatientData patient, ApiClient apiClient) async {
    final success = await LinkPatientDialog.show(
      context: context,
      patientId: patient.patientId,
      patientDisplayId: patient.edcSubjectKey,
      apiClient: apiClient,
    );

    // Refresh the patient list if a code was generated
    if (success && mounted) {
      await _loadPatients();
    }
  }

  /// Opens the ShowLinkingCodeDialog to display an existing code
  Future<void> _showLinkingCode(
    _PatientData patient,
    ApiClient apiClient,
  ) async {
    await ShowLinkingCodeDialog.show(
      context: context,
      patientId: patient.patientId,
      patientDisplayId: patient.edcSubjectKey,
      apiClient: apiClient,
    );
  }

  /// Opens the DisconnectPatientDialog to disconnect a patient
  Future<void> _disconnectPatient(
    _PatientData patient,
    ApiClient apiClient,
  ) async {
    final success = await DisconnectPatientDialog.show(
      context: context,
      patientId: patient.patientId,
      patientDisplayId: patient.edcSubjectKey,
      apiClient: apiClient,
    );

    // Refresh the patient list if disconnection was successful
    if (success && mounted) {
      await _loadPatients();
    }
  }

  /// Opens the PatientActionsDialog for disconnected patients
  Future<void> _openPatientActions(
    _PatientData patient,
    ApiClient apiClient,
  ) async {
    final result = await PatientActionsDialog.show(
      context: context,
      patientId: patient.patientId,
      patientDisplayId: patient.edcSubjectKey,
      mobileLinkingStatus: patient.mobileLinkingStatus,
      apiClient: apiClient,
    );

    // Refresh the patient list if an action was taken
    if (result == PatientActionResult.actionTaken && mounted) {
      await _loadPatients();
    }
  }

  /// Opens the ReactivatePatientDialog to reactivate a not_participating patient
  Future<void> _reactivatePatient(
    _PatientData patient,
    ApiClient apiClient,
  ) async {
    final success = await ReactivatePatientDialog.show(
      context: context,
      patientId: patient.patientId,
      patientDisplayId: patient.edcSubjectKey,
      apiClient: apiClient,
    );

    // Refresh the patient list if reactivation was successful
    if (success && mounted) {
      await _loadPatients();
    }
  }
}
