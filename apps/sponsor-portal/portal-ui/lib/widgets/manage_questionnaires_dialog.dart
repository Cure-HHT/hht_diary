// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00023: Nose and Quality of Life Questionnaire Workflow
//   REQ-CAL-p00066: Status Change Reason Field
//
// Dialog for managing questionnaire status and actions for a patient.
// Shows Nose HHT and QoL rows with status chips and contextual actions.

import 'package:flutter/material.dart';

import '../services/api_client.dart';

/// Data model for a questionnaire row in the dialog
class _QuestionnaireInfo {
  final String? id;
  final String type;
  final String status;

  _QuestionnaireInfo({this.id, required this.type, required this.status});
}

/// Dialog for managing questionnaires for a patient.
///
/// Shows Nose HHT and QoL questionnaire rows with status chips and
/// contextual action buttons (Send, Revoke, Unlock, Finalize).
///
/// Usage:
/// ```dart
/// await ManageQuestionnairesDialog.show(
///   context: context,
///   patientId: patient.patientId,
///   patientDisplayId: patient.edcSubjectKey,
///   apiClient: apiClient,
/// );
/// ```
class ManageQuestionnairesDialog extends StatefulWidget {
  final String patientId;
  final String patientDisplayId;
  final ApiClient apiClient;

  const ManageQuestionnairesDialog({
    super.key,
    required this.patientId,
    required this.patientDisplayId,
    required this.apiClient,
  });

  /// Shows the dialog. Returns when the dialog is closed.
  static Future<void> show({
    required BuildContext context,
    required String patientId,
    required String patientDisplayId,
    required ApiClient apiClient,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => ManageQuestionnairesDialog(
        patientId: patientId,
        patientDisplayId: patientDisplayId,
        apiClient: apiClient,
      ),
    );
  }

  @override
  State<ManageQuestionnairesDialog> createState() =>
      _ManageQuestionnairesDialogState();
}

enum _DialogState { loading, loaded, error }

