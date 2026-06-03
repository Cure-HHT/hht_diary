import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/sponsor_branding_service.dart';

/// Shared scaffold for the portal's auth screens (login, forgot password,
/// enter OTP, create new password).
///
/// Renders the Primary-Bg page background with a centered white card. The
/// card houses the sponsor logo, the consistent "Clinical Trial Portal" title
/// (from [SponsorBrandingConfig]), a per-screen [subtitle], and the
/// per-screen [child] form content.
class AuthScaffold extends StatelessWidget {
  /// The form content that varies per auth screen.
  final Widget child;

  /// Subtitle copy (e.g., "Sign in to access your dashboard", "Reset your
  /// password", "Enter the code we sent to your email").
  final String subtitle;

  /// Overrides the page title. Defaults to the sponsor branding title (e.g.,
  /// "Clinical Trial Portal").
  final String? title;

  /// Maximum card width in logical pixels.
  final double maxWidth;

  const AuthScaffold({
    super.key,
    required this.child,
    required this.subtitle,
    this.title,
    this.maxWidth = 420,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final branding = context.read<SponsorBrandingConfig>();
    final effectiveTitle = title ?? branding.title;
    // Tighter margins on mobile viewports, relaxed on tablet+ for a more
    // spacious feel. Uses the shared breakpoint helpers from the design
    // system so the same logic is reusable across portal screens.
    final outerPadding = context.responsive(mobile: 16.0, tablet: 24.0);
    final innerPadding = context.responsive(mobile: 20.0, tablet: 32.0);

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLow, // Primary Bg
      // SafeArea handles notches / status bars when the portal is opened on
      // a mobile browser or PWA. Bottom inset is excluded because Scaffold
      // already handles the keyboard inset via resizeToAvoidBottomInset.
      body: SafeArea(
        bottom: false,
        child: Center(
          child: SingleChildScrollView(
            // padding around the centered card; collapses if the card grows
            // taller than the viewport, allowing the user to scroll.
            padding: EdgeInsets.symmetric(
              horizontal: outerPadding,
              vertical: outerPadding,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface, // White
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant,
                  ), // Light Gray
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: EdgeInsets.all(innerPadding),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Logo(branding: branding, theme: theme),
                    const SizedBox(height: 24),
                    Text(
                      effectiveTitle,
                      // Inter SemiBold 24 / line-height 32 / Black.
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 24,
                        height: 32 / 24,
                        color: theme.colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      // Inter Regular 14 / line-height 20 / letter-spacing
                      // -0.15 / Dark Grey.
                      style: TextStyle(
                        fontWeight: FontWeight.w400,
                        fontSize: 14,
                        height: 20 / 14,
                        letterSpacing: -0.15,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    child,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  final SponsorBrandingConfig branding;
  final ThemeData theme;

  const _Logo({required this.branding, required this.theme});

  @override
  Widget build(BuildContext context) {
    if (branding.hasLogo) {
      return Image.network(
        branding.appLogoUrl!,
        height: 48,
        errorBuilder: (_, _, _) => _fallback(),
      );
    }
    return _fallback();
  }

  Widget _fallback() =>
      Icon(Icons.medication, size: 48, color: theme.colorScheme.primary);
}
