// // IMPLEMENTS REQUIREMENTS:
// //   REQ-p00024: Portal User Roles and Permissions
// //   REQ-p00014: Authentication and Authorization
//
// import 'package:flutter/material.dart';
// import 'package:go_router/go_router.dart';
// import 'package:provider/provider.dart';
//
// import '../services/auth_service.dart';
//
// class LoginPage extends StatefulWidget {
//   const LoginPage({super.key});
//
//   @override
//   State<LoginPage> createState() => _LoginPageState();
// }
//
// class _LoginPageState extends State<LoginPage> {
//   final _formKey = GlobalKey<FormState>();
//   final _emailController = TextEditingController();
//   final _passwordController = TextEditingController();
//   String? _errorMessage;
//
//   @override
//   void dispose() {
//     _emailController.dispose();
//     _passwordController.dispose();
//     super.dispose();
//   }
//
//   Future<void> _handleLogin() async {
//     if (!_formKey.currentState!.validate()) return;
//
//     setState(() => _errorMessage = null);
//
//     final authService = context.read<AuthService>();
//     final success = await authService.signIn(
//       _emailController.text.trim(),
//       _passwordController.text,
//     );
//
//     if (!mounted) return;
//
//     if (success && authService.currentUser != null) {
//       // Navigate based on role
//       final role = authService.currentUser!.role;
//       switch (role) {
//         case UserRole.admin:
//           context.go('/admin');
//           break;
//         case UserRole.investigator:
//           context.go('/investigator');
//           break;
//         case UserRole.auditor:
//           context.go('/auditor');
//           break;
//       }
//     } else {
//       setState(() => _errorMessage = 'Invalid email or password');
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final authService = context.watch<AuthService>();
//
//     return Scaffold(
//       body: Center(
//         child: Container(
//           constraints: const BoxConstraints(maxWidth: 400),
//           padding: const EdgeInsets.all(24),
//           child: Card(
//             child: Padding(
//               padding: const EdgeInsets.all(32),
//               child: Form(
//                 key: _formKey,
//                 child: Column(
//                   mainAxisSize: MainAxisSize.min,
//                   crossAxisAlignment: CrossAxisAlignment.stretch,
//                   children: [
//                     // Logo placeholder
//                     const Icon(
//                       Icons.medication,
//                       size: 64,
//                       color: Color(0xFF0175C2),
//                     ),
//                     const SizedBox(height: 16),
//                     Text(
//                       'Carina Clinical Trial Portal',
//                       style: Theme.of(context).textTheme.displaySmall,
//                       textAlign: TextAlign.center,
//                     ),
//                     const SizedBox(height: 32),
//                     TextFormField(
//                       controller: _emailController,
//                       decoration: const InputDecoration(
//                         labelText: 'Email',
//                         prefixIcon: Icon(Icons.email),
//                       ),
//                       keyboardType: TextInputType.emailAddress,
//                       validator: (value) {
//                         if (value == null || value.isEmpty) {
//                           return 'Please enter your email';
//                         }
//                         if (!value.contains('@')) {
//                           return 'Please enter a valid email';
//                         }
//                         return null;
//                       },
//                     ),
//                     const SizedBox(height: 16),
//                     TextFormField(
//                       controller: _passwordController,
//                       decoration: const InputDecoration(
//                         labelText: 'Password',
//                         prefixIcon: Icon(Icons.lock),
//                       ),
//                       obscureText: true,
//                       validator: (value) {
//                         if (value == null || value.isEmpty) {
//                           return 'Please enter your password';
//                         }
//                         return null;
//                       },
//                     ),
//                     if (_errorMessage != null) ...[
//                       const SizedBox(height: 16),
//                       Text(
//                         _errorMessage!,
//                         style: TextStyle(
//                           color: Theme.of(context).colorScheme.error,
//                         ),
//                         textAlign: TextAlign.center,
//                       ),
//                     ],
//                     const SizedBox(height: 24),
//                     ElevatedButton(
//                       onPressed: authService.isLoading ? null : _handleLogin,
//                       child: authService.isLoading
//                           ? const SizedBox(
//                               height: 20,
//                               width: 20,
//                               child: CircularProgressIndicator(strokeWidth: 2),
//                             )
//                           : const Text('Sign In'),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
