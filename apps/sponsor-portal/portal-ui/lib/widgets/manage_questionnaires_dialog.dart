// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00023: Nose and Quality of Life Questionnaire Workflow
//   REQ-CAL-p00066: Status Change Reason Field
//   REQ-CAL-p00080: Questionnaire Study Event Association
//
// Dialog for managing questionnaire status and actions for a patient.
// Shows Nose HHT and QoL as cards with status chips and contextual actions.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/api_client.dart';
import 'portal_button.dart';
import 'select_starting_cycle_dialog.dart';
import 'start_next_cycle_dialog.dart';

/// Data model for a questionnaire row in the dialog
class _QuestionnaireInfo {
  final String? id;
  final String type;
  final String status;
  final String? studyEvent;
  final String? lastFinalizedAt;
  final String? lastFinalizedStudyEvent;
  final bool needsInitialSelection;
  final int? suggestedCycle;
  final String? suggestedStudyEvent;
  final bool isBlocked;
  final String? blockedReason;
  final String? endEvent;
  final bool cycleTrackingDisabled;

  _QuestionnaireInfo({
    this.id,
    required this.type,
    required this.status,
    this.studyEvent,
    this.lastFinalizedAt,
    this.lastFinalizedStudyEvent,
    this.needsInitialSelection = false,
    this.suggestedCycle,
    this.suggestedStudyEvent,
    this.isBlocked = false,
    this.blockedReason,
    this.endEvent,
    this.cycleTrackingDisabled = false,
  });
}

