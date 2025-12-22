// // ============================================================================
// // UI Integration Example
// // ============================================================================
// //
// // Example Flutter widgets showing how to integrate the deletion logic.
// // This is reference code - adapt to your app's design system.
// //
// // ============================================================================
//
// import 'package:flutter/material.dart';
// import 'diary_repository.dart';
// import 'event_deletion_handler.dart';
// import 'deletion_models.dart';
// import 'models.dart';
//
// /// Example: Diary event card with delete functionality
// class DiaryEventCard extends StatelessWidget {
//   final EventRecord event;
//   final DiaryRepository repository;
//   final VoidCallback onDeleted;
//
//   const DiaryEventCard({
//     Key? key,
//     required this.event,
//     required this.repository,
//     required this.onDeleted,
//   }) : super(key: key);
//
//   @override
//   Widget build(BuildContext context) {
//     final epistaxis = event.eventData as EpistaxisRecord;
//
//     return Card(
//       margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//       child: ListTile(
//         leading: _buildIntensityIcon(epistaxis.intensity),
//         title: Text(_formatTime(epistaxis.startTime)),
//         subtitle: epistaxis.userNotes != null
//             ? Text(epistaxis.userNotes!)
//             : null,
//         trailing: IconButton(
//           icon: Icon(Icons.delete_outline),
//           onPressed: () => _handleDelete(context),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildIntensityIcon(EpistaxisIntensity? intensity) {
//     if (intensity == null) return Icon(Icons.info_outline);
//
//     Color color;
//     IconData icon;
//
//     switch (intensity) {
//       case EpistaxisIntensity.spotting:
//       case EpistaxisIntensity.drippingSlowly:
//         color = Colors.green;
//         icon = Icons.water_drop;
//         break;
//       case EpistaxisIntensity.drippingQuickly:
//         color = Colors.orange;
//         icon = Icons.water_drop;
//         break;
//       case EpistaxisIntensity.steadyStream:
//       case EpistaxisIntensity.pouring:
//       case EpistaxisIntensity.gushing:
//         color = Colors.red;
//         icon = Icons.warning;
//         break;
//     }
//
//     return Icon(icon, color: color);
//   }
//
//   String _formatTime(DateTime time) {
//     final hour = time.hour > 12 ? time.hour - 12 : time.hour;
//     final period = time.hour >= 12 ? 'PM' : 'AM';
//     final minute = time.minute.toString().padLeft(2, '0');
//     return '$hour:$minute $period';
//   }
//
//   Future<void> _handleDelete(BuildContext context) async {
//     final deletionHandler = EventDeletionHandler(repository);
//     final epistaxis = event.eventData as EpistaxisRecord;
//
//     try {
//       final result = await deletionHandler.deleteEvent(
//         eventUuid: event.id,
//         eventDate: epistaxis.startTime,
//         promptUser: (prompt) => _showDeletionPrompt(context, prompt),
//       );
//
//       if (!context.mounted) return;
//
//       // Show feedback based on result
//       String message;
//       if (result.wasConverted) {
//         message = 'Recorded as day with no nosebleeds';
//       } else {
//         message = 'Event deleted';
//       }
//
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(message),
//           duration: Duration(seconds: 2),
//         ),
//       );
//
//       onDeleted();
//     } catch (error) {
//       if (!context.mounted) return;
//
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Error deleting event: $error'),
//           backgroundColor: Colors.red,
//         ),
//       );
//     }
//   }
//
//   Future<DeletionChoice> _showDeletionPrompt(
//     BuildContext context,
//     DeletionPrompt prompt,
//   ) async {
//     return await showDialog<DeletionChoice>(
//           context: context,
//           builder: (context) => DeletionPromptDialog(prompt: prompt),
//         ) ??
//         DeletionChoice.justDelete;
//   }
// }
//
// /// Dialog prompting user for deletion intent
// class DeletionPromptDialog extends StatelessWidget {
//   final DeletionPrompt prompt;
//
//   const DeletionPromptDialog({
//     Key? key,
//     required this.prompt,
//   }) : super(key: key);
//
//   @override
//   Widget build(BuildContext context) {
//     return AlertDialog(
//       title: Text('Delete Event'),
//       content: Column(
//         mainAxisSize: MainAxisSize.min,
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(prompt.message),
//           SizedBox(height: 24),
//           _buildChoiceButton(
//             context,
//             label: 'Confirm no nosebleeds occurred',
//             subtitle: 'Recommended for compliance',
//             choice: DeletionChoice.confirmNoNosebleeds,
//             isRecommended: true,
//           ),
//           SizedBox(height: 12),
//           _buildChoiceButton(
//             context,
//             label: 'Just remove this entry',
//             subtitle: 'For erroneous entries',
//             choice: DeletionChoice.justDelete,
//             isRecommended: false,
//           ),
//         ],
//       ),
//       actions: [
//         TextButton(
//           onPressed: () => Navigator.pop(context, DeletionChoice.justDelete),
//           child: Text('Cancel'),
//         ),
//       ],
//     );
//   }
//
//   Widget _buildChoiceButton(
//     BuildContext context, {
//     required String label,
//     required String subtitle,
//     required DeletionChoice choice,
//     required bool isRecommended,
//   }) {
//     return InkWell(
//       onTap: () => Navigator.pop(context, choice),
//       borderRadius: BorderRadius.circular(8),
//       child: Container(
//         padding: EdgeInsets.all(16),
//         decoration: BoxDecoration(
//           border: Border.all(
//             color: isRecommended ? Theme.of(context).primaryColor : Colors.grey,
//             width: isRecommended ? 2 : 1,
//           ),
//           borderRadius: BorderRadius.circular(8),
//         ),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Row(
//               children: [
//                 Expanded(
//                   child: Text(
//                     label,
//                     style: TextStyle(
//                       fontWeight:
//                           isRecommended ? FontWeight.bold : FontWeight.normal,
//                     ),
//                   ),
//                 ),
//                 if (isRecommended)
//                   Chip(
//                     label: Text('Recommended'),
//                     backgroundColor: Theme.of(context).primaryColor,
//                     labelStyle: TextStyle(color: Colors.white, fontSize: 10),
//                   ),
//               ],
//             ),
//             SizedBox(height: 4),
//             Text(
//               subtitle,
//               style: TextStyle(fontSize: 12, color: Colors.grey[600]),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
//
// /// Example: Diary calendar view showing days with events
// class DiaryCalendarView extends StatefulWidget {
//   final DiaryRepository repository;
//
//   const DiaryCalendarView({
//     Key? key,
//     required this.repository,
//   }) : super(key: key);
//
//   @override
//   State<DiaryCalendarView> createState() => _DiaryCalendarViewState();
// }
//
// class _DiaryCalendarViewState extends State<DiaryCalendarView> {
//   DateTime selectedDate = DateTime.now();
//   List<EventRecord> eventsOnDate = [];
//   bool isLoading = false;
//
//   @override
//   void initState() {
//     super.initState();
//     _loadEventsForDate(selectedDate);
//   }
//
//   Future<void> _loadEventsForDate(DateTime date) async {
//     setState(() => isLoading = true);
//
//     try {
//       final events = await widget.repository.getEventsForDate(date);
//       setState(() {
//         eventsOnDate = events;
//         isLoading = false;
//       });
//     } catch (error) {
//       setState(() => isLoading = false);
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Error loading events: $error')),
//         );
//       }
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Diary'),
//       ),
//       body: Column(
//         children: [
//           // Calendar would go here
//           Padding(
//             padding: EdgeInsets.all(16),
//             child: Text(
//               _formatDate(selectedDate),
//               style: Theme.of(context).textTheme.headlineSmall,
//             ),
//           ),
//           Expanded(
//             child: isLoading
//                 ? Center(child: CircularProgressIndicator())
//                 : eventsOnDate.isEmpty
//                     ? Center(
//                         child: Text('No events on this day'),
//                       )
//                     : ListView.builder(
//                         itemCount: eventsOnDate.length,
//                         itemBuilder: (context, index) {
//                           return DiaryEventCard(
//                             event: eventsOnDate[index],
//                             repository: widget.repository,
//                             onDeleted: () => _loadEventsForDate(selectedDate),
//                           );
//                         },
//                       ),
//           ),
//         ],
//       ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: () {
//           // Navigate to add event screen
//         },
//         child: Icon(Icons.add),
//       ),
//     );
//   }
//
//   String _formatDate(DateTime date) {
//     final months = [
//       'January',
//       'February',
//       'March',
//       'April',
//       'May',
//       'June',
//       'July',
//       'August',
//       'September',
//       'October',
//       'November',
//       'December'
//     ];
//     return '${months[date.month - 1]} ${date.day}, ${date.year}';
//   }
// }
