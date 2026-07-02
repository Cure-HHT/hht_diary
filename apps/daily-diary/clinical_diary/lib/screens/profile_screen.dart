import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:clinical_diary/screens/license_screen.dart';
import 'package:clinical_diary/widgets/back_to_home_row.dart';
import 'package:clinical_diary/widgets/brand_header.dart';
import 'package:clinical_diary/widgets/branding_logo.dart';
import 'package:clinical_diary/widgets/user_menu_button.dart';
import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

/// Canonical URL for the **Application Privacy Policy** (CUR-1495). Opened in
/// the device's default browser from the profile menu.
const String kApplicationPrivacyPolicyUrl =
    'https://anspar.org/privacy-cure-hht-app/';

/// Signature for the indirection used to open an external URL. Injectable so
/// tests can capture the requested [Uri] without touching platform channels.
/// Returns `true` when the URL was successfully handed off to the platform.
typedef ExternalUrlLauncher = Future<bool> Function(Uri url, {LaunchMode mode});

/// Default launcher — delegates to `url_launcher`'s [launchUrl].
Future<bool> _defaultExternalUrlLauncher(
  Uri url, {
  LaunchMode mode = LaunchMode.externalApplication,
}) {
  return launchUrl(url, mode: mode);
}

/// User profile screen — Figma node 441:6951 ("User Profile Screens").
///
/// Four states share the same shell (brand header, "< Home" breadcrumb,
/// title, "Your Status" section, menu list, sponsor-logo disclaimer) and
/// differ only in the status card area:
///
///   * Not linked     → [AppCard] with the "Join the Study" call-to-action.
///   * Connected      → [BrandedStatusCard] (success tone, sponsor logo header).
///   * Ended          → [BrandedStatusCard] (neutral tone).
///   * Disconnected   → [AppBanner] (error) above the title PLUS a
///                       [BrandedStatusCard] (error tone) with an
///                       "Enter New Linking Code" secondary action.
///
/// The top-bar logo on this screen always renders the **CureHHT** mark —
/// it never swaps to the sponsor logo on linking. The sponsor branding lives
/// only inside the status card's white header strip on this screen, matching
/// the Figma.
// Implements: DIARY-PRD-mobile-application/A
// Implements: DIARY-GUI-participation-status-badge
// Implements: DIARY-PRD-privacy-policy
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    required this.onBack,
    required this.onStartClinicalTrialEnrollment,
    required this.onShowSettings,
    required this.isEnrolledInTrial,
    required this.enrollmentStatus,
    required this.userName,
    required this.onUpdateUserName,
    this.isDisconnected = false,
    this.isNotParticipating = false,
    this.enrollmentCode,
    this.enrollmentDateTime,
    this.enrollmentEndDateTime,
    this.siteName,
    this.sitePhoneNumber,
    this.sponsorLogoBuilder,
    this.externalUrlLauncher = _defaultExternalUrlLauncher,
    super.key,
  });

  final VoidCallback onBack;
  final VoidCallback onStartClinicalTrialEnrollment;
  final VoidCallback onShowSettings;
  final bool isEnrolledInTrial;
  final bool isDisconnected;
  // CUR-1165: True when sponsor portal has marked participant as not participating
  final bool isNotParticipating;
  final String? enrollmentCode;
  final DateTime? enrollmentDateTime;
  final DateTime? enrollmentEndDateTime;
  final String enrollmentStatus; // linking status: 'active', 'ended', or 'none'
  final String userName;
  final ValueChanged<String> onUpdateUserName;
  final String? siteName;
  final String? sitePhoneNumber;

  /// Builds the cache-backed *Sponsor* logo for the **Participation Status
  /// Badge** (content-addressed, JWT-gated fetch-once). Null when no sponsor
  /// logo is configured. The badge retains the logo across the Not-Participating
  /// transition because the cache is kept after participation ends.
  // Implements: DIARY-GUI-participation-status-badge/H
  // Implements: DIARY-DEV-sponsor-branding-assets/D
  final BrandingLogoBuilder? sponsorLogoBuilder;

  /// Indirection used to open the **Application Privacy Policy** URL in the
  /// device browser. Defaults to `url_launcher`'s [launchUrl]; overridden in
  /// tests to capture the requested [Uri] without platform-channel mocking.
  final ExternalUrlLauncher externalUrlLauncher;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  /// Opens the **Application Privacy Policy** (CUR-1495) in the device's
  /// default browser. On failure (launcher returns false or throws) a brief
  /// error SnackBar is shown instead of crashing.
  Future<void> _openApplicationPrivacyPolicy() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    var opened = false;
    try {
      opened = await widget.externalUrlLauncher(
        Uri.parse(kApplicationPrivacyPolicyUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      opened = false;
    }
    if (!opened && mounted) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.couldNotOpenPrivacyPolicy),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _openLicenses() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const LicensesPage()));
  }

  /// Generic "Coming soon" toast for features that aren't built yet (Help
  /// Center, Export Data, Use Face ID / Fingerprint). Uses the generic
  /// [AppLocalizations.comingSoon] string so the message matches the tapped
  /// item instead of mislabeling it as a privacy setting (CUR-1493).
  void _showComingSoon() {
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.comingSoon),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top brand header — always CureHHT on the profile screen, even
            // when the participant is linked to a sponsor (per Figma).
            BrandHeader(
              leading: Image.asset(
                'assets/images/cure-hht-grey.png',
                width: 107,
                height: 42,
                fit: BoxFit.contain,
              ),
              // Reuse the same hamburger menu the home screen uses; hide
              // the "User Profile" row since we're already on profile.
              trailing: UserMenuButton(
                onJoinStudy: widget.isEnrolledInTrial
                    ? null
                    : widget.onStartClinicalTrialEnrollment,
                onShowHelpCenter: _showComingSoon,
              ),
            ),
            Expanded(
              // The maxWidth clamp sits ABOVE the LayoutBuilder/scroll view
              // (not inside the IntrinsicHeight) on purpose: RenderPositionedBox
              // and RenderConstrainedBox forward intrinsic-height probes with
              // the UNCLAMPED incoming width, so an inner Center→ConstrainedBox
              // would make IntrinsicHeight measure text wrap at the full
              // viewport width while layout wraps it at 600 — under-reporting
              // the height and overflowing the Column on wide viewports.
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: IntrinsicHeight(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                BackToHomeRow(onBack: widget.onBack),
                                if (widget.isDisconnected) ...[
                                  const SizedBox(height: 4),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                    ),
                                    child: AppBanner(
                                      severity: AppBannerSeverity.error,
                                      message: l10n
                                          .profileDisconnectionBannerMessage,
                                    ),
                                  ),
                                ],
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    24,
                                    16,
                                    24,
                                    8,
                                  ),
                                  child: Text(
                                    l10n.userProfile,
                                    style: theme.textTheme.headlineSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: theme.colorScheme.onSurface,
                                          letterSpacing: -0.5,
                                        ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    24,
                                    0,
                                    24,
                                    12,
                                  ),
                                  child: AppSectionHeader(
                                    title: l10n.yourStatus,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                  ),
                                  child: _buildStatusSection(theme, l10n),
                                ),
                                const SizedBox(height: 24),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                  ),
                                  child: _buildMenuList(theme, l10n),
                                ),
                                // Spacer pushes the disclaimer to the bottom
                                // of the viewport when content is short, while
                                // [IntrinsicHeight] lets content scroll past
                                // it on small screens.
                                const Spacer(),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    36,
                                    24,
                                    36,
                                    24,
                                  ),
                                  child: Text(
                                    l10n.sponsorLogoFootnote,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      fontSize: 12,
                                      height: 1.5,
                                    ),
                                    textAlign: TextAlign.left,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSection(ThemeData theme, AppLocalizations l10n) {
    final isNotParticipating = widget.isNotParticipating;
    final isDisconnected = widget.isDisconnected;
    final isActive =
        widget.isEnrolledInTrial && !isDisconnected && !isNotParticipating;

    if (!widget.isEnrolledInTrial && !isDisconnected) {
      return _buildJoinStudyCard(theme, l10n);
    }

    // Status icons exported straight from Figma (assets/icons/figma/) so
    // the glyph, stroke weight and colour match the spec exactly. Rendered
    // via [Image.asset] (not [ImageIcon]) so the Figma-supplied tone tint
    // survives — BrandedStatusCard's [iconWidget] slot bypasses tinting.
    final BrandedStatusTone tone;
    final String iconAsset;
    final String title;
    if (isDisconnected) {
      tone = BrandedStatusTone.error;
      iconAsset = _ProfileIcons.statusDisconnected;
      title = l10n.participationStatusDisconnected;
    } else if (isNotParticipating) {
      tone = BrandedStatusTone.neutral;
      iconAsset = _ProfileIcons.statusEnded;
      title = l10n.studyParticipationEnded;
    } else if (isActive) {
      tone = BrandedStatusTone.success;
      iconAsset = _ProfileIcons.statusConnected;
      title = l10n.participationStatusConnected;
    } else {
      tone = BrandedStatusTone.neutral;
      iconAsset = _ProfileIcons.statusEnded;
      title = l10n.studyParticipationEnded;
    }

    return BrandedStatusCard(
      tone: tone,
      header: _sponsorLogoHeader(),
      iconWidget: Image.asset(iconAsset, width: 34, height: 34),
      title: title,
      body: _buildStatusBody(theme, l10n),
      action: isDisconnected
          ? AppButton(
              variant: AppButtonVariant.secondary,
              label: l10n.enterNewLinkingCode,
              fullWidth: true,
              onPressed: widget.onStartClinicalTrialEnrollment,
            )
          : null,
    );
  }

  Widget _sponsorLogoHeader() {
    if (widget.sponsorLogoBuilder != null) {
      return widget.sponsorLogoBuilder!(
        width: 150,
        height: 30,
        fallback: const SizedBox(height: 30, width: 150),
      );
    }
    return const SizedBox(height: 30, width: 150);
  }

  Widget _buildStatusBody(ThemeData theme, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.enrollmentDateTime != null)
          Text(
            l10n.joinedDate(
              _formatEnrollmentDateTime(widget.enrollmentDateTime!),
            ),
            style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14),
          ),
        if (widget.enrollmentEndDateTime != null &&
            (widget.isNotParticipating || widget.enrollmentStatus == 'ended'))
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              l10n.endedDate(
                _formatEnrollmentDateTime(widget.enrollmentEndDateTime!),
              ),
              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14),
            ),
          ),
        if (widget.enrollmentCode != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              l10n.linkingCode(_formatEnrollmentCode(widget.enrollmentCode!)),
              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14),
            ),
          ),
      ],
    );
  }

  Widget _buildJoinStudyCard(ThemeData theme, AppLocalizations l10n) {
    return AppCard(
      color: Colors.white,
      noBorder: true,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.notLinkedToStudyTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.enterLinkingCodeToConnect,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          AppButton(
            variant: AppButtonVariant.primary,
            label: l10n.joinTheStudy,
            leadingWidget: Image.asset(
              _ProfileIcons.btnJoinStudy,
              width: 16,
              height: 16,
            ),
            fullWidth: true,
            onPressed: widget.onStartClinicalTrialEnrollment,
          ),
        ],
      ),
    );
  }

  Widget _buildMenuList(ThemeData theme, AppLocalizations l10n) {
    // Single declarative list drives the rows — no per-row markup duplication.
    // Per Figma every row is the same shape (icon · label · chevron),
    // including Use Face ID / Fingerprint. Glyphs are Figma exports under
    // assets/icons/figma/ so stroke weight and proportions match exactly.
    final items = <_MenuItemSpec>[
      _MenuItemSpec(
        iconAsset: _ProfileIcons.menuExport,
        label: l10n.exportData,
        onTap: _showComingSoon,
      ),
      _MenuItemSpec(
        iconAsset: _ProfileIcons.menuPolicy,
        label: l10n.applicationPrivacyPolicy,
        onTap: _openApplicationPrivacyPolicy,
      ),
      _MenuItemSpec(
        iconAsset: _ProfileIcons.menuLicenses,
        label: l10n.licenses,
        onTap: _openLicenses,
      ),
      _MenuItemSpec(
        iconAsset: _ProfileIcons.menuSettings,
        label: l10n.accessibilityAndPreferences,
        onTap: widget.onShowSettings,
      ),
      _MenuItemSpec(
        iconAsset: _ProfileIcons.menuFingerprint,
        label: l10n.useFaceIdOrFingerprint,
        onTap: _showComingSoon,
      ),
    ];

    return Column(children: [for (final item in items) _MenuItem(spec: item)]);
  }

  String _formatEnrollmentCode(String code) {
    if (code.length >= 5) {
      return '${code.substring(0, 5)}-${code.substring(5)}';
    }
    return code;
  }

  String _formatEnrollmentDateTime(DateTime dateTime) {
    final date = DateFormat('M/d/yyyy').format(dateTime);
    final time = DateFormat.jm().format(dateTime);
    return '$date at $time';
  }
}

