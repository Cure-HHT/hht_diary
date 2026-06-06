// IMPLEMENTS REQUIREMENTS:
//   REQ-p00008: Mobile App Diary Entry
//   REQ-d00006: Mobile App Build and Release Process

import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:clinical_diary/screens/license_screen.dart';
import 'package:clinical_diary/widgets/branding_logo.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Logo menu widget with data management and clinical trial options
class LogoMenu extends StatefulWidget {
  const LogoMenu({
    required this.onResetAllData,
    required this.onEndClinicalTrial,
    required this.onInstructionsAndFeedback,
    this.showDevTools = true,
    this.resetEnabled = true,
    this.resetDisabledReason = 'End your study participation to reset',
    this.isEnrolled,
    this.sponsorLogoBuilder,
    super.key,
  });

  final VoidCallback onResetAllData;
  final VoidCallback? onEndClinicalTrial;
  final VoidCallback onInstructionsAndFeedback;

  /// Whether the "Reset all data" item is tappable. When false the item is
  /// rendered greyed-out and non-tapping (the local factory reset is gated on
  /// non-participation + the sponsor `allow_local_reset` setting).
  final bool resetEnabled;

  /// Subtitle shown under a disabled "Reset all data" item explaining why.
  final String resetDisabledReason;
  final bool? isEnrolled;

  /// Builds the cache-backed *Sponsor* logo (content-addressed, JWT-gated
  /// fetch-once). Null when no sponsor logo is configured — the app default
  /// brand is then shown.
  // Implements: DIARY-DEV-sponsor-branding-assets/D
  final BrandingLogoBuilder? sponsorLogoBuilder;

  /// Whether to show developer tools (Reset All Data).
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
              // Implements: DIARY-DEV-sponsor-branding-assets/D — the logo is
              //   rendered from the content-addressed cache (verified bytes,
              //   JWT-gated fetch-once), not a plain Image.network URL.
              (widget.sponsorLogoBuilder != null)
                  ? widget.sponsorLogoBuilder!(
                      width: 120,
                      height: 40,
                      fallback: const SizedBox(height: 40, width: 120),
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
          case 'reset_all_data':
            // Guarded: a disabled item is non-selectable, but never invoke the
            // destructive reset when the gate is closed.
            if (widget.resetEnabled) widget.onResetAllData();
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
          // Implements: DIARY-BASE-local-data-reset/B+C — the reset item is
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
