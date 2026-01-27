// IMPLEMENTS REQUIREMENTS:
//   REQ-p00024: Portal User Roles and Permissions
//   REQ-p00028: Token Revocation and Access Control
//   REQ-d00035: User Management API
//   REQ-d00036: Create User Dialog Implementation
//   REQ-CAL-p00029: Create User Account (multi-select roles, site requirements)
//   REQ-CAL-p00030: Edit User Account
//   REQ-CAL-p00031: Deactivate User Account
//   REQ-CAL-p00034: Site Visibility and Assignment
//   REQ-CAL-p00066: Capture deactivation reason
//   REQ-CAL-p00067: Active/Inactive user tabs

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../widgets/activation_code_display.dart';
import '../../widgets/error_message.dart';
import '../../widgets/role_badge.dart';
import '../../widgets/status_badge.dart';

class UserManagementTab extends StatefulWidget {
  /// Optional API client for dependency injection (used in tests).
  @visibleForTesting
  final ApiClient? apiClient;

  const UserManagementTab({super.key, this.apiClient});

  @override
  State<UserManagementTab> createState() => _UserManagementTabState();
}

/// Sponsor role mapping - maps sponsor display names to system roles
class SponsorRoleMapping {
  final String sponsorName;
  final String systemRole;

  const SponsorRoleMapping({
    required this.sponsorName,
    required this.systemRole,
  });

  factory SponsorRoleMapping.fromJson(Map<String, dynamic> json) {
    return SponsorRoleMapping(
      sponsorName: json['sponsorName'] as String,
      systemRole: json['systemRole'] as String,
    );
  }
}

