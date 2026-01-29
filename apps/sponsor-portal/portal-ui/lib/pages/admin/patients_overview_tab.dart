// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00063: EDC Patient Ingestion
//   REQ-CAL-p00073: Patient Status Definitions
//
// Patients tab for Admin Dashboard - displays patients synced from EDC (RAVE)

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../services/api_client.dart';
import '../../services/auth_service.dart';

/// Model for a patient synced from EDC
class Patient {
  final String patientId;
  final String siteId;
  final String edcSubjectKey;
  final String mobileLinkingStatus;
  final DateTime? edcSyncedAt;
  final String siteName;
  final String siteNumber;

  Patient({
    required this.patientId,
    required this.siteId,
    required this.edcSubjectKey,
    required this.mobileLinkingStatus,
    this.edcSyncedAt,
    required this.siteName,
    required this.siteNumber,
  });

  factory Patient.fromJson(Map<String, dynamic> json) {
    return Patient(
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
}

/// Patients tab widget for Admin Dashboard
class PatientsTab extends StatefulWidget {
  const PatientsTab({super.key});

  @override
  State<PatientsTab> createState() => _PatientsTabState();
}

class _PatientsTabState extends State<PatientsTab> {
  List<Patient>? _patients;
  Map<String, dynamic>? _syncInfo;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  Future<void> _loadPatients() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final authService = context.read<AuthService>();
    final apiClient = ApiClient(authService);

    final response = await apiClient.get('/api/v1/portal/patients');

    if (!mounted) return;

    if (response.isSuccess && response.data != null) {
      final data = response.data as Map<String, dynamic>;
      final patientsJson = data['patients'] as List<dynamic>? ?? [];
      final patients = patientsJson
          .map((p) => Patient.fromJson(p as Map<String, dynamic>))
          .toList();

      setState(() {
        _patients = patients;
        _syncInfo = data['sync'] as Map<String, dynamic>?;
        _isLoading = false;
      });
    } else {
      setState(() {
        _error = response.error ?? 'Failed to load patients';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'Error loading patients',
              style: theme.textTheme.headlineSmall,
            ),
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

    final patients = _patients ?? [];

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with sync info
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Patients',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Patients synced from Medidata RAVE EDC',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (_syncInfo != null) _buildSyncChip(theme),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _loadPatients,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh patients',
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Patients table
          if (patients.isEmpty)
            _buildEmptyState(theme)
          else
            Expanded(
              child: Card(
                child: SingleChildScrollView(
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(
                      theme.colorScheme.surfaceContainerHighest,
                    ),
                    columns: const [
                      DataColumn(label: Text('Patient ID')),
                      DataColumn(label: Text('Site')),
                      DataColumn(label: Text('Linking Status')),
                      DataColumn(label: Text('Last Synced')),
                    ],
                    rows: patients
                        .map((patient) => _buildPatientRow(patient, theme))
                        .toList(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSyncChip(ThemeData theme) {
    final syncInfo = _syncInfo!;
    final hasError = syncInfo['error'] != null;
    final created = syncInfo['patients_created'] as int? ?? 0;
    final updated = syncInfo['patients_updated'] as int? ?? 0;

    if (hasError) {
      return Tooltip(
        message: syncInfo['error'] as String,
        child: Chip(
          avatar: Icon(
            Icons.warning_amber,
            size: 18,
            color: theme.colorScheme.error,
          ),
          label: const Text('Sync warning'),
          backgroundColor: theme.colorScheme.errorContainer,
        ),
      );
    }

    if (created > 0 || updated > 0) {
      return Chip(
        avatar: Icon(
          Icons.check_circle,
          size: 18,
          color: theme.colorScheme.primary,
        ),
        label: Text('Synced: $created new, $updated updated'),
        backgroundColor: theme.colorScheme.primaryContainer,
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_outline,
              size: 64,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text('No Patients Available', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Patients will appear here once synced from the EDC system.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (_syncInfo?['error'] != null) ...[
              const SizedBox(height: 16),
              Text(
                'Sync error: ${_syncInfo!['error']}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  DataRow _buildPatientRow(Patient patient, ThemeData theme) {
    final dateFormat = DateFormat('MMM d, yyyy h:mm a');

    return DataRow(
      cells: [
        DataCell(
          Text(
            patient.patientId,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        DataCell(Text('${patient.siteNumber} - ${patient.siteName}')),
        DataCell(_buildLinkingStatusChip(patient.mobileLinkingStatus, theme)),
        DataCell(
          Text(
            patient.edcSyncedAt != null
                ? dateFormat.format(patient.edcSyncedAt!.toLocal())
                : 'Never',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }

  Widget _buildLinkingStatusChip(String status, ThemeData theme) {
    final (label, color, icon) = switch (status) {
      'connected' => ('Connected', theme.colorScheme.primary, Icons.link),
      'linking_in_progress' => (
        'Linking...',
        theme.colorScheme.tertiary,
        Icons.hourglass_top,
      ),
      'disconnected' => (
        'Disconnected',
        theme.colorScheme.error,
        Icons.link_off,
      ),
      _ => (
        'Not Connected',
        theme.colorScheme.outline,
        Icons.phone_android_outlined,
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
}
