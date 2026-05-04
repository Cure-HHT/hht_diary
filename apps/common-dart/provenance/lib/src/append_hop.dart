import 'package:provenance/src/provenance_entry.dart';

/// Append a single [ProvenanceEntry] to the tail of a chain-of-custody.
///
/// Returns a NEW unmodifiable list. The input [chain] is never mutated, and
/// the returned list itself rejects modification so callers cannot break the
/// no-mutation invariant downstream.
///
/// Each hop that receives an event calls `appendHop` exactly once to record
/// its receipt.
// Implements: REQ-d00115-A+B — append exactly one entry per hop; never mutate
// prior entries. Returning an unmodifiable list preserves the invariant
// downstream: even buggy callers cannot retroactively alter the chain.
List<ProvenanceEntry> appendHop(
  List<ProvenanceEntry> chain,
  ProvenanceEntry entry,
) => List<ProvenanceEntry>.unmodifiable(<ProvenanceEntry>[...chain, entry]);
