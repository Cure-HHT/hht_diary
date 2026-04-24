import 'package:event_sourcing_datastore/src/entry_type_definition.dart';

/// Reserved id for the per-event security-context redaction audit event.
const String kSecurityContextRedactedEntryType = 'security_context_redacted';

/// Reserved id for the bulk-truncation (retention compact) audit event.
const String kSecurityContextCompactedEntryType = 'security_context_compacted';

/// Reserved id for the bulk-delete (retention purge) audit event.
const String kSecurityContextPurgedEntryType = 'security_context_purged';

/// Reserved set of ids. `bootstrapAppendOnlyDatastore` auto-registers
/// these BEFORE iterating the caller-supplied entry-type list. A
/// caller-supplied id colliding with one of these throws `ArgumentError`
/// with an explicit "reserved" message (REQ-d00134-D revised).
const Set<String> kReservedSystemEntryTypeIds = <String>{
  kSecurityContextRedactedEntryType,
  kSecurityContextCompactedEntryType,
  kSecurityContextPurgedEntryType,
};

/// The three reserved system entry-type definitions. All three have
/// `materialize: false` so they never hit any view; they exist only to
/// stamp an immutable event_log row for every security-context mutation.
// Implements: REQ-d00138-D+E+F+G — system entry types for redaction /
// compact / purge audit events.
const List<EntryTypeDefinition> kSystemEntryTypes = <EntryTypeDefinition>[
  EntryTypeDefinition(
    id: kSecurityContextRedactedEntryType,
    version: '1',
    name: 'Security Context Redacted',
    widgetId: '_system',
    widgetConfig: <String, Object?>{},
    materialize: false,
  ),
  EntryTypeDefinition(
    id: kSecurityContextCompactedEntryType,
    version: '1',
    name: 'Security Context Compacted',
    widgetId: '_system',
    widgetConfig: <String, Object?>{},
    materialize: false,
  ),
  EntryTypeDefinition(
    id: kSecurityContextPurgedEntryType,
    version: '1',
    name: 'Security Context Purged',
    widgetId: '_system',
    widgetConfig: <String, Object?>{},
    materialize: false,
  ),
];
