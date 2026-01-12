// IMPLEMENTS REQUIREMENTS:
//   REQ-p00024: Portal User Roles and Permissions
//   REQ-d00035: Admin Dashboard Implementation
//
// Status badge widget - displays user status with color coding

import 'package:flutter/material.dart';

/// User status values
enum UserStatus {
  active,
  pending,
  revoked;

  static UserStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return UserStatus.active;
      case 'pending':
        return UserStatus.pending;
      case 'revoked':
      case 'inactive':
        return UserStatus.revoked;
      default:
        return UserStatus.pending;
    }
  }

  String get displayName {
    switch (this) {
      case UserStatus.active:
        return 'Active';
      case UserStatus.pending:
        return 'Pending';
      case UserStatus.revoked:
        return 'Inactive';
    }
  }
}

/// A colored badge for displaying user status
class StatusBadge extends StatelessWidget {
  final UserStatus status;
  final bool compact;

  const StatusBadge({super.key, required this.status, this.compact = false});

  /// Create from a status string (e.g., from API response)
  factory StatusBadge.fromString(String statusString, {bool compact = false}) {
    return StatusBadge(
      status: UserStatus.fromString(statusString),
      compact: compact,
    );
  }

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    Color borderColor;

    switch (status) {
      case UserStatus.active:
        bgColor = const Color(0xFFDCFCE7); // Green-100
        textColor = const Color(0xFF166534); // Green-800
        borderColor = const Color(0xFF22C55E); // Green-500
        break;
      case UserStatus.pending:
        bgColor = const Color(0xFFFEF9C3); // Yellow-100
        textColor = const Color(0xFF854D0E); // Yellow-800
        borderColor = const Color(0xFFEAB308); // Yellow-500
        break;
      case UserStatus.revoked:
        bgColor = const Color(0xFFFEE2E2); // Red-100
        textColor = const Color(0xFF991B1B); // Red-800
        borderColor = const Color(0xFFEF4444); // Red-500
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 10,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(
          color: textColor,
          fontSize: compact ? 11 : 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
