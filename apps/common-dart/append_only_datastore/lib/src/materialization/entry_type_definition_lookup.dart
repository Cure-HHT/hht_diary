import 'package:trial_data_types/trial_data_types.dart';

/// Registry that resolves an `entry_type` identifier to its
/// [EntryTypeDefinition].
///
/// The materializer consumes this to obtain `effective_date_path`,
/// `widget_id`, and other per-type metadata while folding events into
/// `DiaryEntry` rows. Keeping the lookup behind an abstract interface lets
/// tests substitute an in-memory map (`MapEntryTypeDefinitionLookup` under
/// `test/test_support/`) and lets production code inject the sponsor's
/// compile-time registry without coupling the materializer to either.
///
/// Implementations SHALL return `null` for unknown ids rather than raising —
/// callers distinguish "unknown type" from "registered" with a null check,
/// which keeps fallback/error paths explicit at the call site.
// Implements: REQ-d00121-A — the lookup supplies the `EntryTypeDefinition`
// that lets Materializer.apply remain a pure function of its inputs.
// ignore: one_member_abstracts
abstract class EntryTypeDefinitionLookup {
  const EntryTypeDefinitionLookup();

  /// Returns the [EntryTypeDefinition] registered under [entryTypeId], or
  /// `null` when no registration matches.
  EntryTypeDefinition? lookup(String entryTypeId);
}
