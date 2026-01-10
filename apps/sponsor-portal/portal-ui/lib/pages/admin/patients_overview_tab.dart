// // IMPLEMENTS REQUIREMENTS:
// //   REQ-p00026: Patient Monitoring Dashboard
//
// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
//
// import '../../config/database_config.dart';
// import '../../services/database_service.dart';
// import '../../theme/portal_theme.dart';
//
// class PatientsOverviewTab extends StatefulWidget {
//   const PatientsOverviewTab({super.key});
//
//   @override
//   State<PatientsOverviewTab> createState() => _PatientsOverviewTabState();
// }
//
// class _PatientsOverviewTabState extends State<PatientsOverviewTab> {
//   List<Map<String, dynamic>> _patients = [];
//   bool _isLoading = true;
//
//   @override
//   void initState() {
//     super.initState();
//     _loadPatients();
//   }
//
//   Future<void> _loadPatients() async {
//     setState(() => _isLoading = true);
//     try {
//       final db = DatabaseConfig.getDatabaseService();
//       final patients = await db.getPatients();
//
//       setState(() {
//         _patients = patients;
//         _isLoading = false;
//       });
//     } catch (e) {
//       debugPrint('Error loading patients: $e');
//       setState(() => _isLoading = false);
//     }
//   }
//
//   Color _getStatusColor(Map<String, dynamic> patient) {
//     final lastEntry = patient['last_diary_entry'] as String?;
//     if (lastEntry == null) return StatusColors.noData;
//
//     final lastEntryDate = DateTime.parse(lastEntry);
//     final daysSince = DateTime.now().difference(lastEntryDate).inDays;
//
//     if (daysSince <= 3) return StatusColors.active;
//     if (daysSince <= 7) return StatusColors.attention;
//     return StatusColors.atRisk;
//   }
//
//   String _getStatusText(Map<String, dynamic> patient) {
//     final lastEntry = patient['last_diary_entry'] as String?;
//     if (lastEntry == null) return 'No Data';
//
//     final lastEntryDate = DateTime.parse(lastEntry);
//     final daysSince = DateTime.now().difference(lastEntryDate).inDays;
//
//     if (daysSince <= 3) return 'Active';
//     if (daysSince <= 7) return 'Attention';
//     return 'At Risk';
//   }
//
//   int _getDaysWithoutData(Map<String, dynamic> patient) {
//     final lastEntry = patient['last_diary_entry'] as String?;
//     if (lastEntry == null) return -1;
//
//     final lastEntryDate = DateTime.parse(lastEntry);
//     return DateTime.now().difference(lastEntryDate).inDays;
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     if (_isLoading) {
//       return const Center(child: CircularProgressIndicator());
//     }
//
//     final activeToday =
//         _patients.where((p) => _getStatusText(p) == 'Active').length;
//     final requiresFollowup = _patients
//         .where((p) => ['Attention', 'At Risk'].contains(_getStatusText(p)))
//         .length;
//
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.stretch,
//       children: [
//         Padding(
//           padding: const EdgeInsets.all(16),
//           child: Text(
//             'All Patients',
//             style: Theme.of(context).textTheme.displaySmall,
//           ),
//         ),
//         // Summary cards
//         Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 16),
//           child: Row(
//             children: [
//               Expanded(
//                 child: Card(
//                   child: Padding(
//                     padding: const EdgeInsets.all(16),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         const Text('Total Patients'),
//                         Text(
//                           '${_patients.length}',
//                           style: Theme.of(context).textTheme.displayMedium,
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//               ),
//               Expanded(
//                 child: Card(
//                   child: Padding(
//                     padding: const EdgeInsets.all(16),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         const Text('Active Today'),
//                         Text(
//                           '$activeToday',
//                           style: Theme.of(context).textTheme.displayMedium,
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//               ),
//               Expanded(
//                 child: Card(
//                   child: Padding(
//                     padding: const EdgeInsets.all(16),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         const Text('Requires Follow-up'),
//                         Text(
//                           '$requiresFollowup',
//                           style: Theme.of(context)
//                               .textTheme
//                               .displayMedium
//                               ?.copyWith(
//                                 color: requiresFollowup > 0
//                                     ? StatusColors.attention
//                                     : null,
//                               ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//         const SizedBox(height: 16),
//         Expanded(
//           child: SingleChildScrollView(
//             padding: const EdgeInsets.all(16),
//             child: Card(
//               child: DataTable(
//                 columns: const [
//                   DataColumn(label: Text('Patient ID')),
//                   DataColumn(label: Text('Site')),
//                   DataColumn(label: Text('Status')),
//                   DataColumn(label: Text('Days Without Data')),
//                   DataColumn(label: Text('Last Login')),
//                   DataColumn(label: Text('Enrolled')),
//                 ],
//                 rows: _patients.map((patient) {
//                   final siteName = patient['sites']?['site_name'] ?? 'Unknown';
//                   final daysWithout = _getDaysWithoutData(patient);
//                   final lastLogin = patient['last_login'] as String?;
//                   final enrolled = patient['created_at'] as String;
//
//                   return DataRow(
//                     cells: [
//                       DataCell(Text(patient['patient_id'] ?? '')),
//                       DataCell(Text(siteName)),
//                       DataCell(
//                         Chip(
//                           label: Text(_getStatusText(patient)),
//                           backgroundColor: _getStatusColor(patient),
//                         ),
//                       ),
//                       DataCell(Text(
//                         daysWithout >= 0 ? '$daysWithout' : 'Never',
//                       )),
//                       DataCell(Text(
//                         lastLogin != null
//                             ? DateFormat.yMd().add_jm().format(
//                                   DateTime.parse(lastLogin),
//                                 )
//                             : 'Never',
//                       )),
//                       DataCell(Text(
//                         DateFormat.yMd().format(DateTime.parse(enrolled)),
//                       )),
//                     ],
//                   );
//                 }).toList(),
//               ),
//             ),
//           ),
//         ),
//       ],
//     );
//   }
// }
