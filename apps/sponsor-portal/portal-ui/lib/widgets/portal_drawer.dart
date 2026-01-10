// // IMPLEMENTS REQUIREMENTS:
// //   REQ-d00029: Portal UI Design System
//
// import 'package:flutter/material.dart';
// import 'package:go_router/go_router.dart';
// import 'package:provider/provider.dart';
//
// import '../services/auth_service.dart';
//
// class PortalDrawer extends StatelessWidget {
//   const PortalDrawer({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     final authService = context.watch<AuthService>();
//     final user = authService.currentUser;
//
//     if (user == null) return const Drawer();
//
//     return Drawer(
//       child: ListView(
//         padding: EdgeInsets.zero,
//         children: [
//           DrawerHeader(
//             decoration: BoxDecoration(
//               color: Theme.of(context).colorScheme.primary,
//             ),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               mainAxisAlignment: MainAxisAlignment.end,
//               children: [
//                 const Text(
//                   'Carina Portal',
//                   style: TextStyle(
//                     color: Colors.white,
//                     fontSize: 24,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//                 const SizedBox(height: 8),
//                 Text(
//                   user.name ?? user.email,
//                   style: const TextStyle(color: Colors.white),
//                 ),
//                 Text(
//                   user.role.name.toUpperCase(),
//                   style: const TextStyle(color: Colors.white70, fontSize: 12),
//                 ),
//               ],
//             ),
//           ),
//           if (user.role == UserRole.admin) ...[
//             ListTile(
//               leading: const Icon(Icons.dashboard),
//               title: const Text('Admin Dashboard'),
//               onTap: () => context.go('/admin'),
//             ),
//           ],
//           if (user.role == UserRole.investigator) ...[
//             ListTile(
//               leading: const Icon(Icons.dashboard),
//               title: const Text('Investigator Dashboard'),
//               onTap: () => context.go('/investigator'),
//             ),
//           ],
//           if (user.role == UserRole.auditor) ...[
//             ListTile(
//               leading: const Icon(Icons.dashboard),
//               title: const Text('Auditor Dashboard'),
//               onTap: () => context.go('/auditor'),
//             ),
//           ],
//           const Divider(),
//           ListTile(
//             leading: const Icon(Icons.logout),
//             title: const Text('Sign Out'),
//             onTap: () => authService.signOut(),
//           ),
//         ],
//       ),
//     );
//   }
// }