class _UserManagementTabState extends State<UserManagementTab>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _sites = [];
  List<SponsorRoleMapping> _roleMappings = [];
  bool _isLoading = true;
  String? _error;
  late ApiClient _apiClient;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  late final TabController _tabController;

  /// Convert system role to sponsor display name
  String _toSponsorName(String systemRole) {
    final mapping = _roleMappings.firstWhere(
      (m) => m.systemRole == systemRole,
      orElse: () =>
          SponsorRoleMapping(sponsorName: systemRole, systemRole: systemRole),
    );
    return mapping.sponsorName;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _apiClient = widget.apiClient ?? ApiClient(context.read<AuthService>());
      _loadData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _searchQuery = '';
      _searchController.clear();
    });

    try {
      // Fetch users, sites, and role mappings in parallel
      // TODO: Get sponsorId from config/context - hardcoded for now
      const sponsorId = 'callisto';
      final results = await Future.wait([
        _apiClient.get('/api/v1/portal/users'),
        _apiClient.get('/api/v1/portal/sites'),
        _apiClient.get('/api/v1/sponsor/roles?sponsorId=$sponsorId'),
      ]);

      final usersResponse = results[0];
      final sitesResponse = results[1];
      final rolesResponse = results[2];

      if (!mounted) return;

      if (usersResponse.isSuccess && sitesResponse.isSuccess) {
        // API returns { users: [...] } and { sites: [...] }
        final usersData = usersResponse.data as Map<String, dynamic>?;
        final sitesData = sitesResponse.data as Map<String, dynamic>?;

        // Parse role mappings (optional - falls back to system names if missing)
        final roleMappings = <SponsorRoleMapping>[];
        if (rolesResponse.isSuccess) {
          final rolesData = rolesResponse.data as Map<String, dynamic>?;
          final mappingsList = (rolesData?['mappings'] as List?) ?? [];
          for (final m in mappingsList) {
            roleMappings.add(
              SponsorRoleMapping.fromJson(m as Map<String, dynamic>),
            );
          }
        }

        setState(() {
          _users = List<Map<String, dynamic>>.from(
            (usersData?['users'] as List?) ?? [],
          );
          _sites = List<Map<String, dynamic>>.from(
            (sitesData?['sites'] as List?) ?? [],
          );
          _roleMappings = roleMappings;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error =
              usersResponse.error ??
              sitesResponse.error ??
              'Failed to load data';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
      if (mounted) {
        setState(() {
          _error = 'Error loading data: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _createUser() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => CreateUserDialog(
        sites: _sites,
        apiClient: _apiClient,
        roleMappings: _roleMappings,
      ),
    );

    if (result == true) {
      _loadData();
    }
  }

  Future<void> _deactivateUser(String userId, String userName) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => DeactivateUserDialog(userName: userName),
    );

    if (reason != null && reason.isNotEmpty && mounted) {
      try {
        final response = await _apiClient.patch(
          '/api/v1/portal/users/$userId',
          {'status': 'revoked', 'reason': reason},
        );

        if (!mounted) return;

        if (response.isSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User account deactivated')),
          );
          _loadData();
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: ${response.error}')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deactivating user: $e')),
          );
        }
      }
    }
  }

  Future<void> _reactivateUser(String userId, String userName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reactivate User'),
        content: Text(
          'Are you sure you want to reactivate "$userName"? '
          'They will be able to log in again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reactivate'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        final response = await _apiClient.patch(
          '/api/v1/portal/users/$userId',
          {'status': 'active'},
        );

        if (!mounted) return;

        if (response.isSuccess) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('User reactivated')));
          _loadData();
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: ${response.error}')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error reactivating user: $e')),
          );
        }
      }
    }
  }

  /// Show user information dialog (read-only view)
  void _showUserInfo(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => UserInfoDialog(
        user: user,
        sites: _sites,
        roleMappings: _roleMappings,
        toSponsorName: _toSponsorName,
        onEdit: () {
          Navigator.pop(context);
          _editUser(user);
        },
        onDeactivate: () {
          Navigator.pop(context);
          _deactivateUser(user['id'], user['name'] ?? 'this user');
        },
        onReactivate: () {
          Navigator.pop(context);
          _reactivateUser(user['id'], user['name'] ?? 'this user');
        },
        apiClient: _apiClient,
      ),
    );
  }

  /// Show edit user dialog
  Future<void> _editUser(Map<String, dynamic> user) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => EditUserDialog(
        user: user,
        sites: _sites,
        apiClient: _apiClient,
        roleMappings: _roleMappings,
        toSponsorName: _toSponsorName,
      ),
    );

    if (result == true) {
      _loadData();
    }
  }

  /// Filter users by search query and status category
  List<Map<String, dynamic>> _filterUsers({required bool showActive}) {
    return _users.where((user) {
      final status = user['status'] as String? ?? 'pending';
      // Active tab: active + pending; Inactive tab: revoked
      final matchesTab = showActive
          ? (status == 'active' || status == 'pending')
          : (status == 'revoked');
      if (!matchesTab) return false;

      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      final name = (user['name'] as String? ?? '').toLowerCase();
      final email = (user['email'] as String? ?? '').toLowerCase();
      return name.contains(query) || email.contains(query);
    }).toList();
  }

  Widget _buildUserTable(
    List<Map<String, dynamic>> users,
    ColorScheme colorScheme, {
    required bool isActiveTab,
  }) {
    if (users.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Text(
            _searchQuery.isNotEmpty
                ? 'No users match "$_searchQuery".'
                : isActiveTab
                ? 'No active users found. Create the first user to get started.'
                : 'No inactive users.',
          ),
        ),
      );
    }

    return DataTable(
      showCheckboxColumn: false,
      columns: const [
        DataColumn(label: Text('Name')),
        DataColumn(label: Text('Email')),
        DataColumn(label: Text('Roles')),
        DataColumn(label: Text('Sites')),
        DataColumn(label: Text('Status')),
        DataColumn(label: Text('Actions')),
      ],
      rows: users.map((user) {
        final status = user['status'] as String? ?? 'pending';
        final isPending = status == 'pending';
        final isRevoked = status == 'revoked';

        // Get roles as list (system names from backend)
        final systemRoles = <String>[];
        if (user['roles'] != null) {
          systemRoles.addAll((user['roles'] as List).cast<String>());
        } else if (user['role'] != null) {
          systemRoles.add(user['role'] as String);
        }

        // Check if user has investigator role for sites display
        final hasInvestigatorRole = systemRoles.contains('Investigator');

        // Get sites
        final sitesList = (user['sites'] as List<dynamic>?) ?? [];
        final sitesDisplay = sitesList.isEmpty
            ? 'No sites'
            : sitesList.length == 1
            ? (sitesList.first['site_name'] ?? 'Unknown')
            : '${sitesList.length} sites assigned';

        return DataRow(
          onSelectChanged: (_) => _showUserInfo(user),
          cells: [
            DataCell(Text(user['name'] ?? 'N/A')),
            DataCell(Text(user['email'] ?? '')),
            DataCell(
              RoleBadgeList(
                roles: systemRoles
                    .map(
                      (r) => RoleDisplayData(
                        displayName: _toSponsorName(r),
                        systemRole: r,
                      ),
                    )
                    .toList(),
                compact: true,
              ),
            ),
            DataCell(Text(hasInvestigatorRole ? sitesDisplay : 'All sites')),
            DataCell(StatusBadge.fromString(status, compact: true)),
            DataCell(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isRevoked)
                    IconButton(
                      icon: Icon(Icons.edit, color: colorScheme.primary),
                      onPressed: () => _editUser(user),
                      tooltip: 'Edit User',
                    ),
                  if (!isRevoked && !isPending)
                    IconButton(
                      icon: Icon(Icons.block, color: colorScheme.error),
                      onPressed: () => _deactivateUser(
                        user['id'],
                        user['name'] ?? 'this user',
                      ),
                      tooltip: 'Deactivate',
                    ),
                  if (isRevoked)
                    IconButton(
                      icon: Icon(
                        Icons.check_circle_outline,
                        color: colorScheme.primary,
                      ),
                      onPressed: () => _reactivateUser(
                        user['id'],
                        user['name'] ?? 'this user',
                      ),
                      tooltip: 'Reactivate',
                    ),
                  if (isPending && user['activation_code'] != null)
                    IconButton(
                      icon: const Icon(Icons.vpn_key),
                      onPressed: () => _showActivationCode(
                        user['name'] ?? 'User',
                        user['activation_code'],
                      ),
                      tooltip: 'Show Activation Code',
                    ),
                  if (isPending && user['activation_code'] == null)
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: () => _regenerateActivationCode(
                        user['id'],
                        user['name'] ?? 'User',
                      ),
                      tooltip: 'Generate Activation Code',
                    ),
                  if (user['linking_code'] != null)
                    IconButton(
                      icon: const Icon(Icons.link),
                      onPressed: () => _showLinkingCode(
                        user['name'] ?? 'User',
                        user['linking_code'],
                      ),
                      tooltip: 'Show Linking Code',
                    ),
                ],
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: colorScheme.error),
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: colorScheme.error)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    // Compute tab counts for badges (REQ-CAL-p00067)
    final activeUsers = _filterUsers(showActive: true);
    final inactiveUsers = _filterUsers(showActive: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Portal Users', style: theme.textTheme.headlineMedium),
              Row(
                children: [
                  SizedBox(
                    width: 250,
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search by name or email',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  setState(() {
                                    _searchController.clear();
                                    _searchQuery = '';
                                  });
                                },
                              )
                            : null,
                        isDense: true,
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _loadData,
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh',
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _createUser,
                    icon: const Icon(Icons.person_add),
                    label: const Text('Create User'),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Tab bar for Active / Inactive users (REQ-CAL-p00067)
        TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Active Users'),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${activeUsers.length}',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Inactive Users'),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${inactiveUsers.length}',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // Active Users tab
              SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Card(
                  child: _buildUserTable(
                    activeUsers,
                    colorScheme,
                    isActiveTab: true,
                  ),
                ),
              ),
              // Inactive Users tab
              SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Card(
                  child: _buildUserTable(
                    inactiveUsers,
                    colorScheme,
                    isActiveTab: false,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showLinkingCode(String userName, String linkingCode) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Linking Code for $userName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Share this code with the user to link their device:'),
            const SizedBox(height: 16),
            ActivationCodeDisplay(
              code: linkingCode,
              showLabel: false,
              fontSize: 20,
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showActivationCode(String userName, String activationCode) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Activation Code for $userName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Share this code with the user to activate their account:',
            ),
            const SizedBox(height: 16),
            ActivationCodeDisplay(
              code: activationCode,
              showLabel: false,
              fontSize: 20,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Activation URL: /activate?code=$activationCode',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _regenerateActivationCode(String userId, String userName) async {
    try {
      final response = await _apiClient.patch('/api/v1/portal/users/$userId', {
        'regenerate_activation': true,
      });

      if (!mounted) return;

      if (response.isSuccess) {
        final data = response.data as Map<String, dynamic>;
        final newCode = data['activation_code'] as String?;
        if (newCode != null) {
          _showActivationCode(userName, newCode);
        }
        _loadData();
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${response.error}')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error regenerating code: $e')));
      }
    }
  }
}

