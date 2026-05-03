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
      '/api/v1/portal/patients/link-code',
      {'patientId': widget.patientId},
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
            const Text('Link Participant'),
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
              'Generate a linking code for participant:',
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
              'The participant will use this code to connect their mobile app. '
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
              'Participant: ${widget.patientDisplayId}',
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
              'Share this code with the participant to connect their mobile app.',
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

  /// When true, displays the Participant Linking Code (previously used code,
  /// for reference/troubleshooting only — GUI-CAL-p00001-I).
  /// When false (default), displays the live Mobile Linking Code with expiry
  /// countdown and generate option (GUI-CAL-p00001-G).
  final bool isReference;

  const ShowLinkingCodeDialog({
    super.key,
    required this.patientId,
    required this.patientDisplayId,
    required this.apiClient,
    this.isReference = false,
  });

  /// Shows the dialog.
  static Future<void> show({
    required BuildContext context,
    required String patientId,
    required String patientDisplayId,
    required ApiClient apiClient,
    bool isReference = false,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (context) => ShowLinkingCodeDialog(
        patientId: patientId,
        patientDisplayId: patientDisplayId,
        apiClient: apiClient,
        isReference: isReference,
      ),
    );
  }

  @override
  State<ShowLinkingCodeDialog> createState() => _ShowLinkingCodeDialogState();
}

class _ShowLinkingCodeDialogState extends State<ShowLinkingCodeDialog> {
  bool _isLoading = true;
  bool _isGenerating = false;
  bool _hasActiveCode = false;
  String? _code;
  String? _expiresAt;
  String? _usedCode;
  String? _usedAt;
  String? _error;
  String? _generateError;

  @override
  void initState() {
    super.initState();
    _fetchCode();
  }

  Future<void> _fetchCode() async {
    final response = await widget.apiClient.get(
      '/api/v1/portal/patients/link-code/active',
      extraHeaders: {'X-Patient-Id': widget.patientId},
    );

    if (!mounted) return;

    if (response.isSuccess && response.data != null) {
      final data = response.data as Map<String, dynamic>;
      setState(() {
        _isLoading = false;
        _hasActiveCode = data['has_active_code'] as bool? ?? false;
        _code = data['code'] as String?;
        _expiresAt = data['expires_at'] as String?;
        _usedCode = data['used_code'] as String?;
        _usedAt = data['used_at'] as String?;
      });
    } else {
      setState(() {
        _isLoading = false;
        _error = response.error ?? 'Failed to fetch linking code';
      });
    }
  }

  Future<void> _generateNewCode() async {
    setState(() {
      _isGenerating = true;
      _generateError = null;
    });

    final response = await widget.apiClient.post(
      '/api/v1/portal/patients/link-code',
      {'patientId': widget.patientId},
    );

    if (!mounted) return;

    if (response.isSuccess && response.data != null) {
      final data = response.data as Map<String, dynamic>;
      setState(() {
        _isGenerating = false;
        _hasActiveCode = true;
        _code = data['code'] as String?;
        _expiresAt = data['expires_at'] as String?;
        _generateError = null;
      });
    } else {
      setState(() {
        _isGenerating = false;
        _generateError = response.error ?? 'Failed to generate linking code';
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
          Text(
            widget.isReference ? 'Participant Linking Code' : 'Linking Code',
          ),
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
      // CUR-1069: Reference mode — show the previously used code if available.
      // For non-pending statuses the active code was consumed; the used code
      // is stored in patient_linking_codes.code and returned by the server.
      if (widget.isReference && _usedCode != null) {
        return _buildReferenceCodeDisplay(theme, _usedCode!, _usedAt);
      }

      // Reference mode with no record at all (edge case: never linked)
      if (widget.isReference) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline,
              color: theme.colorScheme.outline,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'No linking code on record',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'No linking code has been recorded for this patient.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        );
      }

      // Live mode (pending) — offer generate option
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: theme.colorScheme.outline, size: 48),
          const SizedBox(height: 16),
          Text('No Active Linking Code', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'This participant does not have an active linking code. '
            'The previous code may have expired or been used.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _isGenerating ? null : _generateNewCode,
            icon: _isGenerating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh, size: 18),
            label: Text(_isGenerating ? 'Generating...' : 'Generate New Code'),
          ),
          if (_generateError != null) ...[
            const SizedBox(height: 8),
            Text(
              _generateError!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ],
      );
    }

    // Active code display (live mode: with expiry; reference mode: code only)
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Participant: ${widget.patientDisplayId}',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        if (_code != null)
          ActivationCodeDisplay(
            code: _code!,
            label: widget.isReference
                ? 'Participant Linking Code'
                : 'Linking Code',
            fontSize: 20,
          ),
        if (!widget.isReference) ...[
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
      ],
    );
  }

  /// Displays a previously used linking code in reference-only mode.
  Widget _buildReferenceCodeDisplay(
    ThemeData theme,
    String code,
    String? usedAt,
  ) {
    String usedAtLabel = 'Previously used';
    if (usedAt != null) {
      try {
        final dt = DateTime.parse(usedAt).toLocal();
        usedAtLabel =
            'Used on ${dt.day}/${dt.month}/${dt.year} at '
            '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } catch (_) {}
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Participant: ${widget.patientDisplayId}',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        ActivationCodeDisplay(
          code: code,
          label: 'Participant Linking Code',
          fontSize: 20,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Reference only — $usedAtLabel. '
                  'This code cannot be used to establish a new connection.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
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
