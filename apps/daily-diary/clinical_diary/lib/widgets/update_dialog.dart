// IMPLEMENTS REQUIREMENTS:
//   REQ-d00006: Mobile App Build and Release Process

import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Non-dismissible dialog for required updates
///
/// Shown when the app version is below the minimum required version.
/// User must update to continue using the app.
class UpdateDialog extends StatelessWidget {
  const UpdateDialog({
    required this.currentVersion,
    required this.requiredVersion,
    required this.onUpdate,
    this.releaseNotes,
    super.key,
  });

  /// The current app version
  final String currentVersion;

  /// The required minimum version
  final String requiredVersion;

  /// Called when user taps "Update Now"
  final VoidCallback onUpdate;

  /// Optional release notes to display
  final String? releaseNotes;

  /// Show the dialog
  ///
  /// This dialog is non-dismissible (cannot be closed by tapping outside
  /// or pressing back).
  static Future<void> show(
    BuildContext context, {
    required String currentVersion,
    required String requiredVersion,
    required VoidCallback onUpdate,
    String? releaseNotes,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // Cannot dismiss by tapping outside
      builder: (context) => PopScope(
        canPop: false, // Cannot dismiss with back button
        child: UpdateDialog(
          currentVersion: currentVersion,
          requiredVersion: requiredVersion,
          onUpdate: onUpdate,
          releaseNotes: releaseNotes,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return AlertDialog(
      icon: Icon(
        Icons.system_update,
        size: 48,
        color: theme.colorScheme.primary,
      ),
      title: Text(l10n.updateRequired, textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.updateRequiredMessage,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _VersionRow(
                  label: l10n.currentVersionLabel,
                  version: currentVersion,
                  isOutdated: true,
                ),
                const SizedBox(height: 8),
                _VersionRow(
                  label: l10n.requiredVersionLabel,
                  version: requiredVersion,
                  isOutdated: false,
                ),
              ],
            ),
          ),
          if (releaseNotes != null && releaseNotes!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              l10n.whatsNew,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              releaseNotes!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade700,
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onUpdate,
            icon: const Icon(Icons.download),
            label: Text(l10n.updateNow),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }
}

/// Row displaying version label and value
class _VersionRow extends StatelessWidget {
  const _VersionRow({
    required this.label,
    required this.version,
    required this.isOutdated,
  });

  final String label;
  final String version;
  final bool isOutdated;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: isOutdated ? Colors.red.shade100 : Colors.green.shade100,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            'v$version',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: isOutdated ? Colors.red.shade700 : Colors.green.shade700,
            ),
          ),
        ),
      ],
    );
  }
}
