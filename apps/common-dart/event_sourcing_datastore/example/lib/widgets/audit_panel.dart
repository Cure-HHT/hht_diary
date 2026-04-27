import 'dart:async';

import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:event_sourcing_datastore_demo/widgets/styles.dart';
import 'package:flutter/material.dart';

/// Demonstrates the typed cross-store audit query (`StorageBackend.queryAudit`,
/// REQ-d00151). Renders one row per `(event, securityContext)` pair returned
/// by the join, with an optional `flow_token` filter. Re-queries on every
/// `watchEvents` arrival so the list stays live without a polling timer.
///
/// Empty-state in the stock demo: the panel is empty until events are
/// recorded with `SecurityDetails`. Flip the `sec ctx` toggle on the top
/// action bar to ON, then click Start / Complete / Delete (or the colored
/// button-press actions) to populate the audit log. Events recorded with
/// the toggle OFF do not write a security_context sidecar row and so do
/// not appear in the join.
class AuditPanel extends StatefulWidget {
  const AuditPanel({required this.backend, super.key});

  final StorageBackend backend;

  @override
  State<AuditPanel> createState() => _AuditPanelState();
}

class _AuditPanelState extends State<AuditPanel> {
  PagedAudit? _page;
  StreamSubscription<StoredEvent>? _eventsSub;
  String? _flowTokenFilter;
  final TextEditingController _filterController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refresh();
    // Re-query on every event arrival — keeps the audit list live without
    // its own polling timer (mirrors event_stream_panel's pattern).
    _eventsSub = widget.backend.watchEvents().listen((_) {
      if (!mounted) return;
      _refresh();
    });
  }

  @override
  void dispose() {
    _eventsSub?.cancel();
    _filterController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final page = await widget.backend.queryAudit(flowToken: _flowTokenFilter);
      if (!mounted) return;
      setState(() {
        _page = page;
      });
    } catch (_) {
      // Non-fatal: next watchEvents tick retries.
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = _page;
    return Container(
      decoration: BoxDecoration(color: DemoColors.bg, border: demoBorder),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text('AUDIT', style: DemoText.header),
          const SizedBox(height: 8),
          _filterBar(),
          const SizedBox(height: 8),
          Expanded(child: _body(page)),
        ],
      ),
    );
  }

  Widget _filterBar() {
    return TextField(
      controller: _filterController,
      style: DemoText.body,
      decoration: const InputDecoration(
        labelText: 'flow_token (blank = all)',
        labelStyle: TextStyle(color: DemoColors.pending),
        isDense: true,
        border: OutlineInputBorder(),
      ),
      onSubmitted: (v) {
        setState(() {
          _flowTokenFilter = v.isEmpty ? null : v;
        });
        _refresh();
      },
    );
  }

  Widget _body(PagedAudit? page) {
    if (page == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (page.rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        child: Text(
          'no audit rows.\n\n'
          'queryAudit returns the join of event_log x security_context. '
          'a security_context row is written only when an event is '
          'recorded with SecurityDetails attached.\n\n'
          'flip the "sec ctx" toggle on the top action bar to ON, then '
          'record some events — they will populate the join and show up '
          'here.',
          style: DemoText.body,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
          child: ListView.builder(
            itemCount: page.rows.length,
            itemBuilder: (context, i) => _AuditRowTile(row: page.rows[i]),
          ),
        ),
        if (page.nextCursor != null)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'more rows available (cursor present)',
              style: DemoText.body,
            ),
          ),
      ],
    );
  }
}

class _AuditRowTile extends StatelessWidget {
  const _AuditRowTile({required this.row});

  final AuditRow row;

  @override
  Widget build(BuildContext context) {
    final shortEventId = row.event.eventId.length >= 8
        ? row.event.eventId.substring(row.event.eventId.length - 8)
        : row.event.eventId;
    final initiator = row.event.initiator;
    final initiatorLabel = switch (initiator) {
      UserInitiator(:final userId) => 'user:$userId',
      AutomationInitiator(:final service) => 'auto:$service',
      AnonymousInitiator() => 'anon',
    };
    return Container(
      decoration: const BoxDecoration(
        color: DemoColors.bg,
        border: Border(bottom: BorderSide(color: DemoColors.border, width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'evt-$shortEventId  #${row.event.sequenceNumber}',
            style: DemoText.body,
          ),
          Text(
            'recorded ${row.context.recordedAt.toIso8601String()}',
            style: DemoText.body,
          ),
          Text('initiator $initiatorLabel', style: DemoText.body),
          Text('flow ${row.event.flowToken ?? "(none)"}', style: DemoText.body),
        ],
      ),
    );
  }
}
