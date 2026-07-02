// Persistent warning banner shown when participant is disconnected from the
// study. Non-dismissible. Tapping the chevron expands a design-system
// [AppCard] with site contact info and a tappable phone link.

import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Persistent warning banner shown when a participant has been disconnected
/// from the study by their Study Coordinator.
// Implements: DIARY-PRD-participant-disconnection
// Implements: DIARY-PRD-notification-disconnection
// Implements: DIARY-PRD-participant-reactivate
class DisconnectionBanner extends StatefulWidget {
  const DisconnectionBanner({this.siteName, this.sitePhoneNumber, super.key});

  final String? siteName;
  final String? sitePhoneNumber;

  @override
  State<DisconnectionBanner> createState() => _DisconnectionBannerState();
}

class _DisconnectionBannerState extends State<DisconnectionBanner> {
  bool _isExpanded = false;

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
    final subtitle = widget.siteName != null
        ? l10n.contactYourSiteWithName(widget.siteName!)
        : l10n.contactYourSite;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppBanner(
          severity: AppBannerSeverity.error,
          title: l10n.disconnectedFromStudy,
          message: subtitle,
          trailing: hasContactInfo
              ? IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minHeight: 32,
                    minWidth: 32,
                  ),
                  icon: Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: theme.colorScheme.error,
                  ),
                  onPressed: () => setState(() => _isExpanded = !_isExpanded),
                )
              : null,
        ),
        if (_isExpanded && hasContactInfo) ...[
          const SizedBox(height: 8),
          AppCard(
            title: l10n.siteContactInfo,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.siteName != null)
                  Row(
                    children: [
                      Icon(
                        Icons.location_city,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.siteName!,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                if (widget.sitePhoneNumber != null) ...[
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _makePhoneCall,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(
                            Icons.phone,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.sitePhoneNumber!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.primary,
                                decoration: TextDecoration.underline,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 12,
                            color: theme.colorScheme.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  l10n.tapToCall,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
