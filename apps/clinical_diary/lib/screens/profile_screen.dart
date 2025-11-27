// IMPLEMENTS REQUIREMENTS:
//   REQ-d00005: User Profile Screen Implementation

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
    this.enrollmentCode,
    this.enrollmentDateTime,
    this.enrollmentEndDateTime,
    super.key,
  });

  final VoidCallback onBack;
  final VoidCallback onStartClinicalTrialEnrollment;
  final VoidCallback onShowSettings;
  final VoidCallback onShareWithCureHHT;
  final VoidCallback onStopSharingWithCureHHT;
  final bool isEnrolledInTrial;
  final String? enrollmentCode;
  final DateTime? enrollmentDateTime;
  final DateTime? enrollmentEndDateTime;
  final String enrollmentStatus; // 'active' or 'ended'
  final bool isSharingWithCureHHT;
  final String userName;
  final ValueChanged<String> onUpdateUserName;

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
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: widget.onBack,
                        icon: const Icon(Icons.arrow_back),
                        tooltip: 'Back',
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'User Profile',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // CureHHT Logo placeholder
                  Icon(
                    Icons.medical_services,
                    size: 48,
                    color: colorScheme.primary,
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
                      // User Info Section
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
                                          decoration: const InputDecoration(
                                            hintText: 'Enter your name',
                                            isDense: true,
                                            contentPadding:
                                                EdgeInsets.symmetric(
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
                                        child: const Text('Cancel'),
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
                                        tooltip: 'Edit name',
                                      ),
                                    ],
                                  ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Settings Button
                      OutlinedButton.icon(
                        onPressed: widget.onShowSettings,
                        icon: const Icon(Icons.settings, size: 20),
                        label: const Text('Accessibility and Preferences'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Data Sharing Section
                      if (widget.isSharingWithCureHHT)
                        _buildSharingCard(theme)
                      else
                        OutlinedButton.icon(
                          onPressed: widget.onShareWithCureHHT,
                          icon: const Icon(Icons.share, size: 20),
                          label: const Text('Share with CureHHT'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                          ),
                        ),

                      const SizedBox(height: 24),

                      // Privacy & Data Protection Card
                      _buildPrivacyCard(theme),

                      const SizedBox(height: 24),

                      // Clinical Trial Section
                      Row(
                        children: [
                          Icon(
                            Icons.groups,
                            size: 20,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.8,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Clinical Trial',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      if (widget.isEnrolledInTrial)
                        _buildEnrollmentCard(theme)
                      else
                        OutlinedButton.icon(
                          onPressed: widget.onStartClinicalTrialEnrollment,
                          icon: const Icon(Icons.description, size: 20),
                          label: const Text('Enroll in Clinical Trial'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                          ),
                        ),
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

  Widget _buildEnrollmentCard(ThemeData theme) {
    final isActive = widget.enrollmentStatus == 'active';
    final bgColor = isActive ? Colors.green.shade50 : Colors.grey.shade100;
    final borderColor = isActive ? Colors.green.shade200 : Colors.grey.shade300;
    final iconBgColor = isActive ? Colors.green.shade100 : Colors.grey.shade200;
    final iconColor = isActive ? Colors.green.shade700 : Colors.grey.shade600;
    final textColor = isActive ? Colors.green.shade900 : Colors.grey.shade800;
    final subtextColor = isActive
        ? Colors.green.shade700
        : Colors.grey.shade600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          color: bgColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: borderColor),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Clinical Trial Logo placeholder
                Icon(
                  Icons.science,
                  size: 28,
                  color: subtextColor.withValues(alpha: 0.75),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: iconBgColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.check, size: 16, color: iconColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isActive
                                ? 'Enrolled in Clinical Trial'
                                : 'Clinical Trial Enrollment: Ended',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: textColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (widget.enrollmentCode != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Enrollment Code: ${_formatEnrollmentCode(widget.enrollmentCode!)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: subtextColor,
                                fontFamily: 'monospace',
                                fontSize: 11,
                              ),
                            ),
                          ],
                          if (widget.enrollmentDateTime != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Enrolled: ${_formatEnrollmentDateTime(widget.enrollmentDateTime!)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: subtextColor,
                                fontSize: 11,
                              ),
                            ),
                          ],
                          if (!isActive &&
                              widget.enrollmentEndDateTime != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Ended: ${_formatEnrollmentDateTime(widget.enrollmentEndDateTime!)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: subtextColor,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          color: Colors.blue.shade50,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.blue.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              isActive
                  ? 'Note: The logo displayed on the homescreen of the app is a reminder that you are sharing your data with a 3rd party.'
                  : 'Note: Data shared during clinical trial participation remains with researchers indefinitely for scientific analysis.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.blue.shade800,
                fontSize: 11,
              ),
            ),
          ),
        ),
      ],
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
