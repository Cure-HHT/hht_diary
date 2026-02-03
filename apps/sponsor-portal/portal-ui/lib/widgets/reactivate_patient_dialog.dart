// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00064: Mark Patient as Not Participating
//   REQ-CAL-p00073: Patient Status Definitions
//
// Dialog for reactivating a patient who was marked as not participating

import 'package:flutter/material.dart';

import '../services/api_client.dart';

/// Dialog states for the reactivate flow
enum _DialogState { confirm, loading, success, error }

/// Dialog for reactivating a patient who was marked as not participating.
///
/// The patient will be moved to "disconnected" status and will need to
/// be reconnected to continue participating.
class ReactivatePatientDialog extends StatefulWidget {
  final String patientId;
  final String patientDisplayId;
  final ApiClient apiClient;

  const ReactivatePatientDialog({
    super.key,
    required this.patientId,
    required this.patientDisplayId,
    required this.apiClient,
  });

  /// Shows the dialog and returns true if the patient was reactivated successfully.
  static Future<bool> show({
    required BuildContext context,
    required String patientId,
    required String patientDisplayId,
    required ApiClient apiClient,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ReactivatePatientDialog(
        patientId: patientId,
        patientDisplayId: patientDisplayId,
        apiClient: apiClient,
      ),
    );
    return result ?? false;
  }

  @override
  State<ReactivatePatientDialog> createState() =>
      _ReactivatePatientDialogState();
}

class _ReactivatePatientDialogState extends State<ReactivatePatientDialog> {
  _DialogState _state = _DialogState.confirm;
  final _reasonController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  bool get _canSubmit => _reasonController.text.trim().isNotEmpty;

  Future<void> _reactivate() async {
    if (!_canSubmit) return;

    setState(() => _state = _DialogState.loading);

    final response = await widget.apiClient.post(
      '/api/v1/portal/patients/${widget.patientId}/reactivate',
      {'reason': _reasonController.text.trim()},
    );

    if (!mounted) return;

    if (response.isSuccess && response.data != null) {
      setState(() {
        _state = _DialogState.success;
      });
    } else {
      setState(() {
        _state = _DialogState.error;
        _error = response.error ?? 'Failed to reactivate patient';
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
            Icon(Icons.refresh, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            const Text('Reactivate Patient'),
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
            const Text('Reactivating...'),
          ],
        );
      case _DialogState.success:
        return Row(
          children: [
            Icon(Icons.check_circle, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            const Text('Patient Reactivated'),
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
                'Reactivate this patient to resume participation:',
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
              const SizedBox(height: 16),

              // Info message
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.tertiaryContainer.withValues(
                    alpha: 0.3,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.tertiary.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: theme.colorScheme.tertiary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'The patient will be moved to "disconnected" status. '
                        'You will need to generate a new linking code to reconnect them.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onTertiaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Reason field (mandatory)
              Text(
                'Reason for reactivation *',
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _reasonController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Enter reason for reactivation...',
                  contentPadding: EdgeInsets.all(12),
                  helperText:
                      'Required - explain why this patient is being reactivated',
                  helperMaxLines: 2,
                ),
                maxLines: 3,
                onChanged: (_) => setState(() {}),
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
              'Patient ${widget.patientDisplayId} has been reactivated.',
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
                  _buildInfoRow(theme, 'New status', 'Disconnected'),
                  const SizedBox(height: 8),
                  _buildInfoRow(theme, 'Reason', _reasonController.text.trim()),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Use the "Reconnect" action to generate a new linking code for this patient.',
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
              _error ?? 'An error occurred while reactivating the patient.',
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
          width: 100,
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
            onPressed: _canSubmit ? _reactivate : null,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Reactivate'),
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