class CreateUserDialog extends StatefulWidget {
  final List<Map<String, dynamic>> sites;
  final ApiClient apiClient;
  final List<SponsorRoleMapping> roleMappings;

  const CreateUserDialog({
    super.key,
    required this.sites,
    required this.apiClient,
    required this.roleMappings,
  });

  @override
  State<CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends State<CreateUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  // Multi-select roles per REQ-CAL-p00029.F - stores sponsor role names
  final Set<String> _selectedSponsorRoles = {};
  final Set<String> _selectedSites = {};
  String? _activationCode;
  bool _isCreating = false;
  String? _error;
  // Track success state for the confirmation dialog
  bool _userCreated = false;
  bool? _emailSent;
  String? _emailError;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  /// Get system role from sponsor name
  String _toSystemRole(String sponsorName) {
    final mapping = widget.roleMappings.firstWhere(
      (m) => m.sponsorName == sponsorName,
      orElse: () =>
          SponsorRoleMapping(sponsorName: sponsorName, systemRole: sponsorName),
    );
    return mapping.systemRole;
  }

  /// Get selected system roles for backend API
  List<String> get _selectedSystemRoles =>
      _selectedSponsorRoles.map(_toSystemRole).toList();

  /// Check if any selected role requires site assignment
  /// Site-scoped roles: Investigator (Study Coordinator), and sponsor-specific mappings
  bool get _needsSites {
    // Check if any selected system role requires site assignment
    // Investigator is the only site-scoped system role
    return _selectedSystemRoles.contains('Investigator');
  }

