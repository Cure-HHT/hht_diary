import '../models/audit_entry_view.dart';
import '../models/portal_user_view.dart';
import '../models/role_assignment_view.dart';
import '../models/user_status_view.dart';

/// Mock data fixtures used by tests + the example preview app.
///
/// Mirrors the example users + audit entries shown in the redesign Figma
/// (CUR-1450) so we can preview screens against the spec without spinning
/// up the WebSocket / HTTP layer. Tests should prefer these over inlining
/// new instances — keeps a single source of truth for "what the data looks
/// like" and makes intent obvious in test names.
class MockData {
  const MockData._();

  // ---------------------------------------------------------------------------
  // Role assignments — building blocks shared across the user fixtures.
  // ---------------------------------------------------------------------------

  /// Wildcard "all sites" Administrator assignment.
  static const RoleAssignmentView _adminWildcard = RoleAssignmentView(
    role: 'Administrator',
    boundSites: <String>[],
    isWildcard: true,
  );

  /// Study Coordinator at two sites.
  static const RoleAssignmentView _studyCoordTwoSites = RoleAssignmentView(
    role: 'StudyCoordinator',
    boundSites: <String>['site-1', 'site-2'],
    isWildcard: false,
  );

  /// CRA at six sites — matches the Figma's "6 sites assigned" rows.
  static const RoleAssignmentView _craSixSites = RoleAssignmentView(
    role: 'CRA',
    boundSites: <String>[
      'site-1',
      'site-2',
      'site-3',
      'site-4',
      'site-5',
      'site-6',
    ],
    isWildcard: false,
  );

  // ---------------------------------------------------------------------------
  // Users — covers all four lifecycle states surfaced in the UI:
  //   active, pending, revoked (= "Inactive" tab), locked.
  // ---------------------------------------------------------------------------

  static const PortalUserView adminUser = PortalUserView(
    email: 'admin@clinicaltrial.com',
    name: 'Admin User',
    status: UserStatusView.active,
    assignments: <RoleAssignmentView>[_adminWildcard],
  );

  static const PortalUserView emilyParker = PortalUserView(
    email: 'eparker@clinicaltrial.com',
    name: 'Dr. Emily Parker',
    status: UserStatusView.active,
    assignments: <RoleAssignmentView>[_adminWildcard, _studyCoordTwoSites],
  );

  static const PortalUserView sarahJohnson = PortalUserView(
    email: 'sjohnson@clinicaltrial.com',
    name: 'Dr. Sarah Johnson',
    status: UserStatusView.active,
    assignments: <RoleAssignmentView>[_studyCoordTwoSites],
  );

  static const PortalUserView jenniferMartinezPending = PortalUserView(
    email: 'jmartinez@clinicaltrial.com',
    name: 'Jennifer Martinez',
    status: UserStatusView.pending,
    assignments: <RoleAssignmentView>[_craSixSites, _studyCoordTwoSites],
  );

  static const PortalUserView sarahJohnsonInactive = PortalUserView(
    email: 'sjohnson-old@clinicaltrial.com',
    name: 'Dr. Sarah Johnson',
    status: UserStatusView.revoked,
    assignments: <RoleAssignmentView>[_studyCoordTwoSites],
  );

  static const PortalUserView lockedUser = PortalUserView(
    email: 'locked@clinicaltrial.com',
    name: 'Locked Out User',
    status: UserStatusView.locked,
    assignments: <RoleAssignmentView>[_studyCoordTwoSites],
  );

  /// A pending user with no role assignments yet. Useful for previewing the
  /// "freshly invited, awaiting first role assignment" state.
  static const PortalUserView pendingNoRoles = PortalUserView(
    email: 'newinvite@clinicaltrial.com',
    name: 'New Invite',
    status: UserStatusView.pending,
    assignments: <RoleAssignmentView>[],
  );

  /// Additional sample users — pads the directory past the default
  /// pageSize=8 so the example app exercises pagination across multiple
  /// pages and the per-status counts spread realistically.
  static const PortalUserView _michaelChen = PortalUserView(
    email: 'mchen@clinicaltrial.com',
    name: 'Dr. Michael Chen',
    status: UserStatusView.active,
    assignments: <RoleAssignmentView>[_craSixSites],
  );

