import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:clinical_diary/screens/clinical_trial_privacy_policy_screen.dart';
import 'package:clinical_diary/services/enrollment_service.dart';
import 'package:clinical_diary/widgets/back_to_home_row.dart';
import 'package:clinical_diary/widgets/brand_header.dart';
import 'package:clinical_diary/widgets/user_menu_button.dart';
import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// "Join the Study" — linking-code entry screen. Matches the Figma
/// `Join the Study` design (file qWMfvnr455NSByXqsDcok7, node 427-4237)
/// and is built on the shared diary_design_system (AppCodeInput,
/// AppConsentRow, AppButton).
// Implements: DIARY-PRD-mobile-application/A
// Implements: DIARY-PRD-privacy-policy
class ClinicalTrialEnrollmentScreen extends StatefulWidget {
  const ClinicalTrialEnrollmentScreen({
    required this.enrollmentService,
    this.onShowProfile,
    super.key,
  });
  final EnrollmentService enrollmentService;

  /// Called when the participant taps **User Profile** in the trailing
  /// hamburger menu. Wired from the parent so the route that knows how to
  /// build the profile screen (with cached enrollment / disconnection
  /// state) owns the navigation. When null the menu item is hidden — the
  /// enrollment screen itself has no way to construct a meaningful profile.
  final VoidCallback? onShowProfile;

  @override
  State<ClinicalTrialEnrollmentScreen> createState() =>
      _ClinicalTrialEnrollmentScreenState();
}

class _ClinicalTrialEnrollmentScreenState
    extends State<ClinicalTrialEnrollmentScreen> {
  final _codeController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  bool _hasAgreedToSharing = false;
  bool _isLinked = false;

  bool get _isCodeComplete => _codeController.text.length == 10;
  bool get _isReadyToSubmit =>
      _isCodeComplete && _hasAgreedToSharing && !_isLoading;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _enroll() async {
    if (!_isReadyToSubmit) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.enrollmentService.enroll(_codeController.text);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isLinked = true;
      });
    } on EnrollmentException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error: $e';
      });
    }
  }

  void _openClinicalTrialPrivacyPolicy() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ClinicalTrialPrivacyPolicyScreen(),
      ),
    );
  }

  void _handleShowPrivacy() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).privacyComingSoon),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _onCodeChanged(String _) {
    if (_errorMessage != null) {
      setState(() => _errorMessage = null);
    } else {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BrandHeader(
              leading: Image.asset(
                'assets/images/cure-hht-grey.png',
                height: 42,
                fit: BoxFit.contain,
              ),
              // Same hamburger menu as Home / Profile; **Join the Study**
              // is hidden because we're already on the linking screen.
              // **User Profile** is shown when the parent supplied
              // [widget.onShowProfile], which owns the navigation (it has
              // the enrollment data this screen lacks).
              trailing: UserMenuButton(
                onShowProfile: widget.onShowProfile,
                onShowHelpCenter: _handleShowPrivacy,
              ),
            ),
            if (!_isLinked)
              BackToHomeRow(
                semanticId: 'enroll-back',
                onBack: _isLoading ? null : () => Navigator.of(context).pop(),
              ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: _isLinked
                    ? const _LinkedSuccessPanel()
                    : _buildForm(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final hasError = _errorMessage != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Page title — "Join the Study" (Figma h1, 32px / -0.22).
        const Text(
          'Join the Study',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w600,
            height: 1.1,
            letterSpacing: -0.22,
            color: Color(0xFF04161E),
          ),
        ),
        const SizedBox(height: 32),

        // Section heading — "Enter Linking Code" + description.
        const Text(
          'Enter Linking Code',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            height: 26.4 / 22,
            letterSpacing: -0.44,
            color: Color(0xFF04161E),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Please enter the 10-digit linking code provided by your research coordinator.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: const Color(0xFF54636A),
            height: 23.25 / 15,
            letterSpacing: -0.22,
          ),
        ),

        const SizedBox(height: 24),

        // Code input — 2 × 5 segments with dash separator (Figma).
        AppCodeInput(
          controller: _codeController,
          onChanged: _onCodeChanged,
          onCompleted: (_) => _onCodeChanged(_codeController.text),
          enabled: !_isLoading,
          state: hasError ? AppCodeInputState.invalid : AppCodeInputState.idle,
          helperText: 'Code format: XXXXX-XXXXX, letters and numbers',
          errorText: _errorMessage,
          semanticId: 'enroll-code',
        ),

        const SizedBox(height: 24),

        // Consent — Privacy Policy link (Figma Primary-Light-Soft tile).
        AppConsentRow(
          value: _hasAgreedToSharing,
          onChanged: _isLoading
              ? null
              : (v) => setState(() => _hasAgreedToSharing = v),
          semanticId: 'enroll-consent',
          bodyBuilder: (context, foreground) {
            return Text.rich(
              TextSpan(
                style: TextStyle(
                  color: foreground,
                  fontSize: 15,
                  height: 22.5 / 15,
                  letterSpacing: -0.22,
                ),
                children: [
                  TextSpan(text: l10n.linkingConsentPrefix),
                  TextSpan(
                    text: l10n.privacyPolicy,
                    style: TextStyle(
                      decoration: TextDecoration.underline,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = _openClinicalTrialPrivacyPolicy,
                  ),
                  TextSpan(text: l10n.linkingConsentSuffix),
                ],
              ),
            );
          },
        ),

        const SizedBox(height: 24),

        // Primary CTA — "Link to Clinical Trial" / "Linking…" while busy.
        AppButton(
          label: _isLoading ? 'Linking…' : 'Link to Clinical Trial',
          variant: AppButtonVariant.primary,
          size: AppButtonSize.large,
          fullWidth: true,
          onPressed: _isReadyToSubmit ? _enroll : null,
          semanticId: 'enroll-submit',
        ),

        const SizedBox(height: 12),

        // Helper text — "Contact your study site if you need help finding…".
        Text(
          'Contact your study site if you need help finding your linking code.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: const Color(0xFF54636A),
            height: 19.5 / 13,
            fontSize: 13,
            letterSpacing: -0.1,
          ),
        ),
      ],
    );
  }
}

/// Success state — "You're linked to the study" (Figma Linked frame).
class _LinkedSuccessPanel extends StatelessWidget {
  const _LinkedSuccessPanel();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;
    return Semantics(
      identifier: 'enroll-success',
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 48),
          Center(
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: semantic.primaryLightSoft,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(Icons.person_outline, size: 60, color: cs.primary),
            ),
          ),
          const SizedBox(height: 24),
          const Center(
            child: Text(
              "You're linked\nto the study",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                height: 1.1,
                letterSpacing: -0.22,
                color: Color(0xFF04161E),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Center(
            child: Text(
              'Your app is now connected to your clinical trial. You can start recording your data.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 22.5 / 15,
                letterSpacing: -0.22,
                color: Color(0xFF54636A),
              ),
            ),
          ),
          const SizedBox(height: 32),
          AppButton(
            label: 'Continue',
            variant: AppButtonVariant.primary,
            size: AppButtonSize.large,
            fullWidth: true,
            onPressed: () => Navigator.of(context).pop(true),
            semanticId: 'enroll-continue',
          ),
        ],
      ),
    );
  }
}

/// Text input formatter that converts to uppercase. Kept exported for
/// backwards compatibility with consumers / tests that imported it from
/// this file before the AppCodeInput migration.
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