class _ManageQuestionnairesDialogState
    extends State<ManageQuestionnairesDialog> {
  _DialogState _state = _DialogState.loading;
  List<_QuestionnaireInfo> _questionnaires = [];
  String? _error;
  bool _actionInProgress = false;

  @override
  void initState() {
    super.initState();
    _loadQuestionnaires();
  }

  Future<void> _loadQuestionnaires() async {
    setState(() {
      _state = _DialogState.loading;
      _error = null;
    });

    final response = await widget.apiClient.get(
      '/api/v1/portal/patients/${widget.patientId}/questionnaires',
    );

    if (!mounted) return;

    if (response.isSuccess && response.data != null) {
      final data = response.data as Map<String, dynamic>;
      final list = data['questionnaires'] as List<dynamic>? ?? [];

      final questionnaires = <_QuestionnaireInfo>[];
      for (final item in list) {
        final map = item as Map<String, dynamic>;
        final type = map['questionnaire_type'] as String;
        // Filter out EQ — managed via Start Trial separately
        if (type == 'eq') continue;
        questionnaires.add(
          _QuestionnaireInfo(
            id: map['id'] as String?,
            type: type,
            status: map['status'] as String? ?? 'not_sent',
          ),
        );
      }

      setState(() {
        _questionnaires = questionnaires;
        _state = _DialogState.loaded;
      });
    } else {
      setState(() {
        _error = response.error ?? 'Failed to load questionnaires';
        _state = _DialogState.error;
      });
    }
  }

  String _displayName(String type) {
    switch (type) {
      case 'nose_hht':
        return 'Nose HHT';
      case 'qol':
        return 'QoL';
      default:
        return type;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'not_sent':
        return 'Not Sent';
      case 'sent':
        return 'Sent';
      case 'in_progress':
        return 'In Progress';
      case 'ready_to_review':
        return 'Ready to Review';
      case 'finalized':
        return 'Finalized';
      default:
        return status;
    }
  }

  Color _statusColor(String status, ThemeData theme) {
    switch (status) {
      case 'not_sent':
        return theme.colorScheme.outline;
      case 'sent':
        return Colors.blue;
      case 'in_progress':
        return Colors.amber.shade700;
      case 'ready_to_review':
        return Colors.orange;
      case 'finalized':
        return Colors.green;
      default:
        return theme.colorScheme.outline;
    }
  }

  Future<void> _sendQuestionnaire(String type) async {
    setState(() => _actionInProgress = true);

    final response = await widget.apiClient.post(
      '/api/v1/portal/patients/${widget.patientId}/questionnaires/$type/send',
      {},
    );

    if (!mounted) return;

    if (response.isSuccess) {
      await _loadQuestionnaires();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response.error ?? 'Failed to send questionnaire'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }

    if (mounted) setState(() => _actionInProgress = false);
  }

  Future<void> _revokeQuestionnaire(_QuestionnaireInfo q) async {
    final confirmed = await _showRevokeConfirmation(q);
    if (confirmed != true || !mounted) return;

    setState(() => _actionInProgress = true);

    final response = await widget.apiClient.delete(
      '/api/v1/portal/patients/${widget.patientId}/questionnaires/${q.id}',
      body: {'reason': 'Revoked by investigator'},
    );

    if (!mounted) return;

    if (response.isSuccess) {
      await _loadQuestionnaires();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response.error ?? 'Failed to revoke questionnaire'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }

    if (mounted) setState(() => _actionInProgress = false);
  }

  Future<bool?> _showRevokeConfirmation(_QuestionnaireInfo q) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          title: const Text('Revoke Questionnaire?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This will remove the ${_displayName(q.type)} questionnaire '
                'from the patient\'s mobile app.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
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
                      color: theme.colorScheme.error,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Any in-progress answers will be lost.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
              ),
              child: const Text('Revoke Questionnaire'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _unlockQuestionnaire(_QuestionnaireInfo q) async {
    setState(() => _actionInProgress = true);

    final response = await widget.apiClient.post(
      '/api/v1/portal/patients/${widget.patientId}/questionnaires/${q.id}/unlock',
      {},
    );

    if (!mounted) return;

    if (response.isSuccess) {
      await _loadQuestionnaires();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response.error ?? 'Failed to unlock questionnaire'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }

    if (mounted) setState(() => _actionInProgress = false);
  }

  Future<void> _finalizeQuestionnaire(_QuestionnaireInfo q) async {
    final confirmed = await _showFinalizeConfirmation(q);
    if (confirmed != true || !mounted) return;

    setState(() => _actionInProgress = true);

    final response = await widget.apiClient.post(
      '/api/v1/portal/patients/${widget.patientId}/questionnaires/${q.id}/finalize',
      {},
    );

    if (!mounted) return;

    if (response.isSuccess) {
      await _loadQuestionnaires();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response.error ?? 'Failed to finalize questionnaire'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }

    if (mounted) setState(() => _actionInProgress = false);
  }

  Future<bool?> _showFinalizeConfirmation(_QuestionnaireInfo q) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          title: const Text('Finalize Questionnaire?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Finalizing the ${_displayName(q.type)} questionnaire will:',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              _buildBulletPoint('Mark the questionnaire as finalized'),
              const SizedBox(height: 4),
              _buildBulletPoint('Calculate the questionnaire score'),
              const SizedBox(height: 4),
              _buildBulletPoint(
                'Change status back to "Not Sent" for the next cycle',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Finalize Questionnaire'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBulletPoint(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('  \u2022  '),
        Expanded(child: Text(text)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Manage Questionnaires'),
                const SizedBox(height: 4),
                Text(
                  'Manage questionnaire status and actions for patient '
                  '${widget.patientDisplayId}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
            tooltip: 'Close',
          ),
        ],
      ),
      content: SizedBox(width: 520, child: _buildContent(theme)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildContent(ThemeData theme) {
    switch (_state) {
      case _DialogState.loading:
        return const SizedBox(
          height: 120,
          child: Center(child: CircularProgressIndicator()),
        );

      case _DialogState.error:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Failed to load questionnaires',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _loadQuestionnaires,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        );

      case _DialogState.loaded:
        return _buildLoadedContent(theme);
    }
  }

  Widget _buildLoadedContent(ThemeData theme) {
    final allNotSent = _questionnaires.every((q) => q.status == 'not_sent');

    return Stack(
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (allNotSent)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'No questionnaires have been sent yet.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            DataTable(
              headingRowColor: WidgetStateProperty.all(
                theme.colorScheme.surfaceContainerHighest,
              ),
              columns: const [
                DataColumn(label: Text('Questionnaire')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Actions')),
              ],
              rows: _questionnaires
                  .map((q) => _buildQuestionnaireRow(q, theme))
                  .toList(),
            ),
          ],
        ),
        if (_actionInProgress)
          Positioned.fill(
            child: Container(
              color: theme.colorScheme.surface.withValues(alpha: 0.7),
              child: const Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }

  DataRow _buildQuestionnaireRow(_QuestionnaireInfo q, ThemeData theme) {
    final color = _statusColor(q.status, theme);

    return DataRow(
      cells: [
        DataCell(
          Text(
            _displayName(q.type),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        DataCell(
          Chip(
            label: Text(
              _statusLabel(q.status),
              style: TextStyle(fontSize: 12, color: color),
            ),
            side: BorderSide(color: color.withValues(alpha: 0.3)),
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
        ),
        DataCell(_buildActions(q, theme)),
      ],
    );
  }

  Widget _buildActions(_QuestionnaireInfo q, ThemeData theme) {
    switch (q.status) {
      case 'not_sent':
        return FilledButton(
          onPressed: _actionInProgress
              ? null
              : () => _sendQuestionnaire(q.type),
          style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
          child: const Text('Send'),
        );
      case 'sent':
        return OutlinedButton(
          onPressed: _actionInProgress ? null : () => _revokeQuestionnaire(q),
          style: OutlinedButton.styleFrom(
            foregroundColor: theme.colorScheme.error,
            side: BorderSide(color: theme.colorScheme.error),
            visualDensity: VisualDensity.compact,
          ),
          child: const Text('Revoke'),
        );
      case 'in_progress':
        return Text(
          'Patient is working',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
        );
      case 'ready_to_review':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton(
              onPressed: _actionInProgress
                  ? null
                  : () => _unlockQuestionnaire(q),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('Unlock'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _actionInProgress
                  ? null
                  : () => _finalizeQuestionnaire(q),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green,
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('Finalize'),
            ),
          ],
        );
      case 'finalized':
        return const Icon(Icons.check_circle, color: Colors.green, size: 20);
      default:
        return const SizedBox.shrink();
    }
  }
}
