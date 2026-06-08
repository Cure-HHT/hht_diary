// Implements: DIARY-DEV-shared-events-catalog/A+B+C+E
import 'package:event_sourcing/event_sourcing.dart';

EntryTypeDefinition _e(String id, String name) =>
    EntryTypeDefinition(id: id, registeredVersion: 1, name: name);

/// Every [home: portal] private event entry type (spec §4.2-§4.14).
final List<EntryTypeDefinition> portalPrivateEventTypes = <EntryTypeDefinition>[
  // 4.2 portal_user
  _e('user_created', 'User Created'),
  _e('user_activation_code_issued', 'User Activation Code Issued'),
  _e('user_activated', 'User Activated'),
  _e('user_profile_changed', 'User Profile Changed'),
  _e('user_email_change_requested', 'User Email Change Requested'),
  _e('user_email_changed', 'User Email Changed'),
  _e('user_deactivated', 'User Deactivated'),
  _e('user_reactivated', 'User Reactivated'),
  _e('user_sessions_revoked', 'User Sessions Revoked'),
  _e('user_mfa_enrolled', 'User MFA Enrolled'),
  _e('user_account_unlocked', 'User Account Unlocked'),
  _e('user_password_reset_requested', 'User Password Reset Requested'),
  _e('user_password_reset_completed', 'User Password Reset Completed'),
  _e('user_password_expired', 'User Password Expired'),
  _e('user_deleted', 'User Deleted'),
  _e('user_login_otp_issued', 'User Login OTP Issued'),
  _e('user_login_otp_verified', 'User Login OTP Verified'),
  _e('user_login_otp_failed', 'User Login OTP Failed'),
  // 4.4 session
  _e('session_started', 'Session Started'),
  _e('session_terminated', 'Session Terminated'),
  // 4.3 rbac
  _e('permission_registered', 'Permission Registered'),
  _e('role_permission_granted', 'Role Permission Granted'),
  _e('role_permission_revoked', 'Role Permission Revoked'),
  // 4.6 site
  _e('site_synced_from_edc', 'Site Synced From EDC'),
  // 4.7 rave_sync
  _e('edc_sync_succeeded', 'EDC Sync Succeeded'),
  _e('edc_sync_failed', 'EDC Sync Failed'),
  _e('rave_auth_failed', 'RAVE Auth Failed'),
  _e('rave_hard_lockout_triggered', 'RAVE Hard Lockout Triggered'),
  _e('rave_unwedged', 'RAVE Unwedged'),
  // 4.10 investigator_annotation
  _e('annotation_created', 'Annotation Created'),
  _e('annotation_resolved', 'Annotation Resolved'),
  _e('annotation_replied', 'Annotation Replied'),
  // 4.11 break_glass
  _e('break_glass_granted', 'Break Glass Granted'),
  _e('break_glass_revoked', 'Break Glass Revoked'),
  _e('break_glass_access_recorded', 'Break Glass Access Recorded'),
  // 4.12 auditor_export
  _e('auditor_export_recorded', 'Auditor Export Recorded'),
  // 4.13 email
  _e('email_sent', 'Email Sent'),
  _e('email_failed', 'Email Failed'),
  // 4.14 system_config
  _e('system_config_changed', 'System Config Changed'),
  // 4.2 portal_user (operator-tier authz)
  _e('user_tier_changed', 'User Tier Changed'),
  // Implements: DIARY-DEV-sponsor-branding-source/A — event-sourced sponsor
  //   branding (metadata + asset manifest; image bytes never in the log).
  _e('sponsor_branding_configured', 'Sponsor Branding Configured'),
];
