import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

WidgetbookComponent appDataTableComponent() {
  return WidgetbookComponent(
    name: 'AppDataTable + AppTableTabs + AppTablePagination',
    useCases: [
      WidgetbookUseCase(
        name: 'Gallery — User Management + Audit Logs mocks',
        builder: (_) => const _TableGallery(),
      ),
    ],
  );
}

class _User {
  final String name;
  final String email;
  final String role;
  final String status;
  const _User(this.name, this.email, this.role, this.status);
}

class _AuditEntry {
  final String timestamp;
  final String user;
  final String userRole;
  final String activity;
  const _AuditEntry(this.timestamp, this.user, this.userRole, this.activity);
}

const _users = [
  _User('Admin User', 'admin@clinicaltrial.com', 'Admin', 'Active'),
  _User('Dr. Emily Parker', 'eparker@clinicaltrial.com', 'Admin', 'Active'),
  _User(
    'Dr. Sarah Johnson',
    'sjohnson@clinicaltrial.com',
    'Site Study Coordinator',
    'Active',
  ),
  _User('Jennifer Martinez', 'jmartinez@clinicaltrial.com', 'CRA', 'Pending'),
  _User(
    'Dr. Sarah Johnson',
    'sjohnson@clinicaltrial.com',
    'Site Study Coordinator',
    'Inactive',
  ),
  _User('Jennifer Martinez', 'jmartinez@clinicaltrial.com', 'Admin', 'Pending'),
  _User('Jennifer Martinez', 'jmartinez@clinicaltrial.com', 'CRA', 'Pending'),
  _User('Jennifer Martinez', 'jmartinez@clinicaltrial.com', 'Admin', 'Pending'),
];

const _audit = [
  _AuditEntry(
    'Oct 16, 2024, 07:30 AM',
    'Terry Wilson',
    'Admin',
    'Created user account for Dr. Emily Parker',
  ),
  _AuditEntry(
    'Oct 16, 2024, 06:15 AM',
    'Elvira Koliadina',
    'Admin',
    'Activation email sent to Dr. Emily Parker',
  ),
  _AuditEntry(
    'Oct 15, 2024, 09:45 AM',
    'Bob Smith',
    'Admin',
    'Modified user account for Dr. Sarah Johnson',
  ),
  _AuditEntry(
    'Oct 15, 2024, 04:30 AM',
    'Jordan Johns',
    'Admin',
    'Deactivated user account for John Smith',
  ),
  _AuditEntry(
    'Oct 14, 2024, 08:10 AM',
    'Sarah Lee',
    'Admin',
    'Reactivated user account for Dr. Michael Chen',
  ),
];

const _tabs = [
  AppTableTab(key: 'all', label: 'All users', count: 18),
  AppTableTab(key: 'active', label: 'Active', count: 12),
  AppTableTab(key: 'pending', label: 'Pending', count: 2),
  AppTableTab(key: 'inactive', label: 'Inactive', count: 4),
];

class _TableGallery extends StatefulWidget {
  const _TableGallery();

  @override
  State<_TableGallery> createState() => _TableGalleryState();
}

class _TableGalleryState extends State<_TableGallery> {
  String _activeTab = 'all';
  int _userPage = 1;
  int _userPageSize = 8;
  int _auditPage = 1;
  int _auditPageSize = 8;
  String? _sortKey;
  SortDirection? _sortDir;

  // Per-column overrides. All cells inherit Inter Medium 14 / 20 / -0.15 /
  // Dark Grey from the table's row default; these columns override weight
  // and/or color.
  static const _nameStyle = TextStyle(fontWeight: FontWeight.w500); // Black
  static const _emailStyle = TextStyle(fontWeight: FontWeight.w400); // Black
  static const _sitesStyle = TextStyle(
    fontWeight: FontWeight.w400,
  ); // Dark Grey (default)

