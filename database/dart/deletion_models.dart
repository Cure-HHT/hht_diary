// // ============================================================================
// // Deletion Logic - Supporting Types
// // ============================================================================
// //
// // Handles the logic for deleting diary events with appropriate user prompting
// // when deleting the last event on a given day.
// //
// // ============================================================================
//
// import 'models.dart';
//
// /// Prompt shown to user when deleting last event on a day
// class DeletionPrompt {
//   final DateTime date;
//   final bool isLastEventOnDay;
//
//   DeletionPrompt({
//     required this.date,
//     required this.isLastEventOnDay,
//   });
//
//   /// Message to display to user
//   String get message =>
//       'This was the only event on ${_formatDate(date)}. Would you like to:';
//
//   String _formatDate(DateTime date) {
//     return '${_monthName(date.month)} ${date.day}';
//   }
//
//   String _monthName(int month) {
//     const months = [
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
//     return months[month - 1];
//   }
// }
//
// /// User's choice when prompted about deletion
// enum DeletionChoice {
//   /// Convert to "no nosebleeds" event (recommended for compliance)
//   confirmNoNosebleeds,
//
//   /// Just delete the entry
//   justDelete,
// }
//
// /// Result of deletion operation
// class DeletionResult {
//   final DeletionResultType type;
//   final EpistaxisRecord? convertedEvent;
//
//   DeletionResult.convertedToNoNosebleeds(EpistaxisRecord event)
//       : type = DeletionResultType.converted,
//         convertedEvent = event;
//
//   DeletionResult.deleted()
//       : type = DeletionResultType.deleted,
//         convertedEvent = null;
//
//   bool get wasConverted => type == DeletionResultType.converted;
//   bool get wasDeleted => type == DeletionResultType.deleted;
// }
//
// /// Type of deletion result
// enum DeletionResultType {
//   /// Converted to "no nosebleeds" event
//   converted,
//
//   /// Soft deleted
//   deleted,
// }
