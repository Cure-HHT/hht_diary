// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00020: Patient Disconnection Workflow
//   REQ-CAL-p00077: Disconnection Notification
//   REQ-CAL-p00065: Reactivate Patient
//
// Dismissable warning banner shown when patient is disconnected from the study.
// Tapping the banner shows site contact information with a tappable phone number.

import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Dismissable warning banner shown when a patient has been disconnected
/// from the study by their Study Coordinator.
///
/// Displays at the top of the screen with:
/// - Warning icon and message to contact the study site
/// - Dismiss button (X) to hide the banner
/// - Tap to expand and show site contact details
/// - Tappable phone number to initiate a call
///
/// The banner reappears on app restart until the patient is reconnected.
class DisconnectionBanner extends StatefulWidget {
  const DisconnectionBanner({
    required this.onDismiss,
    this.siteName,
    this.sitePhoneNumber,
    super.key,
  });

  /// Called when user dismisses the banner
  final VoidCallback onDismiss;

  /// Optional site name to include in the message
  final String? siteName;

  /// Optional site phone number for contact (REQ-CAL-p00077)
  final String? sitePhoneNumber;

  @override
  State<DisconnectionBanner> createState() => _DisconnectionBannerState();
}

class _DisconnectionBannerState extends State<DisconnectionBanner> {
  bool _isExpanded = false;

  /// Attempt to make a phone call
  Future<void> _makePhoneCall() async {
    if (widget.sitePhoneNumber == null) return;

    final uri = Uri.parse('tel:${widget.sitePhoneNumber}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final hasContactInfo =
        widget.siteName != null || widget.sitePhoneNumber != null;

    return Material(
      elevation: 4,
      child: InkWell(
        onTap: hasContactInfo
            ? () => setState(() => _isExpanded = !_isExpanded)
            : null,
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Main banner row
                Row(
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
                            widget.siteName != null
                                ? l10n.contactYourSiteWithName(widget.siteName!)
                                : l10n.contactYourSite,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.red.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Expand indicator (if has contact info)
                    if (hasContactInfo) ...[
                      Icon(
                        _isExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: Colors.red.shade600,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                    ],

                    // Dismiss button
                    IconButton(
                      onPressed: widget.onDismiss,
                      icon: Icon(
                        Icons.close,
                        color: Colors.red.shade600,
                        size: 20,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: l10n.close,
                    ),
                  ],
                ),

                // Expanded contact details
                if (_isExpanded && hasContactInfo)
                  _buildExpandedContactDetails(theme, l10n),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedContactDetails(ThemeData theme, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, left: 40),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.siteContactInfo,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.red.shade900,
              ),
            ),
            const SizedBox(height: 8),

            // Site name
            if (widget.siteName != null)
              Row(
                children: [
                  Icon(
                    Icons.location_city,
                    size: 16,
                    color: Colors.red.shade700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.siteName!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.red.shade900,
                      ),
                    ),
                  ),
                ],
              ),

            // Phone number (tappable)
            if (widget.sitePhoneNumber != null) ...[
              const SizedBox(height: 8),
              InkWell(
                onTap: _makePhoneCall,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.phone, size: 16, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.sitePhoneNumber!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.blue.shade700,
                            decoration: TextDecoration.underline,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 12,
                        color: Colors.blue.shade700,
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Hint text
            const SizedBox(height: 8),
            Text(
              l10n.tapToCall,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
