# Development Specification: Clinical Trial Web Portal

**Document Type**: Development Specification (Implementation Blueprint)
**Audience**: Software Engineers, Flutter Developers, DevOps Engineers
**Status**: Draft
**Last Updated**: 2025-10-27

---

## Overview

This document specifies the technical implementation requirements for the Clinical Trial Web Portal, a sponsor-specific web application built with **Flutter Web** that enables Admins and Investigators to manage clinical trial users, enroll patients, monitor patient engagement, and manage questionnaires.

The portal is a **separate application** from the patient diary mobile app, deployed as a web-only Flutter application. It provides role-based dashboards with site-level data isolation, integrates with Supabase for authentication and database access, and generates linking codes for patient enrollment.

**Related Documents**:
- Product Requirements: `spec/prd-portal.md` (Portal product requirements)
- Operations Requirements: `spec/ops-portal.md` (Portal deployment and operations)
- Multi-Sponsor Architecture: `spec/prd-architecture-multi-sponsor.md` (REQ-p00009)
- Overall Deployment: `spec/ops-deployment.md` (REQ-o00009)
- Database Schema: `database/schema.sql`
- RLS Policies: `database/rls_policies.sql`
- Security: `spec/prd-security-RBAC.md`, `spec/prd-security-RLS.md`

---

## Architecture Overview

The portal is a standalone Flutter web application, separate from the patient diary mobile app:

```
┌─────────────────────────────────────────────────────────────┐
│         Clinical Trial Portal (Flutter Web)                  │
│  ┌──────────────┐  ┌──────────────┐                         │
│  │    Admin     │  │ Investigator │                         │
│  │  Dashboard   │  │  Dashboard   │                         │
│  └──────────────┘  └──────────────┘                         │
│           │                │                                 │
│           └────────────────┘                                 │
│                            │                                 │
│                  ┌─────────▼─────────┐                      │
│                  │  Supabase Auth    │ (OAuth + Email/Pwd)  │
│                  └─────────┬─────────┘                      │
│                            │                                 │
│                  ┌─────────▼─────────┐                      │
│                  │ Supabase Flutter  │ (RLS-enforced)       │
│                  │      Client       │                       │
│                  └─────────┬─────────┘                      │
└────────────────────────────┼─────────────────────────────────┘
                             │
                   ┌─────────▼─────────┐
                   │  Supabase Cloud   │
                   │  (PostgreSQL 15)  │
                   │  - portal_users   │
                   │  - patients       │
                   │  - sites          │
                   │  - questionnaires │
                   │  - RLS policies   │
                   └───────────────────┘
                             │
                             │ (Separate database connection)
                             │
┌─────────────────────────────────────────────────────────────┐
│       Patient Diary App (Flutter Mobile - Separate)         │
│  - Patient diary entries (offline-first)                     │
│  - Multi-sponsor support                                     │
│  - Demo mode: "START-DEMO1" / "00END-DEMO1" codes          │
└─────────────────────────────────────────────────────────────┘
```

**Key Principles**:
- **Flutter Web**: Single codebase, potential future merge with mobile app
- **Web-Only**: No mobile deployment (separate from patient diary app)
- **Authentication First**: All routes protected, role-based access
- **Database-Driven UI**: RLS policies enforce data isolation
- **Responsive Design**: Desktop-first, tablet support
- **No Backend API**: Direct Supabase client access with RLS
- **Separate App**: Independent from patient diary mobile app (may merge later)

**Scope Simplifications**:
- **Three Roles**: Admin, Investigator, Auditor (no Analyst role)
- **No Diary Viewing**: Patient diary entries viewed in 3rd party EDC system
- **No Event Viewer**: Event sourcing exists at database level, not exposed in portal UI
- **Essential Functions Only**: Login, user management, patient enrollment, questionnaire management, audit viewing

---

## Technology Stack Requirements

# REQ-d00028: Portal Frontend Framework

**Level**: Dev | **Implements**: p00009, p00038 | **Status**: Draft

The portal SHALL be implemented using Flutter for web deployment, enabling code reuse with the patient diary mobile app if they are merged in the future.

