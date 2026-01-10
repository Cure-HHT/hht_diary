// IMPLEMENTS REQUIREMENTS:
//   REQ-p00024: Portal User Roles and Permissions
//   REQ-p00028: Token Revocation and Access Control
//   REQ-d00035: User Management API

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/api_client.dart';
import '../../services/auth_service.dart';

class UserManagementTab extends StatefulWidget {
  const UserManagementTab({super.key});

  @override
  State<UserManagementTab> createState() => _UserManagementTabState();
}

class _UserManagementTabState extends State<UserManagementTab> {
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _sites = [];
  bool _isLoading = true;
  String? _error;
  late ApiClient _apiClient;

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
      // Fetch users and sites in parallel
      final results = await Future.wait([
        _apiClient.get('/api/v1/portal/users'),
        _apiClient.get('/api/v1/portal/sites'),
      ]);

      final usersResponse = results[0];
      final sitesResponse = results[1];

      if (!mounted) return;

      if (usersResponse.isSuccess && sitesResponse.isSuccess) {
        setState(() {
          _users = List<Map<String, dynamic>>.from(
            (usersResponse.data as List?) ?? [],
          );
          _sites = List<Map<String, dynamic>>.from(
            (sitesResponse.data as List?) ?? [],
          );
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = usersResponse.error ??
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User access revoked')),
          );
          _loadData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${response.error}')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error revoking user: $e')),
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User reactivated')),
          );
          _loadData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${response.error}')),
          );
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
            Icon(
              Icons.error_outline,
              size: 48,
              color: colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(color: colorScheme.error),
            ),
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
              Text(
                'Portal Users',
                style: theme.textTheme.headlineMedium,
              ),
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
                            'No users found. Create the first user to get started.'),
                      ),
                    )
                  : DataTable(
                      columns: const [
                        DataColumn(label: Text('Name')),
                        DataColumn(label: Text('Email')),
                        DataColumn(label: Text('Role')),
                        DataColumn(label: Text('Sites')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: _users.map((user) {
                        final isActive = user['status'] == 'active';
                        final sites = (user['sites'] as List<dynamic>?)
                                ?.map((s) => s['site_id'] ?? s.toString())
                                .join(', ') ??
                            '';
                        final role = user['role'] as String? ?? '';
                        final roleEnum = UserRole.fromString(role);

                        return DataRow(
                          cells: [
                            DataCell(Text(user['name'] ?? 'N/A')),
                            DataCell(Text(user['email'] ?? '')),
                            DataCell(
                              Chip(
                                label: Text(roleEnum.displayName),
                                backgroundColor:
                                    _getRoleColor(roleEnum, colorScheme),
                                labelStyle: TextStyle(
                                  color: _getRoleForegroundColor(
                                      roleEnum, colorScheme),
                                  fontSize: 12,
                                ),
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                            DataCell(
                              Text(
                                roleEnum == UserRole.investigator
                                    ? (sites.isNotEmpty ? sites : 'None')
                                    : 'All',
                              ),
                            ),
                            DataCell(
                              Chip(
                                label: Text(isActive ? 'Active' : 'Revoked'),
                                backgroundColor: isActive
                                    ? colorScheme.primaryContainer
                                    : colorScheme.errorContainer,
                                labelStyle: TextStyle(
                                  color: isActive
                                      ? colorScheme.onPrimaryContainer
                                      : colorScheme.onErrorContainer,
                                  fontSize: 12,
                                ),
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isActive)
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
                                    )
                                  else
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

  Color _getRoleColor(UserRole role, ColorScheme colorScheme) {
    switch (role) {
      case UserRole.administrator:
      case UserRole.developerAdmin:
        return colorScheme.tertiaryContainer;
      case UserRole.sponsor:
        return colorScheme.secondaryContainer;
      case UserRole.auditor:
        return colorScheme.surfaceContainerHighest;
      case UserRole.analyst:
        return colorScheme.surfaceContainerHigh;
      case UserRole.investigator:
        return colorScheme.primaryContainer;
    }
  }

  Color _getRoleForegroundColor(UserRole role, ColorScheme colorScheme) {
    switch (role) {
      case UserRole.administrator:
      case UserRole.developerAdmin:
        return colorScheme.onTertiaryContainer;
      case UserRole.sponsor:
        return colorScheme.onSecondaryContainer;
      case UserRole.auditor:
        return colorScheme.onSurface;
      case UserRole.analyst:
        return colorScheme.onSurface;
      case UserRole.investigator:
        return colorScheme.onPrimaryContainer;
    }
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
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                linkingCode,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontFamily: 'monospace',
                      letterSpacing: 2,
                    ),
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
}

class CreateUserDialog extends StatefulWidget {
  final List<Map<String, dynamic>> sites;
  final ApiClient apiClient;

  const CreateUserDialog({
    super.key,
    required this.sites,
    required this.apiClient,
  });

  @override
  State<CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends State<CreateUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  UserRole _selectedRole = UserRole.investigator;
  final Set<String> _selectedSites = {};
  String? _linkingCode;
  bool _isCreating = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _createUser() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedRole == UserRole.investigator && _selectedSites.isEmpty) {
      setState(() {
        _error = 'Please select at least one site for Investigator';
      });
      return;
    }

    setState(() {
      _isCreating = true;
      _error = null;
    });

    try {
      final body = <String, dynamic>{
        'email': _emailController.text.trim(),
        'name': _nameController.text.trim(),
        'role': _selectedRole.displayName,
      };

      if (_selectedRole == UserRole.investigator) {
        body['site_ids'] = _selectedSites.toList();
      }

      final response =
          await widget.apiClient.post('/api/v1/portal/users', body);

      if (!mounted) return;

      if (response.isSuccess) {
        final data = response.data as Map<String, dynamic>;
        setState(() {
          _linkingCode = data['linking_code'] as String?;
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

    if (_linkingCode != null) {
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
            const SizedBox(height: 24),
            const Text(
              'Linking Code:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colorScheme.outline),
              ),
              child: SelectableText(
                _linkingCode!,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontFamily: 'monospace',
                  letterSpacing: 2,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: colorScheme.onPrimaryContainer,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Share this code with the user to link their device.',
                      style: TextStyle(color: colorScheme.onPrimaryContainer),
                    ),
                  ),
                ],
              ),
            ),
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
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: colorScheme.onErrorContainer,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style:
                                TextStyle(color: colorScheme.onErrorContainer),
                          ),
                        ),
                      ],
                    ),
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
                DropdownButtonFormField<UserRole>(
                  // Using value for controlled dropdown (initialValue doesn't work with setState)
                  // ignore: deprecated_member_use
                  value: _selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    prefixIcon: Icon(Icons.badge_outlined),
                    border: OutlineInputBorder(),
                  ),
                  items: UserRole.values.map((role) {
                    return DropdownMenuItem(
                      value: role,
                      child: Text(role.displayName),
                    );
                  }).toList(),
                  onChanged: (role) {
                    if (role != null) {
                      setState(() {
                        _selectedRole = role;
                        if (role != UserRole.investigator) {
                          _selectedSites.clear();
                        }
                      });
                    }
                  },
                ),
                if (_selectedRole == UserRole.investigator) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Assign Sites',
                    style: theme.textTheme.titleMedium,
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
                      decoration: BoxDecoration(
                        border: Border.all(color: colorScheme.outline),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: widget.sites.map((site) {
                          final siteId = site['site_id'] as String;
                          final siteName =
                              site['site_name'] as String? ?? siteId;
                          return CheckboxListTile(
                            title: Text(siteName),
                            subtitle: Text(siteId),
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