/// Dialog for managing questionnaires for a patient.
///
/// Shows Nose HHT and QoL questionnaire cards with status chips and
/// contextual action buttons (Send Now, Revoke, Unlock, Finalize).
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

        // Parse next_cycle_info if present (REQ-CAL-p00080)
        final nextCycleInfo =
            map['next_cycle_info'] as Map<String, dynamic>? ?? {};

        questionnaires.add(
          _QuestionnaireInfo(
            id: map['id'] as String?,
            type: type,
            status: map['status'] as String? ?? 'not_sent',
            studyEvent: map['study_event'] as String?,
            lastFinalizedAt: map['last_finalized_at'] as String?,
            lastFinalizedStudyEvent:
                map['last_finalized_study_event'] as String?,
            needsInitialSelection:
                nextCycleInfo['needs_initial_selection'] as bool? ?? false,
            suggestedCycle: nextCycleInfo['suggested_cycle'] as int?,
            suggestedStudyEvent: nextCycleInfo['study_event'] as String?,
            isBlocked: nextCycleInfo['blocked'] as bool? ?? false,
            blockedReason: nextCycleInfo['blocked_reason'] as String?,
            endEvent: nextCycleInfo['end_event'] as String?,
            cycleTrackingDisabled:
                map['cycle_tracking_disabled'] as bool? ??
                nextCycleInfo['cycle_tracking_disabled'] as bool? ??
                false,
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
        return 'Quality of Life';
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

  Color _statusColor(String status) {
    switch (status) {
      case 'not_sent':
        return const Color(0xFF6F7884);
      case 'sent':
        return const Color(0xFF6383FD);
      case 'in_progress':
        return Colors.amber.shade700;
      case 'ready_to_review':
        return const Color(0xFFC25F16);
      case 'finalized':
        return Colors.green;
      default:
        return const Color(0xFF6F7884);
    }
  }

  Color _statusBackgroundColor(String status) {
    switch (status) {
      case 'sent':
        return const Color(0xFFDBEAFF);
      case 'ready_to_review':
        return const Color(0xFFFEF1BA).withValues(alpha: 0.4);
      default:
        return Colors.transparent;
    }
  }

  /// Card background color — yellow tint for ready_to_review
  Color _cardBackgroundColor(String status) {
    switch (status) {
      case 'ready_to_review':
        return const Color(0xFFFFFBEA).withValues(alpha: 0.4);
      default:
        return Colors.transparent;
    }
  }

  /// Card border color — golden for ready_to_review
  Color? _cardBorderColor(String status, ThemeData theme) {
    switch (status) {
      case 'ready_to_review':
        return const Color(0xFFFEF1BA);
      default:
        return theme.colorScheme.outlineVariant;
    }
  }

  /// Formats an ISO 8601 date string for display (e.g., "Apr 2, 2026").
  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate).toLocal();
      return DateFormat('MMM d, yyyy, h:mm a').format(date);
    } catch (_) {
      return isoDate;
    }
  }

  // REQ-CAL-p00080: Cycle-aware send flow
  Future<void> _sendQuestionnaire(String type) async {
    final q = _questionnaires.firstWhere((q) => q.type == type);

    String? studyEvent;
    if (q.cycleTrackingDisabled) {
      // Cycle tracking disabled — send immediately, no dialogs
    } else if (q.needsInitialSelection) {
      // First send — show cycle selection dropdown
      final selectedCycle = await SelectStartingCycleDialog.show(
        context: context,
        questionnaireDisplayName: _displayName(type),
        patientDisplayId: widget.patientDisplayId,
        suggestedCycle: q.suggestedCycle,
      );
      if (selectedCycle == null || !mounted) return;
      studyEvent = 'Cycle $selectedCycle Day 1';
    } else {
      // Next cycle — show confirmation dialog
      final confirmed = await StartNextCycleDialog.show(
        context: context,
        cycleLabel: q.suggestedStudyEvent ?? 'Next Cycle',
        patientDisplayId: widget.patientDisplayId,
        questionnaireDisplayName: _displayName(type),
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() => _actionInProgress = true);

    final body = studyEvent != null
        ? {'study_event': studyEvent}
        : <String, dynamic>{};
    final response = await widget.apiClient.post(
      '/api/v1/portal/patients/${widget.patientId}/questionnaires/$type/send',
      body,
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
    final reason = await _showDeleteConfirmation(q);
    if (reason == null || !mounted) return;

    setState(() => _actionInProgress = true);

    final response = await widget.apiClient.delete(
      '/api/v1/portal/patients/${widget.patientId}/questionnaires/${q.id}',
      body: {'reason': reason},
    );

    if (!mounted) return;

    if (response.isSuccess) {
      await _loadQuestionnaires();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response.error ?? 'Failed to delete questionnaire'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }

    if (mounted) setState(() => _actionInProgress = false);
  }

  /// Shows delete confirmation with reason input.
  /// Returns the reason string or null if cancelled.
  Future<String?> _showDeleteConfirmation(_QuestionnaireInfo q) {
    final reasonController = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final reason = reasonController.text.trim();
            final isValid = reason.isNotEmpty && reason.length <= 25;

            return AlertDialog(
              backgroundColor: Colors.white,
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Delete Questionnaire?',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(null),
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                  ),
                ],
              ),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        text:
                            'Are you sure you want to delete the '
                            '${_displayName(q.type)} questionnaire for patient ',
                        children: [
                          TextSpan(
                            text: widget.patientDisplayId,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const TextSpan(text: '?'),
                        ],
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Why?',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: reasonController,
                      maxLength: 25,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Enter the reason...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade400),
                        ),
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                  ],
                ),
              ),
              actions: [
                PortalButton.outlined(
                  onPressed: () => Navigator.of(context).pop(null),
                  label: 'Cancel',
                ),
                PortalButton(
                  onPressed: isValid
                      ? () => Navigator.of(context).pop(reason)
                      : null,
                  label: 'Delete Questionnaire',
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: Colors.white,
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ignore: unused_element
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
    String? endEvent;

    if (q.cycleTrackingDisabled) {
      // Simple confirmation — no cycle dropdown
      final confirmed = await _showSimpleFinalizeConfirmation(q);
      if (confirmed != true || !mounted) return;
    } else {
      final result = await _showFinalizeConfirmation(q);
      if (result == null || !mounted) return;

      endEvent = result.isEmpty ? null : result;

      // Show additional confirmation when End of Treatment / End of Study selected
      if (endEvent != null) {
        final confirmed = await _showEndEventConfirmation(q, endEvent);
        if (confirmed != true || !mounted) return;
      }
    }

    setState(() => _actionInProgress = true);

    final body = endEvent != null
        ? {'end_event': endEvent}
        : <String, dynamic>{};
    final response = await widget.apiClient.post(
      '/api/v1/portal/patients/${widget.patientId}/questionnaires/${q.id}/finalize',
      body,
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

  /// Simple finalize confirmation when cycle tracking is disabled.
  Future<bool?> _showSimpleFinalizeConfirmation(_QuestionnaireInfo q) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          backgroundColor: Colors.white,
          title: Row(
            children: [
              Expanded(
                child: Text(
                  'Finalize Questionnaire?',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(null),
                icon: const Icon(Icons.close),
                tooltip: 'Close',
              ),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    text:
                        'Are you sure you want to finalize the '
                        '${_displayName(q.type)} questionnaire for patient ',
                    children: [
                      TextSpan(
                        text: widget.patientDisplayId,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const TextSpan(text: '?'),
                    ],
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.green.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.check_circle_outline,
                            color: Colors.green,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'This action will:',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildBulletPoint('Finalize this questionnaire'),
                      const SizedBox(height: 4),
                      _buildBulletPoint(
                        'Calculate the score and send it to EDC',
                      ),
                      const SizedBox(height: 4),
                      _buildBulletPoint(
                        'Finalizing the questionnaire locks all patient '
                        'responses. After this point, the patient cannot '
                        'edit or update their answers in the Daily Diary app.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            PortalButton.outlined(
              onPressed: () => Navigator.of(context).pop(null),
              label: 'Cancel',
            ),
            PortalButton(
              onPressed: () => Navigator.of(context).pop(true),
              label: 'Finalize Questionnaire',
              icon: Icons.check_circle_outline,
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ],
        );
      },
    );
  }

  Future<String?> _showFinalizeConfirmation(_QuestionnaireInfo q) {
    final cycleName = q.studyEvent ?? 'Current Cycle';

    return showDialog<String>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        String selectedValue = cycleName;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isEndEvent =
                selectedValue == 'end_of_treatment' ||
                selectedValue == 'end_of_study';
            return AlertDialog(
              title: const Text('Finalize Questionnaire?'),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        text:
                            'Are you sure you want to finalize the '
                            '${_displayName(q.type)} questionnaire for patient ',
                        children: [
                          TextSpan(
                            text: widget.patientDisplayId,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const TextSpan(text: '?'),
                        ],
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text('Cycle', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: selectedValue,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: cycleName,
                          child: Text(cycleName),
                        ),
                        const DropdownMenuItem(
                          value: 'end_of_treatment',
                          child: Text('End of Treatment'),
                        ),
                        const DropdownMenuItem(
                          value: 'end_of_study',
                          child: Text('End of Study'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setDialogState(() => selectedValue = v);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isEndEvent
                            ? theme.colorScheme.errorContainer.withValues(
                                alpha: 0.3,
                              )
                            : Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isEndEvent
                              ? theme.colorScheme.error.withValues(alpha: 0.5)
                              : Colors.green.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isEndEvent
                                    ? Icons.warning_amber
                                    : Icons.check_circle_outline,
                                color: isEndEvent
                                    ? theme.colorScheme.error
                                    : Colors.green,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'This action will:',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: isEndEvent
                                      ? theme.colorScheme.error
                                      : Colors.green.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _buildBulletPoint('Finalize this questionnaire'),
                          const SizedBox(height: 4),
                          _buildBulletPoint(
                            'Calculate the score and send it to EDC',
                          ),
                          const SizedBox(height: 4),
                          _buildBulletPoint(
                            'Finalizing the questionnaire locks all patient '
                            'responses. After this point, the patient cannot '
                            'edit or update their answers in the Daily Diary app.',
                          ),
                          if (isEndEvent) ...[
                            const SizedBox(height: 4),
                            _buildBulletPoint(
                              'No further ${_displayName(q.type)} '
                              'questionnaires can be sent to this patient.',
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final result = selectedValue == cycleName
                        ? ''
                        : selectedValue;
                    Navigator.of(context).pop(result);
                  },
                  style: FilledButton.styleFrom(backgroundColor: Colors.green),
                  child: const Text('Finalize Questionnaire'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Confirmation dialog when End of Treatment / End of Study is selected.
  /// Returns true if confirmed, null if cancelled.
  Future<bool?> _showEndEventConfirmation(
    _QuestionnaireInfo q,
    String endEvent,
  ) {
    final displayLabel = endEvent == 'end_of_treatment'
        ? 'End of Treatment'
        : endEvent == 'end_of_study'
        ? 'End of Study'
        : endEvent;

    const accentColor = Color(0xFFE17200);

    return showDialog<bool>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);

        return AlertDialog(
          backgroundColor: Colors.white,
          title: Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: accentColor,
                size: 24,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  displayLabel,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    text: 'This action will ',
                    children: [
                      const TextSpan(
                        text: 'permanently close',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const TextSpan(
                        text:
                            ' this questionnaire type for this patient. '
                            "You won't be able to send ",
                      ),
                      TextSpan(text: _displayName(q.type)),
                      const TextSpan(text: ' questionnaires to patient '),
                      TextSpan(
                        text: widget.patientDisplayId,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const TextSpan(text: '.'),
                    ],
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Are you sure?',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            PortalButton.outlined(
              onPressed: () => Navigator.of(context).pop(null),
              label: 'Cancel',
            ),
            PortalButton(
              onPressed: () => Navigator.of(context).pop(true),
              label: 'Yes',
              backgroundColor: accentColor,
              foregroundColor: Colors.white,
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

  // ================================================================
  // BUILD — Card-based layout matching Miro design
  // ================================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      backgroundColor: Colors.white,
      title: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Manage Questionnaires',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text.rich(
                  TextSpan(
                    text: 'View and manage questionnaire status for patient ',
                    children: [
                      TextSpan(
                        text: widget.patientDisplayId,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
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
    final allNotSent = _questionnaires.every(
      (q) => q.status == 'not_sent' && q.lastFinalizedAt == null,
    );

    return Stack(
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ..._questionnaires.map((q) => _buildQuestionnaireCard(q, theme)),
            if (allNotSent) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xfff8fafb),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'No questionnaires sent yet',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
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

  Widget _buildQuestionnaireCard(_QuestionnaireInfo q, ThemeData theme) {
    const closedTextColor = Color(0xFFC85427);
    const closedBorderColor = Color(0xFFFCE0DB);
    const closedBgColor = Color(0xFFFEF5F3);

    String? endEventLabel;
    if (q.endEvent == 'end_of_treatment') {
      endEventLabel = 'End of treatment';
    } else if (q.endEvent == 'end_of_study') {
      endEventLabel = 'End of study';
    }
    final statusLabel = q.isBlocked
        ? (endEventLabel != null ? 'Closed \u00B7 $endEventLabel' : 'Closed')
        : _statusLabel(q.status);
    final statusColor = q.isBlocked ? closedTextColor : _statusColor(q.status);
    final statusBg = q.isBlocked
        ? closedBgColor
        : _statusBackgroundColor(q.status);
    final statusBorder = q.isBlocked
        ? closedBorderColor
        : (q.status == 'ready_to_review'
              ? const Color(0xFFFEF1BA)
              : statusColor.withValues(alpha: 0.4));
    final lastCompleted = q.lastFinalizedAt != null
        ? _formatDate(q.lastFinalizedAt!)
        : 'Never';
    final currentCycle = q.studyEvent ?? q.lastFinalizedStudyEvent;
    final isClosed = q.isBlocked;

    final cardBg = isClosed
        ? const Color(0xFFF9FAFC)
        : _cardBackgroundColor(q.status);
    final cardBorder = _cardBorderColor(q.status, theme);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          border: Border.all(color: cardBorder!),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Questionnaire icon
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isClosed
                    ? const Color(0xFFEDEFF2)
                    : const Color(0xFFDBEAFF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.description_outlined,
                color: isClosed
                    ? const Color(0xFF7D8691)
                    : const Color(0xFF6383FD),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),

            // Info section
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _displayName(q.type),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Status chip
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: statusBg,
                      border: Border.all(color: statusBorder),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: statusColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Last Completed
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 14,
                        color: Color(0xFF7D8691),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Last Completed:  ',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF7D8691),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Flexible(
                        child: Text(
                          lastCompleted,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Current Cycle / Finalized cycle (if active and cycle tracking enabled)
                  if (currentCycle != null && !q.cycleTrackingDisabled) ...[
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 14,
                          color: Color(0xFF7D8691),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isClosed ? 'Finalized cycle:  ' : 'Current Cycle:  ',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF7D8691),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          currentCycle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
                  // Closed message (end of treatment / end of study)
                  if (isClosed) ...[
                    const SizedBox(height: 8),
                    Text(
                      'No further questionnaires of this type can be sent.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF7D8691),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Action buttons
            _buildCardActions(q, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildCardActions(_QuestionnaireInfo q, ThemeData theme) {
    switch (q.status) {
      case 'not_sent':
        if (q.isBlocked) {
          return PortalButton(
            onPressed: null,
            icon: q.cycleTrackingDisabled ? Icons.send : Icons.replay,
            label: q.cycleTrackingDisabled ? 'Send Now' : 'Start Next Cycle',
          );
        }
        final isNextCycle =
            q.lastFinalizedAt != null && !q.cycleTrackingDisabled;
        return PortalButton(
          onPressed: _actionInProgress
              ? null
              : () => _sendQuestionnaire(q.type),
          icon: isNextCycle ? Icons.replay : Icons.send,
          label: isNextCycle ? 'Start Next Cycle' : 'Send Now',
        );

      case 'sent':
        return IconButton(
          onPressed: _actionInProgress ? null : () => _revokeQuestionnaire(q),
          icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
          tooltip: 'Revoke questionnaire',
          iconSize: 22,
          constraints: const BoxConstraints(),
          padding: const EdgeInsets.all(4),
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
            PortalButton(
              onPressed: _actionInProgress
                  ? null
                  : () => _finalizeQuestionnaire(q),
              label: 'Finalize',
              icon: Icons.check_circle_outline,
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            const SizedBox(width: 4),
            IconButton(
              onPressed: _actionInProgress
                  ? null
                  : () => _revokeQuestionnaire(q),
              icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
              tooltip: 'Revoke questionnaire',
              iconSize: 22,
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(4),
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
