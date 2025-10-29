// IMPLEMENTS REQUIREMENTS:
//   REQ-p00030: Role-Based Visual Indicators
//   REQ-d00052: Role-Based Banner Component

import 'package:flutter/material.dart';

import '../services/auth_service.dart';

/// Role-to-color mapping for visual role indication
/// Colors selected for accessibility (WCAG AA contrast with white text)
const Map<UserRole, Color> roleColors = {
  UserRole.admin: Color(0xFFF44336), // Red
  UserRole.investigator: Color(0xFF4CAF50), // Green
  UserRole.auditor: Color(0xFFFF9800), // Orange
};

/// Role display names for banner
const Map<UserRole, String> roleDisplayNames = {
  UserRole.admin: 'ADMINISTRATOR',
  UserRole.investigator: 'INVESTIGATOR',
  UserRole.auditor: 'AUDITOR',
};

/// A prominent banner that displays the current user's role with color coding
///
/// Displays at the top of authenticated pages to prevent accidental actions
/// in the wrong role context. Uses standardized colors across all sponsors.
class RoleBanner extends StatelessWidget {
  final UserRole role;

  const RoleBanner({
    super.key,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    final color = roleColors[role] ?? Colors.grey;
    final displayName = roleDisplayNames[role] ?? role.name.toUpperCase();

    return Container(
      height: 48,
      width: double.infinity,
      color: color,
      child: Center(
        child: Text(
          displayName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}
