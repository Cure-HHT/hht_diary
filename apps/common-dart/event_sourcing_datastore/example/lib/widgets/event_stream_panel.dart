import 'dart:async';

import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:event_sourcing_datastore_demo/app_state.dart';
import 'package:event_sourcing_datastore_demo/widgets/styles.dart';
import 'package:flutter/material.dart';

// Validated by: JNY-01 event order; JNY-02 CQRS (aggregate_type variety).
class EventStreamPanel extends StatefulWidget {
  const EventStreamPanel({
    required this.backend,
    required this.appState,
    super.key,
  });

  final StorageBackend backend;
  final AppState appState;

  @override
  State<EventStreamPanel> createState() => _EventStreamPanelState();
}

class _EventStreamPanelState extends State<EventStreamPanel> {
  List<StoredEvent> _events = const <StoredEvent>[];
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    widget.appState.addListener(_onAppState);
    _poll = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => _refresh(),
    );
    _refresh();
  }

  @override
  void dispose() {
    _poll?.cancel();
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
    required this.selected,
    required this.onTap,
  });

  final StoredEvent event;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shortAgg = event.aggregateId.length >= 6
        ? event.aggregateId.substring(0, 6)
        : event.aggregateId;
    final eventTypeShort = event.eventType.length > 7
        ? event.eventType.substring(0, 7)
        : event.eventType;
    return InkWell(
      onTap: onTap,
      child: Container(
        color: selected ? DemoColors.selected : DemoColors.bg,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          '#${event.sequenceNumber} $eventTypeShort ${event.aggregateType} $shortAgg',
          style: DemoText.body,
        ),
      ),
    );
  }
}
