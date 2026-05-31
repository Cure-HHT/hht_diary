// Implements: DIARY-DEV-participant-site-index/A — the portal materializes the
//   participant -> site map from RAVE-sourced participant_synced_from_edc events
//   to back the participant-contained-in-site containment resolution. Upsert by
//   participant_id: a re-sync with a new site_id overwrites the row.
import 'package:event_sourcing/event_sourcing.dart';

/// `participant_site_index`: one row per participant carrying its current
/// RAVE-assigned site. Read by the ContainmentResolver when a participant-scoped
/// permission is evaluated. RAVE is authoritative; the portal never writes it
/// except by folding the edge event.
final TableProjectionSpec participantSiteIndexSpec = TableProjectionSpec(
  viewName: 'participant_site_index',
  interest: const SubscriptionFilter(
    eventTypes: {'participant_synced_from_edc'},
    aggregateTypes: {'participant'},
  ),
  insertEventTypes: const {'participant_synced_from_edc'},
  removeEventTypes: const {},
  rowKey: const CompositeKey(['data.participant_id']),
  rowData: const SelectedFields(['participant_id', 'site_id']),
);
