// IMPLEMENTS REQUIREMENTS:
//   REQ-d00166-D: EventDraft value type input to Action.execute.

/// Input value for `appendWithSecurity`: the event to be persisted.
///
/// The dispatcher fills in `initiator`, `metadata['action_invocation_id']`,
/// and `metadata['action_name']` before persisting. `flowToken` is optional
/// input from the action; the dispatcher uses the call parameter as fallback.
//
// Implements: REQ-d00166-D — value type holding aggregateId, aggregateType,
// entryType, eventType, data, flowToken, metadata.
class EventDraft {
  const EventDraft({
    required this.aggregateId,
    required this.aggregateType,
    required this.entryType,
    required this.eventType,
    required this.data,
    this.flowToken,
    this.metadata,
  });

  final String aggregateId;
  final String aggregateType;
  final String entryType;
  final String eventType;
  final Map<String, dynamic> data;
  final String? flowToken;
  final Map<String, dynamic>? metadata;
}
