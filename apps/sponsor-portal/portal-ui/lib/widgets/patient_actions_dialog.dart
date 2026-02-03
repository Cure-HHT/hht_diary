// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00064: Mark Patient as Not Participating
//   REQ-CAL-p00073: Patient Status Definitions
//
// Modal dialog showing available actions for a patient based on their status

import 'package:flutter/material.dart';

import '../services/api_client.dart';
import 'link_patient_dialog.dart';
import 'mark_not_participating_dialog.dart';
import 'reconnect_patient_dialog.dart';

/// Result from opening a patient action dialog
enum PatientActionResult {
  /// No action taken, dialog was cancelled
  cancelled,

  /// An action was taken that requires refreshing the patient list
  actionTaken,
}

/// Dialog showing available actions for a patient.
///
/// Actions vary based on the patient's current status:
/// - disconnected: Show Linking Code, Reconnect Patient, Mark as Not Participating
/// - not_participating: Reactivate
/// - other statuses: relevant actions (link, show code, etc.)
class PatientActionsDialog extends StatelessWidget {
  final String patientId;
  final String patientDisplayId;
  final String mobileLinkingStatus;
  final ApiClient apiClient;

  const PatientActionsDialog({
    super.key,
    required this.patientId,
    required this.patientDisplayId,
    required this.mobileLinkingStatus,
    required this.apiClient,
  });

  /// Shows the dialog and returns whether an action was taken.
  static Future<PatientActionResult> show({
    required BuildContext context,
    required String patientId,
    required String patientDisplayId,
    required String mobileLinkingStatus,
    required ApiClient apiClient,
  }) async {
    final result = await showDialog<PatientActionResult>(
      context: context,
      builder: (context) => PatientActionsDialog(
        patientId: patientId,
        patientDisplayId: patientDisplayId,
        mobileLinkingStatus: mobileLinkingStatus,
        apiClient: apiClient,
      ),
    );
    return result ?? PatientActionResult.cancelled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.person, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          const Text('Patient Actions'),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Patient ID display
            Container(
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
                    patientDisplayId,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Actions based on status
            ..._buildActions(context, theme),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(PatientActionResult.cancelled),
          child: const Text('Close'),
        ),
      ],
    );
  }

  List<Widget> _buildActions(BuildContext context, ThemeData theme) {
    switch (mobileLinkingStatus) {
      case 'disconnected':
        return [
          _ActionTile(
            icon: Icons.visibility,
            title: 'Show Linking Code',
            description: 'View active linking code if available',
            onTap: () async {
              Navigator.of(context).pop(PatientActionResult.cancelled);
              await ShowLinkingCodeDialog.show(
                context: context,
                patientId: patientId,
                patientDisplayId: patientDisplayId,
                apiClient: apiClient,
              );
            },
          ),
          const SizedBox(height: 8),
          _ActionTile(
            icon: Icons.link,
            title: 'Reconnect Patient',
            description: 'Generate new linking code to reconnect',
            iconColor: theme.colorScheme.primary,
            onTap: () async {
              final success = await ReconnectPatientDialog.show(
                context: context,
                patientId: patientId,
                patientDisplayId: patientDisplayId,
                apiClient: apiClient,
              );
              if (context.mounted) {
                Navigator.of(context).pop(
                  success
                      ? PatientActionResult.actionTaken
                      : PatientActionResult.cancelled,
                );
              }
            },
          ),
          const SizedBox(height: 8),
          _ActionTile(
            icon: Icons.person_off,
            title: 'Mark as Not Participating',
            description: 'Patient completed trial, withdrew, or discontinued',
            iconColor: theme.colorScheme.error,
            titleColor: theme.colorScheme.error,
            onTap: () async {
              final success = await MarkNotParticipatingDialog.show(
                context: context,
                patientId: patientId,
                patientDisplayId: patientDisplayId,
                apiClient: apiClient,
              );
              if (context.mounted) {
                Navigator.of(context).pop(
                  success
                      ? PatientActionResult.actionTaken
                      : PatientActionResult.cancelled,
                );
              }
            },
          ),
        ];

      case 'linking_in_progress':
        return [
          _ActionTile(
            icon: Icons.qr_code,
            title: 'Show Linking Code',
            description: 'View the active linking code',
            onTap: () async {
              Navigator.of(context).pop(PatientActionResult.cancelled);
              await ShowLinkingCodeDialog.show(
                context: context,
                patientId: patientId,
                patientDisplayId: patientDisplayId,
                apiClient: apiClient,
              );
            },
          ),
        ];

      case 'not_participating':
        return [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.colorScheme.error.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 20,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'This patient is marked as not participating. Sponsor rules are not applied.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'To re-enroll this patient, use the "Reactivate" button in the patient list.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ];

      default:
        return [
          Text(
            'No actions available for this patient status.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ];
    }
  }
}

/// Action tile widget for the patient actions dialog
class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color? iconColor;
  final Color? titleColor;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.description,
    this.iconColor,
    this.titleColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.3),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 24,
                color: iconColor ?? theme.colorScheme.onSurface,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: titleColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