  late final List<AppTableColumn<_User>> _userColumns = [
    AppTableColumn(
      key: 'name',
      label: 'Name',
      sortable: true,
      // Names: Inter Medium 14 black.
      textStyle: _nameStyle.copyWith(
        color: Theme.of(context).colorScheme.onSurface,
      ),
      cellBuilder: (_, u) => Text(u.name),
    ),
    AppTableColumn(
      key: 'email',
      label: 'Email',
      // Emails: Inter Regular 14 black.
      textStyle: _emailStyle.copyWith(
        color: Theme.of(context).colorScheme.onSurface,
      ),
      cellBuilder: (_, u) => Text(u.email),
    ),
    AppTableColumn(
      key: 'role',
      label: 'Roles',
      width: 280,
      cellBuilder: (_, u) => Text(u.role),
    ),
    AppTableColumn(
      key: 'sites',
      label: 'Sites',
      width: 140,
      // Sites: Inter Regular 14 Dark Grey.
      textStyle: _sitesStyle,
      cellBuilder: (ctx, _) {
        // Demo: empty cells render as a muted "No sites" label.
        const sites = 2;
        if (sites == 0) {
          return Text(
            'No sites',
            style: TextStyle(color: Theme.of(ctx).colorScheme.outline),
          );
        }
        return const Text('$sites sites assigned');
      },
    ),
    AppTableColumn(
      key: 'status',
      label: 'Status',
      width: 120,
      headerTrailing: Icon(
        Icons.info_outline,
        size: 14,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      cellBuilder: (_, u) => Text(u.status),
    ),
  ];

  late final List<AppTableColumn<_AuditEntry>> _auditColumns = [
    AppTableColumn(
      key: 'timestamp',
      label: 'Timestamp',
      width: 240,
      cellBuilder: (_, e) => Text(e.timestamp),
    ),
    AppTableColumn(
      key: 'user',
      label: 'User',
      width: 240,
      cellBuilder: (ctx, e) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            e.user,
            style: Theme.of(
              ctx,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          Text(
            e.userRole,
            style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
              color: Theme.of(ctx).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ),
    AppTableColumn(
      key: 'activity',
      label: 'Activity',
      cellBuilder: (_, e) => Text(e.activity),
    ),
    AppTableColumn(
      key: 'actions',
      label: '',
      width: 120,
      alignment: Alignment.centerRight,
      cellBuilder: (ctx, _) => InkWell(
        onTap: () {},
        child: Text(
          'View details',
          style: TextStyle(color: Theme.of(ctx).colorScheme.primary),
        ),
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('AppDataTable — Gallery', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          'Structured slots: searchField (top-left) + paginationControls '
          '(top-right) + tabs (below). Two mocks below: User Management with '
          'tabs, Audit Logs without.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 32),

        Text('User Management', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        AppDataTable<_User>(
          searchField: AppTextField.search(hintText: 'Search by email'),
          paginationControls: AppTablePagination(
            currentPage: _userPage,
            pageSize: _userPageSize,
            totalCount: 18,
            pageSizeOptions: const [8, 16, 32],
            onPageChanged: (p) => setState(() => _userPage = p),
            onPageSizeChanged: (s) => setState(() {
              _userPageSize = s;
              _userPage = 1;
            }),
          ),
          tabs: AppTableTabs(
            tabs: _tabs,
            activeKey: _activeTab,
            onTap: (k) => setState(() => _activeTab = k),
          ),
          columns: _userColumns,
          rows: _users,
          sortColumnKey: _sortKey,
          sortDirection: _sortDir,
          onSort: (record) => setState(() {
            _sortKey = record.key;
            _sortDir = record.direction;
          }),
          // Whole-row grey when the user is Inactive.
          isRowInactive: (u) => u.status == 'Inactive',
        ),

        const SizedBox(height: 48),

        Text('Audit Logs', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        AppDataTable<_AuditEntry>(
          searchField: AppTextField.search(hintText: 'Search by email'),
          paginationControls: AppTablePagination(
            currentPage: _auditPage,
            pageSize: _auditPageSize,
            totalCount: 18,
            pageSizeOptions: const [8, 16, 32],
            onPageChanged: (p) => setState(() => _auditPage = p),
            onPageSizeChanged: (s) => setState(() {
              _auditPageSize = s;
              _auditPage = 1;
            }),
          ),
          columns: _auditColumns,
          rows: _audit,
        ),
      ],
    );
  }
}
