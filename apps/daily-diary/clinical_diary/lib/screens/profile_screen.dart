// IMPLEMENTS REQUIREMENTS:
//   REQ-d00005: User Profile Screen Implementation
//   REQ-CAL-p00076: Participation Status Badge

import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// User profile screen with enrollment status, data sharing, and settings
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
    this.enrollmentCode,
    this.enrollmentDateTime,
    this.enrollmentEndDateTime,
    this.siteName,
    this.sitePhoneNumber,
    super.key,
  });

  final VoidCallback onBack;
  final VoidCallback onStartClinicalTrialEnrollment;
  final VoidCallback onShowSettings;
  final VoidCallback onShareWithCureHHT;
  final VoidCallback onStopSharingWithCureHHT;
  final bool isEnrolledInTrial;
  final bool isDisconnected;
  final String? enrollmentCode;
  final DateTime? enrollmentDateTime;
  final DateTime? enrollmentEndDateTime;
  final String enrollmentStatus; // 'active', 'ended', or 'none'
  final bool isSharingWithCureHHT;
  final String userName;
  final ValueChanged<String> onUpdateUserName;
  final String? siteName;
  final String? sitePhoneNumber;

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

  String _getPrivacyText() {
    final isSharingWithCureHHT = widget.isSharingWithCureHHT;
    final isEnrolledInTrial = widget.isEnrolledInTrial;
    final enrollmentStatus = widget.enrollmentStatus;
    final enrollmentEndDateTime = widget.enrollmentEndDateTime;

    var text = 'Your health data is stored locally on your device.';

    if (isSharingWithCureHHT) {
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

    if (!isSharingWithCureHHT && !isEnrolledInTrial) {
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

                      // 3. REQ-CAL-p00076: Participation Status Badge or Enroll Button
                      if (widget.isEnrolledInTrial || widget.isDisconnected)
                        _buildParticipationStatusBadge(theme, l10n)
                      else
                        OutlinedButton.icon(
                          onPressed: widget.onStartClinicalTrialEnrollment,
                          icon: const Icon(Icons.description, size: 20),
                          label: Text(l10n.enrollInClinicalTrial),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                          ),
                        ),

                      const SizedBox(height: 24),

                      // 4. Data Sharing Section
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

                      const SizedBox(height: 24),

                      // 5. Privacy & Data Protection Card
                      _buildPrivacyCard(theme),
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
    final isActive = widget.isEnrolledInTrial && !widget.isDisconnected;
    final isDisconnected = widget.isDisconnected;

    Color bgColor;
    Color borderColor;
    Color iconBgColor;
    Color iconColor;
    Color textColor;
    Color subtextColor;
    IconData statusIcon;
    String statusText;
    String statusMessage;

    if (isDisconnected) {
      // Disconnected state - warning styling
      bgColor = Colors.orange.shade50;
      borderColor = Colors.orange.shade300;
      iconBgColor = Colors.orange.shade100;
      iconColor = Colors.orange.shade800;
      textColor = Colors.orange.shade900;
      subtextColor = Colors.orange.shade700;
      statusIcon = Icons.warning_amber_rounded;
      statusText = l10n.participationStatusDisconnected;
      statusMessage = l10n.participationStatusDisconnectedMessage;
    } else if (isActive) {
      // Active state - green styling
      bgColor = Colors.green.shade50;
      borderColor = Colors.green.shade200;
      iconBgColor = Colors.green.shade100;
      iconColor = Colors.green.shade700;
      textColor = Colors.green.shade900;
      subtextColor = Colors.green.shade700;
      statusIcon = Icons.check_circle;
      statusText = l10n.participationStatusActive;
      statusMessage = l10n.participationStatusActiveMessage;
    } else {
      // Not participating state - grey styling
      bgColor = Colors.grey.shade100;
      borderColor = Colors.grey.shade300;
      iconBgColor = Colors.grey.shade200;
      iconColor = Colors.grey.shade600;
      textColor = Colors.grey.shade800;
      subtextColor = Colors.grey.shade600;
      statusIcon = Icons.person_off;
      statusText = l10n.participationStatusNotParticipating;
      statusMessage = l10n.participationStatusNotParticipatingMessage;
    }

    return Card(
      color: bgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: isDisconnected ? 2 : 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Sponsor logo placeholder
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconBgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.science, size: 28, color: iconColor),
            ),
            const SizedBox(height: 12),

            // Status header row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(statusIcon, size: 20, color: iconColor),
                const SizedBox(width: 8),
                Text(
                  statusText,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Status message
            Text(
              statusMessage,
              style: theme.textTheme.bodySmall?.copyWith(color: subtextColor),
              textAlign: TextAlign.center,
            ),

            // Enrollment details (if enrolled)
            if (widget.isEnrolledInTrial) ...[
              const SizedBox(height: 12),
              if (widget.enrollmentCode != null)
                Text(
                  l10n.linkingCode(
                    _formatEnrollmentCode(widget.enrollmentCode!),
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
                    _formatEnrollmentDateTime(widget.enrollmentDateTime!),
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: subtextColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ],

            // Reconnect button for disconnected state
            if (isDisconnected) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: widget.onStartClinicalTrialEnrollment,
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
                  l10n.contactYourSiteWithName(widget.siteName!),
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
