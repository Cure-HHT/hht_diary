// // IMPLEMENTS REQUIREMENTS:
// //   REQ-p00025: Participant Enrollment Workflow
//
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:provider/provider.dart';
//
// import '../../config/database_config.dart';
// import '../../services/auth_service.dart';
// import '../../services/database_service.dart';
//
// class ParticipantEnrollmentTab extends StatefulWidget {
//   const ParticipantEnrollmentTab({super.key});
//
//   @override
//   State<ParticipantEnrollmentTab> createState() => _ParticipantEnrollmentTabState();
// }
//
// class _ParticipantEnrollmentTabState extends State<ParticipantEnrollmentTab> {
//   final _formKey = GlobalKey<FormState>();
//   final _participantIdController = TextEditingController();
//   String? _selectedSiteId;
//   List<Map<String, dynamic>> _sites = [];
//   bool _isLoading = true;
//   String? _generatedCode;
//
//   @override
//   void initState() {
//     super.initState();
//     _loadSites();
//   }
//
//   @override
//   void dispose() {
//     _participantIdController.dispose();
//     super.dispose();
//   }
//
//   Future<void> _loadSites() async {
//     setState(() => _isLoading = true);
//     try {
//       final authService = context.read<AuthService>();
//       final assignedSites = authService.currentUser?.assignedSites ?? [];
//       final db = DatabaseConfig.getDatabaseService();
//
//       // Get sites (filtered by assigned sites if not admin)
//       final sites = await db.getSites(
//         siteIds: assignedSites.isNotEmpty ? assignedSites : null,
//       );
//
//       setState(() {
//         _sites = sites;
//         _isLoading = false;
//       });
//     } catch (e) {
//       debugPrint('Error loading sites: $e');
//       setState(() => _isLoading = false);
//     }
//   }
//
//   Future<void> _enrollParticipant() async {
//     if (!_formKey.currentState!.validate()) return;
//     if (_selectedSiteId == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Please select a site')),
//       );
//       return;
//     }
//
//     try {
//       final participantId = _participantIdController.text.trim();
//       final db = DatabaseConfig.getDatabaseService();
//
//       final result = await db.enrollParticipant(
//         participantId: participantId,
//         siteId: _selectedSiteId!,
//       );
//
//       setState(() {
//         _generatedCode = result['linking_code'] as String;
//         _participantIdController.clear();
//         _selectedSiteId = null;
//       });
//
//       if (mounted) {
//         showDialog(
//           context: context,
//           builder: (context) => AlertDialog(
//             title: const Text('Participant Enrolled'),
//             content: Column(
//               mainAxisSize: MainAxisSize.min,
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text('Participant $participantId enrolled successfully!'),
//                 const SizedBox(height: 16),
//                 const Text(
//                   'Linking Code:',
//                   style: TextStyle(fontWeight: FontWeight.bold),
//                 ),
//                 const SizedBox(height: 8),
//                 SelectableText(
//                   _generatedCode!,
//                   style: Theme.of(context).textTheme.displayMedium,
//                 ),
//                 const SizedBox(height: 16),
//                 const Text(
//                   'Share this code with the participant to link their mobile app.',
//                   style: TextStyle(fontStyle: FontStyle.italic),
//                 ),
//               ],
//             ),
//             actions: [
//               TextButton(
//                 onPressed: () async {
//                   await Clipboard.setData(ClipboardData(text: _generatedCode!));
//                   if (context.mounted) {
//                     ScaffoldMessenger.of(context).showSnackBar(
//                       const SnackBar(content: Text('Code copied to clipboard')),
//                     );
//                   }
//                 },
//                 child: const Text('Copy Code'),
//               ),
//               FilledButton(
//                 onPressed: () => Navigator.pop(context),
//                 child: const Text('Done'),
//               ),
//             ],
//           ),
//         );
//       }
//     } catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Error enrolling participant: $e')),
//         );
//       }
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     if (_isLoading) {
//       return const Center(child: CircularProgressIndicator());
//     }
//
//     return SingleChildScrollView(
//       padding: const EdgeInsets.all(24),
//       child: Center(
//         child: Container(
//           constraints: const BoxConstraints(maxWidth: 600),
//           child: Card(
//             child: Padding(
//               padding: const EdgeInsets.all(32),
//               child: Form(
//                 key: _formKey,
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.stretch,
//                   children: [
//                     Text(
//                       'Enroll New Participant',
//                       style: Theme.of(context).textTheme.displaySmall,
//                     ),
//                     const SizedBox(height: 8),
//                     const Text(
//                       'Enter the participant ID from the IRT system and select their clinical site.',
//                       style: TextStyle(color: Colors.grey),
//                     ),
//                     const SizedBox(height: 32),
//                     TextFormField(
//                       controller: _participantIdController,
//                       decoration: const InputDecoration(
//                         labelText: 'Participant ID (from IRT)',
//                         hintText: 'SSS-PPPPPPP',
//                         helperText: 'Format: SSS-PPPPPPP',
//                         prefixIcon: Icon(Icons.badge),
//                       ),
//                       validator: (value) {
//                         if (value == null || value.isEmpty) {
//                           return 'Please enter participant ID';
//                         }
//                         // Basic format validation (can be customized)
//                         if (!RegExp(r'^\d{3}-\d{7}$').hasMatch(value)) {
//                           return 'Invalid format. Use: SSS-PPPPPPP';
//                         }
//                         return null;
//                       },
//                     ),
//                     const SizedBox(height: 24),
//                     DropdownButtonFormField<String>(
//                       value: _selectedSiteId,
//                       decoration: const InputDecoration(
//                         labelText: 'Clinical Site',
//                         prefixIcon: Icon(Icons.location_on),
//                       ),
//                       items: _sites.map((site) {
//                         return DropdownMenuItem(
//                           value: site['site_id'] as String,
//                           child: Text(
//                             '${site['site_name']} (${site['site_number']})',
//                           ),
//                         );
//                       }).toList(),
//                       onChanged: (value) {
//                         setState(() => _selectedSiteId = value);
//                       },
//                       validator: (value) {
//                         if (value == null) {
//                           return 'Please select a site';
//                         }
//                         return null;
//                       },
//                     ),
//                     const SizedBox(height: 32),
//                     FilledButton.icon(
//                       onPressed: _enrollParticipant,
//                       icon: const Icon(Icons.person_add),
//                       label: const Text('Enroll Participant'),
//                       style: FilledButton.styleFrom(
//                         padding: const EdgeInsets.all(16),
//                       ),
//                     ),
//                     const SizedBox(height: 16),
//                     const Divider(),
//                     const SizedBox(height: 16),
//                     Row(
//                       children: [
//                         const Icon(Icons.info_outline, size: 20),
//                         const SizedBox(width: 8),
//                         Expanded(
//                           child: Text(
//                             'The system will generate a unique linking code. '
//                             'Share this code with the participant to link their mobile app.',
//                             style: Theme.of(context).textTheme.bodySmall,
//                           ),
//                         ),
//                       ],
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