**Technical Details**:
- **Framework**: Flutter 3.24+ (stable channel)
- **Language**: Dart 3.5+
- **Target Platform**: Web (HTML renderer for wide browser compatibility)
- **Build Tool**: Flutter build web (optimized production builds)
- **Package Manager**: pub (Dart's package manager)

**Key Dependencies**:
```yaml
dependencies:
  flutter:
    sdk: flutter
  supabase_flutter: ^2.5.0     # Supabase client with auth
  go_router: ^14.0.0           # Declarative routing
  provider: ^6.1.0             # State management
  flutter_svg: ^2.0.0          # SVG icons
  intl: ^0.19.0                # Date formatting
  url_strategy: ^0.3.0         # Remove # from URLs
```

**Web Configuration** (`web/index.html`):
```html
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Clinical Trial Portal</title>
  <script defer src="main.dart.js" type="application/javascript"></script>
</head>
<body>
  <script>
    window.addEventListener('load', function(ev) {
      _flutter.loader.loadEntrypoint({
        serviceWorker: {
          serviceWorkerVersion: serviceWorkerVersion,
        }
      });
    });
  </script>
</body>
</html>
```

**Build Commands**:
```bash
## Development
flutter run -d chrome

## Production build
flutter build web --release --web-renderer html

## Build output: build/web/
```

**Acceptance Criteria**:
- [ ] Flutter 3.24+ configured for web
- [ ] HTML renderer enabled for broad browser support
- [ ] Production build produces optimized bundle (<2MB)
- [ ] Hot reload working in development
- [ ] URL strategy removes `#` from routes
- [ ] Works on Chrome, Firefox, Safari, Edge (latest versions)

*End* *Portal Frontend Framework* | **Hash**: 38268b2d

---

# REQ-d00029: Portal UI Design System

**Level**: Dev | **Implements**: p00009 | **Status**: Draft

The portal SHALL use Flutter's Material Design 3 widgets with a custom theme matching the portal mockups.

**Technical Details**:
- **Design System**: Material Design 3
- **Theme**: Custom colors, typography, spacing
- **Components**: Material widgets (Card, Button, DataTable, Dialog, Badge, etc.)
- **Icons**: Material Icons + custom SVG icons
- **Responsive**: MediaQuery-based breakpoints

**Theme Configuration** (`lib/theme.dart`):
```dart
import 'package:flutter/material.dart';

final portalTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.blue,
    brightness: Brightness.light,
  ),
  textTheme: const TextTheme(
    displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
    displayMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
    bodyLarge: TextStyle(fontSize: 16),
    bodyMedium: TextStyle(fontSize: 14),
  ),
  cardTheme: CardTheme(
    elevation: 2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  ),
);
```

**Custom Widgets**:
- `StatusBadge`: Color-coded patient status (Recent, Warning, At Risk, No Data)
- `LinkingCodeDisplay`: Monospace code display with copy button
- `DaysWithoutDataCell`: Calculated from `last_data_entry_date`
- `QuestionnaireActions`: Send/Resend/Acknowledge buttons based on status

**Acceptance Criteria**:
- [ ] Material Design 3 theme configured
- [ ] Custom theme matches portal mockup colors
- [ ] Responsive layout works on desktop (1024px+) and tablet (768px+)
- [ ] Reusable widgets created for common patterns
- [ ] Accessible contrast ratios (WCAG AA compliant)

*End* *Portal UI Design System* | **Hash**: 022edb23
---

# REQ-d00052: Role-Based Banner Component

**Level**: Dev | **Implements**: p00030, o00055 | **Status**: Active

The portal SHALL display a color-coded banner component at the top of all authenticated pages showing the current user's role.

**Technical Details**:
- **Component**: `RoleBanner` widget in `lib/widgets/role_banner.dart`
- **Placement**: Top of authenticated scaffold, above AppBar
- **Height**: 48px fixed height
- **Color Mapping**:
  ```dart
  final roleColors = {
    'Patient': Color(0xFF2196F3),        // Blue
    'Investigator': Color(0xFF4CAF50),   // Green
    'Sponsor': Color(0xFF9C27B0),        // Purple
    'Auditor': Color(0xFFFF9800),        // Orange
    'Analyst': Color(0xFF009688),        // Teal
    'Administrator': Color(0xFFF44336),  // Red
    'Developer Admin': Color(0xFFC62828),// Dark Red
  };
  ```
- **Text Display**: Role name centered in white text (WCAG AA compliant contrast)
- **State Management**: Read from authenticated user's role claim

**Acceptance Criteria**:
- [ ] Banner displays on all authenticated pages
- [ ] Banner shows correct role name from user claims
- [ ] Banner uses correct color per role
- [ ] Text contrast meets WCAG AA standards (4.5:1 minimum)
- [ ] Banner included in core platform (all sponsor portals)

*End* *Role-Based Banner Component* | **Hash**: 40c44430
---

# REQ-d00030: Portal Routing and Navigation

**Level**: Dev | **Implements**: p00009 | **Status**: Draft

The portal SHALL implement declarative routing with role-based route guards and automatic redirects based on authentication state.

**Technical Details**:
- **Router**: go_router package (Flutter's recommended router)
- **Protected Routes**: Redirect wrapper checking auth + role
- **Route Structure**:
  ```
  /                      → Redirect to /login or dashboard
  /login                 → Login page (OAuth + email/password)
  /admin                 → Admin dashboard (Admin role only)
  /investigator          → Investigator dashboard (Investigator role only)
  /auditor               → Auditor dashboard (Auditor role only)
  /unauthorized          → 403 error page
  ```

**Router Configuration** (`lib/router.dart`):
```dart
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

final router = GoRouter(
  initialLocation: '/',
  redirect: (context, state) async {
    final authProvider = context.read<AuthProvider>();
    final isLoggedIn = authProvider.isAuthenticated;
    final role = authProvider.userRole;

    final isGoingToLogin = state.matchedLocation == '/login';

    // Not logged in → redirect to login
    if (!isLoggedIn && !isGoingToLogin) {
      return '/login';
    }

    // Logged in but on login page → redirect to dashboard
    if (isLoggedIn && isGoingToLogin) {
      if (role == 'Admin') return '/admin';
      if (role == 'Investigator') return '/investigator';
      if (role == 'Auditor') return '/auditor';
      return '/unauthorized';
    }

    // Role-based access control
    if (state.matchedLocation == '/admin' && role != 'Admin') {
      return '/unauthorized';
    }
    if (state.matchedLocation == '/investigator' && role != 'Investigator') {
      return '/unauthorized';
    }
    if (state.matchedLocation == '/auditor' && role != 'Auditor') {
      return '/unauthorized';
    }

    return null; // No redirect
  },
  routes: [
    GoRoute(
      path: '/',
      redirect: (context, state) => '/login',
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: '/admin',
      builder: (context, state) => const AdminDashboard(),
    ),
    GoRoute(
      path: '/investigator',
      builder: (context, state) => const InvestigatorDashboard(),
    ),
    GoRoute(
      path: '/auditor',
      builder: (context, state) => const AuditorDashboard(),
    ),
    GoRoute(
      path: '/unauthorized',
      builder: (context, state) => const UnauthorizedPage(),
    ),
  ],
);
```

**Acceptance Criteria**:
- [ ] go_router configured with routes
- [ ] Unauthenticated users redirected to /login
- [ ] Authenticated users redirected to role-specific dashboard
- [ ] Unauthorized access shows /unauthorized page
- [ ] Browser back button works correctly
- [ ] Deep linking preserves intended destination after login

*End* *Portal Routing and Navigation* | **Hash**: 7429dd55
---

## Authentication & Authorization Requirements

# REQ-d00031: Supabase Authentication Integration

**Level**: Dev | **Implements**: p00009, p00038, p00028 | **Status**: Draft

The portal SHALL use Supabase Authentication for OAuth (Google, Microsoft) and email/password login, with automatic session management and token refresh.

**Technical Details**:
- **Auth Provider**: Supabase Auth
- **OAuth Providers**:
  - Google Workspace (OAuth 2.0)
  - Microsoft 365 (OAuth 2.0)
- **Email/Password**: Native Supabase auth with email verification
- **Session Storage**: Supabase client handles JWT storage in browser localStorage
- **Token Refresh**: Automatic via Supabase client

**Supabase Configuration** (`lib/supabase_client.dart`):
```dart
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> initSupabase() async {
  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce, // Proof Key for Code Exchange
    ),
  );
}

final supabase = Supabase.instance.client;
```

**Authentication Provider** (`lib/providers/auth_provider.dart`):
```dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthProvider extends ChangeNotifier {
  User? _user;
  String? _userRole;
  bool _isLoading = true;

  User? get user => _user;
  String? get userRole => _userRole;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;

  AuthProvider() {
    _init();
  }

  Future<void> _init() async {
    // Get initial session
    final session = supabase.auth.currentSession;
    _user = session?.user;
    if (_user != null) {
      await _fetchUserRole();
    }
    _isLoading = false;
    notifyListeners();

    // Listen for auth state changes
    supabase.auth.onAuthStateChange.listen((data) async {
      _user = data.session?.user;
      if (_user != null) {
        await _fetchUserRole();
      } else {
        _userRole = null;
      }
      notifyListeners();
    });
  }

  Future<void> _fetchUserRole() async {
    final response = await supabase
        .from('portal_users')
        .select('role')
        .eq('supabase_user_id', _user!.id)
        .single();
    _userRole = response['role'] as String;
  }

  Future<void> signInWithOAuth(OAuthProvider provider) async {
    await supabase.auth.signInWithOAuth(provider);
  }

  Future<void> signInWithEmail(String email, String password) async {
    await supabase.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    await supabase.auth.signOut();
    _user = null;
    _userRole = null;
    notifyListeners();
  }
}
```

**OAuth Configuration** (Supabase Dashboard):
- **Google OAuth**: Client ID, Client Secret from Google Cloud Console
- **Microsoft OAuth**: Client ID, Client Secret from Azure AD
- **Redirect URLs**: `https://{sponsor-subdomain}.netlify.app/auth/callback`

**Acceptance Criteria**:
- [ ] Supabase client configured with environment variables
- [ ] Google OAuth working (login, logout, session persistence)
- [ ] Microsoft OAuth working
- [ ] Email/password login working
- [ ] Email verification required for email/password signups
- [ ] Automatic token refresh every 50 minutes
- [ ] Session persists across browser refresh
- [ ] Logout clears all auth state

*End* *Supabase Authentication Integration* | **Hash**: 8abcbfac
---

# REQ-d00032: Role-Based Access Control Implementation

**Level**: Dev | **Implements**: p00038, p00028 | **Status**: Draft

The portal SHALL enforce role-based access control (RBAC) with three roles: Admin, Investigator, and Auditor. UI routing and database queries SHALL be filtered by role using Supabase RLS policies.

**Technical Details**:
- **Roles**: Admin, Investigator, Auditor (no Analyst role)
- **Role Storage**: `portal_users.role` column (enum type)
- **Role Retrieval**: After authentication, query `portal_users` table
- **UI Enforcement**: Router guards check user role before rendering
- **Database Enforcement**: RLS policies filter data by role

**Role Permissions Matrix**:

| Feature | Admin | Investigator | Auditor |
| --- | --- | --- | --- |
| View all users | ✅ | ❌ | ✅ |
| Create users (Inv/Aud) | ✅ | ❌ | ❌ |
| Generate linking codes | ❌ | ✅ | ❌ |
| Enroll patients | ❌ | ✅ (own sites) | ❌ |
| View patient data | ✅ | ✅ (own sites) | ✅ (all) |
| Send questionnaires | ❌ | ✅ (own sites) | ❌ |
| Revoke patient tokens | ❌ | ✅ (own sites) | ❌ |
| Revoke investigator/auditor tokens | ✅ | ❌ | ❌ |
| Generate monthly reports | ❌ | ✅ | ❌ |
| Export database | ❌ | ❌ | ✅ |

**Acceptance Criteria**:
- [ ] `AuthProvider` provides user, role, loading state
- [ ] Role loaded from `portal_users` table after authentication
- [ ] Dashboard routes protected by role
- [ ] Unauthorized access shows 403 error page
- [ ] RLS policies enforce role-based data access
- [ ] Admin can access all dashboards

*End* *Role-Based Access Control Implementation* | **Hash**: 394dec01
---

# REQ-d00033: Site-Based Data Isolation

**Level**: Dev | **Implements**: p00009, d00016 | **Status**: Draft

Investigators SHALL only see and manage patients from their assigned sites, enforced by UI filtering and database RLS policies.

**Technical Details**:
- **Site Assignment**: `user_site_access` table (user_id, site_id)
- **UI Filtering**: Investigator dashboard queries patients filtered by site
- **RLS Enforcement**: `patients` table RLS policy checks site access

**Site Access Query** (Investigator Dashboard):
```dart
Future<List<Patient>> getInvestigatorPatients() async {
  // RLS policy automatically filters by user's site access
  final response = await supabase
      .from('patients')
      .select('''
        *,
        site:sites(site_number, name, location),
        questionnaires(type, status, last_completion_date)
      ''')
      .order('last_data_entry_date', ascending: false);

  return (response as List)
      .map((json) => Patient.fromJson(json))
      .toList();
}
```

**RLS Policy** (database implementation):
```sql
-- Investigators can only see patients from their assigned sites
CREATE POLICY "investigators_own_sites_patients" ON patients
  FOR SELECT
  USING (
    auth.jwt() ->> 'role' = 'investigator'
    AND site_id IN (
      SELECT site_id FROM user_site_access
      WHERE user_id = (
        SELECT id FROM portal_users WHERE supabase_user_id = auth.uid()
      )
    )
  );
```

**"My Sites" Display**:
- Investigator dashboard shows assigned sites at top
- Patient table filtered to show only those sites
- Enrollment dialog dropdown only shows assigned sites

**Acceptance Criteria**:
- [ ] `user_site_access` table created with foreign keys
- [ ] Investigator dashboard shows "My Sites" section
- [ ] Patient table filtered by investigator's sites
- [ ] Enrollment dialog shows only assigned sites
- [ ] RLS policy prevents cross-site data access
- [ ] Admin can see all sites (bypass RLS)

*End* *Site-Based Data Isolation* | **Hash**: c3440de7
---

## Frontend Components Requirements

# REQ-d00034: Login Page Implementation

**Level**: Dev | **Implements**: p00009, d00031 | **Status**: Draft

The portal SHALL provide a login page with OAuth (Google, Microsoft) and email/password authentication options.

**Technical Details**:
- **Route**: `/login`
- **OAuth Buttons**: "Continue with Google", "Continue with Microsoft"
- **Email Form**: Email input, password input, "Sign In" button
- **Design**: Centered card layout, sponsor branding, clean UI

**Component Structure** (`lib/pages/login_page.dart`):
```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleOAuthLogin(OAuthProvider provider) async {
    setState(() => _isLoading = true);
    try {
      final authProvider = context.read<AuthProvider>();
      await authProvider.signInWithOAuth(provider);
      // Redirect handled by router onAuthStateChange
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleEmailLogin() async {
    setState(() => _isLoading = true);
    try {
      final authProvider = context.read<AuthProvider>();
      await authProvider.signInWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
      );
      // Redirect handled by router
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Card(
          margin: const EdgeInsets.all(16),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Clinical Trial Portal',
                  style: Theme.of(context).textTheme.displayMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Sign in to access your dashboard',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // OAuth buttons
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : () => _handleOAuthLogin(OAuthProvider.google),
                  icon: const Icon(Icons.g_mobiledata), // Replace with Google icon
                  label: const Text('Continue with Google'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : () => _handleOAuthLogin(OAuthProvider.azure),
                  icon: const Icon(Icons.microsoft), // Replace with Microsoft icon
                  label: const Text('Continue with Microsoft'),
                ),

                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 24),

                // Email/password form
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  onSubmitted: (_) => _handleEmailLogin(),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleEmailLogin,
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text('Sign In'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

**Acceptance Criteria**:
- [ ] Login page matches portal mockup design
- [ ] Google OAuth button triggers Google login flow
- [ ] Microsoft OAuth button triggers Microsoft login flow
- [ ] Email/password form validates input
- [ ] Loading states prevent double submission
- [ ] Error messages displayed via SnackBar
- [ ] Successful login redirects to role-specific dashboard

*End* *Login Page Implementation* | **Hash**: 50d0c2b5
---

# REQ-d00035: Admin Dashboard Implementation

**Level**: Dev | **Implements**: p00009 | **Status**: Draft

The portal SHALL provide an Admin dashboard for user management, displaying all portal users and enabling creation of new Investigators with site assignments.

**Technical Details**:
- **Route**: `/admin`
- **Access**: Admin role only
- **Features**:
  - User management table (name, email, role, site assignments)
  - "Create New User" button → modal dialog
  - Summary cards (Investigator count, total patients, active patients)
  - Token revocation (deactivate investigator accounts)

**Component Structure** (`lib/pages/admin_dashboard.dart`):
```dart
import 'package:flutter/material.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  List<PortalUser> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final response = await supabase
          .from('portal_users')
          .select('''
            *,
            site_access:user_site_access(site:sites(site_number, name))
          ''')
          .order('created_at', ascending: false);

      setState(() {
        _users = (response as List)
            .map((json) => PortalUser.fromJson(json))
            .toList();
        _isLoading = false;
      });
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load users: $error')),
      );
      setState(() => _isLoading = false);
    }
  }

  Future<void> _revokeInvestigatorToken(String userId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revoke Access'),
        content: const Text('Are you sure you want to revoke this investigator\'s access? They will be logged out and unable to access the portal.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await supabase
          .from('portal_users')
          .update({'status': 'revoked'})
          .eq('id', userId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Investigator access revoked')),
      );
      _loadUsers();
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to revoke access: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            onPressed: () => context.read<AuthProvider>().signOut(),
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Summary cards
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryCard(
                          title: 'Investigators',
                          value: _users.where((u) => u.role == 'Investigator').length.toString(),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _SummaryCard(
                          title: 'Total Users',
                          value: _users.length.toString(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // User management card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'User Management',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              ElevatedButton.icon(
                                onPressed: () => _showCreateUserDialog(),
                                icon: const Icon(Icons.add),
                                label: const Text('Create New User'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          DataTable(
                            columns: const [
                              DataColumn(label: Text('Name')),
                              DataColumn(label: Text('Email')),
                              DataColumn(label: Text('Role')),
                              DataColumn(label: Text('Sites')),
                              DataColumn(label: Text('Actions')),
                            ],
                            rows: _users.map((user) {
                              return DataRow(cells: [
                                DataCell(Text(user.name)),
                                DataCell(Text(user.email)),
                                DataCell(
                                  Chip(
                                    label: Text(user.role),
                                    backgroundColor: user.role == 'Admin'
                                        ? Colors.red.shade100
                                        : Colors.grey.shade200,
                                  ),
                                ),
                                DataCell(Text(
                                  user.siteAccess.map((s) => s.siteNumber).join(', '),
                                )),
                                DataCell(
                                  user.role == 'Investigator'
                                      ? IconButton(
                                          icon: const Icon(Icons.block),
                                          onPressed: () => _revokeInvestigatorToken(user.id),
                                          tooltip: 'Revoke access',
                                        )
                                      : const SizedBox.shrink(),
                                ),
                              ]);
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  void _showCreateUserDialog() {
    showDialog(
      context: context,
      builder: (context) => CreateUserDialog(onUserCreated: _loadUsers),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;

  const _SummaryCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.displayLarge,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
```

**Acceptance Criteria**:
- [ ] Admin dashboard matches portal mockup design
- [ ] User table displays all portal users
- [ ] Role badges color-coded (Admin red, Investigator grey)
- [ ] Site assignments displayed for investigators
- [ ] Summary cards show accurate counts
- [ ] "Create New User" button opens dialog
- [ ] Revoke button deactivates investigator accounts
- [ ] Table responsive on desktop and tablet

*End* *Admin Dashboard Implementation* | **Hash**: 7b82ec93
---

# REQ-d00036: Create User Dialog Implementation

**Level**: Dev | **Implements**: p00038 | **Status**: Draft

The portal SHALL provide a modal dialog for Admins to create new Investigators and Auditors with site assignments (for Investigators only) and generate linking codes for device enrollment (for Investigators only).

**Technical Details**:
- **Trigger**: "Create New User" button on Admin dashboard
- **Form Fields**:
  - Name (text input, required)
  - Email (email input, required, validated)
  - Role (dropdown: Investigator, Auditor)
  - Sites (multi-checkbox, shown only for Investigator role, required if Investigator)
  - Linking Code (read-only, shown only for Investigator role, auto-generated)
- **Linking Code**: Auto-generated XXXXX-XXXXX format for Investigators only (Auditors don't need device enrollment)
- **Validation**: All fields required, email format check, at least one site for Investigators
- **Submission**: Creates `portal_users` record + `user_site_access` records (for Investigators only) + generates linking code (for Investigators only)

**Linking Code Generation**:
```dart
String generateLinkingCode() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Exclude ambiguous: 0, O, 1, I
  final random = Random.secure();

  String generatePart() {
    return List.generate(5, (_) => chars[random.nextInt(chars.length)]).join();
  }

  return '${generatePart()}-${generatePart()}'; // e.g., KBN48-T5GJZ
}
```

**Component Structure** (`lib/dialogs/create_user_dialog.dart`):
```dart
import 'package:flutter/material.dart';
import 'dart:math';

class CreateUserDialog extends StatefulWidget {
  final VoidCallback onUserCreated;

  const CreateUserDialog({super.key, required this.onUserCreated});

  @override
  State<CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends State<CreateUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  String _selectedRole = 'Investigator'; // Default to Investigator
  List<Site> _allSites = [];
  List<String> _selectedSiteIds = [];
  String _linkingCode = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _linkingCode = generateLinkingCode();
    _loadSites();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadSites() async {
    final response = await supabase
        .from('sites')
        .select()
        .order('site_number');

    setState(() {
      _allSites = (response as List)
          .map((json) => Site.fromJson(json))
          .toList();
    });
  }

  String generateLinkingCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();

    String generatePart() {
      return List.generate(5, (_) => chars[random.nextInt(chars.length)]).join();
    }

    return '${generatePart()}-${generatePart()}';
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    // Only Investigators need site assignment
    if (_selectedRole == 'Investigator' && _selectedSiteIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one site for investigator')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Create portal user
      final userResponse = await supabase
          .from('portal_users')
          .insert({
            'name': _nameController.text.trim(),
            'email': _emailController.text.trim(),
            'role': _selectedRole,
            'linking_code': _selectedRole == 'Investigator' ? _linkingCode : null, // Only Investigators get linking codes
            'status': 'active',
          })
          .select()
          .single();

      final userId = userResponse['id'] as String;

      // Create site access records (only for Investigators)
      if (_selectedRole == 'Investigator') {
        final siteAccessRecords = _selectedSiteIds.map((siteId) => {
          'user_id': userId,
          'site_id': siteId,
        }).toList();

        await supabase.from('user_site_access').insert(siteAccessRecords);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _selectedRole == 'Investigator'
                  ? 'Investigator created. Linking code: $_linkingCode'
                  : 'Auditor created successfully',
            ),
            duration: const Duration(seconds: 5),
          ),
        );
        Navigator.pop(context);
        widget.onUserCreated();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create user: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create New Investigator'),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
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
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Email is required';
                    }
                    if (!value.contains('@')) {
                      return 'Invalid email format';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                Text(
                  'Assigned Sites',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: _allSites.map((site) {
                      return CheckboxListTile(
                        title: Text('${site.siteNumber} - ${site.name}, ${site.location}'),
                        value: _selectedSiteIds.contains(site.id),
                        onChanged: (checked) {
                          setState(() {
                            if (checked == true) {
                              _selectedSiteIds.add(site.id);
                            } else {
                              _selectedSiteIds.remove(site.id);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  'Device Linking Code',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: TextEditingController(text: _linkingCode),
                        readOnly: true,
                        style: const TextStyle(fontFamily: 'monospace'),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _linkingCode));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Linking code copied')),
                        );
                      },
                      icon: const Icon(Icons.copy),
                      tooltip: 'Copy linking code',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Share this code with the investigator to link their device.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleSubmit,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create Investigator'),
        ),
      ],
    );
  }
}
```

**Acceptance Criteria**:
- [ ] Dialog matches portal mockup design
- [ ] Name, email fields validated
- [ ] Role fixed to "Investigator" (no dropdown)
- [ ] Multi-select checkboxes for site assignment
- [ ] Linking code auto-generated when dialog opens
- [ ] Linking code uses non-ambiguous characters only
- [ ] Copy button copies linking code to clipboard
- [ ] Form submission creates `portal_users` record
- [ ] Form submission creates `user_site_access` records
- [ ] Duplicate email check prevents creation
- [ ] Success message shows linking code
- [ ] Dialog closes and table refreshes after creation

*End* *Create User Dialog Implementation* | **Hash**: 42a93086
---

# REQ-d00037: Investigator Dashboard Implementation

**Level**: Dev | **Implements**: p00040, p00027 | **Status**: Draft

The portal SHALL provide an Investigator dashboard showing assigned sites, patient monitoring table, questionnaire management, and patient enrollment.

**Technical Details**:
- **Route**: `/investigator`
- **Access**: Investigator role only (RLS enforced)
- **Features**:
  - "My Sites" section (assigned sites)
  - Patient Summary table (ID, site, status, days without data, last login, questionnaires)
  - "Enroll New Patient" button → generates patient linking code
  - Questionnaire actions (Send, Resend, Acknowledge)
  - Summary cards (Total Patients, Active Today, Requires Follow-up)
  - "Generate Monthly Report" button

**Patient Status Calculation**:
```dart
enum PatientStatus { recent, warning, atRisk, noData }

PatientStatus calculatePatientStatus(DateTime? lastDataEntry) {
  if (lastDataEntry == null) return PatientStatus.noData;

  final daysWithoutData = DateTime.now().difference(lastDataEntry).inDays;

  if (daysWithoutData <= 3) return PatientStatus.recent;
  if (daysWithoutData <= 7) return PatientStatus.warning;
  return PatientStatus.atRisk;
}

Color getStatusColor(PatientStatus status) {
  switch (status) {
    case PatientStatus.recent:
      return Colors.green;
    case PatientStatus.warning:
      return Colors.orange;
    case PatientStatus.atRisk:
      return Colors.red;
    case PatientStatus.noData:
      return Colors.grey;
  }
}
```

**Component Structure** (`lib/pages/investigator_dashboard.dart`):
```dart
import 'package:flutter/material.dart';

class InvestigatorDashboard extends StatefulWidget {
  const InvestigatorDashboard({super.key});

  @override
  State<InvestigatorDashboard> createState() => _InvestigatorDashboardState();
}

class _InvestigatorDashboardState extends State<InvestigatorDashboard> {
  List<Site> _mySites = [];
  List<Patient> _patients = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadMySites(),
      _loadMyPatients(),
    ]);
    setState(() => _isLoading = false);
  }

  Future<void> _loadMySites() async {
    // RLS automatically filters by user's site access
    final response = await supabase
        .from('sites')
        .select()
        .order('site_number');

    _mySites = (response as List)
        .map((json) => Site.fromJson(json))
        .toList();
  }

  Future<void> _loadMyPatients() async {
    // RLS automatically filters by user's site access
    final response = await supabase
        .from('patients')
        .select('''
          *,
          site:sites(site_number, name),
          questionnaires(type, status, last_completion_date)
        ''')
        .order('last_data_entry_date', ascending: false);

    _patients = (response as List)
        .map((json) => Patient.fromJson(json))
        .toList();
  }

  Future<void> _sendQuestionnaire(String patientId, String type) async {
    try {
      await supabase
          .from('questionnaires')
          .update({
            'status': 'sent',
            'sent_at': DateTime.now().toIso8601String(),
          })
          .eq('patient_id', patientId)
          .eq('type', type);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$type questionnaire sent')),
      );
      _loadMyPatients();
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send questionnaire: $error')),
      );
    }
  }

  Future<void> _acknowledgeQuestionnaire(String patientId, String type) async {
    try {
      await supabase
          .from('questionnaires')
          .update({
            'status': 'not_sent',
            'acknowledged_at': DateTime.now().toIso8601String(),
          })
          .eq('patient_id', patientId)
          .eq('type', type);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Questionnaire acknowledged')),
      );
      _loadMyPatients();
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to acknowledge: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final totalPatients = _patients.length;
    final activeToday = _patients.where((p) {
      if (p.lastDataEntryDate == null) return false;
      return DateTime.now().difference(p.lastDataEntryDate!).inDays == 0;
    }).length;
    final requiresFollowup = _patients.where((p) {
      if (p.lastDataEntryDate == null) return true;
      return DateTime.now().difference(p.lastDataEntryDate!).inDays > 7;
    }).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Investigator Dashboard'),
        actions: [
          IconButton(
            onPressed: () => context.read<AuthProvider>().signOut(),
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // My Sites
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'My Sites',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: _mySites.map((site) {
                        return Chip(
                          label: Text('${site.siteNumber} - ${site.name}, ${site.location}'),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Summary Cards
            Row(
              children: [
                Expanded(
                  child: _SummaryCard(
                    title: 'Total Patients',
                    value: totalPatients.toString(),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _SummaryCard(
                    title: 'Active Today',
                    value: activeToday.toString(),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _SummaryCard(
                    title: 'Requires Follow-up',
                    value: requiresFollowup.toString(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Patient Summary Table
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Patient Summary',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Row(
                            children: [
                              ElevatedButton.icon(
                                onPressed: () => _showEnrollPatientDialog(),
                                icon: const Icon(Icons.add),
                                label: const Text('Enroll Patient'),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: () => _generateMonthlyReport(),
                                icon: const Icon(Icons.email),
                                label: const Text('Monthly Report'),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Patient ID')),
                              DataColumn(label: Text('Site')),
                              DataColumn(label: Text('Status')),
                              DataColumn(label: Text('Days Without Data')),
                              DataColumn(label: Text('Last Login')),
                              DataColumn(label: Text('NOSE HHT')),
                              DataColumn(label: Text('QoL')),
                              DataColumn(label: Text('Actions')),
                            ],
                            rows: _patients.map((patient) {
                              final noseQ = patient.questionnaires.firstWhere(
                                (q) => q.type == 'NOSE_HHT',
                                orElse: () => Questionnaire.empty(),
                              );
                              final qolQ = patient.questionnaires.firstWhere(
                                (q) => q.type == 'QoL',
                                orElse: () => Questionnaire.empty(),
                              );

                              return DataRow(cells: [
                                DataCell(Text(patient.patientId)),
                                DataCell(Text(patient.site.name)),
                                DataCell(
                                  Chip(
                                    label: Text(patient.status.name.toUpperCase()),
                                    backgroundColor: getStatusColor(patient.status),
                                  ),
                                ),
                                DataCell(Text(
                                  patient.lastDataEntryDate == null
                                      ? 'No data'
                                      : '${DateTime.now().difference(patient.lastDataEntryDate!).inDays} days',
                                )),
                                DataCell(Text(patient.lastLoginRelative)),
                                DataCell(
                                  _QuestionnaireActions(
                                    questionnaire: noseQ,
                                    onSend: () => _sendQuestionnaire(patient.patientId, 'NOSE_HHT'),
                                    onAcknowledge: () => _acknowledgeQuestionnaire(patient.patientId, 'NOSE_HHT'),
                                  ),
                                ),
                                DataCell(
                                  _QuestionnaireActions(
                                    questionnaire: qolQ,
                                    onSend: () => _sendQuestionnaire(patient.patientId, 'QoL'),
                                    onAcknowledge: () => _acknowledgeQuestionnaire(patient.patientId, 'QoL'),
                                  ),
                                ),
                                DataCell(
                                  IconButton(
                                    icon: const Icon(Icons.block),
                                    onPressed: () => _revokePatientToken(patient.patientId),
                                    tooltip: 'Unenroll patient',
                                  ),
                                ),
                              ]);
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEnrollPatientDialog() {
    showDialog(
      context: context,
      builder: (context) => EnrollPatientDialog(
        assignedSites: _mySites,
        onPatientEnrolled: _loadMyPatients,
      ),
    );
  }

  Future<void> _generateMonthlyReport() async {
    // TODO: Implement monthly report generation
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Monthly report generation coming soon')),
    );
  }

  Future<void> _revokePatientToken(String patientId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unenroll Patient'),
        content: const Text('Are you sure you want to unenroll this patient? They will lose access to their trial data.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Unenroll'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await supabase
          .from('patients')
          .update({'status': 'unenrolled'})
          .eq('patient_id', patientId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Patient unenrolled')),
      );
      _loadMyPatients();
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to unenroll patient: $error')),
      );
    }
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;

  const _SummaryCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.displayLarge,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionnaireActions extends StatelessWidget {
  final Questionnaire questionnaire;
  final VoidCallback onSend;
  final VoidCallback onAcknowledge;

  const _QuestionnaireActions({
    required this.questionnaire,
    required this.onSend,
    required this.onAcknowledge,
  });

  @override
  Widget build(BuildContext context) {
    if (questionnaire.status == 'not_sent' || questionnaire.status == null) {
      return ElevatedButton(
        onPressed: onSend,
        child: const Text('Send'),
      );
    }

    if (questionnaire.status == 'sent') {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Chip(
            label: Text('Pending'),
            backgroundColor: Colors.orange,
          ),
          TextButton(
            onPressed: onSend,
            child: const Text('Resend'),
          ),
        ],
      );
    }

    if (questionnaire.status == 'completed') {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Last: ${questionnaire.lastCompletionDate != null ? DateFormat.yMd().format(questionnaire.lastCompletionDate!) : "N/A"}',
            style: const TextStyle(fontSize: 12),
          ),
          const Chip(
            label: Text('Completed'),
            backgroundColor: Colors.green,
          ),
          ElevatedButton(
            onPressed: onAcknowledge,
            child: const Text('Acknowledge'),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }
}
```

**Acceptance Criteria**:
- [ ] Investigator dashboard matches portal mockup design
- [ ] "My Sites" section shows assigned sites
- [ ] Patient table shows only patients from investigator's sites (RLS)
- [ ] Status badges color-coded correctly
- [ ] Days without data calculated correctly
- [ ] Last login shows relative time ("2 days ago")
- [ ] Questionnaire actions work (Send, Resend, Acknowledge)
- [ ] Summary cards show accurate counts
- [ ] "Enroll New Patient" button opens dialog
- [ ] "Monthly Report" button triggers report generation
- [ ] "Unenroll" button revokes patient tokens
- [ ] Table responsive on desktop and tablet

*End* *Investigator Dashboard Implementation* | **Hash**: 9f7a8612
---

# REQ-d00038: Enroll Patient Dialog Implementation

**Level**: Dev | **Implements**: p00039 | **Status**: Draft

The portal SHALL provide a modal dialog for Investigators to generate patient linking codes for enrollment, with site selection restricted to investigator's assigned sites.

**Technical Details**:
- **Trigger**: "Enroll Patient" button on Investigator dashboard
- **Form Fields**:
  - Site: Dropdown (only investigator's assigned sites)
  - Patient Linking Code: Read-only, auto-generated 10-character code (XXXXX-XXXXX)
- **No Patient ID Input**: Portal generates the linking code; patient ID assigned when patient uses code in mobile app
- **Validation**: Site selection required
- **Submission**: Creates `patients` record with linking code + creates initial questionnaire records

**Component Structure** (`lib/dialogs/enroll_patient_dialog.dart`):
```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';

class EnrollPatientDialog extends StatefulWidget {
  final List<Site> assignedSites;
  final VoidCallback onPatientEnrolled;

  const EnrollPatientDialog({
    super.key,
    required this.assignedSites,
    required this.onPatientEnrolled,
  });

  @override
  State<EnrollPatientDialog> createState() => _EnrollPatientDialogState();
}

class _EnrollPatientDialogState extends State<EnrollPatientDialog> {
  String? _selectedSiteId;
  String _linkingCode = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _linkingCode = _generateLinkingCode();
  }

  String _generateLinkingCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();

    String generatePart() {
      return List.generate(5, (_) => chars[random.nextInt(chars.length)]).join();
    }

    return '${generatePart()}-${generatePart()}';
  }

  Future<void> _handleSubmit() async {
    if (_selectedSiteId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a site')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Check if linking code already exists (should be unique)
      final existing = await supabase
          .from('patients')
          .select('id')
          .eq('linking_code', _linkingCode)
          .maybeSingle();

      if (existing != null) {
        throw Exception('Linking code collision (very rare). Please try again.');
      }

      // Create patient record (patient_id will be assigned when patient enrolls)
      final patientResponse = await supabase
          .from('patients')
          .insert({
            'site_id': _selectedSiteId,
            'linking_code': _linkingCode,
            'enrollment_date': DateTime.now().toIso8601String(),
            'status': 'pending_enrollment', // Changed when patient uses code
          })
          .select()
          .single();

      final patientId = patientResponse['id'] as String;

      // Create initial questionnaire records
      await supabase.from('questionnaires').insert([
        {
          'patient_id': patientId,
          'type': 'NOSE_HHT',
          'status': 'not_sent',
        },
        {
          'patient_id': patientId,
          'type': 'QoL',
          'status': 'not_sent',
        },
      ]);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Patient enrollment prepared. Share code: $_linkingCode'),
            duration: const Duration(seconds: 5),
          ),
        );
        Navigator.pop(context);
        widget.onPatientEnrolled();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to prepare enrollment: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Enroll New Patient'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Generate a linking code for the patient to enroll in their mobile app.'),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: _selectedSiteId,
              decoration: const InputDecoration(
                labelText: 'Site',
                border: OutlineInputBorder(),
              ),
              items: widget.assignedSites.map((site) {
                return DropdownMenuItem(
                  value: site.id,
                  child: Text('${site.siteNumber} - ${site.name}, ${site.location}'),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedSiteId = value);
              },
            ),
            const SizedBox(height: 16),

            Text(
              'Patient Linking Code',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: TextEditingController(text: _linkingCode),
                    readOnly: true,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _linkingCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Linking code copied')),
                    );
                  },
                  icon: const Icon(Icons.copy),
                  tooltip: 'Copy linking code',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Share this code with the patient. They will enter it in their mobile app to enroll.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleSubmit,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Generate Code'),
        ),
      ],
    );
  }
}
```

**Acceptance Criteria**:
- [ ] Dialog matches portal mockup design
- [ ] Site dropdown shows only investigator's assigned sites
- [ ] Linking code auto-generated when dialog opens
- [ ] Linking code uses non-ambiguous characters only
- [ ] Copy button copies linking code to clipboard
- [ ] Form submission creates `patients` record with status `pending_enrollment`
- [ ] Form submission creates initial questionnaire records (NOSE_HHT, QoL)
- [ ] Linking code uniqueness checked before insertion
- [ ] Success message shows linking code
- [ ] Dialog closes and table refreshes after enrollment

*End* *Enroll Patient Dialog Implementation* | **Hash**: c553d403
---

# REQ-d00051: Auditor Dashboard Implementation

**Level**: Dev | **Implements**: p00029 | **Status**: Draft

The portal SHALL provide an Auditor dashboard with read-only access to all portal data (users, patients, sites, questionnaires) and a stubbed "Export Database" function for compliance auditing.

**Technical Details**:
- **Route**: `/auditor`
- **Access**: Auditor role only (RLS enforced)
- **Features**:
  - Read-only view of all users (all sites, all investigators)
  - Read-only view of all patients (across all sites)
  - Read-only view of questionnaire status
  - "Export Database" button (stubbed, returns "Export coming soon" message)
  - No create, update, or delete actions (all buttons disabled or hidden)

**Component Structure** (`lib/pages/auditor_dashboard.dart`):
```dart
import 'package:flutter/material.dart';

class AuditorDashboard extends StatefulWidget {
  const AuditorDashboard({super.key});

  @override
  State<AuditorDashboard> createState() => _AuditorDashboardState();
}

class _AuditorDashboardState extends State<AuditorDashboard> {
  List<PortalUser> _users = [];
  List<Patient> _patients = [];
  List<Site> _sites = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadUsers(),
      _loadPatients(),
      _loadSites(),
    ]);
    setState(() => _isLoading = false);
  }

  Future<void> _loadUsers() async {
    // RLS allows Auditors to see all users
    final response = await supabase
        .from('portal_users')
        .select('''
          *,
          site_access:user_site_access(site:sites(site_number, name))
        ''')
        .order('created_at', ascending: false);

    _users = (response as List)
        .map((json) => PortalUser.fromJson(json))
        .toList();
  }

  Future<void> _loadPatients() async {
    // RLS allows Auditors to see all patients
    final response = await supabase
        .from('patients')
        .select('''
          *,
          site:sites(site_number, name),
          questionnaires(type, status, last_completion_date)
        ''')
        .order('enrollment_date', ascending: false);

    _patients = (response as List)
        .map((json) => Patient.fromJson(json))
        .toList();
  }

  Future<void> _loadSites() async {
    final response = await supabase
        .from('sites')
        .select()
        .order('site_number');

    _sites = (response as List)
        .map((json) => Site.fromJson(json))
        .toList();
  }

  Future<void> _exportDatabase() async {
    // TODO: Implement database export (CSV, JSON, or SQL dump)
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Database export coming soon'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Auditor Dashboard'),
        actions: [
          ElevatedButton.icon(
            onPressed: _exportDatabase,
            icon: const Icon(Icons.download),
            label: const Text('Export Database'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
          IconButton(
            onPressed: () => context.read<AuthProvider>().signOut(),
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Summary Cards
              Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      title: 'Total Users',
                      value: _users.length.toString(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _SummaryCard(
                      title: 'Total Patients',
                      value: _patients.length.toString(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _SummaryCard(
                      title: 'Total Sites',
                      value: _sites.length.toString(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _SummaryCard(
                      title: 'Investigators',
                      value: _users.where((u) => u.role == 'Investigator').length.toString(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Users Table
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Portal Users (Read-Only)',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Chip(
                            label: const Text('AUDIT MODE'),
                            backgroundColor: Colors.orange.shade100,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Name')),
                            DataColumn(label: Text('Email')),
                            DataColumn(label: Text('Role')),
                            DataColumn(label: Text('Sites')),
                            DataColumn(label: Text('Status')),
                            DataColumn(label: Text('Created')),
                          ],
                          rows: _users.map((user) {
                            return DataRow(cells: [
                              DataCell(Text(user.name)),
                              DataCell(Text(user.email)),
                              DataCell(
                                Chip(
                                  label: Text(user.role),
                                  backgroundColor: user.role == 'Admin'
                                      ? Colors.red.shade100
                                      : Colors.grey.shade200,
                                ),
                              ),
                              DataCell(Text(
                                user.siteAccess.map((s) => s.siteNumber).join(', '),
                              )),
                              DataCell(
                                Chip(
                                  label: Text(user.status),
                                  backgroundColor: user.status == 'active'
                                      ? Colors.green.shade100
                                      : Colors.red.shade100,
                                ),
                              ),
                              DataCell(Text(
                                DateFormat.yMd().format(user.createdAt),
                              )),
                            ]);
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Patients Table
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'All Patients (Read-Only)',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Patient ID')),
                            DataColumn(label: Text('Site')),
                            DataColumn(label: Text('Status')),
                            DataColumn(label: Text('Enrollment Date')),
                            DataColumn(label: Text('Days Without Data')),
                            DataColumn(label: Text('Last Login')),
                            DataColumn(label: Text('NOSE HHT')),
                            DataColumn(label: Text('QoL')),
                          ],
                          rows: _patients.map((patient) {
                            final noseQ = patient.questionnaires.firstWhere(
                              (q) => q.type == 'NOSE_HHT',
                              orElse: () => Questionnaire.empty(),
                            );
                            final qolQ = patient.questionnaires.firstWhere(
                              (q) => q.type == 'QoL',
                              orElse: () => Questionnaire.empty(),
                            );

                            return DataRow(cells: [
                              DataCell(Text(patient.patientId ?? 'Pending')),
                              DataCell(Text(patient.site.name)),
                              DataCell(
                                Chip(
                                  label: Text(patient.status),
                                  backgroundColor: patient.status == 'enrolled'
                                      ? Colors.green.shade100
                                      : Colors.grey.shade200,
                                ),
                              ),
                              DataCell(Text(
                                patient.enrollmentDate != null
                                    ? DateFormat.yMd().format(patient.enrollmentDate!)
                                    : 'N/A',
                              )),
                              DataCell(Text(
                                patient.lastDataEntryDate == null
                                    ? 'No data'
                                    : '${DateTime.now().difference(patient.lastDataEntryDate!).inDays} days',
                              )),
                              DataCell(Text(patient.lastLoginRelative)),
                              DataCell(
                                Chip(
                                  label: Text(noseQ.status ?? 'not_sent'),
                                  backgroundColor: _getQuestionnaireStatusColor(noseQ.status),
                                ),
                              ),
                              DataCell(
                                Chip(
                                  label: Text(qolQ.status ?? 'not_sent'),
                                  backgroundColor: _getQuestionnaireStatusColor(qolQ.status),
                                ),
                              ),
                            ]);
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getQuestionnaireStatusColor(String? status) {
    switch (status) {
      case 'sent':
        return Colors.orange.shade100;
      case 'completed':
        return Colors.green.shade100;
      case 'not_sent':
      default:
        return Colors.grey.shade200;
    }
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;

  const _SummaryCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.displayLarge,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
```

**Acceptance Criteria**:
- [ ] Auditor dashboard accessible at `/auditor` route
- [ ] Auditor can view all users (across all sites)
- [ ] Auditor can view all patients (across all sites)
- [ ] Auditor can view all questionnaire statuses
- [ ] "Export Database" button visible in app bar
- [ ] "Export Database" shows "coming soon" message (stubbed)
- [ ] No create, update, or delete actions available
- [ ] "AUDIT MODE" indicator visible
- [ ] Summary cards show accurate counts
- [ ] RLS policies allow Auditor read access to all data

*End* *Auditor Dashboard Implementation* | **Hash**: 86038561
---

## Database Schema Requirements

# REQ-d00039: Portal Users Table Schema

**Level**: Dev | **Implements**: p00009, d00016 | **Status**: Draft

The portal database SHALL include a `portal_users` table to store portal user accounts with roles, linking codes, and authentication linkage.

**Technical Details**:

**Table: `portal_users`**
```sql
CREATE TYPE user_role AS ENUM ('Admin', 'Investigator', 'Auditor');

CREATE TABLE portal_users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  supabase_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  role user_role NOT NULL,
  linking_code TEXT UNIQUE, -- For device enrollment
  status TEXT NOT NULL DEFAULT 'active', -- active, revoked
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Index for fast role lookup by Supabase user ID
CREATE INDEX idx_portal_users_supabase_id ON portal_users(supabase_user_id);

-- Index for email lookups
CREATE INDEX idx_portal_users_email ON portal_users(email);

-- Index for linking code lookups (mobile app uses this)
CREATE INDEX idx_portal_users_linking_code ON portal_users(linking_code);

-- RLS policies
ALTER TABLE portal_users ENABLE ROW LEVEL SECURITY;

-- Admins and Auditors can see all users
CREATE POLICY "admins_auditors_see_all_users" ON portal_users
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM portal_users pu
      WHERE pu.supabase_user_id = auth.uid()
      AND pu.role IN ('Admin', 'Auditor')
    )
  );

-- Investigators can see themselves
CREATE POLICY "users_see_themselves" ON portal_users
  FOR SELECT
  USING (supabase_user_id = auth.uid());

-- Admins can insert new users
CREATE POLICY "admins_insert_users" ON portal_users
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM portal_users pu
      WHERE pu.supabase_user_id = auth.uid()
      AND pu.role = 'Admin'
    )
  );

-- Admins can update user status (revoke tokens)
CREATE POLICY "admins_update_users" ON portal_users
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM portal_users pu
      WHERE pu.supabase_user_id = auth.uid()
      AND pu.role = 'Admin'
    )
  );
```

**Columns**:
- `id`: Primary key (UUID)
- `supabase_user_id`: Foreign key to Supabase `auth.users` table (nullable until investigator enrolls device)
- `email`: Unique email address for login
- `name`: Display name (e.g., "Dr. Sarah Johnson")
- `role`: Enum (Admin, Investigator)
- `linking_code`: Unique code for device enrollment (XXXXX-XXXXX format, same as patient codes)
- `status`: `active` or `revoked` (revoked users cannot log in)
- `created_at`: Timestamp of user creation
- `updated_at`: Timestamp of last update

**Acceptance Criteria**:
- [ ] `portal_users` table created with correct schema
- [ ] `user_role` enum type created
- [ ] Foreign key constraint to `auth.users` table
- [ ] Unique constraint on `email` column
- [ ] Unique constraint on `linking_code` column
- [ ] Indexes created for performance
- [ ] RLS policies enable role-based access
- [ ] Admins can query all users
- [ ] Investigators can only query themselves

*End* *Portal Users Table Schema* | **Hash**: 848297db
---

# REQ-d00040: User Site Access Table Schema

**Level**: Dev | **Implements**: p00009, d00033 | **Status**: Draft

The portal database SHALL include a `user_site_access` table to store site assignments for Investigators, enabling site-level data isolation.

**Technical Details**:

**Table: `user_site_access`**
```sql
CREATE TABLE user_site_access (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES portal_users(id) ON DELETE CASCADE,
  site_id UUID NOT NULL REFERENCES sites(id) ON DELETE CASCADE,
  assigned_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(user_id, site_id)
);

-- Index for fast site lookups by user
CREATE INDEX idx_user_site_access_user ON user_site_access(user_id);

-- Index for fast user lookups by site
CREATE INDEX idx_user_site_access_site ON user_site_access(site_id);

-- RLS policies
ALTER TABLE user_site_access ENABLE ROW LEVEL SECURITY;

-- Admins and Auditors can see all site access records
CREATE POLICY "admins_auditors_see_all_site_access" ON user_site_access
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM portal_users pu
      WHERE pu.supabase_user_id = auth.uid()
      AND pu.role IN ('Admin', 'Auditor')
    )
  );

-- Investigators can see their own site access
CREATE POLICY "users_see_own_site_access" ON user_site_access
  FOR SELECT
  USING (
    user_id IN (
      SELECT id FROM portal_users
      WHERE supabase_user_id = auth.uid()
    )
  );

-- Admins can insert site access records
CREATE POLICY "admins_insert_site_access" ON user_site_access
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM portal_users pu
      WHERE pu.supabase_user_id = auth.uid()
      AND pu.role = 'Admin'
    )
  );
```

**Columns**:
- `id`: Primary key (UUID)
- `user_id`: Foreign key to `portal_users.id`
- `site_id`: Foreign key to `sites.id`
- `assigned_at`: Timestamp of site assignment
- Unique constraint on `(user_id, site_id)` prevents duplicates

**Acceptance Criteria**:
- [ ] `user_site_access` table created with correct schema
- [ ] Foreign key constraints to `portal_users` and `sites`
- [ ] Unique constraint prevents duplicate assignments
- [ ] Indexes created for performance
- [ ] RLS policies enable role-based access
- [ ] Cascade delete removes assignments when user or site deleted

*End* *User Site Access Table Schema* | **Hash**: 2e3c150c
---

# REQ-d00041: Patients Table Extensions for Portal

**Level**: Dev | **Implements**: p00009 | **Status**: Draft

The portal database SHALL extend the `patients` table with fields for linking codes, enrollment tracking, and status management.

**Technical Details**:

**Table Extensions: `patients`**
```sql
-- Add new columns to existing patients table
ALTER TABLE patients ADD COLUMN linking_code TEXT UNIQUE;
ALTER TABLE patients ADD COLUMN enrollment_date TIMESTAMPTZ;
ALTER TABLE patients ADD COLUMN last_login_at TIMESTAMPTZ;
ALTER TABLE patients ADD COLUMN last_data_entry_date TIMESTAMPTZ;
ALTER TABLE patients ADD COLUMN mobile_app_linked_at TIMESTAMPTZ;
ALTER TABLE patients ADD COLUMN status TEXT DEFAULT 'pending_enrollment';
-- Status: pending_enrollment, enrolled, unenrolled

-- Index for linking code lookups (mobile app uses this)
CREATE INDEX idx_patients_linking_code ON patients(linking_code);

-- Index for status queries
CREATE INDEX idx_patients_status ON patients(status);

-- Index for engagement monitoring
CREATE INDEX idx_patients_last_data_entry ON patients(last_data_entry_date DESC);

-- RLS policy for investigators to see patients from their sites
CREATE POLICY "investigators_own_sites_patients" ON patients
  FOR SELECT
  USING (
    -- Admins and Auditors see all
    EXISTS (
      SELECT 1 FROM portal_users pu
      WHERE pu.supabase_user_id = auth.uid()
      AND pu.role IN ('Admin', 'Auditor')
    )
    OR
    -- Investigators see patients from their assigned sites
    (
      EXISTS (
        SELECT 1 FROM portal_users pu
        WHERE pu.supabase_user_id = auth.uid()
        AND pu.role = 'Investigator'
      )
      AND site_id IN (
        SELECT usa.site_id
        FROM user_site_access usa
        JOIN portal_users pu ON usa.user_id = pu.id
        WHERE pu.supabase_user_id = auth.uid()
      )
    )
  );

-- RLS policy for investigators to insert patients (only to their sites)
CREATE POLICY "investigators_insert_own_sites_patients" ON patients
  FOR INSERT
  WITH CHECK (
    -- Admins can enroll anywhere
    EXISTS (
      SELECT 1 FROM portal_users pu
      WHERE pu.supabase_user_id = auth.uid()
      AND pu.role = 'Admin'
    )
    OR
    -- Investigators can only enroll at their assigned sites
    (
      EXISTS (
        SELECT 1 FROM portal_users pu
        WHERE pu.supabase_user_id = auth.uid()
        AND pu.role = 'Investigator'
      )
      AND site_id IN (
        SELECT usa.site_id
        FROM user_site_access usa
        JOIN portal_users pu ON usa.user_id = pu.id
        WHERE pu.supabase_user_id = auth.uid()
      )
    )
  );

-- RLS policy for investigators to update patient status (unenroll)
CREATE POLICY "investigators_update_own_sites_patients" ON patients
  FOR UPDATE
  USING (
    -- Same logic as SELECT policy
    EXISTS (
      SELECT 1 FROM portal_users pu
      WHERE pu.supabase_user_id = auth.uid()
      AND pu.role = 'Admin'
    )
    OR
    (
      EXISTS (
        SELECT 1 FROM portal_users pu
        WHERE pu.supabase_user_id = auth.uid()
        AND pu.role = 'Investigator'
      )
      AND site_id IN (
        SELECT usa.site_id
        FROM user_site_access usa
        JOIN portal_users pu ON usa.user_id = pu.id
        WHERE pu.supabase_user_id = auth.uid()
      )
    )
  );
```

**New Columns**:
- `linking_code`: Unique 10-character code (XXXXX-XXXXX) for mobile app linking
- `enrollment_date`: Timestamp when linking code generated by investigator
- `last_login_at`: Timestamp of last mobile app login
- `last_data_entry_date`: Timestamp of last diary entry (for status calculation)
- `mobile_app_linked_at`: Timestamp when patient linked mobile app using code
- `status`: `pending_enrollment` (code generated), `enrolled` (patient used code), `unenrolled` (revoked)

**Acceptance Criteria**:
- [ ] New columns added to `patients` table
- [ ] `linking_code` has unique constraint
- [ ] Indexes created for performance
- [ ] RLS policies enable site-based isolation
- [ ] Investigators can only see/enroll patients at their assigned sites
- [ ] Migration script creates columns with proper types

*End* *Patients Table Extensions for Portal* | **Hash**: e4b8c181
---

# REQ-d00042: Questionnaires Table Schema

**Level**: Dev | **Implements**: p00009 | **Status**: Draft

The portal database SHALL include a `questionnaires` table to track questionnaire status (NOSE HHT, QoL) for each patient with send/complete/acknowledge timestamps.

**Technical Details**:

**Table: `questionnaires`**
```sql
CREATE TYPE questionnaire_type AS ENUM ('NOSE_HHT', 'QoL');
CREATE TYPE questionnaire_status AS ENUM ('not_sent', 'sent', 'completed');

CREATE TABLE questionnaires (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
  type questionnaire_type NOT NULL,
  status questionnaire_status NOT NULL DEFAULT 'not_sent',
  sent_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  last_completion_date TIMESTAMPTZ, -- For display in table
  acknowledged_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(patient_id, type)
);

-- Index for fast lookups by patient
CREATE INDEX idx_questionnaires_patient ON questionnaires(patient_id);

-- Index for status queries
CREATE INDEX idx_questionnaires_status ON questionnaires(status);

-- RLS policies (inherit from patients table)
ALTER TABLE questionnaires ENABLE ROW LEVEL SECURITY;

-- Investigators can see questionnaires for patients at their sites
CREATE POLICY "investigators_own_sites_questionnaires" ON questionnaires
  FOR SELECT
  USING (
    patient_id IN (
      SELECT id FROM patients
      -- patients table RLS policy handles site filtering
    )
  );

-- Investigators can update questionnaires for patients at their sites
CREATE POLICY "investigators_update_own_sites_questionnaires" ON questionnaires
  FOR UPDATE
  USING (
    patient_id IN (
      SELECT id FROM patients
      -- patients table RLS policy handles site filtering
    )
  );

-- Investigators can insert questionnaires for patients at their sites
CREATE POLICY "investigators_insert_own_sites_questionnaires" ON questionnaires
  FOR INSERT
  WITH CHECK (
    patient_id IN (
      SELECT id FROM patients
      -- patients table RLS policy handles site filtering
    )
  );

-- Trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_questionnaires_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER questionnaires_updated_at
  BEFORE UPDATE ON questionnaires
  FOR EACH ROW
  EXECUTE FUNCTION update_questionnaires_updated_at();
```

**Columns**:
- `id`: Primary key (UUID)
- `patient_id`: Foreign key to `patients.id`
- `type`: Enum (NOSE_HHT, QoL)
- `status`: Enum (not_sent, sent, completed)
- `sent_at`: Timestamp when questionnaire pushed to mobile app
- `completed_at`: Timestamp when patient completed questionnaire
- `last_completion_date`: Timestamp of last completion (for display)
- `acknowledged_at`: Timestamp when investigator acknowledged completion
- `created_at`: Timestamp of record creation
- `updated_at`: Timestamp of last update

**Status Flow**:
1. `not_sent` → Initial state, ready to send
2. `sent` → Investigator clicked "Send", pushed to mobile app (sent_at set)
3. `completed` → Patient finished questionnaire (completed_at set, last_completion_date set)
4. `not_sent` → Investigator clicked "Acknowledge" (acknowledged_at set, status reset for next cycle)

**Acceptance Criteria**:
- [ ] `questionnaires` table created with correct schema
- [ ] Enum types created for `type` and `status`
- [ ] Unique constraint on `(patient_id, type)` prevents duplicates
- [ ] Foreign key constraint to `patients` table
- [ ] Indexes created for performance
- [ ] RLS policies enable site-based isolation
- [ ] Trigger updates `updated_at` on every row change
- [ ] Cascade delete removes questionnaires when patient deleted

*End* *Questionnaires Table Schema* | **Hash**: 166c9e74
---

## Deployment Requirements

# REQ-d00043: Netlify Deployment Configuration

**Level**: Dev | **Implements**: o00009 | **Status**: Draft

The portal SHALL be deployed to Netlify with sponsor-specific subdomains, automatic builds from Git, and environment variable configuration.

**Technical Details**:
- **Platform**: Netlify (static site hosting)
- **Build Command**: `flutter build web --release --web-renderer html`
- **Publish Directory**: `build/web/`
- **Deployment**: Automatic on `main` branch push

**Netlify Configuration File** (`netlify.toml`):
```toml
[build]
  command = "flutter build web --release --web-renderer html"
  publish = "build/web"

[[redirects]]
  from = "/*"
  to = "/index.html"
  status = 200

[[headers]]
  for = "/*"
  [headers.values]
    X-Frame-Options = "DENY"
    X-Content-Type-Options = "nosniff"
    Referrer-Policy = "strict-origin-when-cross-origin"
    Permissions-Policy = "geolocation=(), microphone=(), camera=()"
    Content-Security-Policy = "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self' https://*.supabase.co https://*.google.com https://*.microsoft.com; frame-ancestors 'none';"
```

**Environment Variables** (Netlify Dashboard):
```
SUPABASE_URL=https://<sponsor-project>.supabase.co
SUPABASE_ANON_KEY=<anon-key-from-supabase>
```

**Build Settings**:
- **Flutter Version**: Specify in `.flutter-version` file
- **Build Image**: Ubuntu 20.04 (default Netlify image)
- **Node Version**: Not required (Flutter uses Dart SDK)

**Sponsor-Specific Deployment**:
- Each sponsor gets a separate Netlify site
- Custom domain: `https://<sponsor-name>.clinicaltrial.com` (or sponsor-provided domain)
- Each site points to same Git repo but different Supabase project
- Environment variables differ per sponsor

**Acceptance Criteria**:
- [ ] `netlify.toml` configuration file created
- [ ] Build command configured correctly
- [ ] Publish directory set to `build/web/`
- [ ] SPA redirects configured (`/* → /index.html`)
- [ ] Security headers configured
- [ ] CSP headers restrict resource loading
- [ ] Environment variables set in Netlify dashboard
- [ ] Automatic deployments trigger on `main` branch push
- [ ] Custom domain configured for sponsor

*End* *Netlify Deployment Configuration* | **Hash**: d7c11f03
---

## Summary

This development specification defines the technical implementation requirements for the Clinical Trial Web Portal, a **Flutter web application** (separate from patient diary mobile app) with role-based dashboards (Admin, Investigator), site-level data isolation, and patient enrollment/questionnaire management.

**Key Technologies**:
- Flutter 3.24+ for web
- Dart 3.5+
- Supabase Auth (OAuth + email/password)
- Supabase Database with RLS policies
- Netlify deployment

**Simplified Scope**:
- **Two roles only**: Admin, Investigator (no Auditor/Analyst)
- **Essential features**: Login, user management, patient enrollment, questionnaire management, token revocation, monthly reports
- **No diary viewing**: Patient diaries viewed in 3rd party EDC
- **No event viewer**: Event sourcing at database level only
- **Separate app**: Independent from patient diary mobile app (may merge later for code reuse)

**Implementation Priority**:
1. **P1 (Critical)**: Auth, routing, Admin/Investigator dashboards, database schema, linking codes, token revocation
2. **P2 (High)**: Monthly report generation, testing
3. **P3 (Future)**: Merge with patient diary app for code reuse (if "Investigator Mode" on mobile is needed)

**Next Steps**:
1. Review this specification with stakeholders
2. Create Linear tickets for each REQ-d00xxx requirement
3. Set up Flutter development environment
4. Implement authentication and routing (REQ-d00030, d00031)
5. Build Admin dashboard (REQ-d00035, d00036)
6. Build Investigator dashboard (REQ-d00037, d00038)
7. Deploy to Netlify (REQ-d00043)

---

**Document Control**:
- **Created**: 2025-10-27
- **Author**: Claude Code
- **Status**: Draft (awaiting review)
- **Next Review**: After stakeholder feedback
