import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';

/// Shared chrome for every unauthenticated auth screen (login, OTP,
/// forgot-password, password-reset, role-selection).
///
/// Renders the Figma "centered card on a light page" layout: a light-grey
/// page background, a centered scrollable [AppCard] carrying the brand mark, a
/// bold [title], an optional [subtitle], an optional [banner] slot (for inline
/// status / error), and the caller-supplied [child] form.
///
/// This is deliberately consumer-owned styled UI: `reaction_widgets` ships only
/// headless primitives and mandates that "rendered sugar — buttons, lists,
/// theming — SHALL live in downstream consumer applications"
/// (EVS-PRD-reaction-widget-contract/G). The auth screens compose
/// `diary_design_system` components here in the app, never in the library.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.banner,
    this.brandMark,
    this.maxWidth = 440,
    this.semanticId,
  });

  /// Bold heading inside the card (e.g. "Sponsor Portal",
  /// "Forgot your password?").
  final String title;

  /// Optional muted line under the title.
  final String? subtitle;

  /// The form content (fields + action buttons + footer links).
  final Widget child;

  /// Optional widget rendered between the subtitle and the form — typically an
  /// [AppBanner] carrying an inline error or status message.
  final Widget? banner;

  /// Sponsor brand mark rendered at the top of the card. When null, the sponsor
  /// logo baked into the served content (`/portal/assets/images/app_logo.png`,
  /// the standard sponsor-content path the portal-final image overlays from a
  /// sponsor's `content/portal/`) is shown, falling back to a neutral
  /// theme-primary placeholder when no logo is present (e.g. a sponsor that
  /// ships no logo). Pass a widget here to override entirely.
  final Widget? brandMark;

  final double maxWidth;

  final String? semanticId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: AppCard(
            padding: const EdgeInsets.all(32),
            semanticId: semanticId,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: brandMark ?? const SponsorBrandMark()),
                const SizedBox(height: 24),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    subtitle!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                if (banner != null) ...[banner!, const SizedBox(height: 16)],
                child,
              ],
            ),
          ),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLow,
      body: SafeArea(child: body),
    );
  }
}

/// Full-width tertiary text link used in the footer of the auth cards
/// ("Back to Login", "Resend code"). [loading] swaps the label for a spinner
/// and disables the tap (used by "Resend code" while the request is in flight).
class AuthLinkButton extends StatelessWidget {
  const AuthLinkButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.semanticId,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final String? semanticId;

  @override
  Widget build(BuildContext context) {
    return AppButton(
      variant: AppButtonVariant.tertiary,
      label: label,
      fullWidth: true,
      loading: loading,
      onPressed: onPressed,
      semanticId: semanticId,
    );
  }
}

/// The sponsor logo shown atop the auth cards.
///
/// Loads the sponsor logo from the standard served content path
/// (`/portal/assets/images/app_logo.png`). The portal-final image overlays a
/// sponsor's `content/portal/` into the SPA's `web/portal/`, so any sponsor
/// (including the built-in `reference` sponsor) that ships a logo there renders
/// it here with no per-sponsor code. When no logo is served — or the host
/// can't resolve an http(s) origin (unit tests run on the VM) — it falls back
/// to a neutral theme-primary glyph so the card never renders an empty header.
class SponsorBrandMark extends StatelessWidget {
  const SponsorBrandMark({super.key, this.maxHeight = 56, this.maxWidth = 220});

  /// Conventional sponsor-content path for the portal logo (see class doc).
  static const String logoPath = '/portal/assets/images/app_logo.png';

  /// Upper bound on the rendered logo height.
  final double maxHeight;

  /// Upper bound on the rendered logo WIDTH. Without it a wide sponsor logo
  /// (only its height was constrained) blew out horizontally. Combined with
  /// [BoxFit.contain] the whole logo is scaled to fit inside
  /// [maxWidth] x [maxHeight], preserving aspect ratio.
  final double maxWidth;

  /// The absolute logo URL for the current web origin, or null when there is no
  /// http(s) origin to resolve against (non-web / tests) — in which case the
  /// neutral fallback is used instead of attempting a network fetch.
  static String? _logoUrl() {
    final base = Uri.base;
    if (base.scheme == 'http' || base.scheme == 'https') {
      return base.replace(path: logoPath, query: '', fragment: '').toString();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final url = _logoUrl();
    if (url == null) return const _FallbackBrandMark();
    // Give the image an explicit width AND height and scale-to-fit:
    // BoxFit.contain keeps the entire logo visible inside maxWidth x maxHeight
    // without distortion, so an oversized/wide sponsor asset can never dominate
    // the layout.
    return Image.network(
      url,
      width: maxWidth,
      height: maxHeight,
      fit: BoxFit.contain,
      semanticLabel: 'Sponsor logo',
      errorBuilder: (_, __, ___) => const _FallbackBrandMark(),
    );
  }
}

/// Neutral placeholder used when no sponsor logo is available.
class _FallbackBrandMark extends StatelessWidget {
  const _FallbackBrandMark();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Icon(Icons.local_hospital, size: 30, color: cs.primary);
  }
}
