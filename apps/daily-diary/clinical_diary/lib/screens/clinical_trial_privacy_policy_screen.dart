// IMPLEMENTS REQUIREMENTS:
//   REQ-p00045: Clinical Trial Privacy Policy

import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Placeholder screen for the Clinical Trial Privacy Policy.
/// Final policy content TBD — displays a "coming soon" message for now.
class ClinicalTrialPrivacyPolicyScreen extends StatelessWidget {
  const ClinicalTrialPrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.clinicalTrialPrivacyPolicy)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.description_outlined,
                size: 64,
                color: theme.colorScheme.primary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 24),
              Text(
                l10n.clinicalTrialPrivacyPolicy,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.comingSoon,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
