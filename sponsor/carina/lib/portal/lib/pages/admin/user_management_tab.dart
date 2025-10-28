// IMPLEMENTS REQUIREMENTS:
//   REQ-p00024: Portal User Roles and Permissions
//   REQ-p00028: Token Revocation and Access Control

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../services/auth_service.dart';
import '../../config/supabase_config.dart';

class UserManagementTab extends StatefulWidget {
  const UserManagementTab({super.key});

  @override
  State<UserManagementTab> createState() => _UserManagementTabState();
}

class _UserManagementTabState extends State<UserManagementTab> {
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _sites = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final usersResponse =
          await SupabaseConfig.client.from('portal_users').select();
      final sitesResponse =
          await SupabaseConfig.client.from('sites').select();

      setState(() {
        _users = List<Map<String, dynamic>>.from(usersResponse);
        _sites = List<Map<String, dynamic>>.from(sitesResponse);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createUser() async {
    await showDialog(
      context: context,
      builder: (context) => CreateUserDialog(
        sites: _sites,
        onUserCreated: _loadData,
      ),
    );
  }

  Future<void> _revokeUser(String userId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revoke Access'),
        content: const Text(
          'Are you sure you want to revoke access for this user? '
          'They will not be able to log in until reactivated.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await SupabaseConfig.client
            .from('portal_users')
            .update({'is_active': false}).eq('id', userId);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User access revoked')),
          );
          _loadData();
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
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
                style: Theme.of(context).textTheme.displaySmall,
              ),
              ElevatedButton.icon(
                onPressed: _createUser,
                icon: const Icon(Icons.add),
                label: const Text('Create User'),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Name')),
                  DataColumn(label: Text('Email')),
                  DataColumn(label: Text('Role')),
                  DataColumn(label: Text('Sites')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: _users.map((user) {
                  final isActive = user['is_active'] ?? true;
                  final sites = (user['assigned_sites'] as List<dynamic>?)
                          ?.map((s) => s.toString())
                          .join(', ') ??
                      'All';

                  return DataRow(
                    cells: [
                      DataCell(Text(user['name'] ?? 'N/A')),
                      DataCell(Text(user['email'] ?? '')),
                      DataCell(Text(user['role'] ?? '')),
                      DataCell(Text(sites)),
                      DataCell(
                        Chip(
                          label: Text(isActive ? 'Active' : 'Revoked'),
                          backgroundColor: isActive ? Colors.green : Colors.red,
                        ),
                      ),
                      DataCell(
                        isActive
                            ? IconButton(
                                icon: const Icon(Icons.block),
                                onPressed: () => _revokeUser(user['id']),
                                tooltip: 'Revoke Access',
                              )
                            : const Icon(Icons.check, color: Colors.grey),
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
}

class CreateUserDialog extends StatefulWidget {
  final List<Map<String, dynamic>> sites;
  final VoidCallback onUserCreated;

  const CreateUserDialog({
    super.key,
    required this.sites,
    required this.onUserCreated,
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

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  String _generateLinkingCode() {
    // Generate 10-character code: XXXXX-XXXXX
    // Use non-ambiguous characters (no 0, O, 1, I, l)
    const chars = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
    final random = DateTime.now().millisecondsSinceEpoch.toString();
    final uuid = const Uuid().v4();
    final combined = random + uuid;

    String code = '';
    for (int i = 0; i < 10; i++) {
      final index = combined.codeUnitAt(i % combined.length) % chars.length;
      code += chars[index];
      if (i == 4) code += '-';
    }
    return code;
  }

  Future<void> _createUser() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedRole == UserRole.investigator && _selectedSites.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one site for Investigator'),
        ),
      );
      return;
    }

    try {
      final linkingCode = _generateLinkingCode();

      await SupabaseConfig.client.from('portal_users').insert({
        'email': _emailController.text.trim(),
        'name': _nameController.text.trim(),
        'role': _selectedRole.name,
        'assigned_sites': _selectedRole == UserRole.investigator
            ? _selectedSites.toList()
            : null,
        'linking_code': linkingCode,
        'is_active': true,
      });

      setState(() => _linkingCode = linkingCode);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating user: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_linkingCode != null) {
      return AlertDialog(
        title: const Text('User Created'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('User account created successfully!'),
            const SizedBox(height: 16),
            const Text('Linking Code:'),
            SelectableText(
              _linkingCode!,
              style: Theme.of(context).textTheme.displayMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Share this code with the user to link their device.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () {
              widget.onUserCreated();
              Navigator.pop(context);
            },
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) =>
                    v?.contains('@') ?? false ? null : 'Invalid email',
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<UserRole>(
                value: _selectedRole,
                decoration: const InputDecoration(labelText: 'Role'),
                items: UserRole.values.map((role) {
                  return DropdownMenuItem(
                    value: role,
                    child: Text(role.name.toUpperCase()),
                  );
                }).toList(),
                onChanged: (role) => setState(() => _selectedRole = role!),
              ),
              if (_selectedRole == UserRole.investigator) ...[
                const SizedBox(height: 16),
                const Text('Assign Sites:'),
                ...widget.sites.map((site) {
                  final siteId = site['site_id'] as String;
                  return CheckboxListTile(
                    title: Text(site['site_name'] ?? siteId),
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
                }),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _createUser,
          child: const Text('Create'),
        ),
      ],
    );
  }
}
