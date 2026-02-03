// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00020: Patient Disconnection Workflow
//   REQ-CAL-p00077: Disconnection Notification
//
// Dismissable warning banner shown when patient is disconnected from the study

import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Dismissable warning banner shown when a patient has been disconnected
/// from the study by their Study Coordinator.
///
/// Displays at the top of the screen with:
/// - Warning icon and message to contact the study site
/// - Dismiss button (X) to hide the banner
///
/// The banner reappears on app restart until the patient is reconnected.
class DisconnectionBanner extends StatelessWidget {
  const DisconnectionBanner({
    required this.onDismiss,
    this.siteName,
    super.key,
  });

  /// Called when user dismisses the banner
  final VoidCallback onDismiss;

  /// Optional site name to include in the message
  final String? siteName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Material(
      elevation: 4,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          border: Border(
            bottom: BorderSide(color: Colors.red.shade200, width: 1),
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Warning icon
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.red.shade700,
                size: 28,
              ),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.disconnectedFromStudy,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      siteName != null
                          ? l10n.contactYourSiteWithName(siteName!)
                          : l10n.contactYourSite,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.red.shade800,
                      ),
                    ),
                  ],
                ),
              ),

              // Dismiss button
              IconButton(
                onPressed: onDismiss,
                icon: Icon(Icons.close, color: Colors.red.shade600, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: l10n.close,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
