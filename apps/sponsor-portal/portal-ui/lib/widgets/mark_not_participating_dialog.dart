// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00064: Mark Patient as Not Participating
//   REQ-CAL-p00073: Patient Status Definitions
//
// Confirmation dialog for marking a patient as not participating

import 'package:flutter/material.dart';

import '../services/api_client.dart';

/// Valid reasons for marking a patient as not participating
enum NotParticipatingReason {
  subjectWithdrawal('Subject Withdrawal', 'Patient chose to leave the study'),
  death('Death', 'Patient is deceased'),
  protocolComplete(
    'Protocol treatment/study complete',
    'Patient completed all trial requirements',
  ),
  other('Other', 'Specify reason in notes');

  final String label;
  final String description;
  const NotParticipatingReason(this.label, this.description);
}

/// Dialog states for the mark not participating flow
enum _DialogState { confirm, loading, success, error }

/// Dialog for marking a patient as not participating.
///
/// Shows a confirmation with reason dropdown, then calls the API,
/// and displays the result.
class MarkNotParticipatingDialog extends StatefulWidget {
  final String patientId;
  final String patientDisplayId;
  final ApiClient apiClient;

  const MarkNotParticipatingDialog({
    super.key,
    required this.patientId,
    required this.patientDisplayId,
    required this.apiClient,
  });

  /// Shows the dialog and returns true if the patient was marked successfully.
  static Future<bool> show({
    required BuildContext context,
    required String patientId,
    required String patientDisplayId,
    required ApiClient apiClient,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => MarkNotParticipatingDialog(
        patientId: patientId,
        patientDisplayId: patientDisplayId,
        apiClient: apiClient,
      ),
    );
    return result ?? false;
  }

  @override
  State<MarkNotParticipatingDialog> createState() =>
      _MarkNotParticipatingDialogState();
}

class _MarkNotParticipatingDialogState
    extends State<MarkNotParticipatingDialog> {
  _DialogState _state = _DialogState.confirm;
  NotParticipatingReason? _selectedReason;
  final _notesController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    if (_selectedReason == null) return false;
    if (_selectedReason == NotParticipatingReason.other &&
        _notesController.text.trim().isEmpty) {
      return false;
    }
    return true;
  }

  Future<void> _markNotParticipating() async {
    if (!_canSubmit) return;

    setState(() => _state = _DialogState.loading);

    final response = await widget.apiClient
        .post('/api/v1/portal/patients/${widget.patientId}/not-participating', {
          'reason': _selectedReason!.label,
          if (_notesController.text.trim().isNotEmpty)
            'notes': _notesController.text.trim(),
        });

    if (!mounted) return;

    if (response.isSuccess && response.data != null) {
      setState(() {
        _state = _DialogState.success;
      });
    } else {
      setState(() {
        _state = _DialogState.error;
        _error =
            response.error ?? 'Failed to mark patient as not participating';
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
            Icon(Icons.person_off, color: theme.colorScheme.error),
            const SizedBox(width: 8),
            const Expanded(child: Text('Mark Patient as Not Participating')),
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
            const Text('Updating...'),
          ],
        );
      case _DialogState.success:
        return Row(
          children: [
            Icon(Icons.check_circle, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            const Text('Status Updated'),
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
          width: 450,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Patient ID display
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Text(
                      'Patient ID: ',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
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

              // Warning section
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer.withValues(
                    alpha: 0.2,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.error.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.warning_amber,
                          size: 20,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Warning:',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "This will stop applying sponsor-specific rules to this patient's data. Use this status for patients who have:",
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    _buildBulletPoint(theme, 'Completed the trial'),
                    _buildBulletPoint(theme, 'Withdrawn consent'),
                    _buildBulletPoint(
                      theme,
                      'Been discontinued from the study',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This patient will no longer be considered actively enrolled in the trial.',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'All historical data will be preserved.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Reason dropdown
              Text('Reason *', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              DropdownButtonFormField<NotParticipatingReason>(
                // ignore: deprecated_member_use
                value: _selectedReason,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Select a reason',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                items: NotParticipatingReason.values.map((reason) {
                  return DropdownMenuItem(
                    value: reason,
                    child: Text(reason.label),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedReason = value);
                },
              ),

              // Notes field (required for "Other")
              if (_selectedReason == NotParticipatingReason.other) ...[
                const SizedBox(height: 16),
                Text('Additional notes *', style: theme.textTheme.labelLarge),
                const SizedBox(height: 8),
                TextField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Enter details...',
                    contentPadding: EdgeInsets.all(12),
                    helperText: 'Required when reason is "Other"',
                  ),
                  maxLines: 3,
                  onChanged: (_) => setState(() {}),
                ),
              ],
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
              'Patient ${widget.patientDisplayId} has been marked as not participating.',
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
                  if (_notesController.text.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildInfoRow(theme, 'Notes', _notesController.text.trim()),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Sponsor-specific rules will no longer be applied to this patient. '
              'To re-enroll them, use the "Reactivate" action.',
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
              _error ?? 'An error occurred.',
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

  Widget _buildBulletPoint(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('\u2022 ', style: theme.textTheme.bodySmall),
          Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(ThemeData theme, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
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
            onPressed: _canSubmit ? _markNotParticipating : null,
            icon: const Icon(Icons.person_off, size: 18),
            label: const Text('Mark as Not Participating'),
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
