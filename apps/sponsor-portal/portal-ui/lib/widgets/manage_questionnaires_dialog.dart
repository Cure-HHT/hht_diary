// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00023: Nose and Quality of Life Questionnaire Workflow
//   REQ-CAL-p00066: Status Change Reason Field
//   REQ-CAL-p00080: Questionnaire Study Event Association
//
// Dialog for managing questionnaire status and actions for a patient.
// Shows Nose HHT and QoL as cards with status chips and contextual actions.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:trial_data_types/trial_data_types.dart';

import '../services/api_client.dart';
import 'portal_button.dart';
import 'portal_dropdown.dart';
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

  /// Human-readable name for this questionnaire type.
  /// Single source of truth — used by both the state class (dialogs) and
  /// [_QuestionnaireCard] (card header).
  String get displayName {
    switch (type) {
      case 'nose_hht':
        return 'NOSE HHT';
      case 'qol':
        return 'HHT-QoL';
      default:
        return type;
    }
  }
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

      const typeOrder = {'qol': 0, 'nose_hht': 1};
      questionnaires.sort((a, b) {
        final aOrder = typeOrder[a.type] ?? 99;
        final bOrder = typeOrder[b.type] ?? 99;
        return aOrder.compareTo(bOrder);
      });

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
        questionnaireDisplayName: q.displayName,
        patientDisplayId: widget.patientDisplayId,
        suggestedCycle: q.suggestedCycle,
      );
      if (selectedCycle == null || !mounted) return;
      studyEvent = StudyEvent.format(selectedCycle);
    } else {
      // Next cycle — show confirmation dialog
      final confirmed = await StartNextCycleDialog.show(
        context: context,
        cycleLabel: q.suggestedStudyEvent ?? 'Next Cycle',
        patientDisplayId: widget.patientDisplayId,
        questionnaireDisplayName: q.displayName,
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

            return AlertDialog(
              backgroundColor: Colors.white,
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Call Back Questionnaire?',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
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
                    Text(
                      'Please provide a reason for calling back this questionnaire.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: reasonController,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: 'Enter reason...',

                        hintStyle: TextStyle(color: Colors.grey.shade400),
                        fillColor: Colors.transparent,
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
                  onPressed: reason.isNotEmpty
                      ? () => Navigator.of(context).pop(reason)
                      : null,
                  label: 'Confirm',
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
      // GUI-CAL-p00007 Assertion G: cancelling the Terminal Cycle Warning
      // returns the user to the Finalization Dialog, not all the way out.
      while (true) {
        final result = await _showFinalizeConfirmation(q);
        if (result == null || !mounted) return;

        endEvent = result.isEmpty ? null : result;

        if (endEvent == null) break; // Normal cycle — no warning needed

        final confirmed = await _showEndEventConfirmation(q, endEvent);
        if (!mounted) return;
        if (confirmed == true) break; // Warning accepted — proceed
        // Warning cancelled → loop back to Finalization Dialog
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
                        '${q.displayName} questionnaire for patient ',
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
            final isEndEvent = StudyEvent.isEndEvent(selectedValue);
            final selectedLabel = isEndEvent
                ? StudyEvent.endEventDisplayLabel(selectedValue)
                : selectedValue;

            return AlertDialog(
              backgroundColor: Colors.white,
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Finalize Questionnaire?',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
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
                    // Subtitle — questionnaire name and patient ID both bold
                    Text.rich(
                      TextSpan(
                        text: 'Are you sure you want to finalize the ',
                        children: [
                          TextSpan(
                            text: q.displayName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const TextSpan(text: ' questionnaire for patient '),
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

                    // Cycle dropdown
                    PortalDropdown<String>(
                      label: 'Cycle',
                      value: selectedValue,
                      items: [
                        DropdownMenuItem(
                          value: cycleName,
                          child: Text(cycleName),
                        ),
                        DropdownMenuItem(
                          value: StudyEvent.endOfTreatment,
                          child: Text(
                            StudyEvent.endEventDisplayLabel(
                              StudyEvent.endOfTreatment,
                            ),
                          ),
                        ),
                        DropdownMenuItem(
                          value: StudyEvent.endOfStudy,
                          child: Text(
                            StudyEvent.endEventDisplayLabel(
                              StudyEvent.endOfStudy,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setDialogState(() => selectedValue = v);
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // Blue info box — shows selected cycle dynamically
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFD0DBFF)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: Color(0xFF2868FC),
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                text:
                                    'This questionnaire will be finalized as: ',
                                children: [
                                  TextSpan(
                                    text: selectedLabel,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2868FC),
                                    ),
                                  ),
                                ],
                              ),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: const Color(0xFF334E99),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Green action box — bullet points
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDF7ED),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFA5D6A7)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.check_circle_outline,
                            color: Color(0xFF2E7D32),
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildBulletPoint(
                                  'Finalize this questionnaire',
                                ),
                                const SizedBox(height: 4),
                                _buildBulletPoint(
                                  'Calculate the score and send it to EDC',
                                ),
                                const SizedBox(height: 4),
                                _buildBulletPoint(
                                  'Finalizing the questionnaire locks all '
                                  'participant responses. After this point, the '
                                  'participant cannot edit or update their '
                                  'answers in the Daily Diary app.',
                                ),
                                if (isEndEvent) ...[
                                  const SizedBox(height: 4),
                                  _buildBulletPoint(
                                    'No further ${q.displayName} '
                                    'questionnaires can be sent to this participant.',
                                  ),
                                ],
                              ],
                            ),
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
                  onPressed: () {
                    final result = selectedValue == cycleName
                        ? ''
                        : selectedValue;
                    Navigator.of(context).pop(result);
                  },
                  label: 'Finalize Questionnaire',
                  icon: Icons.check_circle_outline,
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
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
    final displayLabel = StudyEvent.endEventDisplayLabel(endEvent);

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
                      TextSpan(
                        text: q.displayName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const TextSpan(text: ' questionnaires to patient '),
                      TextSpan(
                        text: widget.patientDisplayId,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const TextSpan(text: '. Are you sure?'),
                    ],
                  ),
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
    return Stack(
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ..._questionnaires.map(
              (q) => _QuestionnaireCard(
                q: q,
                patientDisplayId: widget.patientDisplayId,
                actionInProgress: _actionInProgress,
                onSend: () => _sendQuestionnaire(q.type),
                onRevoke: () => _revokeQuestionnaire(q),
                onFinalize: () => _finalizeQuestionnaire(q),
              ),
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
}

// ============================================================
// Extracted card widget — keeps the state class focused on
// network / dialog orchestration.
// ============================================================

/// A single questionnaire row card shown inside [ManageQuestionnairesDialog].
///
/// Stateless — all mutable state (action-in-progress flag, callbacks) is
/// passed in from the parent state.
class _QuestionnaireCard extends StatelessWidget {
  const _QuestionnaireCard({
    required this.q,
    required this.patientDisplayId,
    required this.actionInProgress,
    required this.onSend,
    required this.onRevoke,
    required this.onFinalize,
  });

  final _QuestionnaireInfo q;
  final String patientDisplayId;
  final bool actionInProgress;
  final VoidCallback onSend;
  final VoidCallback onRevoke;
  final VoidCallback onFinalize;

  // ── helpers ──────────────────────────────────────────────

  String _statusLabel() {
    switch (q.status) {
      case 'not_sent':
        return 'Not Sent';
      case 'sent':
        return 'Sent';
      case 'in_progress':
        return 'In Progress';
      case 'ready_to_review':
        return 'Ready to Review';
      case 'delivery_failed':
        return 'Delivery Failed';
      case 'finalized':
        return 'Finalized';
      default:
        return q.status;
    }
  }

  Color _statusColor() {
    switch (q.status) {
      case 'not_sent':
        return const Color(0xFF6F7884);
      case 'sent':
        return const Color(0xFF6383FD);
      case 'in_progress':
        return Colors.amber.shade700;
      case 'ready_to_review':
        return const Color(0xFFC25F16);
      case 'delivery_failed':
        return const Color(0xFFD32F2F);
      case 'finalized':
        return Colors.green;
      default:
        return const Color(0xFF6F7884);
    }
  }

  Color _statusBackgroundColor() {
    switch (q.status) {
      case 'sent':
        return const Color(0xFFDBEAFF);
      case 'ready_to_review':
        return const Color(0xFFFEF1BA).withValues(alpha: 0.4);
      case 'delivery_failed':
        return const Color(0xFFFFEBEE);
      default:
        return Colors.transparent;
    }
  }

  Color _cardBackgroundColor() {
    switch (q.status) {
      case 'ready_to_review':
        return const Color(0xFFFFFBEA);
      default:
        return Colors.white;
    }
  }

  Color _cardBorderColor(ThemeData theme) {
    switch (q.status) {
      case 'ready_to_review':
        return const Color(0xFFFEF1BA);
      default:
        return theme.colorScheme.outlineVariant;
    }
  }

  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate).toLocal();
      return DateFormat('MMM d, yyyy, h:mm a').format(date);
    } catch (_) {
      return isoDate;
    }
  }

  bool get _isAfterFinalize =>
      q.status == 'not_sent' && q.lastFinalizedAt != null && !q.isBlocked;

  /// Abbreviated display label: "Cycle N" or end-event display name.
  String _cycleDisplayLabel(String studyEvent) {
    final n = StudyEvent.parseCycleNumber(studyEvent);
    return n != null ? 'Cycle $n' : StudyEvent.endEventDisplayLabel(studyEvent);
  }

  // ── build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    const closedTextColor = Color(0xFFC85427);
    const closedBorderColor = Color(0xFFFCE0DB);
    const closedBgColor = Color(0xFFFEF5F3);

    final endEventLabel = q.endEvent != null
        ? StudyEvent.endEventDisplayLabel(q.endEvent!)
        : null;
    final statusLabel = q.isBlocked
        ? (endEventLabel != null ? 'Closed \u00B7 $endEventLabel' : 'Closed')
        : _statusLabel();
    final statusColor = q.isBlocked ? closedTextColor : _statusColor();
    final statusBg = q.isBlocked ? closedBgColor : _statusBackgroundColor();
    final statusBorder = q.isBlocked
        ? closedBorderColor
        : (q.status == 'ready_to_review'
              ? const Color(0xFFFEF1BA)
              : statusColor.withValues(alpha: 0.4));
    final currentCycle = q.studyEvent ?? q.lastFinalizedStudyEvent;
    final isClosed = q.isBlocked;

    final cardBg = isClosed ? const Color(0xFFF9FAFC) : _cardBackgroundColor();
    final cardBorder = _cardBorderColor(theme);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardBg,
          border: Border.all(color: cardBorder),
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
                    q.displayName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (q.isBlocked) ...[
                    const SizedBox(height: 10),
                    // Last finalized: Cycle N · date  [Closed chip]
                    if (q.lastFinalizedAt != null &&
                        q.lastFinalizedStudyEvent != null &&
                        !q.cycleTrackingDisabled) ...[
                      Row(
                        children: [
                          Flexible(
                            child: Text.rich(
                              TextSpan(
                                text: 'Last finalized: ',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: const Color(0xFF7D8691),
                                ),
                                children: [
                                  TextSpan(
                                    text:
                                        '${_cycleDisplayLabel(q.lastFinalizedStudyEvent!)} · '
                                        '${_formatDate(q.lastFinalizedAt!)}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF1A1A2E),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
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
                        ],
                      ),
                    ] else ...[
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
                    ],
                    const SizedBox(height: 6),
                    Text(
                      'No further questionnaires of this type can be sent.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF7D8691),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ] else if (_isAfterFinalize && !q.cycleTrackingDisabled) ...[
                    const SizedBox(height: 10),
                    // Last: Cycle N · date
                    Text.rich(
                      TextSpan(
                        text: 'Last: ',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF7D8691),
                        ),
                        children: [
                          TextSpan(
                            text:
                                '${_cycleDisplayLabel(q.lastFinalizedStudyEvent!)} · '
                                '${_formatDate(q.lastFinalizedAt!)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1A1A2E),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Next: Cycle N [badge]
                    Row(
                      children: [
                        Text.rich(
                          TextSpan(
                            text: 'Next: ',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF7D8691),
                            ),
                            children: [
                              TextSpan(
                                text: _cycleDisplayLabel(
                                  q.suggestedStudyEvent ?? '',
                                ),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF1A1A2E),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
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
                      ],
                    ),
                  ] else if (q.status == 'sent' &&
                      !q.cycleTrackingDisabled &&
                      currentCycle != null) ...[
                    const SizedBox(height: 10),
                    // Current: Cycle N Day 1 [Sent badge]
                    Row(
                      children: [
                        Text.rich(
                          TextSpan(
                            text: 'Current: ',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF7D8691),
                            ),
                            children: [
                              TextSpan(
                                text: currentCycle,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF1A1A2E),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
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
                      ],
                    ),
                  ] else if (q.status == 'delivery_failed' &&
                      !q.cycleTrackingDisabled &&
                      currentCycle != null) ...[
                    const SizedBox(height: 10),
                    // Current: Cycle X [Delivery Failed badge] [ⓘ]
                    Row(
                      children: [
                        Text.rich(
                          TextSpan(
                            text: 'Current: ',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF7D8691),
                            ),
                            children: [
                              TextSpan(
                                text: currentCycle,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF1A1A2E),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: statusBg,
                            border: Border.all(
                              color: statusColor.withValues(alpha: 0.4),
                            ),
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
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTapDown: (details) => _showTroubleshootingPopover(
                            context,
                            theme,
                            details.globalPosition,
                          ),
                          child: Icon(
                            Icons.info_outline,
                            color: statusColor,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ] else if (q.status == 'ready_to_review' &&
                      !q.cycleTrackingDisabled &&
                      currentCycle != null) ...[
                    const SizedBox(height: 10),
                    // Current: Cycle N Day 1 [Ready to Review chip]
                    Row(
                      children: [
                        Text.rich(
                          TextSpan(
                            text: 'Current: ',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF7D8691),
                            ),
                            children: [
                              TextSpan(
                                text: currentCycle,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF1A1A2E),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
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
                      ],
                    ),
                  ] else ...[
                    const SizedBox(height: 10),
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
                    const SizedBox(height: 10),
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
                            isClosed
                                ? 'Finalized cycle:  '
                                : 'Current Cycle:  ',
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
                ],
              ),
            ),

            // Action buttons
            _buildActions(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildActions(ThemeData theme) {
    switch (q.status) {
      case 'not_sent':
        if (q.isBlocked) return const SizedBox.shrink();
        final isNextCycle =
            q.lastFinalizedAt != null && !q.cycleTrackingDisabled;
        return PortalButton(
          onPressed: actionInProgress ? null : onSend,
          icon: Icons.send,
          label: isNextCycle ? 'Start Next Cycle' : 'Send Now',
        );

      case 'sent':
        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.error, width: 1.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: IconButton(
            onPressed: actionInProgress ? null : onRevoke,
            icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
            tooltip: 'Delete',
            iconSize: 22,
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(8),
          ),
        );

      case 'in_progress':
        return Text(
          'Participant is working',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
        );

      case 'ready_to_review':
        return IntrinsicHeight(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                onPressed: actionInProgress ? null : onFinalize,
                icon: const Icon(Icons.check_circle_outline, size: 15),
                label: const Text('Finalize'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.green.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: actionInProgress ? null : onRevoke,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: theme.colorScheme.error, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Icon(
                  Icons.delete_outline,
                  color: theme.colorScheme.error,
                  size: 18,
                ),
              ),
            ],
          ),
        );

      case 'delivery_failed':
        return PortalButton(
          onPressed: actionInProgress ? null : onSend,
          icon: Icons.send,
          label: 'Send Now',
        );

      case 'finalized':
        return const Icon(Icons.check_circle, color: Colors.green, size: 20);

      default:
        return const SizedBox.shrink();
    }
  }

  void _showTroubleshootingPopover(
    BuildContext context,
    ThemeData theme,
    Offset tapPosition,
  ) {
    final overlayState = Overlay.of(context);
    late OverlayEntry barrier;
    late OverlayEntry popover;

    void dismiss() {
      barrier.remove();
      popover.remove();
    }

    barrier = OverlayEntry(
      builder: (_) => Positioned.fill(
        child: GestureDetector(
          onTap: dismiss,
          behavior: HitTestBehavior.translucent,
          child: const SizedBox.expand(),
        ),
      ),
    );

    popover = OverlayEntry(
      builder: (ctx) {
        final screen = MediaQuery.of(ctx).size;
        const popoverWidth = 340.0;
        const arrowHeight = 10.0;
        const arrowHalfBase = 10.0;

        final left = (tapPosition.dx - popoverWidth / 2).clamp(
          8.0,
          screen.width - popoverWidth - 8.0,
        );
        final arrowX = (tapPosition.dx - left).clamp(
          arrowHalfBase + 12,
          popoverWidth - arrowHalfBase - 12,
        );

        return Positioned(
          left: left,
          bottom: screen.height - tapPosition.dy,
          child: Material(
            color: Colors.transparent,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: popoverWidth,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: theme.colorScheme.error,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Immediate Troubleshooting Steps',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildTroubleshootStep(
                        theme,
                        1,
                        'Check the participant\'s phone is online',
                        ' \u2014 confirm Wi-Fi or cellular connection is active.',
                      ),
                      _buildTroubleshootStep(
                        theme,
                        2,
                        'Check for a captive portal',
                        ' \u2014 if on hospital/hotel Wi-Fi, the phone may appear'
                            ' "connected" but require logging in through a browser'
                            ' page (accepting terms, entering a code, etc.). Open a'
                            ' browser and complete any login page.',
                      ),
                      _buildTroubleshootStep(
                        theme,
                        3,
                        'Wait ~1 minute after connectivity is restored',
                        ' \u2014 the system will automatically retry delivery.',
                      ),
                      _buildTroubleshootStep(
                        theme,
                        4,
                        'Check the app itself',
                        ' \u2014 confirm the app launches, isn\'t crashing, and'
                            ' the phone isn\'t out of storage (the app should'
                            ' surface these itself, but worth verifying).',
                      ),
                      _buildTroubleshootStep(
                        theme,
                        5,
                        'If still failing after the above',
                        ' \u2014 fall back to a paper form and contact support /'
                            ' the study team per escalation protocol.',
                      ),
                    ],
                  ),
                ),
                // Downward-pointing arrow connecting popover to the ⓘ icon
                ClipPath(
                  clipper: _DownArrowClipper(xCenter: arrowX),
                  child: Container(
                    width: popoverWidth,
                    height: arrowHeight,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    overlayState.insertAll([barrier, popover]);
  }

  Widget _buildTroubleshootStep(
    ThemeData theme,
    int number,
    String boldPart,
    String regularPart,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$number. ',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: boldPart,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextSpan(
                    text: regularPart,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Clips a downward-pointing triangle arrow centered at [xCenter].
class _DownArrowClipper extends CustomClipper<Path> {
  final double xCenter;

  const _DownArrowClipper({required this.xCenter});

  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(xCenter - size.height, 0)
      ..lineTo(xCenter + size.height, 0)
      ..lineTo(xCenter, size.height)
      ..close();
  }

  @override
  bool shouldReclip(_DownArrowClipper old) => old.xCenter != xCenter;
}
