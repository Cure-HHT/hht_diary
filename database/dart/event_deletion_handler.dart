// // ============================================================================
// // Event Deletion Handler
// // ============================================================================
// //
// // Handles deletion logic for diary events with appropriate user prompting
// // when deleting the last event on a given day.
// //
// // Business Logic:
// // - If deleting the last event on a day, prompt user
// // - User can confirm "no nosebleeds" (recommended for compliance)
// // - Or user can just delete (e.g., erroneous entry)
// //
// // ============================================================================
//
// import 'diary_repository.dart';
// import 'deletion_models.dart';
// import 'models.dart';
//
// /// Handles deletion logic for diary events
// ///
// /// Prompts user when deleting the last event on a day to determine intent:
// /// - Convert to "no nosebleeds" event (shows protocol adherence)
// /// - Just delete (removes erroneous entry)
// class EventDeletionHandler {
//   final DiaryRepository repository;
//
//   EventDeletionHandler(this.repository);
//
//   /// Delete an event with appropriate user prompting
//   ///
//   /// [eventUuid] - UUID of event to delete
//   /// [eventDate] - Date of the event (for checking if last on day)
//   /// [promptUser] - Callback to prompt user for intent
//   ///
//   /// Returns [DeletionResult] indicating what happened.
//   Future<DeletionResult> deleteEvent({
//     required String eventUuid,
//     required DateTime eventDate,
//     required Future<DeletionChoice> Function(DeletionPrompt) promptUser,
//   }) async {
//     // Check if this is the last event on this day
//     final eventsOnDay = await repository.getEventsForDate(eventDate);
//
//     // Filter to only epistaxis events (not "no nosebleeds" placeholders)
//     final actualEventsOnDay = eventsOnDay.where((event) {
//       if (event.eventData is EpistaxisRecord) {
//         final epistaxis = event.eventData as EpistaxisRecord;
//         // Don't count "no nosebleeds" or "unknown" events
//         return !epistaxis.isNoNosebleedsEvent &&
//             !epistaxis.isUnknownNosebleedsEvent;
//       }
//       return true; // Count surveys and other event types
//     }).toList();
//
//     if (actualEventsOnDay.length == 1 &&
//         actualEventsOnDay.first.id == eventUuid) {
//       // This is the last actual event on this day - prompt user
//       final prompt = DeletionPrompt(
//         date: eventDate,
//         isLastEventOnDay: true,
//       );
//
//       final userChoice = await promptUser(prompt);
//
//       switch (userChoice) {
//         case DeletionChoice.confirmNoNosebleeds:
//           return await _convertToNoNosebleeds(eventUuid, eventDate);
//         case DeletionChoice.justDelete:
//           return await _softDelete(eventUuid);
//       }
//     } else {
//       // Not the last event, just delete
//       return await _softDelete(eventUuid);
//     }
//   }
//
//   /// Convert event to "no nosebleeds" confirmation
//   ///
//   /// Updates the event via audit trail (USER_UPDATE operation).
//   /// This preserves the audit history and shows protocol adherence.
//   Future<DeletionResult> _convertToNoNosebleeds(
//     String eventUuid,
//     DateTime eventDate,
//   ) async {
//     // Create "no nosebleeds" event
//     final noNosebleedsEvent = EpistaxisRecord.createNoNosebleeds(
//       date: DateTime(eventDate.year, eventDate.month, eventDate.day),
//       userNotes: 'Confirmed no nosebleeds on this date',
//     );
//
//     // Update via audit trail (maintains Event Sourcing pattern)
//     await repository.updateEvent(
//       eventUuid: eventUuid,
//       eventData: noNosebleedsEvent,
//       changeReason: 'User confirmed no nosebleeds occurred on this date',
//     );
//
//     return DeletionResult.convertedToNoNosebleeds(noNosebleedsEvent);
//   }
//
//   /// Soft delete the event
//   ///
//   /// Marks event as deleted in record_state (is_deleted=true).
//   /// Event remains in audit trail permanently.
//   Future<DeletionResult> _softDelete(String eventUuid) async {
//     // Soft delete via audit trail (USER_DELETE operation)
//     await repository.deleteEvent(
//       eventUuid: eventUuid,
//       changeReason: 'User deleted event',
//     );
//
//     return DeletionResult.deleted();
//   }
//
//   /// Delete multiple events with prompting
//   ///
//   /// Useful for batch operations.
//   /// Still prompts for each event that is last on its day.
//   Future<List<DeletionResult>> deleteEvents({
//     required List<String> eventUuids,
//     required List<DateTime> eventDates,
//     required Future<DeletionChoice> Function(DeletionPrompt) promptUser,
//   }) async {
//     if (eventUuids.length != eventDates.length) {
//       throw ArgumentError('eventUuids and eventDates must have same length');
//     }
//
//     final results = <DeletionResult>[];
//
//     for (var i = 0; i < eventUuids.length; i++) {
//       final result = await deleteEvent(
//         eventUuid: eventUuids[i],
//         eventDate: eventDates[i],
//         promptUser: promptUser,
//       );
//       results.add(result);
//     }
//
//     return results;
//   }
// }