  Future<void> _createUser() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate at least one role is selected
    if (_selectedSponsorRoles.isEmpty) {
      setState(() {
        _error = 'Please select at least one role';
      });
      return;
    }

    // Validate site selection for roles that require it (REQ-CAL-p00029.B)
    if (_needsSites && _selectedSites.isEmpty) {
      setState(() {
        _error = 'Please select at least one site for the selected role(s)';
      });
      return;
    }

    setState(() {
      _isCreating = true;
      _error = null;
    });

    try {
      // Send system roles to backend API (convert from sponsor names)
      final body = <String, dynamic>{
        'email': _emailController.text.trim(),
        'name': _nameController.text.trim(),
        'roles': _selectedSystemRoles,
      };

      if (_needsSites) {
        body['site_ids'] = _selectedSites.toList();
      }

      final response = await widget.apiClient.post(
        '/api/v1/portal/users',
        body,
      );

      if (!mounted) return;

      if (response.isSuccess) {
        final data = response.data as Map<String, dynamic>;
        setState(() {
          _activationCode = data['activation_code'] as String?;
          _emailSent = data['email_sent'] as bool?;
          _emailError = data['email_error'] as String?;
          _userCreated = true;
          _isCreating = false;
        });
      } else {
        setState(() {
          _error = response.error ?? 'Failed to create user';
          _isCreating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error creating user: $e';
          _isCreating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Show success dialog after user creation
    if (_userCreated) {
      return AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: colorScheme.primary),
            const SizedBox(width: 8),
            const Text('User Created'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'User account created successfully for ${_nameController.text}!',
            ),
            const SizedBox(height: 16),
            // Show email status (REQ-CAL-p00029.D)
            if (_emailSent == true)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.email_outlined,
                      color: colorScheme.onPrimaryContainer,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Activation email sent to ${_emailController.text}',
                        style: TextStyle(color: colorScheme.onPrimaryContainer),
                      ),
                    ),
                  ],
                ),
              )
            else if (_emailError != null || _emailSent == false) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_outlined,
                      color: colorScheme.onErrorContainer,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _emailError != null
                            ? 'Email not sent: $_emailError'
                            : 'Activation email could not be sent.',
                        style: TextStyle(color: colorScheme.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              ),
              // Show activation code when email fails so admin can share manually
              if (_activationCode != null) ...[
                const SizedBox(height: 16),
                ActivationCodeDisplay(
                  code: _activationCode!,
                  label: 'Activation Code (share manually)',
                  fontSize: 18,
                ),
              ],
            ],
            // NOTE: Linking codes are NOT shown for portal users.
            // Linking codes are only for patients (diary app device linking).
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Done'),
          ),
        ],
      );
    }

    return AlertDialog(
      title: const Text('Create New User'),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null) ...[
                  ErrorMessage(
                    message: _error!,
                    supportEmail: const String.fromEnvironment('SUPPORT_EMAIL'),
                    onDismiss: () => setState(() => _error = null),
                  ),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Email is required';
                    }
                    if (!v.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Multi-select roles using checkboxes (REQ-CAL-p00029.F)
                // Uses sponsor role names from mappings
                Text('Roles *', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _selectedSponsorRoles.isEmpty
                          ? colorScheme.error
                          : colorScheme.outline,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: widget.roleMappings.map((mapping) {
                      return CheckboxListTile(
                        title: Text(mapping.sponsorName),
                        value: _selectedSponsorRoles.contains(
                          mapping.sponsorName,
                        ),
                        onChanged: (checked) {
                          setState(() {
                            if (checked == true) {
                              _selectedSponsorRoles.add(mapping.sponsorName);
                            } else {
                              _selectedSponsorRoles.remove(mapping.sponsorName);
                              // Clear sites if no role requires them anymore
                              if (!_needsSites) {
                                _selectedSites.clear();
                              }
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
                if (_selectedSponsorRoles.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Select at least one role',
                      style: TextStyle(color: colorScheme.error, fontSize: 12),
                    ),
                  ),
                // Show site selection for roles that require it (REQ-CAL-p00029.B, C)
                if (_needsSites) ...[
                  const SizedBox(height: 24),
                  Text('Assigned Sites *', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Select the sites this user will have access to.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (widget.sites.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('No sites available'),
                    )
                  else
                    Container(
                      constraints: const BoxConstraints(maxHeight: 250),
                      decoration: BoxDecoration(
                        border: Border.all(color: colorScheme.outline),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          children: widget.sites.map((site) {
                            final siteId = site['site_id'] as String;
                            final siteNumber =
                                site['site_number'] as String? ?? '';
                            final siteName =
                                site['site_name'] as String? ?? siteId;
                            final city = site['city'] as String?;
                            final state = site['state'] as String?;
                            final location = [city, state]
                                .where((s) => s != null && s.isNotEmpty)
                                .join(', ');
                            return CheckboxListTile(
                              title: Text('$siteNumber - $siteName'),
                              subtitle: location.isNotEmpty
                                  ? Text(location)
                                  : null,
                              value: _selectedSites.contains(siteId),
                              onChanged: (checked) {
                                setState(() {
                                  if (checked == true) {
                                    _selectedSites.add(siteId);
                                  } else {
                                    _selectedSites.remove(siteId);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  if (_selectedSites.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'At least one site must be selected',
                        style: TextStyle(
                          color: colorScheme.error,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isCreating ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isCreating ? null : _createUser,
          child: _isCreating
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }
}

/// Read-only dialog showing user details, roles, and assigned sites.
/// Provides actions to edit or deactivate the user.
/// For revoked users, shows deactivation reason and reactivate option.
///
/// IMPLEMENTS REQUIREMENTS:
///   REQ-CAL-p00030: Edit User Account
///   REQ-CAL-p00031: Deactivate User Account
///   REQ-CAL-p00034: Site Visibility and Assignment
class UserInfoDialog extends StatelessWidget {
  final Map<String, dynamic> user;
  final List<Map<String, dynamic>> sites;
  final List<SponsorRoleMapping> roleMappings;
  final String Function(String) toSponsorName;
  final VoidCallback onEdit;
  final VoidCallback onDeactivate;
  final VoidCallback? onReactivate;
  final ApiClient apiClient;

  const UserInfoDialog({
    super.key,
    required this.user,
    required this.sites,
    required this.roleMappings,
    required this.toSponsorName,
    required this.onEdit,
    required this.onDeactivate,
    this.onReactivate,
    required this.apiClient,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final status = user['status'] as String? ?? 'pending';
    final isRevoked = status == 'revoked';

    // Deactivation details (REQ-CAL-p00031)
    final statusChangeReason = user['status_change_reason'] as String?;
    final statusChangedAt = user['status_changed_at'] as String?;
    final statusChangedBy = user['status_changed_by'] as String?;

    // Get roles (system names for RoleBadge compatibility)
    final systemRoles = <String>[];
    if (user['roles'] != null) {
      systemRoles.addAll((user['roles'] as List).cast<String>());
    } else if (user['role'] != null) {
      systemRoles.add(user['role'] as String);
    }

    // Get sites
    final sitesList = (user['sites'] as List<dynamic>?) ?? [];

    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('User Information'),
          const SizedBox(height: 4),
          Text(
            'View and manage user details, roles, and assigned sites.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // User name and email
              Text(
                user['name'] ?? 'N/A',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                user['email'] ?? '',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              StatusBadge.fromString(status),
              const SizedBox(height: 24),

              // Roles section
              Text('Roles', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              if (systemRoles.isEmpty)
                Text(
                  'No roles assigned',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  // Pair sponsor display name with system role
                  // so badge gets correct color and shows sponsor name
                  children: systemRoles
                      .map(
                        (role) => RoleBadge.fromDisplayData(
                          RoleDisplayData(
                            displayName: toSponsorName(role),
                            systemRole: role,
                          ),
                        ),
                      )
                      .toList(),
                ),
              const SizedBox(height: 24),

              // Sites section
              Text(
                'Assigned Sites (${sitesList.length})',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (sitesList.isEmpty)
                Text(
                  systemRoles.contains('Investigator')
                      ? 'No sites assigned'
                      : 'All sites (role does not require site assignment)',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                )
              else
                ...sitesList.map((site) {
                  final siteNumber = site['site_number'] as String? ?? '';
                  final siteName = site['site_name'] as String? ?? '';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 20,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$siteNumber - $siteName',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),

              // Deactivation info section (REQ-CAL-p00031)
              if (isRevoked) ...[
                const SizedBox(height: 24),
                Text(
                  'Deactivation Details',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer.withValues(alpha: 0.3),
                    border: Border.all(
                      color: colorScheme.error.withValues(alpha: 0.3),
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (statusChangeReason != null &&
                          statusChangeReason.isNotEmpty) ...[
                        Text(
                          'Reason',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(statusChangeReason),
                        const SizedBox(height: 8),
                      ],
                      if (statusChangedAt != null) ...[
                        Text(
                          'Deactivated on',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(statusChangedAt),
                        const SizedBox(height: 8),
                      ],
                      if (statusChangedBy != null) ...[
                        Text(
                          'Deactivated by',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(statusChangedBy),
                      ],
                      if (statusChangeReason == null && statusChangedAt == null)
                        Text(
                          'No deactivation details available.',
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (!isRevoked)
          TextButton(
            style: TextButton.styleFrom(foregroundColor: colorScheme.error),
            onPressed: onDeactivate,
            child: const Text('Deactivate User'),
          ),
        if (isRevoked && onReactivate != null)
          OutlinedButton(
            onPressed: onReactivate,
            child: const Text('Reactivate User'),
          ),
        if (!isRevoked)
          OutlinedButton(onPressed: onEdit, child: const Text('Edit User')),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

/// Dialog for editing user roles and site assignments.
/// Name is editable, email is read-only.
/// Shows session termination warning.
///
/// IMPLEMENTS REQUIREMENTS:
///   REQ-CAL-p00030: Edit User Account
///   REQ-CAL-p00034: Site Visibility and Assignment
class EditUserDialog extends StatefulWidget {
  final Map<String, dynamic> user;
  final List<Map<String, dynamic>> sites;
  final ApiClient apiClient;
  final List<SponsorRoleMapping> roleMappings;
  final String Function(String) toSponsorName;

  const EditUserDialog({
    super.key,
    required this.user,
    required this.sites,
    required this.apiClient,
    required this.roleMappings,
    required this.toSponsorName,
  });

  @override
  State<EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<EditUserDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late Set<String> _selectedSponsorRoles;
  late Set<String> _selectedSites;
  bool _isSaving = false;
  String? _error;

  // Track original values for change detection
  late final String _originalName;
  late final Set<String> _originalSponsorRoles;
  late final Set<String> _originalSites;

  @override
  void initState() {
    super.initState();

    _originalName = widget.user['name'] as String? ?? '';
    _nameController = TextEditingController(text: _originalName);

    // Get current system roles and convert to sponsor names
    final systemRoles = <String>[];
    if (widget.user['roles'] != null) {
      systemRoles.addAll((widget.user['roles'] as List).cast<String>());
    }
    _originalSponsorRoles = systemRoles.map(widget.toSponsorName).toSet();
    _selectedSponsorRoles = Set<String>.from(_originalSponsorRoles);

    // Get current site IDs
    final sitesList = (widget.user['sites'] as List<dynamic>?) ?? [];
    _originalSites = sitesList.map((s) => s['site_id'] as String).toSet();
    _selectedSites = Set<String>.from(_originalSites);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// Get system role from sponsor name
  String _toSystemRole(String sponsorName) {
    final mapping = widget.roleMappings.firstWhere(
      (m) => m.sponsorName == sponsorName,
      orElse: () =>
          SponsorRoleMapping(sponsorName: sponsorName, systemRole: sponsorName),
    );
    return mapping.systemRole;
  }

  List<String> get _selectedSystemRoles =>
      _selectedSponsorRoles.map(_toSystemRole).toList();

  bool get _needsSites => _selectedSystemRoles.contains('Investigator');

  bool get _hasChanges {
    if (_nameController.text.trim() != _originalName) return true;
    if (!_setEquals(_selectedSponsorRoles, _originalSponsorRoles)) return true;
    if (!_setEquals(_selectedSites, _originalSites)) return true;
    return false;
  }

  bool _setEquals(Set<String> a, Set<String> b) {
    return a.length == b.length && a.containsAll(b);
  }

  /// Get list of permissions being removed
  List<String> _getRemovedPermissions() {
    final removed = <String>[];

    // Check removed roles
    for (final role in _originalSponsorRoles) {
      if (!_selectedSponsorRoles.contains(role)) {
        removed.add('Role: $role');
      }
    }

    // Check removed sites
    for (final siteId in _originalSites) {
      if (!_selectedSites.contains(siteId)) {
        final site = widget.sites.firstWhere(
          (s) => s['site_id'] == siteId,
          orElse: () => {'site_name': siteId},
        );
        removed.add('Site: ${site['site_name']}');
      }
    }

    return removed;
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedSponsorRoles.isEmpty) {
      setState(() => _error = 'At least one role is required');
      return;
    }

    if (_needsSites && _selectedSites.isEmpty) {
      setState(
        () => _error = 'At least one site is required for the selected role(s)',
      );
      return;
    }

    // Check for permission removals and confirm
    final removedPermissions = _getRemovedPermissions();
    if (removedPermissions.isNotEmpty) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm Permission Changes'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('The following permissions will be removed:'),
              const SizedBox(height: 12),
              ...removedPermissions.map(
                (p) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.remove_circle_outline,
                        size: 16,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: 8),
                      Text(p),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Active sessions will be terminated.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      );

      if (confirm != true) return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final body = <String, dynamic>{};

      // Include name if changed
      final newName = _nameController.text.trim();
      if (newName != _originalName) {
        body['name'] = newName;
      }

      // Include roles if changed
      if (!_setEquals(_selectedSponsorRoles, _originalSponsorRoles)) {
        body['roles'] = _selectedSystemRoles;
      }

      // Include sites if changed
      if (!_setEquals(_selectedSites, _originalSites)) {
        body['site_ids'] = _selectedSites.toList();
      }

      if (body.isEmpty) {
        // No changes
        if (mounted) Navigator.pop(context, false);
        return;
      }

      final response = await widget.apiClient.patch(
        '/api/v1/portal/users/${widget.user['id']}',
        body,
      );

      if (!mounted) return;

      if (response.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User updated successfully')),
        );
        Navigator.pop(context, true);
      } else {
        setState(() {
          _error = response.error ?? 'Failed to update user';
          _isSaving = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error updating user: $e';
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Edit User'),
          const SizedBox(height: 4),
          Text(
            'Update user roles and site assignments. Changes will take effect '
            'immediately and active sessions will be terminated.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null) ...[
                  ErrorMessage(
                    message: _error!,
                    supportEmail: const String.fromEnvironment('SUPPORT_EMAIL'),
                    onDismiss: () => setState(() => _error = null),
                  ),
                  const SizedBox(height: 16),
                ],

                // Name field (editable)
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Name is required';
                    }
                    return null;
                  },
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),

                // Email field (read-only display)
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    widget.user['email'] as String? ?? '',
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
                const SizedBox(height: 16),

                // Roles section
                Text('Roles *', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _selectedSponsorRoles.isEmpty
                          ? colorScheme.error
                          : colorScheme.outline,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: widget.roleMappings.map((mapping) {
                      final isOriginal = _originalSponsorRoles.contains(
                        mapping.sponsorName,
                      );
                      final isSelected = _selectedSponsorRoles.contains(
                        mapping.sponsorName,
                      );
                      final isRemoving = isOriginal && !isSelected;

                      return CheckboxListTile(
                        title: Row(
                          children: [
                            Text(mapping.sponsorName),
                            if (isRemoving) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.errorContainer,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Removing',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: colorScheme.onErrorContainer,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        value: isSelected,
                        onChanged: (checked) {
                          setState(() {
                            if (checked == true) {
                              _selectedSponsorRoles.add(mapping.sponsorName);
                            } else {
                              _selectedSponsorRoles.remove(mapping.sponsorName);
                              if (!_needsSites) {
                                _selectedSites.clear();
                              }
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
                if (_selectedSponsorRoles.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Select at least one role',
                      style: TextStyle(color: colorScheme.error, fontSize: 12),
                    ),
                  ),

                // Sites section
                if (_needsSites) ...[
                  const SizedBox(height: 24),
                  Text('Assigned Sites *', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (widget.sites.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('No sites available'),
                    )
                  else
                    Container(
                      constraints: const BoxConstraints(maxHeight: 200),
                      decoration: BoxDecoration(
                        border: Border.all(color: colorScheme.outline),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          children: widget.sites.map((site) {
                            final siteId = site['site_id'] as String;
                            final siteNumber =
                                site['site_number'] as String? ?? '';
                            final siteName =
                                site['site_name'] as String? ?? siteId;
                            final isOriginal = _originalSites.contains(siteId);
                            final isSelected = _selectedSites.contains(siteId);
                            final isRemoving = isOriginal && !isSelected;

                            return CheckboxListTile(
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text('$siteNumber - $siteName'),
                                  ),
                                  if (isRemoving) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colorScheme.errorContainer,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Removing',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: colorScheme.onErrorContainer,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              value: isSelected,
                              onChanged: (checked) {
                                setState(() {
                                  if (checked == true) {
                                    _selectedSites.add(siteId);
                                  } else {
                                    _selectedSites.remove(siteId);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  if (_selectedSites.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'At least one site must be selected',
                        style: TextStyle(
                          color: colorScheme.error,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],

                // Session termination warning (always shown)
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    border: Border.all(color: Colors.amber.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_outlined,
                        color: Colors.amber.shade800,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Active sessions will be terminated when changes are saved.',
                          style: TextStyle(
                            color: Colors.amber.shade900,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving || !_hasChanges ? null : _saveChanges,
          child: _isSaving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save Changes'),
        ),
      ],
    );
  }
}

/// Dialog for deactivating a user account (REQ-CAL-p00031).
/// Shows consequences of deactivation and requires a reason.
/// Returns the reason string if confirmed, null if cancelled.
class DeactivateUserDialog extends StatefulWidget {
  final String userName;

  const DeactivateUserDialog({super.key, required this.userName});

  @override
  State<DeactivateUserDialog> createState() => _DeactivateUserDialogState();
}

class _DeactivateUserDialogState extends State<DeactivateUserDialog> {
  final _reasonController = TextEditingController();
  String _reason = '';

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.person_off, color: colorScheme.error),
          const SizedBox(width: 8),
          const Text('Deactivate User Account'),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You are about to deactivate the account for "${widget.userName}".',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            // Consequences warning
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer.withValues(alpha: 0.3),
                border: Border.all(
                  color: colorScheme.error.withValues(alpha: 0.3),
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This will:',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildConsequence(
                    Icons.cancel_outlined,
                    'Terminate all active sessions immediately',
                    colorScheme,
                  ),
                  _buildConsequence(
                    Icons.lock_outline,
                    'Prevent the user from logging in',
                    colorScheme,
                  ),
                  _buildConsequence(
                    Icons.swap_horiz,
                    'Move the user to the Inactive Users tab',
                    colorScheme,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This action can be reversed by reactivating the user.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Reason field (required)
            TextField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason for deactivation *',
                hintText: 'e.g., Employee left the organization',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
              onChanged: (value) {
                setState(() {
                  _reason = value.trim();
                });
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: colorScheme.error),
          onPressed: _reason.isEmpty
              ? null
              : () => Navigator.pop(context, _reason),
          child: const Text('Deactivate'),
        ),
      ],
    );
  }

  Widget _buildConsequence(
    IconData icon,
    String text,
    ColorScheme colorScheme,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: colorScheme.error),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
