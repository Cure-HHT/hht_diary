// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00019: Link New Patient Workflow
//   REQ-CAL-p00049: Mobile Linking Codes
//   REQ-CAL-p00073: Patient Status Definitions
//   REQ-p70007: Linking Code Lifecycle Management
//
// Dialog for generating patient linking codes

import 'package:flutter/material.dart';

import '../services/api_client.dart';
import 'activation_code_display.dart';

/// Dialog states for the linking flow
enum _DialogState { confirm, loading, success, error }

/// Dialog for generating a patient linking code.
///
/// Shows a confirmation prompt, then generates a linking code via API,
/// and displays the code with copy functionality.
///
/// Usage:
/// ```dart
/// await LinkPatientDialog.show(
///   context: context,
///   patientId: patient.patientId,
///   patientDisplayId: patient.edcSubjectKey,
///   apiClient: apiClient,
/// );
/// ```
class LinkPatientDialog extends StatefulWidget {
  final String patientId;
  final String patientDisplayId;
  final ApiClient apiClient;

  const LinkPatientDialog({
    super.key,
    required this.patientId,
    required this.patientDisplayId,
    required this.apiClient,
  });

  /// Shows the dialog and returns true if a code was generated successfully.
  static Future<bool> show({
    required BuildContext context,
    required String patientId,
    required String patientDisplayId,
    required ApiClient apiClient,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => LinkPatientDialog(
        patientId: patientId,
        patientDisplayId: patientDisplayId,
        apiClient: apiClient,
      ),
    );
    return result ?? false;
  }

  @override
  State<LinkPatientDialog> createState() => _LinkPatientDialogState();
}

class _LinkPatientDialogState extends State<LinkPatientDialog> {
  _DialogState _state = _DialogState.confirm;
  String? _code;
  String? _expiresAt;
  String? _siteName;
  String? _error;

  Future<void> _generateCode() async {
    setState(() => _state = _DialogState.loading);

    final response = await widget.apiClient.post(
      '/api/v1/portal/patients/${widget.patientId}/link-code',
      {}, // Empty body - no request payload needed
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
        _error = response.error ?? 'Failed to generate linking code';
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
            const Text('Link Patient'),
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
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Generate a linking code for patient:',
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
            Text(
              'The patient will use this code to connect their mobile app. '
              'The code expires after 72 hours.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
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
              'Share this code with the patient to connect their mobile app.',
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
              _error ?? 'An error occurred while generating the linking code.',
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
            onPressed: _generateCode,
            icon: const Icon(Icons.link, size: 18),
            label: const Text('Generate Code'),
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

/// Dialog for showing an existing patient linking code.
///
/// Fetches the active linking code for a patient and displays it.
class ShowLinkingCodeDialog extends StatefulWidget {
  final String patientId;
  final String patientDisplayId;
  final ApiClient apiClient;

  const ShowLinkingCodeDialog({
    super.key,
    required this.patientId,
    required this.patientDisplayId,
    required this.apiClient,
  });

  /// Shows the dialog.
  static Future<void> show({
    required BuildContext context,
    required String patientId,
    required String patientDisplayId,
    required ApiClient apiClient,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (context) => ShowLinkingCodeDialog(
        patientId: patientId,
        patientDisplayId: patientDisplayId,
        apiClient: apiClient,
      ),
    );
  }

  @override
  State<ShowLinkingCodeDialog> createState() => _ShowLinkingCodeDialogState();
}

class _ShowLinkingCodeDialogState extends State<ShowLinkingCodeDialog> {
  bool _isLoading = true;
  bool _hasActiveCode = false;
  String? _code;
  String? _expiresAt;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchCode();
  }

  Future<void> _fetchCode() async {
    final response = await widget.apiClient.get(
      '/api/v1/portal/patients/${widget.patientId}/link-code',
    );

    if (!mounted) return;

    if (response.isSuccess && response.data != null) {
      final data = response.data as Map<String, dynamic>;
      setState(() {
        _isLoading = false;
        _hasActiveCode = data['has_active_code'] as bool? ?? false;
        _code = data['code'] as String?;
        _expiresAt = data['expires_at'] as String?;
      });
    } else {
      setState(() {
        _isLoading = false;
        _error = response.error ?? 'Failed to fetch linking code';
      });
    }
  }

  String _formatExpiresAt(String? expiresAt) {
    if (expiresAt == null) return 'Unknown';
    try {
      final expiry = DateTime.parse(expiresAt);
      final now = DateTime.now();
      final diff = expiry.difference(now);
      if (diff.isNegative) return 'Expired';
      if (diff.inHours >= 24) {
        final days = diff.inDays;
        final hours = diff.inHours % 24;
        if (hours > 0) {
          return '$days day${days > 1 ? 's' : ''}, $hours hour${hours > 1 ? 's' : ''}';
        }
        return '$days day${days > 1 ? 's' : ''}';
      }
      if (diff.inHours > 0) {
        return '${diff.inHours} hour${diff.inHours > 1 ? 's' : ''}';
      }
      return '${diff.inMinutes} minute${diff.inMinutes > 1 ? 's' : ''}';
    } catch (_) {
      return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.qr_code, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          const Text('Linking Code'),
        ],
      ),
      content: _buildContent(theme),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildContent(ThemeData theme) {
    if (_isLoading) {
      return const SizedBox(
        width: 300,
        height: 100,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error, color: theme.colorScheme.error, size: 48),
          const SizedBox(height: 16),
          Text(
            _error!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
      );
    }

    if (!_hasActiveCode) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: theme.colorScheme.outline, size: 48),
          const SizedBox(height: 16),
          Text('No Active Linking Code', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'This patient does not have an active linking code. '
            'The previous code may have expired or been used.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Patient: ${widget.patientDisplayId}',
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
            color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.colorScheme.tertiary.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.timer, size: 18, color: theme.colorScheme.tertiary),
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
      ],
    );
  }
}