/// Asset paths for the Figma-exported PNG glyphs used on the profile
/// screen. Kept colocated so any reorganisation of the icon export folder
/// only touches one file. (Both BrandedStatusCard.iconWidget and the menu
/// list reach for these.)
abstract class _ProfileIcons {
  static const _base = 'assets/icons/figma';
  static const statusConnected = '$_base/status_connected.png';
  static const statusEnded = '$_base/status_ended.png';
  static const statusDisconnected = '$_base/status_disconnected.png';
  static const menuExport = '$_base/menu_export.png';
  static const menuPolicy = '$_base/menu_policy.png';
  static const menuLicenses = '$_base/menu_licenses.png';
  static const menuSettings = '$_base/menu_settings.png';
  static const menuFingerprint = '$_base/menu_fingerprint.png';
  static const btnJoinStudy = '$_base/btn_join_study.png';
}

/// Declarative description of one row in the profile menu list. Lets
/// [_ProfileScreenState._buildMenuList] build the rows from a single list
/// instead of repeating the row markup five times.
class _MenuItemSpec {
  const _MenuItemSpec({
    required this.iconAsset,
    required this.label,
    required this.onTap,
  });

  /// Path to a Figma-exported PNG under assets/icons/figma/.
  final String iconAsset;
  final String label;
  final VoidCallback onTap;
}

/// Row in the profile menu list — leading Figma glyph, label, trailing
/// chevron. Used for every row including Use Face ID / Fingerprint (no
/// switch).
class _MenuItem extends StatelessWidget {
  const _MenuItem({required this.spec});

  final _MenuItemSpec spec;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: spec.onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Image.asset(spec.iconAsset, width: 18, height: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                spec.label,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontSize: 16,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
