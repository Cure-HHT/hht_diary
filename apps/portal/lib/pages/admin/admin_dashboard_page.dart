// // IMPLEMENTS REQUIREMENTS:
// //   REQ-p00024: Portal User Roles and Permissions
// //   REQ-p00025: Patient Enrollment Workflow
// //   REQ-p00030: Role-Based Visual Indicators
// //   REQ-d00052: Role-Based Banner Component
//
// import 'package:flutter/material.dart';
// import 'package:go_router/go_router.dart';
// import 'package:provider/provider.dart';
//
// import '../../services/auth_service.dart';
// import '../../widgets/portal_app_bar.dart';
// import '../../widgets/portal_drawer.dart';
// import '../../widgets/role_banner.dart';
// import 'user_management_tab.dart';
// import 'patients_overview_tab.dart';
//
// class AdminDashboardPage extends StatefulWidget {
//   const AdminDashboardPage({super.key});
//
//   @override
//   State<AdminDashboardPage> createState() => _AdminDashboardPageState();
// }
//
// class _AdminDashboardPageState extends State<AdminDashboardPage> {
//   int _selectedIndex = 0;
//
//   @override
//   Widget build(BuildContext context) {
//     final authService = context.watch<AuthService>();
//
//     // Check authentication and role
//     if (!authService.isAuthenticated || !authService.hasRole(UserRole.admin)) {
//       WidgetsBinding.instance.addPostFrameCallback((_) {
//         context.go('/login');
//       });
//       return const Scaffold(body: Center(child: CircularProgressIndicator()));
//     }
//
//     final tabs = [
//       const UserManagementTab(),
//       const PatientsOverviewTab(),
//     ];
//
//     return Scaffold(
//       appBar: const PortalAppBar(title: 'Admin Dashboard'),
//       drawer: const PortalDrawer(),
//       body: Column(
//         children: [
//           RoleBanner(role: authService.currentUser!.role),
//           Expanded(
//             child: Row(
//               children: [
//                 NavigationRail(
//                   selectedIndex: _selectedIndex,
//                   onDestinationSelected: (index) {
//                     setState(() => _selectedIndex = index);
//                   },
//                   labelType: NavigationRailLabelType.all,
//                   destinations: const [
//                     NavigationRailDestination(
//                       icon: Icon(Icons.people_outline),
//                       selectedIcon: Icon(Icons.people),
//                       label: Text('Users'),
//                     ),
//                     NavigationRailDestination(
//                       icon: Icon(Icons.person_outline),
//                       selectedIcon: Icon(Icons.person),
//                       label: Text('Patients'),
//                     ),
//                   ],
//                 ),
//                 const VerticalDivider(thickness: 1, width: 1),
//                 Expanded(
//                   child: tabs[_selectedIndex],
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
