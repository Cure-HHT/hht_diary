import 'dart:async';

import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:event_sourcing_datastore_demo/app_state.dart';
import 'package:event_sourcing_datastore_demo/widgets/styles.dart';
import 'package:flutter/material.dart';

// Validated by: JNY-01 event order; JNY-02 CQRS (aggregate_type variety).
class EventStreamPanel extends StatefulWidget {
  const EventStreamPanel({
    required this.backend,
    required this.eventStore,
    required this.appState,
    super.key,
  });

  final StorageBackend backend;

  /// Owns the per-pane `Source` used to discriminate locally-originated
  /// rows from rows ingested from another hop. Drives the `[L]` / `[R]`
  /// hop badge prefix on each row (see [_EventRow]).
  // Implements: REQ-d00154-B — UI hop discrimination uses
  //   `EventStore.isLocallyOriginated`, which compares
  //   `provenance[0].identifier` against the pane's `source.identifier`.
  final EventStore eventStore;
  final AppState appState;

  @override
  State<EventStreamPanel> createState() => _EventStreamPanelState();
}

class _EventStreamPanelState extends State<EventStreamPanel> {
  List<StoredEvent> _events = const <StoredEvent>[];
  StreamSubscription<StoredEvent>? _eventsSub;

  @override
  void initState() {
    super.initState();
    widget.appState.addListener(_onAppState);
    _eventsSub = widget.backend.watchEvents().listen((_) {
      if (!mounted) return;
      _refresh();
    });
    _refresh();
  }

  @override
  void dispose() {
    _eventsSub?.cancel();
    widget.appState.removeListener(_onAppState);
    super.dispose();
  }

  void _onAppState() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _refresh() async {
    try {
      final events = await widget.backend.findAllEvents(limit: 500);
      if (!mounted) return;
      setState(() {
        _events = events;
      });
    } catch (_) {
      // Non-fatal; next poll retries.
    }
  }

  @override
  Widget build(BuildContext context) {
    // Most-recent first: sort descending by sequenceNumber.
    final sorted = <StoredEvent>[..._events]
      ..sort((a, b) => b.sequenceNumber.compareTo(a.sequenceNumber));
    return Container(
      decoration: BoxDecoration(color: DemoColors.bg, border: demoBorder),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text('EVENTS', style: DemoText.header),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: sorted.length,
              itemBuilder: (context, i) => _EventRow(
                event: sorted[i],
                locallyOriginated: widget.eventStore.isLocallyOriginated(
                  sorted[i],
                ),
                selected: widget.appState.selectedEventId == sorted[i].eventId,
                onTap: () => widget.appState.selectEvent(sorted[i].eventId),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({
    required this.event,
    required this.locallyOriginated,
    required this.selected,
    required this.onTap,
  });

  final StoredEvent event;

  /// `true` when this row's event was originated on the same install as
  /// the panel's pane. Drives the `[L]` vs `[R]` prefix.
  final bool locallyOriginated;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // UUIDv7 prefix is a timestamp, so aggregates minted close in time
    // share leading bytes. Tail (rand_b) is where the visual entropy lives.
    final shortAgg = event.aggregateId.length >= 6
        ? event.aggregateId.substring(event.aggregateId.length - 6)
        : event.aggregateId;
    // Implements: REQ-d00154-B — visual hop discrimination per row.
    //   `[L]` flags rows originated on this pane's install; `[R]` flags
    //   rows ingested from another hop (e.g. mobile -> portal via the
    //   downstream bridge).
    final originBadge = locallyOriginated ? '[L]' : '[R]';
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: selected ? DemoColors.selected : DemoColors.bg,
          border: selected ? demoSelectedBorder : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          '$originBadge #${event.sequenceNumber} ${event.eventType} '
          '${event.aggregateType} $shortAgg',
          style: DemoText.body,
        ),
      ),
    );
  }
}
