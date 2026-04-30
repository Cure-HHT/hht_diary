// IMPLEMENTS REQUIREMENTS:
//   REQ-d00005: User Profile Screen Implementation
//   REQ-CAL-p00076: Participation Status Badge
//   REQ-p00045: Clinical Trial Privacy Policy

import 'package:clinical_diary/config/feature_flags.dart';
import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:clinical_diary/screens/clinical_trial_privacy_policy_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// User profile screen with linking status, data sharing, and settings
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    required this.onBack,
    required this.onStartClinicalTrialEnrollment,
    required this.onShowSettings,
    required this.onShareWithCureHHT,
    required this.onStopSharingWithCureHHT,
    required this.isEnrolledInTrial,
    required this.enrollmentStatus,
    required this.isSharingWithCureHHT,
    required this.userName,
    required this.onUpdateUserName,
    this.isDisconnected = false,
    this.isNotParticipating = false,
    this.enrollmentCode,
    this.enrollmentDateTime,
    this.enrollmentEndDateTime,
    this.siteName,
    this.sitePhoneNumber,
    this.sponsorLogo,
    super.key,
  });

  final VoidCallback onBack;
  final VoidCallback onStartClinicalTrialEnrollment;
  final VoidCallback onShowSettings;
  final VoidCallback onShareWithCureHHT;
  final VoidCallback onStopSharingWithCureHHT;
  final bool isEnrolledInTrial;
  final bool isDisconnected;
  // CUR-1165: True when sponsor portal has marked patient as not participating
  final bool isNotParticipating;
  final String? enrollmentCode;
  final DateTime? enrollmentDateTime;
  final DateTime? enrollmentEndDateTime;
  final String enrollmentStatus; // linking status: 'active', 'ended', or 'none'
  final bool isSharingWithCureHHT;
  final String userName;
  final ValueChanged<String> onUpdateUserName;
  final String? siteName;
  final String? sitePhoneNumber;
  final String? sponsorLogo;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isEditingName = false;
  late TextEditingController _nameController;
  final _nameFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.userName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  void _startEditing() {
    setState(() {
      _nameController.text = widget.userName;
      _isEditingName = true;
    });
    // Auto-focus after rebuild
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _nameFocusNode.requestFocus();
    });
  }

  void _cancelEditing() {
    setState(() {
      _nameController.text = widget.userName;
      _isEditingName = false;
    });
  }

  void _saveName() {
    final trimmedName = _nameController.text.trim();
    if (trimmedName.isNotEmpty) {
      widget.onUpdateUserName(trimmedName);
    } else {
      _nameController.text = widget.userName; // Reset to original if empty
    }
    setState(() {
      _isEditingName = false;
    });
  }

  void _openClinicalTrialPrivacyPolicy() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ClinicalTrialPrivacyPolicyScreen(),
      ),
    );
  }

  String _getPrivacyText() {
    final isSharingWithCureHHT = widget.isSharingWithCureHHT;
    final isEnrolledInTrial = widget.isEnrolledInTrial;
    final enrollmentStatus = widget.enrollmentStatus;
    final enrollmentEndDateTime = widget.enrollmentEndDateTime;

    // CUR-1116: sharing is only "active" when both the feature is enabled and
    // the user has opted in — mirrors the UI gate in build().
    final isEffectivelySharing =
        FeatureFlagService.instance.showShareWithCureHHT &&
        isSharingWithCureHHT;

    var text = 'Your health data is stored locally on your device.';

    if (isEffectivelySharing) {
      text += ' Anonymized data is shared with CureHHT for research purposes.';
    }

    if (isEnrolledInTrial && enrollmentStatus == 'active') {
      text +=
          ' Clinical trial participation involves sharing anonymized data with researchers according to the study protocol.';
    }

    if (isEnrolledInTrial &&
        enrollmentStatus == 'ended' &&
        enrollmentEndDateTime != null) {
      final endDateStr = DateFormat.yMMMd().format(enrollmentEndDateTime);
      text +=
          ' Clinical trial participation ended on $endDateStr. Previously shared data remains with researchers indefinitely for scientific analysis.';
    }

    if (!isEffectivelySharing && !isEnrolledInTrial) {
      text +=
          ' No data is shared with external parties unless you choose to participate in research or clinical trials.';
    }

    return text;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: widget.onBack,
                    icon: const Icon(Icons.arrow_back),
                    tooltip: l10n.back,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.profile,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. User Info Section (Name)
                      Row(
                        children: [
                          Icon(
                            Icons.person,
                            size: 20,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _isEditingName
                                ? Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: _nameController,
                                          focusNode: _nameFocusNode,
                                          decoration: InputDecoration(
                                            hintText: l10n.enterYourName,
                                            isDense: true,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 8,
                                                ),
                                          ),
                                          onSubmitted: (_) => _saveName(),
                                          onEditingComplete: _saveName,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      TextButton(
                                        onPressed: _cancelEditing,
                                        child: Text(l10n.cancel),
                                      ),
                                    ],
                                  )
                                : Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          widget.userName,
                                          style: theme.textTheme.titleMedium,
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: _startEditing,
                                        icon: const Icon(Icons.edit, size: 20),
                                        tooltip: l10n.editName,
                                      ),
                                    ],
                                  ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // 2. Accessibility & Preferences Button
                      OutlinedButton.icon(
                        onPressed: widget.onShowSettings,
                        icon: const Icon(Icons.settings, size: 20),
                        label: Text(l10n.accessibilityAndPreferences),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // 3. REQ-CAL-p00076: Participation Status Badge or Link Button
                      // CUR-1165: Hide enroll button when not_participating — this
                      // is not a disconnection; patient should not re-enroll.
                      if ((!widget.isEnrolledInTrial ||
                              widget.isDisconnected) &&
                          !widget.isNotParticipating) ...[
                        OutlinedButton.icon(
                          onPressed: widget.onStartClinicalTrialEnrollment,
                          icon: const Icon(Icons.description, size: 20),
                          label: Text(l10n.enrollInClinicalTrial),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                          ),
                        ),

                        const SizedBox(height: 24),
                      ],

                      // 4. Data Sharing Section
                      // CUR-1116: Hidden behind FeatureFlagService.showShareWithCureHHT flag.
                      if (FeatureFlagService.instance.showShareWithCureHHT) ...[
                        if (widget.isSharingWithCureHHT)
                          _buildSharingCard(theme)
                        else
                          OutlinedButton.icon(
                            onPressed: widget.onShareWithCureHHT,
                            icon: const Icon(Icons.share, size: 20),
                            label: Text(l10n.shareWithCureHHT),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 48),
                            ),
                          ),
                      ],
                      const SizedBox(height: 24),

                      // 5. Privacy & Data Protection Card
                      _buildPrivacyCard(theme),
                      const SizedBox(height: 24),
                      if (widget.isEnrolledInTrial ||
                          widget.isDisconnected ||
                          widget.isNotParticipating)
                        _buildParticipationStatusBadge(theme, l10n),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// REQ-CAL-p00076: Build the participation status badge
  Widget _buildParticipationStatusBadge(
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    // Determine status and colors
    final isNotParticipating = widget.isNotParticipating;
    final isDisconnected = widget.isDisconnected;
    // CUR-1165: not_participating is distinct from active — exclude it explicitly
    final isActive =
        widget.isEnrolledInTrial && !isDisconnected && !isNotParticipating;

    Color bgColor;
    Color borderColor;
    Color iconColor;
    Color subtextColor;
    IconData statusIcon;
    String statusMessage;

    if (isDisconnected) {
      // Disconnected state - exact brand colors
      bgColor = const Color(0xFFFFFBEA);
      borderColor = Colors.amber.shade300;
      iconColor = Colors.amber.shade700;
      subtextColor = const Color(0xFF7B3306);
      statusIcon = Icons.warning_amber_rounded;
      statusMessage = l10n.participationStatusDisconnectedMessage;
    } else if (isNotParticipating) {
      // CUR-1165: Not participating state — grey/inactive styling (GUI-p00076)
      bgColor = const Color(0xFFF9FAFB);
      borderColor = const Color(0xFFE7E8EC);
      iconColor = const Color(0xFF586170);
      subtextColor = const Color(0xFF586170);
      statusIcon = Icons.check;
      statusMessage = l10n.participationStatusNotParticipatingMessage;
    } else if (isActive) {
      // Active state - green styling
      bgColor = Colors.green.shade50;
      borderColor = Colors.green.shade200;
      iconColor = Colors.green.shade700;
      subtextColor = Colors.green.shade700;
      statusIcon = Icons.check;
      statusMessage = l10n.participationStatusActiveMessage;
    } else {
      // Fallback: enrolled but status unknown
      bgColor = Colors.grey.shade100;
      borderColor = Colors.grey.shade300;
      iconColor = Colors.grey.shade600;
      subtextColor = Colors.grey.shade600;
      statusIcon = Icons.person_off;
      statusMessage = l10n.participationStatusNotParticipatingMessage;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Image.asset('assets/images/users.png'),
            const SizedBox(width: 12),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.clinicalTrialLabel,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Card(
          color: bgColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: borderColor, width: isDisconnected ? 2 : 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isNotParticipating) ...[
                  // CUR-1165: Not-participating clean layout matching design
                  if (widget.sponsorLogo != null)
                    Center(
                      child: Image.network(
                        widget.sponsorLogo!,
                        height: 60,
                        errorBuilder: (context, _, _) =>
                            const SizedBox(height: 60),
                      ),
                    )
                  else
                    const SizedBox(),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        height: 40,
                        width: 40,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFF3F4F6),
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Color(0xFF586170),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          statusMessage,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF212C3B),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (widget.enrollmentCode != null)
                    Text(
                      l10n.linkingCode(
                        _formatEnrollmentCode(widget.enrollmentCode!),
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF586170),
                        fontFamily: 'monospace',
                      ),
                    ),
                  if (widget.enrollmentDateTime != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      l10n.joinedDate(
                        _formatEnrollmentDateTime(widget.enrollmentDateTime!),
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF586170),
                      ),
                    ),
                  ],
                  if (widget.enrollmentEndDateTime != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      l10n.endedDate(
                        _formatEnrollmentDateTime(
                          widget.enrollmentEndDateTime!,
                        ),
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF586170),
                      ),
                    ),
                  ],
                ] else ...[
                  // Active / disconnected states: existing layout
                  if (widget.sponsorLogo != null)
                    Image.network(
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
                  else
                    const SizedBox(),
                  const SizedBox(height: 12),

                if (isDisconnected) ...[
                  // Disconnected layout: icon + bold title, then code + body + button
                  Row(
                    children: [
                      Container(
                        height: 40,
                        width: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.amber.shade100,
                        ),
                        child: Icon(statusIcon, color: iconColor, size: 22),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          l10n.connectionIssueDetected,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF7B3306),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (widget.enrollmentCode != null)
                    Text(
                      l10n.currentCode(
                        _formatEnrollmentCode(widget.enrollmentCode!),
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFFC05C0D),
                        fontFamily: 'monospace',
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.connectionIssueBody,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF7B3306),
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: widget.onStartClinicalTrialEnrollment,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                      backgroundColor: const Color(0xFFF6F8F5),
                      foregroundColor: const Color(0xFF7B3306),
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      l10n.enterNewLinkingCode,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF7B3306),
                      ),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        height: 40,
                        width: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: borderColor,
                        ),
                        child: Icon(statusIcon, color: iconColor),
                      ),
                      const SizedBox(width: 20),
                      Flexible(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              statusMessage,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: subtextColor,
                              ),
                              textAlign: TextAlign.start,
                            ),

                            // Linking details (if linked)
                            if (widget.isEnrolledInTrial) ...[
                              const SizedBox(height: 5),
                              if (widget.enrollmentCode != null)
                                Text(
                                  l10n.linkingCode(
                                    _formatEnrollmentCode(
                                      widget.enrollmentCode!,
                                    ),
                                  ),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: subtextColor,
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                  ),
                                ),
                              if (widget.enrollmentDateTime != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  l10n.joinedDate(
                                    _formatEnrollmentDateTime(
                                      widget.enrollmentDateTime!,
                                    ),
                                  ),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: subtextColor,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                              // CUR-1165: Show end date when not_participating (GUI-p00076)
                              if (widget.enrollmentEndDateTime != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  l10n.endedDate(
                                    _formatEnrollmentDateTime(
                                      widget.enrollmentEndDateTime!,
                                    ),
                                  ),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: subtextColor,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],

                            // REQ-p00045: Clinical Trial Privacy Policy link
                            const SizedBox(height: 12),
                            InkWell(
                              onTap: _openClinicalTrialPrivacyPolicy,
                              borderRadius: BorderRadius.circular(4),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.open_in_new,
                                      size: 14,
                                      color: subtextColor,
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        l10n.viewClinicalTrialPrivacyPolicy,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: subtextColor,
                                              decoration:
                                                  TextDecoration.underline,
                                              fontWeight: FontWeight.w500,
                                              fontSize: 12,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Reconnect button for disconnected state
                            if (isDisconnected) ...[
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed:
                                    widget.onStartClinicalTrialEnrollment,
                                icon: const Icon(Icons.link, size: 18),
                                label: Text(l10n.enterNewLinkingCode),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange.shade600,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(double.infinity, 44),
                                ),
                              ),
                              if (widget.siteName != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  l10n.contactYourSiteWithName(
                                    widget.siteName!,
                                  ),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: subtextColor,
                                    fontSize: 11,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSharingCard(ThemeData theme) {
    return Card(
      color: Colors.blue.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.blue.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check, size: 16, color: Colors.blue.shade700),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Sharing with CureHHT',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: Colors.blue.shade900,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: widget.onStopSharingWithCureHHT,
                    icon: const Icon(Icons.share, size: 20),
                    label: const Text('Stop Sharing with CureHHT'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 40),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacyCard(ThemeData theme) {
    return Card(
      color: Colors.blue.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.blue.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Privacy & Data Protection',
              style: theme.textTheme.titleSmall?.copyWith(
                color: Colors.blue.shade900,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _getPrivacyText(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.blue.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatEnrollmentCode(String code) {
    if (code.length >= 5) {
      return '${code.substring(0, 5)}-${code.substring(5)}';
    }
    return code;
  }

  String _formatEnrollmentDateTime(DateTime dateTime) {
    final date = DateFormat.yMMMd().format(dateTime);
    final time = DateFormat.jm().format(dateTime); // 12-hour format with AM/PM
    return '$date at $time';
  }
}