  static const PortalUserView _priyaPatel = PortalUserView(
    email: 'ppatel@clinicaltrial.com',
    name: 'Priya Patel',
    status: UserStatusView.active,
    assignments: <RoleAssignmentView>[_studyCoordTwoSites],
  );

  static const PortalUserView _carlosRivera = PortalUserView(
    email: 'crivera@clinicaltrial.com',
    name: 'Carlos Rivera',
    status: UserStatusView.active,
    assignments: <RoleAssignmentView>[
      RoleAssignmentView(
        role: 'CRA',
        boundSites: <String>['site-2', 'site-3'],
        isWildcard: false,
      ),
    ],
  );

  static const PortalUserView _amaraOkafor = PortalUserView(
    email: 'aokafor@clinicaltrial.com',
    name: 'Amara Okafor',
    status: UserStatusView.active,
    assignments: <RoleAssignmentView>[_adminWildcard],
  );

  static const PortalUserView _lucasMoreau = PortalUserView(
    email: 'lmoreau@clinicaltrial.com',
    name: 'Lucas Moreau',
    status: UserStatusView.pending,
    assignments: <RoleAssignmentView>[_studyCoordTwoSites],
  );

  static const PortalUserView _ninaHansen = PortalUserView(
    email: 'nhansen@clinicaltrial.com',
    name: 'Nina Hansen',
    status: UserStatusView.pending,
    assignments: <RoleAssignmentView>[
      RoleAssignmentView(
        role: 'CRA',
        boundSites: <String>['site-1'],
        isWildcard: false,
      ),
    ],
  );

  static const PortalUserView _omarHaddad = PortalUserView(
    email: 'ohaddad@clinicaltrial.com',
    name: 'Omar Haddad',
    status: UserStatusView.active,
    assignments: <RoleAssignmentView>[_craSixSites, _studyCoordTwoSites],
  );

  static const PortalUserView _ireneLi = PortalUserView(
    email: 'ili@clinicaltrial.com',
    name: 'Irene Li',
    status: UserStatusView.revoked,
    assignments: <RoleAssignmentView>[_studyCoordTwoSites],
  );

  static const PortalUserView _benRoss = PortalUserView(
    email: 'bross@clinicaltrial.com',
    name: 'Ben Ross',
    status: UserStatusView.revoked,
    assignments: <RoleAssignmentView>[
      RoleAssignmentView(
        role: 'CRA',
        boundSites: <String>['site-4'],
        isWildcard: false,
      ),
    ],
  );

  static const PortalUserView _hannahWebb = PortalUserView(
    email: 'hwebb@clinicaltrial.com',
    name: 'Hannah Webb',
    status: UserStatusView.locked,
    assignments: <RoleAssignmentView>[_studyCoordTwoSites],
  );

  static const PortalUserView _devKapoor = PortalUserView(
    email: 'dkapoor@clinicaltrial.com',
    name: 'Dev Kapoor',
    status: UserStatusView.active,
    assignments: <RoleAssignmentView>[_studyCoordTwoSites, _craSixSites],
  );

  static const PortalUserView _elenaVargas = PortalUserView(
    email: 'evargas@clinicaltrial.com',
    name: 'Elena Vargas',
    status: UserStatusView.active,
    assignments: <RoleAssignmentView>[_studyCoordTwoSites],
  );

  static const PortalUserView _terryWilson = PortalUserView(
    email: 'twilson@clinicaltrial.com',
    name: 'Terry Wilson',
    status: UserStatusView.active,
    assignments: <RoleAssignmentView>[_adminWildcard],
  );

  static const PortalUserView _yukoTanaka = PortalUserView(
    email: 'ytanaka@clinicaltrial.com',
    name: 'Yuko Tanaka',
    status: UserStatusView.pending,
    assignments: <RoleAssignmentView>[
      RoleAssignmentView(
        role: 'CRA',
        boundSites: <String>['site-5', 'site-6'],
        isWildcard: false,
      ),
    ],
  );

  /// Combined sample list — covers all four lifecycle states with
  /// single-role / multi-role / wildcard / site-bound mixes, and is long
  /// enough that the default pageSize=8 spills onto 3 pages.
  static const List<PortalUserView> users = <PortalUserView>[
    adminUser,
    emilyParker,
    sarahJohnson,
    jenniferMartinezPending,
    sarahJohnsonInactive,
    lockedUser,
    pendingNoRoles,
    _michaelChen,
    _priyaPatel,
    _carlosRivera,
    _amaraOkafor,
    _lucasMoreau,
    _ninaHansen,
    _omarHaddad,
    _ireneLi,
    _benRoss,
    _hannahWebb,
    _devKapoor,
    _elenaVargas,
    _terryWilson,
    _yukoTanaka,
  ];

