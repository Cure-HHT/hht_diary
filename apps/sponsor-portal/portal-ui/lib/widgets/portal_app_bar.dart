// // IMPLEMENTS REQUIREMENTS:
// //   REQ-d00029: Portal UI Design System
//
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
//
// import '../services/auth_service.dart';
//
// class PortalAppBar extends StatelessWidget implements PreferredSizeWidget {
//   final String title;
//
//   const PortalAppBar({
//     super.key,
//     required this.title,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     final authService = context.watch<AuthService>();
//     final user = authService.currentUser;
//
//     return AppBar(
//       title: Text(title),
//       actions: [
//         if (user != null) ...[
//           Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 16),
//             child: Center(
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 crossAxisAlignment: CrossAxisAlignment.end,
//                 children: [
//                   Text(
//                     user.name ?? user.email,
//                     style: Theme.of(context).textTheme.bodySmall,
//                   ),
//                   Text(
//                     user.role.name.toUpperCase(),
//                     style: Theme.of(context).textTheme.bodySmall?.copyWith(
//                           color: Colors.grey,
//                         ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//           IconButton(
//             icon: const Icon(Icons.logout),
//             onPressed: () => authService.signOut(),
//             tooltip: 'Sign Out',
//           ),
//         ],
//       ],
//     );
//   }
//
//   @override
//   Size get preferredSize => const Size.fromHeight(kToolbarHeight);
// }
