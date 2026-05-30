// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00020: Participant Disconnection Workflow
//   REQ-CAL-p00077: Disconnection Notification
//   REQ-CAL-p00065: Reactivate Participant
//   REQ-p05004: Disconnection Notification (persistent, non-dismissible)
//   REQ-p70011: Participant Reconnection Workflow (banner variant for linking_in_progress)
//
// Persistent warning banner shown when participant is disconnected from the study.
// Non-dismissible per REQ-p05004. In the plain `disconnected` state the banner
// expands on tap to show site contact info. When the underlying mobile linking
// status is `linkingInProgress` (i.e. the portal has issued a new linking
// code), the banner copy and tap behavior switch to a "tap to enter your new
// code" call-to-action (REQ-p70011/F).

import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:clinical_diary/models/mobile_linking_status.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Persistent warning banner shown when a participant has been disconnected
/// from the study by their Study Coordinator, or when the portal has just
/// issued a new linking code and is awaiting re-entry on mobile.
///
/// Non-dismissible per REQ-p05004 — stays visible until participant reconnects.
class DisconnectionBanner extends StatefulWidget {
  const DisconnectionBanner({
    required this.status,
    this.siteName,
    this.sitePhoneNumber,
    this.onTapReconnect,
    super.key,
  });

  /// The underlying mobile linking status driving the banner copy/behavior.
  /// Only [MobileLinkingStatus.disconnected] and
  /// [MobileLinkingStatus.linkingInProgress] render meaningful banner
  /// variants; the host widget decides whether to mount the banner at all.
  final MobileLinkingStatus status;

  /// Optional site name to include in the message (disconnected variant)
  final String? siteName;

  /// Optional site phone number for contact (REQ-CAL-p00077)
  final String? sitePhoneNumber;

  /// Invoked when the participant taps the banner in the `linkingInProgress`
  /// variant. Host wires this to the enrollment screen.
  // Implements: REQ-p70011/F
  final VoidCallback? onTapReconnect;

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
    final isAwaitingReconnect =
        widget.status == MobileLinkingStatus.linkingInProgress;
    final hasContactInfo =
        widget.siteName != null || widget.sitePhoneNumber != null;

    final title = isAwaitingReconnect
        ? l10n.reconnectionRequired
        : l10n.disconnectedFromStudy;
    final body = isAwaitingReconnect
        ? l10n.tapToEnterNewCode
        : (widget.siteName != null
              ? l10n.contactYourSiteWithName(widget.siteName!)
              : l10n.contactYourSite);

    final onTap = isAwaitingReconnect
        ? widget.onTapReconnect
        : (hasContactInfo
              ? () => setState(() => _isExpanded = !_isExpanded)
              : null);

    final trailingIcon = isAwaitingReconnect
        ? Icons.arrow_forward_ios
        : (hasContactInfo
              ? (_isExpanded
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down)
              : null);

    return Material(
      child: InkWell(
        onTap: onTap,
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
                            title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            body,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.red.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Trailing indicator (chevron for expand, arrow for reconnect)
                    if (trailingIcon != null)
                      Icon(
                        trailingIcon,
                        color: Colors.red.shade600,
                        size: isAwaitingReconnect ? 14 : 20,
                      ),
                  ],
                ),

                // Expanded contact details (disconnected variant only)
                if (!isAwaitingReconnect && _isExpanded && hasContactInfo)
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