  // ---------------------------------------------------------------------------
  // Audit entries — mirrors the Figma's Audit Logs table.
  // ---------------------------------------------------------------------------

  static final AuditEntryView _createdEmily = AuditEntryView(
    id: 'audit-001',
    timestamp: DateTime.utc(2024, 10, 16, 7, 30),
    actorName: 'Terry Wilson',
    actorRole: 'Admin',
    activityLabel: 'Created user account for Dr. Emily Parker',
    raw: const <String, dynamic>{
      'event_id': 'audit-001',
      'entry_type': 'user_account_created',
      'initiator': <String, dynamic>{
        'kind': 'user',
        'label': 'terry.wilson@clinicaltrial.com',
      },
      'data': <String, dynamic>{'target_email': 'eparker@clinicaltrial.com'},
    },
  );

  static final AuditEntryView _activationEmail = AuditEntryView(
    id: 'audit-002',
    timestamp: DateTime.utc(2024, 10, 16, 6, 15),
    actorName: 'Elvira Koliadina',
    actorRole: 'Admin',
    activityLabel: 'Activation email sent to Dr. Emily Parker',
    raw: const <String, dynamic>{
      'event_id': 'audit-002',
      'entry_type': 'activation_email_sent',
      'initiator': <String, dynamic>{
        'kind': 'user',
        'label': 'elvira.k@clinicaltrial.com',
      },
    },
  );

  static final AuditEntryView _modifiedSarah = AuditEntryView(
    id: 'audit-003',
    timestamp: DateTime.utc(2024, 10, 15, 9, 45),
    actorName: 'Bob Smith',
    actorRole: 'Admin',
    activityLabel: 'Modified user account for Dr. Sarah Johnson',
    raw: const <String, dynamic>{
      'event_id': 'audit-003',
      'entry_type': 'user_account_modified',
    },
  );

  static final AuditEntryView _deactivatedJohn = AuditEntryView(
    id: 'audit-004',
    timestamp: DateTime.utc(2024, 10, 15, 4, 30),
    actorName: 'Jordan Johns',
    actorRole: 'Admin',
    activityLabel: 'Deactivated user account for John Smith',
    raw: const <String, dynamic>{
      'event_id': 'audit-004',
      'entry_type': 'user_account_deactivated',
    },
  );

  static final AuditEntryView _reactivatedMichael = AuditEntryView(
    id: 'audit-005',
    timestamp: DateTime.utc(2024, 10, 14, 8, 10),
    actorName: 'Sarah Lee',
    actorRole: 'Admin',
    activityLabel: 'Reactivated user account for Dr. Michael Chen',
    raw: const <String, dynamic>{
      'event_id': 'audit-005',
      'entry_type': 'user_account_reactivated',
    },
  );

  /// Automation-initiated entry — exercises the "no actor name" branch
  /// (the Figma doesn't show this; included so the row renderer is
  /// pre-tested against the case).
  static final AuditEntryView _automationEdcSync = AuditEntryView(
    id: 'audit-006',
    timestamp: DateTime.utc(2026, 6, 1, 15, 43, 3),
    actorName: '',
    actorRole: '',
    activityLabel: 'EDC sync succeeded',
    raw: const <String, dynamic>{
      'event_id': '10d232a-992f-4d5d-b4bd-39ca99c6e600',
      'entry_type': 'edc_sync_succeeded',
      'initiator': <String, dynamic>{'kind': 'automation', 'label': 'edc_sync'},
      'data': <String, dynamic>{
        'consecutive_auth_failures': 0,
        'sites_count': 3,
        'participants_count': 33,
      },
    },
  );

  /// Combined audit log — 6 entries in reverse-chronological order.
  static final List<AuditEntryView> auditEntries = <AuditEntryView>[
    _automationEdcSync,
    _createdEmily,
    _activationEmail,
    _modifiedSarah,
    _deactivatedJohn,
    _reactivatedMichael,
  ];
}
