import 'dart:async';
import 'dart:math' as math;

import 'package:event_sourcing_datastore/event_sourcing_datastore.dart'
    show tombstoneAndRefill, DestinationSchedule, SembastBackend;
import 'package:event_sourcing_datastore_demo/app_state.dart';
import 'package:event_sourcing_datastore_demo/demo_destination.dart';
import 'package:event_sourcing_datastore_demo/widgets/styles.dart';
import 'package:flutter/material.dart';
import 'package:sembast/sembast.dart';

// Validated by: JNY-03, JNY-04, JNY-07, JNY-08, JNY-09.
class FifoPanel extends StatefulWidget {
  const FifoPanel({
    required this.destination,
    required this.backend,
    required this.appState,
    super.key,
  });

  final DemoDestination destination;
  final SembastBackend backend;
  final AppState appState;

  @override
  State<FifoPanel> createState() => _FifoPanelState();
}

class _FifoPanelState extends State<FifoPanel> {
  List<Map<String, Object?>> _rows = const <Map<String, Object?>>[];
  DestinationSchedule? _schedule;
  bool _opsOpen = false;
  String? _banner;
  Timer? _poll;
  Timer? _bannerTimer;

  final TextEditingController _startCtrl = TextEditingController();
  final TextEditingController _endCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.destination.connection.addListener(_onNotifier);
    widget.destination.sendLatency.addListener(_onNotifier);
    widget.destination.batchSize.addListener(_onNotifier);
    widget.destination.maxAccumulateTimeN.addListener(_onNotifier);
    widget.appState.addListener(_onNotifier);
    _poll = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => _refresh(),
    );
    _refresh();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _bannerTimer?.cancel();
    widget.destination.connection.removeListener(_onNotifier);
    widget.destination.sendLatency.removeListener(_onNotifier);
    widget.destination.batchSize.removeListener(_onNotifier);
    widget.destination.maxAccumulateTimeN.removeListener(_onNotifier);
    widget.appState.removeListener(_onNotifier);
    _startCtrl.dispose();
    _endCtrl.dispose();
    super.dispose();
  }

  void _onNotifier() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _refresh() async {
    try {
      final store = intMapStoreFactory.store('fifo_${widget.destination.id}');
      final records = await store.find(widget.backend.debugDatabase());
      final rows = records
          .map((r) => Map<String, Object?>.from(r.value))
          .toList();
      final schedule = await widget.appState.registry.scheduleOf(
        widget.destination.id,
      );
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _schedule = schedule;
      });
    } catch (_) {
      // Non-fatal.
    }
  }

  void _flashBanner(String msg) {
    if (!mounted) return;
    setState(() => _banner = msg);
    _bannerTimer?.cancel();
    _bannerTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _banner = null);
    });
  }

  String _scheduleLabel() {
    final s = _schedule;
    if (s == null) return 'LOADING';
    final now = DateTime.now().toUtc();
    if (s.startDate == null) return 'DORMANT';
    if (s.startDate!.isAfter(now)) {
      return 'SCHEDULED until ${s.startDate!.toIso8601String()}';
    }
    if (s.endDate == null || s.endDate!.isAfter(now)) return 'ACTIVE';
    return 'CLOSED @ ${s.endDate!.toIso8601String()}';
  }

  @override
  Widget build(BuildContext context) {
    final s = _schedule;
    final showStartEditor =
        s == null ||
        s.startDate == null ||
        s.startDate!.isAfter(DateTime.now().toUtc());
    return Container(
      decoration: BoxDecoration(color: DemoColors.bg, border: demoBorder),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(widget.destination.id.toUpperCase(), style: DemoText.header),
          Text(
            _scheduleLabel(),
            style: const TextStyle(
              color: DemoColors.accent,
              fontFamily: 'monospace',
              fontSize: 14,
            ),
          ),
          if (showStartEditor) _startDateEditor(),
          _endDateEditor(),
          _connectionDropdown(),
          _latencySlider(),
          _sliderRow(
            label: 'batch size',
            value: widget.destination.batchSize.value.toDouble(),
            min: 1,
            max: 12,
            onChanged: (v) => widget.destination.batchSize.value = v.round(),
          ),
          _sliderRow(
            label: 'accumulate (s)',
            value: widget.destination.maxAccumulateTimeN.value.inSeconds
                .toDouble(),
            min: 0,
            max: 20,
            onChanged: (v) => widget.destination.maxAccumulateTimeN.value =
                Duration(seconds: v.round()),
          ),
          _opsDrawer(),
          if (_banner != null)
            Container(
              padding: const EdgeInsets.all(4),
              color: DemoColors.accent,
              child: Text(
                _banner!,
                style: const TextStyle(color: DemoColors.bg, fontSize: 12),
              ),
            ),
          Expanded(child: _rowList()),
        ],
      ),
    );
  }

  Widget _startDateEditor() {
    return Row(
      children: <Widget>[
        Expanded(
          child: TextField(
            controller: _startCtrl,
            style: const TextStyle(color: DemoColors.fg, fontSize: 12),
            decoration: const InputDecoration(
              hintText: 'startDate ISO-8601 (e.g. 2026-04-23T00:00:00Z)',
              hintStyle: TextStyle(color: DemoColors.pending, fontSize: 11),
              isDense: true,
            ),
          ),
        ),
        TextButton(
          onPressed: () async {
            final d = DateTime.tryParse(_startCtrl.text);
            if (d == null) {
              _flashBanner('invalid date');
              return;
            }
            try {
              await widget.appState.registry.setStartDate(
                widget.destination.id,
                d.toUtc(),
              );
              _flashBanner('startDate set');
              await _refresh();
            } catch (e) {
              _flashBanner('err: $e');
            }
          },
          child: const Text('Set', style: TextStyle(color: DemoColors.accent)),
        ),
      ],
    );
  }

  Widget _endDateEditor() {
    return Row(
      children: <Widget>[
        Expanded(
          child: TextField(
            controller: _endCtrl,
            style: const TextStyle(color: DemoColors.fg, fontSize: 12),
            decoration: const InputDecoration(
              hintText: 'endDate ISO-8601 (past = close now)',
              hintStyle: TextStyle(color: DemoColors.pending, fontSize: 11),
              isDense: true,
            ),
          ),
        ),
        TextButton(
          onPressed: () async {
            final d = DateTime.tryParse(_endCtrl.text);
            if (d == null) {
              _flashBanner('invalid date');
              return;
            }
            try {
              final result = await widget.appState.registry.setEndDate(
                widget.destination.id,
                d.toUtc(),
              );
              _flashBanner('endDate: $result');
              await _refresh();
            } catch (e) {
              _flashBanner('err: $e');
            }
          },
          child: const Text('Set', style: TextStyle(color: DemoColors.accent)),
        ),
      ],
    );
  }

  Widget _connectionDropdown() {
    return Row(
      children: <Widget>[
        const Text('conn:', style: TextStyle(color: DemoColors.fg)),
        const SizedBox(width: 4),
        DropdownButton<Connection>(
          value: widget.destination.connection.value,
          dropdownColor: DemoColors.bg,
          style: const TextStyle(color: DemoColors.fg),
          items: Connection.values
              .map(
                (c) =>
                    DropdownMenuItem<Connection>(value: c, child: Text(c.name)),
              )
              .toList(),
          onChanged: (c) {
            if (c == null) return;
            widget.destination.connection.value = c;
          },
        ),
      ],
    );
  }

  Widget _sliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
    String? displayOverride,
  }) {
    return Row(
      children: <Widget>[
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(color: DemoColors.fg, fontSize: 12),
          ),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            activeColor: DemoColors.accent,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 54,
          child: Text(
            displayOverride ?? value.round().toString(),
            style: const TextStyle(color: DemoColors.fg, fontSize: 12),
          ),
        ),
      ],
    );
  }

  /// Non-linear latency slider: slider position `p` in [0, 1] maps to
  /// milliseconds `p^2 * 10000`. Small positions give small ms so
  /// single-digit / low-hundreds values are easy to dial in; the top
  /// of the slider reaches 10 s.
  Widget _latencySlider() {
    const maxMs = 10000.0;
    final currentMs = widget.destination.sendLatency.value.inMilliseconds
        .toDouble();
    final position = math.sqrt((currentMs / maxMs).clamp(0.0, 1.0));
    return _sliderRow(
      label: 'latency (ms)',
      value: position,
      min: 0,
      max: 1,
      displayOverride: currentMs.round().toString(),
      onChanged: (p) {
        final ms = (p * p * maxMs).round();
        widget.destination.sendLatency.value = Duration(milliseconds: ms);
      },
    );
  }

  Widget _opsDrawer() {
    return Column(
      children: <Widget>[
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => setState(() => _opsOpen = !_opsOpen),
            child: Text(
              _opsOpen ? 'ops ▾' : 'ops ▸',
              style: const TextStyle(color: DemoColors.accent),
            ),
          ),
        ),
        if (_opsOpen)
          Wrap(
            children: <Widget>[
              if (widget.destination.allowHardDelete)
                TextButton(
                  onPressed: () async {
                    try {
                      await widget.appState.registry.deleteDestination(
                        widget.destination.id,
                      );
                      _flashBanner('deleted');
                    } catch (e) {
                      _flashBanner('delete err: $e');
                    }
                  },
                  child: const Text(
                    '[Delete destination]',
                    style: TextStyle(color: DemoColors.red),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _rowList() {
    // Display reversed (descending sequence_in_queue) so the most
    // recently enqueued row is on top.
    final display = <Map<String, Object?>>[..._rows]
      ..sort(
        (a, b) => (b['sequence_in_queue'] as int? ?? 0).compareTo(
          a['sequence_in_queue'] as int? ?? 0,
        ),
      );
    return ListView.builder(
      itemCount: display.length,
      itemBuilder: (context, i) => _FifoRowTile(
        row: display[i],
        selected:
            widget.appState.selectedFifoRowId == display[i]['entry_id'] &&
            widget.appState.selectedFifoDestinationId == widget.destination.id,
        onTap: () => widget.appState.selectFifoRow(
          widget.destination.id,
          display[i]['entry_id'] as String?,
        ),
        destinationId: widget.destination.id,
        backend: widget.backend,
        onTombstoneAndRefill: () async {
          try {
            await tombstoneAndRefill(
              widget.destination.id,
              display[i]['entry_id']! as String,
              backend: widget.backend,
            );
            _flashBanner('tombstoned & refilled');
            await _refresh();
          } catch (e) {
            _flashBanner('err: $e');
          }
        },
      ),
    );
  }
}

class _FifoRowTile extends StatelessWidget {
  const _FifoRowTile({
    required this.row,
    required this.selected,
    required this.onTap,
    required this.destinationId,
    required this.backend,
    required this.onTombstoneAndRefill,
  });

  final Map<String, Object?> row;
  final bool selected;
  final VoidCallback onTap;
  final String destinationId;
  final SembastBackend backend;
  final VoidCallback onTombstoneAndRefill;

  @override
  Widget build(BuildContext context) {
    final seq = row['sequence_in_queue'] ?? '?';
    final status = row['final_status'];
    final attemptsRaw = row['attempts'];
    final attemptsLen = attemptsRaw is List ? attemptsRaw.length : 0;
    final eventIdsRaw = row['event_ids'];
    final eventIds = eventIdsRaw is List ? eventIdsRaw : const <Object?>[];
    final count = eventIds.length;
    final latestEventId = eventIds.isNotEmpty ? eventIds.last.toString() : '-';

    String prefix;
    Color color;
    if (status == 'sent') {
      prefix = '[SENT] ';
      color = DemoColors.sent;
    } else if (status == 'wedged') {
      prefix = '[wdg]  ';
      color = DemoColors.wedged;
    } else if (status == 'tombstoned') {
      prefix = '[tmb]  ';
      color = DemoColors.wedged;
    } else if (attemptsLen > 0) {
      prefix = '> ';
      color = DemoColors.retrying;
    } else {
      prefix = '[pend] ';
      color = DemoColors.fg;
    }

    final label =
        '$prefix#$seq: events: $count (latest: $latestEventId)  attempts:$attemptsLen';
    // Show TombstoneAndRefill button only on wedged rows. A healthy pending
    // head is also a valid target per REQ-d00144-A, but surfacing the control
    // on every transient null head during rapid enqueue reads as a false
    // "this row needs intervention" signal. Operator scripts can still call
    // tombstoneAndRefill on a null head directly through the library API.
    final isWedged = status == 'wedged';
    return InkWell(
      onTap: onTap,
      child: Container(
        color: selected ? DemoColors.selected : DemoColors.bg,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontFamily: 'monospace',
                  fontSize: 14,
                ),
              ),
            ),
            if (isWedged)
              ElevatedButton(
                onPressed: onTombstoneAndRefill,
                child: const Text(
                  'Tombstone & Refill',
                  style: TextStyle(fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
