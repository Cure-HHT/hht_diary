// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00020: Patient Disconnection Workflow
//   REQ-CAL-p00073: Patient Status Definitions
//   REQ-CAL-p00077: Disconnection Notification
//
// Dialog for disconnecting patients from the mobile app

import 'package:flutter/material.dart';

import '../services/api_client.dart';

/// Valid disconnect reasons per CUR-768 specification
enum DisconnectReason {
  deviceIssues('Device Issues', 'Lost, stolen, or damaged device'),
  technicalIssues('Technical Issues', 'App not working, sync problems'),
  other('Other', 'No additional details required');

  final String label;
  final String description;
  const DisconnectReason(this.label, this.description);
}

/// Dialog states for the disconnect flow
enum _DialogState { confirm, loading, success, error }

/// Dialog for disconnecting a patient from the mobile app.
///
/// Shows a confirmation prompt with reason dropdown, then calls the API,
/// and displays the result.
///
/// Usage:
/// ```dart
/// final success = await DisconnectPatientDialog.show(
///   context: context,
///   patientId: patient.patientId,
///   patientDisplayId: patient.edcSubjectKey,
///   apiClient: apiClient,
/// );
/// ```
class DisconnectPatientDialog extends StatefulWidget {
  final String patientId;
  final String patientDisplayId;
  final ApiClient apiClient;
  // REQ-p70010-C: true = predefined dropdown, false = free text field
  final bool useDropdown;

  const DisconnectPatientDialog({
    super.key,
    required this.patientId,
    required this.patientDisplayId,
    required this.apiClient,
    this.useDropdown = true,
  });

  /// Shows the dialog and returns true if the patient was disconnected successfully.
  static Future<bool> show({
    required BuildContext context,
    required String patientId,
    required String patientDisplayId,
    required ApiClient apiClient,
    bool useDropdown = true,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => DisconnectPatientDialog(
        patientId: patientId,
        patientDisplayId: patientDisplayId,
        apiClient: apiClient,
        useDropdown: useDropdown,
      ),
    );
    return result ?? false;
  }

  @override
  State<DisconnectPatientDialog> createState() =>
      _DisconnectPatientDialogState();
}

class _DisconnectPatientDialogState extends State<DisconnectPatientDialog> {
  _DialogState _state = _DialogState.confirm;
  DisconnectReason? _selectedReason;
  final _reasonTextController = TextEditingController();
  String? _error;
  int _codesRevoked = 0;

  bool get _canSubmit => widget.useDropdown
      ? _selectedReason != null
      : _reasonTextController.text.trim().isNotEmpty;

  @override
  void dispose() {
    _reasonTextController.dispose();
    super.dispose();
  }

  Future<void> _disconnect() async {
    if (!_canSubmit) return;

    setState(() => _state = _DialogState.loading);

    final reason = widget.useDropdown
        ? _selectedReason!.label
        : _reasonTextController.text.trim();
    final response = await widget.apiClient.post(
      '/api/v1/portal/patients/disconnect',
      {'patientId': widget.patientId, 'reason': reason},
    );

    if (!mounted) return;

    if (response.isSuccess && response.data != null) {
      final data = response.data as Map<String, dynamic>;
      setState(() {
        _state = _DialogState.success;
        _codesRevoked = data['codes_revoked'] as int? ?? 0;
      });
    } else {
      setState(() {
        _state = _DialogState.error;
        _error = response.error ?? 'Failed to disconnect participant';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: _buildTitle(theme),
      content: _buildContent(theme),
      actions: _buildActions(theme),
    );
  }

  Widget _buildTitle(ThemeData theme) {
    switch (_state) {
      case _DialogState.confirm:
        return Row(
          children: [
            Icon(Icons.link_off, color: theme.colorScheme.error),
            const SizedBox(width: 8),
            const Text('Disconnect Participant'),
          ],
        );
      case _DialogState.loading:
        return Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            const Text('Disconnecting...'),
          ],
        );
      case _DialogState.success:
        return Row(
          children: [
            Icon(Icons.check_circle, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            const Text('Participant Disconnected'),
          ],
        );
      case _DialogState.error:
        return Row(
          children: [
            Icon(Icons.error, color: theme.colorScheme.error),
            const SizedBox(width: 8),
            const Text('Error'),
          ],
        );
    }
  }

  Widget _buildContent(ThemeData theme) {
    switch (_state) {
      case _DialogState.confirm:
        return SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Disconnect this participant from the mobile app:',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.person,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.patientDisplayId,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Reason input — dropdown or free text based on sponsor config
              Text(
                'Reason for disconnection *',
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              if (widget.useDropdown)
                DropdownButtonFormField<DisconnectReason>(
                  initialValue: _selectedReason,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Select a reason',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  items: DisconnectReason.values.map((reason) {
                    return DropdownMenuItem(
                      value: reason,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(reason.label),
                          Text(
                            reason.description,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedReason = value);
                  },
                  selectedItemBuilder: (context) {
                    return DisconnectReason.values.map((reason) {
                      return Text(reason.label);
                    }).toList();
                  },
                )
              else
                TextField(
                  controller: _reasonTextController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Enter reason for disconnection',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  maxLines: 3,
                  onChanged: (_) => setState(() {}),
                ),
              const SizedBox(height: 16),

              // Warning message
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer.withValues(
                    alpha: 0.3,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.error.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber,
                      size: 20,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This will revoke all active linking codes and the participant will see a disconnection notice in their app.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

      case _DialogState.loading:
        return const SizedBox(
          width: 300,
          height: 100,
          child: Center(child: CircularProgressIndicator()),
        );

      case _DialogState.success:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Participant ${widget.patientDisplayId} has been disconnected from the mobile app.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow(theme, 'Reason', _selectedReason?.label ?? '-'),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    theme,
                    'Linking codes revoked',
                    _codesRevoked.toString(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'The participant will see a disconnection notice when they next open the app. '
              'To reconnect, generate a new linking code.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        );

      case _DialogState.error:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _error ??
                  'An error occurred while disconnecting the participant.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Please try again or contact support if the problem persists.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        );
    }
  }

  Widget _buildInfoRow(ThemeData theme, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildActions(ThemeData theme) {
    switch (_state) {
      case _DialogState.confirm:
        return [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: _canSubmit ? _disconnect : null,
            icon: const Icon(Icons.link_off, size: 18),
            label: const Text('Disconnect'),
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
          ),
        ];

      case _DialogState.loading:
        return []; // No actions while loading

      case _DialogState.success:
        return [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Done'),
          ),
        ];

      case _DialogState.error:
        return [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => setState(() => _state = _DialogState.confirm),
            child: const Text('Try Again'),
          ),
        ];
    }
  }
}
