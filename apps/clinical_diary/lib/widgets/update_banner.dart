// IMPLEMENTS REQUIREMENTS:
//   REQ-d00006: Mobile App Build and Release Process

import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Dismissible banner showing that an optional update is available
///
/// Displays at the top of the screen with:
/// - Update message with version number
/// - Optional release notes preview
/// - "Update Now" button
/// - Dismiss button (X)
class UpdateBanner extends StatelessWidget {
  const UpdateBanner({
    required this.newVersion,
    required this.onUpdate,
    required this.onDismiss,
    this.releaseNotes,
    super.key,
  });

  /// The new version available
  final String newVersion;

  /// Called when user taps "Update Now"
  final VoidCallback onUpdate;

  /// Called when user dismisses the banner
  final VoidCallback onDismiss;

  /// Optional release notes to display
  final String? releaseNotes;

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
          color: Colors.blue.shade50,
          border: Border(
            bottom: BorderSide(color: Colors.blue.shade200, width: 1),
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info icon
              Icon(Icons.system_update, color: Colors.blue.shade700, size: 24),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.updateAvailable,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.newVersionAvailable(newVersion),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.blue.shade800,
                      ),
                    ),
                    if (releaseNotes != null && releaseNotes!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        releaseNotes!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.blue.shade700,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),

                    // Action buttons
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: onUpdate,
                          icon: const Icon(Icons.download, size: 18),
                          label: Text(l10n.updateNow),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        TextButton(
                          onPressed: onDismiss,
                          child: Text(
                            l10n.later,
                            style: TextStyle(color: Colors.blue.shade700),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Dismiss button
              IconButton(
                onPressed: onDismiss,
                icon: Icon(Icons.close, color: Colors.blue.shade600, size: 20),
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
