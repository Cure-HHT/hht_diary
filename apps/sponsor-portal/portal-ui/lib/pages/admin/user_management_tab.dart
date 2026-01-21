// IMPLEMENTS REQUIREMENTS:
//   REQ-p00024: Portal User Roles and Permissions
//   REQ-p00028: Token Revocation and Access Control
//   REQ-d00035: User Management API
//   REQ-d00036: Create User Dialog Implementation
//   REQ-CAL-p00029: Create User Account (multi-select roles, site requirements)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../widgets/activation_code_display.dart';
import '../../widgets/error_message.dart';
import '../../widgets/role_badge.dart';
import '../../widgets/status_badge.dart';

class UserManagementTab extends StatefulWidget {
  const UserManagementTab({super.key});

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

class _UserManagementTabState extends State<UserManagementTab> {
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _sites = [];
  List<SponsorRoleMapping> _roleMappings = [];
  bool _isLoading = true;
  String? _error;
  late ApiClient _apiClient;

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _apiClient = ApiClient(context.read<AuthService>());
      _loadData();
    });
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
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

  Future<void> _revokeUser(String userId, String userName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revoke Access'),
        content: Text(
          'Are you sure you want to revoke access for "$userName"? '
          'They will not be able to log in until reactivated.',
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
            child: const Text('Revoke'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        final response = await _apiClient.patch(
          '/api/v1/portal/users/$userId',
          {'status': 'revoked'},
        );

        if (!mounted) return;

        if (response.isSuccess) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('User access revoked')));
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
          ).showSnackBar(SnackBar(content: Text('Error revoking user: $e')));
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
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: _users.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          'No users found. Create the first user to get started.',
                        ),
                      ),
                    )
                  : DataTable(
                      columns: const [
                        DataColumn(label: Text('Name')),
                        DataColumn(label: Text('Email')),
                        DataColumn(label: Text('Roles')),
                        DataColumn(label: Text('Sites')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: _users.map((user) {
                        final status = user['status'] as String? ?? 'pending';
                        final isPending = status == 'pending';
                        final isRevoked = status == 'revoked';

                        // Get roles as list (system names from backend)
                        final systemRoles = <String>[];
                        if (user['roles'] != null) {
                          systemRoles.addAll(
                            (user['roles'] as List).cast<String>(),
                          );
                        } else if (user['role'] != null) {
                          systemRoles.add(user['role'] as String);
                        }

                        // Convert system roles to sponsor display names
                        final displayRoles = systemRoles
                            .map(_toSponsorName)
                            .toList();

                        // Check if user has investigator role for sites display
                        final hasInvestigatorRole = systemRoles.contains(
                          'Investigator',
                        );

                        // Get sites
                        final sitesList =
                            (user['sites'] as List<dynamic>?) ?? [];
                        final sitesDisplay = sitesList.isEmpty
                            ? 'No sites'
                            : sitesList.length == 1
                            ? (sitesList.first['site_name'] ?? 'Unknown')
                            : '${sitesList.length} sites assigned';

                        return DataRow(
                          cells: [
                            DataCell(Text(user['name'] ?? 'N/A')),
                            DataCell(Text(user['email'] ?? '')),
                            DataCell(
                              RoleBadgeList(roles: displayRoles, compact: true),
                            ),
                            DataCell(
                              Text(
                                hasInvestigatorRole
                                    ? sitesDisplay
                                    : 'All sites',
                              ),
                            ),
                            DataCell(
                              StatusBadge.fromString(status, compact: true),
                            ),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (!isRevoked && !isPending)
                                    IconButton(
                                      icon: Icon(
                                        Icons.block,
                                        color: colorScheme.error,
                                      ),
                                      onPressed: () => _revokeUser(
                                        user['id'],
                                        user['name'] ?? 'this user',
                                      ),
                                      tooltip: 'Revoke Access',
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
                                  if (isPending &&
                                      user['activation_code'] != null)
                                    IconButton(
                                      icon: const Icon(Icons.vpn_key),
                                      onPressed: () => _showActivationCode(
                                        user['name'] ?? 'User',
                                        user['activation_code'],
                                      ),
                                      tooltip: 'Show Activation Code',
                                    ),
                                  if (isPending &&
                                      user['activation_code'] == null)
                                    IconButton(
                                      icon: const Icon(Icons.refresh),
                                      onPressed: () =>
                                          _regenerateActivationCode(
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
                    ),
            ),
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
