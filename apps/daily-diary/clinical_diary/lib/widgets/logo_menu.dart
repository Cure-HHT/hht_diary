// IMPLEMENTS REQUIREMENTS:
//   REQ-p00008: Mobile App Diary Entry
//   REQ-d00006: Mobile App Build and Release Process

import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:clinical_diary/screens/license_screen.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Logo menu widget with data management and clinical trial options
class LogoMenu extends StatefulWidget {
  const LogoMenu({
    required this.onExportData,
    required this.onImportData,
    required this.onResetAllData,
    required this.onFeatureFlags,
    required this.onEndClinicalTrial,
    required this.onInstructionsAndFeedback,
    this.showDevTools = true,
    this.resetEnabled = true,
    this.resetDisabledReason = 'End your study participation to reset',
    this.isEnrolled,
    this.sponsorLogo,
    super.key,
  });

  final VoidCallback onExportData;
  final VoidCallback onImportData;
  final VoidCallback onResetAllData;
  final VoidCallback onFeatureFlags;
  final VoidCallback? onEndClinicalTrial;
  final VoidCallback onInstructionsAndFeedback;

  /// Whether the "Reset all data" item is tappable. When false the item is
  /// rendered greyed-out and non-tapping (the local factory reset is gated on
  /// non-participation + the sponsor `allow_local_reset` setting).
  final bool resetEnabled;

  /// Subtitle shown under a disabled "Reset all data" item explaining why.
  final String resetDisabledReason;
  final bool? isEnrolled;
  final String? sponsorLogo;

  /// Whether to show developer tools (Reset All Data, Import/Export Data, Feature Flags).
  /// Should be false in production and UAT environments.
  final bool showDevTools;

  @override
  State<LogoMenu> createState() => _LogoMenuState();
}

class _LogoMenuState extends State<LogoMenu> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    // Use package_info_plus for display (works in dev and prod on all platforms)
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _version = packageInfo.buildNumber.isNotEmpty
              ? '${packageInfo.version}+${packageInfo.buildNumber}'
              : packageInfo.version;
        });
      }
    } catch (e) {
      debugPrint('PackageInfo error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<String>(
      tooltip: l10n.appMenu,
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (widget.isEnrolled ?? false)
              (widget.sponsorLogo != null)
                  ? Image.network(
                      widget.sponsorLogo!,
                      height: 40,
                      width: 120,
                      errorBuilder: (context, _, _) {
                        return const SizedBox(
                          height: 40,
                          width: 120,
                          child: Center(
                            child: Icon(Icons.broken_image_outlined, size: 32),
                          ),
                        );
                      },
                    )
                  : const SizedBox()
            else
              ColorFiltered(
                colorFilter: ColorFilter.mode(
                  Colors.grey.withValues(alpha: 0.5),
                  BlendMode.srcATop,
                ),
                child: Image.asset(
                  'assets/images/cure-hht-grey.png',
                  width: 100,
                  height: 40,
                  fit: BoxFit.contain,
                ),
              ),
          ],
        ),
      ),
      onSelected: (value) {
        switch (value) {
          case 'export_data':
            widget.onExportData();
          case 'import_data':
            widget.onImportData();
          case 'reset_all_data':
            // Guarded: a disabled item is non-selectable, but never invoke the
            // destructive reset when the gate is closed.
            if (widget.resetEnabled) widget.onResetAllData();
          case 'feature_flags':
            widget.onFeatureFlags();
          case 'end_clinical_trial':
            widget.onEndClinicalTrial?.call();
          case 'instructions_feedback':
            widget.onInstructionsAndFeedback();
          case 'licenses':
            Navigator.push<dynamic>(
              context,
              MaterialPageRoute(builder: (context) => const LicensesPage()),
            );
        }
      },
      itemBuilder: (context) => [
        // Data Management section header (only shown in dev/test environments)
        if (widget.showDevTools) ...[
          PopupMenuItem<String>(
            enabled: false,
            child: Text(
              l10n.dataManagement,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          PopupMenuItem<String>(
            value: 'export_data',
            child: Row(
              children: [
                Icon(
                  Icons.upload_outlined,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                const SizedBox(width: 12),
                Flexible(child: Text(l10n.exportData)),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'import_data',
            child: Row(
              children: [
                Icon(
                  Icons.download_outlined,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                const SizedBox(width: 12),
                Flexible(child: Text(l10n.importData)),
              ],
            ),
          ),
          // Implements: DIARY-PRD-local-data-reset/B+C — the reset item is
          //   disabled (greyed, non-tapping, with a reason) while the gate is
          //   closed (participating in a trial, or sponsor-disabled).
          PopupMenuItem<String>(
            value: 'reset_all_data',
            enabled: widget.resetEnabled,
            child: Row(
              children: [
                Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: widget.resetEnabled
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).disabledColor,
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.resetAllData,
                        style: TextStyle(
                          color: widget.resetEnabled
                              ? Theme.of(context).colorScheme.error
                              : Theme.of(context).disabledColor,
                        ),
                      ),
                      if (!widget.resetEnabled)
                        Text(
                          widget.resetDisabledReason,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(context).disabledColor,
                              ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'feature_flags',
            child: Row(
              children: [
                Icon(
                  Icons.science_outlined,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                const SizedBox(width: 12),
                Flexible(child: Text(l10n.featureFlagsTitle)),
              ],
            ),
          ),
        ],

        // Clinical Trial section (only if linked)
        if (widget.onEndClinicalTrial != null) ...[
          // Only add divider if dev tools section was shown
          if (widget.showDevTools) const PopupMenuDivider(),
          PopupMenuItem<String>(
            enabled: false,
            child: Text(
              l10n.clinicalTrialLabel,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          PopupMenuItem<String>(
            value: 'end_clinical_trial',
            child: Row(
              children: [
                Icon(
                  Icons.exit_to_app,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                const SizedBox(width: 12),
                Flexible(child: Text(l10n.endClinicalTrial)),
              ],
            ),
          ),
        ],

        // External links section
        // Only add divider if there was content above
        if (widget.showDevTools || widget.onEndClinicalTrial != null)
          const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'instructions_feedback',
          child: Row(
            children: [
              Icon(
                Icons.open_in_new,
                size: 20,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              const SizedBox(width: 12),
              Flexible(child: Text(l10n.instructionsAndFeedback)),
            ],
          ),
        ),

        // Version info at bottom
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'licenses',
          child: Row(
            children: [
              Icon(
                Icons.credit_card_rounded,
                size: 20,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              const SizedBox(width: 12),
              Flexible(child: Text(l10n.licenses)),
            ],
          ),
        ),
        PopupMenuItem<String>(
          enabled: false,
          height: 32,
          child: Center(
            child: Text(
              _version.isNotEmpty ? 'v$_version' : '',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
