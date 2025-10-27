// ============================================================================
// Diary Repository
// ============================================================================
//required imports    
//req uired imports
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models.dart';
//req uired imports 
//req

/// Repository for diary events
///
/// Follows Event Sourcing pattern:
/// - All changes written to record_audit (event store)
/// - record_state is derived/materialized view
/// - Never directly modify record_state
class DiaryRepository {
  final SupabaseClient supabase;

  DiaryRepository(this.supabase);

  /// Get all events for a specific date (not soft deleted)
  ///
  /// Returns only epistaxis events that occurred on the given date.
  /// Filters out soft-deleted records.
  Future<List<EventRecord>> getEventsForDate(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(Duration(days: 1));

    final response = await supabase
        .from('record_state')
        .select('current_data, event_uuid')
        .eq('patient_id', supabase.auth.currentUser!.id)
        .eq('is_deleted', false)
        .gte(
          'current_data->event_data->startTime',
          startOfDay.toIso8601String(),
        )
        .lt(
          'current_data->event_data->startTime',
          endOfDay.toIso8601String(),
        );

    return (response as List)
        .map((row) => EventRecord.fromJson(row['current_data']))
        .toList();
  }

  /// Get a single event by UUID
  Future<EventRecord?> getEvent(String eventUuid) async {
    final response = await supabase
        .from('record_state')
        .select('current_data')
        .eq('event_uuid', eventUuid)
        .eq('patient_id', supabase.auth.currentUser!.id)
        .eq('is_deleted', false)
        .maybeSingle();

    if (response == null) return null;

    return EventRecord.fromJson(response['current_data']);
  }

  /// Create a new event via audit trail
  Future<void> createEvent({
    required EventRecord event,
    required String changeReason,
  }) async {
    await supabase.from('record_audit').insert({
      'event_uuid': event.id,
      'patient_id': supabase.auth.currentUser!.id,
      'site_id': await _getUserSiteId(),
      'operation': 'USER_CREATE',
      'data': event.toJson(),
      'created_by': supabase.auth.currentUser!.id,
      'role': 'USER',
      'client_timestamp': DateTime.now().toIso8601String(),
      'change_reason': changeReason,
    });
  }

  /// Update an event via audit trail
  ///
  /// Creates a new audit entry with USER_UPDATE operation.
  /// The trigger will update record_state automatically.
  Future<void> updateEvent({
    required String eventUuid,
    required dynamic eventData,
    required String changeReason,
  }) async {
    final eventRecord = EventRecord(
      id: eventUuid,
      versionedType: getVersionedType(eventData),
      eventData: eventData,
    );

    await supabase.from('record_audit').insert({
      'event_uuid': eventUuid,
      'patient_id': supabase.auth.currentUser!.id,
      'site_id': await _getUserSiteId(),
      'operation': 'USER_UPDATE',
      'data': eventRecord.toJson(),
      'created_by': supabase.auth.currentUser!.id,
      'role': 'USER',
      'client_timestamp': DateTime.now().toIso8601String(),
      'change_reason': changeReason,
    });
  }

  /// Soft delete an event via audit trail
  ///
  /// Creates a USER_DELETE audit entry.
  /// The record remains in the database with is_deleted=true.
  Future<void> deleteEvent({
    required String eventUuid,
    required String changeReason,
  }) async {
    // Get current event data to include in delete audit entry
    final currentEvent = await getEvent(eventUuid);
    if (currentEvent == null) {
      throw Exception('Event not found: $eventUuid');
    }

    await supabase.from('record_audit').insert({
      'event_uuid': eventUuid,
      'patient_id': supabase.auth.currentUser!.id,
      'site_id': await _getUserSiteId(),
      'operation': 'USER_DELETE',
      'data': currentEvent.toJson(), // Include final state in audit
      'created_by': supabase.auth.currentUser!.id,
      'role': 'USER',
      'client_timestamp': DateTime.now().toIso8601String(),
      'change_reason': changeReason,
    });
  }

  /// Get user's site ID
  ///
  /// Required for all audit entries.
  /// Assumes user is assigned to exactly one site.
  Future<String> _getUserSiteId() async {
    final response = await supabase
        .from('user_site_assignments')
        .select('site_id')
        .eq('patient_id', supabase.auth.currentUser!.id)
        .eq('enrollment_status', 'ACTIVE')
        .single();

    return response['site_id'] as String;
  }

  /// Get all events for a date range
  Future<List<EventRecord>> getEventsForDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final response = await supabase
        .from('record_state')
        .select('current_data')
        .eq('patient_id', supabase.auth.currentUser!.id)
        .eq('is_deleted', false)
        .gte(
          'current_data->event_data->startTime',
          startDate.toIso8601String(),
        )
        .lte(
          'current_data->event_data->startTime',
          endDate.toIso8601String(),
        )
        .order('current_data->event_data->startTime');

    return (response as List)
        .map((row) => EventRecord.fromJson(row['current_data']))
        .toList();
  }

  /// Get audit history for an event
  ///
  /// Returns all audit entries for a given event UUID.
  /// Useful for viewing change history.
  Future<List<Map<String, dynamic>>> getAuditHistory(String eventUuid) async {
    final response = await supabase
        .from('record_audit')
        .select('*')
        .eq('event_uuid', eventUuid)
        .eq('patient_id', supabase.auth.currentUser!.id)
        .order('audit_id');

    return (response as List).cast<Map<String, dynamic>>();
  }
}
