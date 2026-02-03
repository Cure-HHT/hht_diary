// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00021: Patient Reconnection Workflow
//   REQ-CAL-p00066: Status Change Reason Field
//   REQ-CAL-p00073: Patient Status Definitions
//
// Dialog for reconnecting disconnected patients to the mobile app

import 'package:flutter/material.dart';

import '../services/api_client.dart';
import 'activation_code_display.dart';

/// Dialog states for the reconnect flow
enum _DialogState { confirm, loading, success, error }

/// Dialog for reconnecting a disconnected patient to the mobile app.
///
/// Shows a confirmation prompt with mandatory reason field, generates a new
/// linking code, and displays the code with copy functionality.
///
/// Usage:
/// ```dart
/// final success = await ReconnectPatientDialog.show(
///   context: context,
///   patientId: patient.patientId,
///   patientDisplayId: patient.edcSubjectKey,
///   apiClient: apiClient,
/// );
/// ```
class ReconnectPatientDialog extends StatefulWidget {
  final String patientId;
  final String patientDisplayId;
  final ApiClient apiClient;

  const ReconnectPatientDialog({
    super.key,
    required this.patientId,
    required this.patientDisplayId,
    required this.apiClient,
  });

  /// Shows the dialog and returns true if reconnection was successful.
  static Future<bool> show({
    required BuildContext context,
    required String patientId,
    required String patientDisplayId,
    required ApiClient apiClient,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ReconnectPatientDialog(
        patientId: patientId,
        patientDisplayId: patientDisplayId,
        apiClient: apiClient,
      ),
    );
    return result ?? false;
  }

  @override
  State<ReconnectPatientDialog> createState() => _ReconnectPatientDialogState();
}

class _ReconnectPatientDialogState extends State<ReconnectPatientDialog> {
  _DialogState _state = _DialogState.confirm;
  final _reasonController = TextEditingController();
  String? _code;
  String? _expiresAt;
  String? _siteName;
  String? _error;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  bool get _canSubmit => _reasonController.text.trim().isNotEmpty;

  Future<void> _reconnect() async {
    if (!_canSubmit) return;

    setState(() => _state = _DialogState.loading);

    final response = await widget.apiClient.post(
      '/api/v1/portal/patients/${widget.patientId}/link-code',
      {'reconnect_reason': _reasonController.text.trim()},
    );

    if (!mounted) return;

    if (response.isSuccess && response.data != null) {
      final data = response.data as Map<String, dynamic>;
      setState(() {
        _state = _DialogState.success;
        _code = data['code'] as String?;
        _expiresAt = data['expires_at'] as String?;
        _siteName = data['site_name'] as String?;
      });
    } else {
      setState(() {
        _state = _DialogState.error;
        _error = response.error ?? 'Failed to reconnect patient';
      });
    }
  }

  String _formatExpiresAt(String? expiresAt) {
    if (expiresAt == null) return '72 hours';
    try {
      final expiry = DateTime.parse(expiresAt);
      final now = DateTime.now();
      final diff = expiry.difference(now);
      if (diff.inHours >= 24) {
        final days = diff.inDays;
        final hours = diff.inHours % 24;
        if (hours > 0) {
          return '$days day${days > 1 ? 's' : ''}, $hours hour${hours > 1 ? 's' : ''}';
        }
        return '$days day${days > 1 ? 's' : ''}';
      }
      return '${diff.inHours} hour${diff.inHours > 1 ? 's' : ''}';
    } catch (_) {
      return '72 hours';
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
            Icon(Icons.link, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            const Text('Reconnect Patient'),
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
            const Text('Generating Code...'),
          ],
        );
      case _DialogState.success:
        return Row(
          children: [
            Icon(Icons.check_circle, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            const Text('Linking Code Generated'),
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
                'Reconnect this disconnected patient to the mobile app:',
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

              // Reason field (mandatory)
              Text(
                'Reason for reconnection *',
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _reasonController,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  hintText: 'Enter reason for reconnection...',
                  contentPadding: const EdgeInsets.all(12),
                  helperText:
                      'Required - explain why this patient is being reconnected',
                  helperMaxLines: 2,
                  errorText: _reasonController.text.isEmpty ? null : null,
                ),
                maxLines: 3,
                onChanged: (_) => setState(() {}),
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
                        'A new linking code will be generated. The patient will use this code to reconnect their mobile app.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onTertiaryContainer,
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
            if (_siteName != null) ...[
              Text(
                'Site: $_siteName',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
            ],
            Text(
              'Patient: ${widget.patientDisplayId}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Reason: ${_reasonController.text.trim()}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (_code != null)
              ActivationCodeDisplay(
                code: _code!,
                label: 'Linking Code',
                fontSize: 20,
              ),
            const SizedBox(height: 16),
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
                    Icons.timer,
                    size: 18,
                    color: theme.colorScheme.tertiary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Expires in ${_formatExpiresAt(_expiresAt)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onTertiaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Share this code with the patient to reconnect their mobile app.',
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
              _error ?? 'An error occurred while reconnecting the patient.',
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

  List<Widget> _buildActions(ThemeData theme) {
    switch (_state) {
      case _DialogState.confirm:
        return [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: _canSubmit ? _reconnect : null,
            icon: const Icon(Icons.link, size: 18),
            label: const Text('Reconnect'),
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
