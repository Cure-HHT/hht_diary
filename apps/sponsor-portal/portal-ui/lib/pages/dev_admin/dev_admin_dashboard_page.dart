// IMPLEMENTS REQUIREMENTS:
//   REQ-d00035: Admin Dashboard Implementation
//   REQ-p00024: Portal User Roles and Permissions
//
// Developer Admin dashboard - for bootstrapping the first Portal Admin

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../widgets/error_message.dart';
import '../../widgets/portal_app_bar.dart';
import '../../widgets/status_badge.dart';

/// Developer Admin dashboard for system configuration and admin setup
class DevAdminDashboardPage extends StatefulWidget {
  const DevAdminDashboardPage({super.key});

  @override
  State<DevAdminDashboardPage> createState() => _DevAdminDashboardPageState();
}

class _DevAdminDashboardPageState extends State<DevAdminDashboardPage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final theme = Theme.of(context);

    // Check authentication and Developer Admin role
    if (!authService.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/login');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final user = authService.currentUser!;
    if (!user.hasRole(UserRole.developerAdmin)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/admin');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: const PortalAppBar(
        title: 'Clinical Trial Portal',
        subtitle: 'Developer Admin Dashboard',
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() => _selectedIndex = index);
            },
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.admin_panel_settings_outlined),
                selectedIcon: Icon(Icons.admin_panel_settings),
                label: Text('Portal Admin'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people),
                label: Text('All Users'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: Text('System'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: _buildContent(theme)),
        ],
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    switch (_selectedIndex) {
      case 0:
        return const _PortalAdminSetupTab();
      case 1:
        return const _AllUsersTab();
      case 2:
        return _buildSystemTab(theme);
      default:
        return const _PortalAdminSetupTab();
    }
  }

  Widget _buildSystemTab(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.settings_outlined,
            size: 64,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text('System Settings', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'System configuration coming soon',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tab for setting up the first Portal Admin
class _PortalAdminSetupTab extends StatefulWidget {
  const _PortalAdminSetupTab();

  @override
  State<_PortalAdminSetupTab> createState() => _PortalAdminSetupTabState();
}

class _PortalAdminSetupTabState extends State<_PortalAdminSetupTab> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();

  bool _isCreating = false;
  String? _error;
  String? _activationCode;
  bool _emailSent = false;
  String? _emailError;
  late ApiClient _apiClient;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _apiClient = ApiClient(context.read<AuthService>());
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _createPortalAdmin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isCreating = true;
      _error = null;
      _activationCode = null;
      _emailSent = false;
      _emailError = null;
    });

    try {
      final response = await _apiClient.post('/api/v1/portal/users', {
        'email': _emailController.text.trim(),
        'name': _nameController.text.trim(),
        'roles': ['Administrator'],
      });

      if (!mounted) return;

      if (response.isSuccess) {
        final data = response.data as Map<String, dynamic>;
        setState(() {
          _activationCode = data['activation_code'] as String?;
          _emailSent = data['email_sent'] == true;
          _emailError = data['email_error'] as String?;
          _isCreating = false;
        });
      } else {
        setState(() {
          _error = response.error ?? 'Failed to create admin';
          _isCreating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error: $e';
          _isCreating = false;
        });
      }
    }
  }

  void _copyActivationCode() {
    if (_activationCode != null) {
      Clipboard.setData(ClipboardData(text: _activationCode!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Activation code copied to clipboard')),
      );
    }
  }

  void _resetForm() {
    setState(() {
      _activationCode = null;
      _error = null;
      _emailSent = false;
      _emailError = null;
      _emailController.clear();
      _nameController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Portal Administrator Setup',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create the first Portal Administrator to manage users and access.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),

          // Instructions card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'How it works',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildStep(theme, '1', 'Enter the admin\'s email and name'),
                  _buildStep(theme, '2', 'Generate an activation code'),
                  _buildStep(
                    theme,
                    '3',
                    'Share the code with the admin via email',
                  ),
                  _buildStep(
                    theme,
                    '4',
                    'Admin visits /activate to create their password',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Main form card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: _activationCode != null
                  ? _buildSuccessView(theme)
                  : _buildForm(theme),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(ThemeData theme, String number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }

  Widget _buildForm(ThemeData theme) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Create Portal Administrator',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
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
              labelText: 'Email Address',
              prefixIcon: Icon(Icons.email_outlined),
              border: OutlineInputBorder(),
              helperText: 'The admin will use this email to sign in',
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
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _isCreating ? null : _createPortalAdmin,
            icon: _isCreating
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.vpn_key),
            label: Text(
              _isCreating ? 'Creating...' : 'Generate Activation Code',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 32),
            const SizedBox(width: 12),
            Text(
              'Administrator Created!',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'Account created for ${_nameController.text}',
          style: theme.textTheme.bodyLarge,
        ),
        Text(
          _emailController.text,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Activation Code',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.colorScheme.outline),
          ),
          child: Row(
            children: [
              Expanded(
                child: SelectableText(
                  _activationCode!,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontFamily: 'monospace',
                    letterSpacing: 2,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy),
                onPressed: _copyActivationCode,
                tooltip: 'Copy code',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Email status message
        if (_emailSent)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Activation email sent to ${_emailController.text}',
                    style: TextStyle(color: Colors.green.shade800),
                  ),
                ),
              ],
            ),
          )
        else if (_emailError != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Email could not be sent',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Please share the activation code manually.',
                            style: TextStyle(color: Colors.orange.shade800),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.mail_outline,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Send this code to the admin along with the activation URL:\n'
                        '/activate?code=$_activationCode',
                        style: TextStyle(
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          )
        else
          // Fallback: email not attempted (feature disabled)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.mail_outline,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Send this code to the admin along with the activation URL:\n'
                    '/activate?code=$_activationCode',
                    style: TextStyle(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: _resetForm,
          icon: const Icon(Icons.add),
          label: const Text('Create Another Admin'),
        ),
      ],
    );
  }
}

/// Tab showing all users (for Developer Admin oversight)
class _AllUsersTab extends StatefulWidget {
  const _AllUsersTab();

  @override
  State<_AllUsersTab> createState() => _AllUsersTabState();
}

class _AllUsersTabState extends State<_AllUsersTab> {
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  String? _error;
  late ApiClient _apiClient;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _apiClient = ApiClient(context.read<AuthService>());
      _loadUsers();
    });
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _apiClient.get('/api/v1/portal/users');

      if (!mounted) return;

      if (response.isSuccess) {
        final data = response.data as Map<String, dynamic>;
        setState(() {
          _users = List<Map<String, dynamic>>.from(data['users'] ?? []);
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = response.error ?? 'Failed to load users';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loadUsers,
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
              Text('All Portal Users', style: theme.textTheme.headlineMedium),
              IconButton(
                onPressed: _loadUsers,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
              ),
            ],
          ),
        ),
        Expanded(
          child: _users.isEmpty
              ? Center(
                  child: Text(
                    'No users found',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Name')),
                        DataColumn(label: Text('Email')),
                        DataColumn(label: Text('Roles')),
                        DataColumn(label: Text('Status')),
                      ],
                      rows: _users.map((user) {
                        final roles =
                            (user['roles'] as List?)?.join(', ') ?? 'None';
                        final status = user['status'] as String? ?? 'pending';

                        return DataRow(
                          cells: [
                            DataCell(Text(user['name'] ?? '')),
                            DataCell(Text(user['email'] ?? '')),
                            DataCell(Text(roles)),
                            DataCell(StatusBadge.fromString(status)),
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
