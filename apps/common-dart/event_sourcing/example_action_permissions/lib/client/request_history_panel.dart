// lib/client/request_history_panel.dart
//
// Reverse-chronological list of dispatch outcomes. Each entry carries the
// raw request and the wire response; rendering is shape-aware so denials
// surface their denial kind and authorization failures highlight which
// permission was missing.

import 'package:action_permissions_demo/client/action_buttons_panel.dart';
import 'package:action_permissions_demo/shared/wire_types.dart';
import 'package:flutter/material.dart';

class RequestHistoryPanel extends StatelessWidget {
  const RequestHistoryPanel({super.key, required this.entries});

  final List<DispatchHistoryEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          '(no dispatches yet)',
          style: TextStyle(fontStyle: FontStyle.italic),
        ),
      );
    }
    final reversed = entries.reversed.toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final entry in reversed) _HistoryRow(entry: entry),
      ],
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry});

  final DispatchHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final outcome = _outcomeLabel(entry.response);
    final color = _outcomeColor(entry.response);
    final detail = _outcomeDetail(entry.response);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 12,
            height: 12,
            margin: const EdgeInsets.only(top: 4, right: 8),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${entry.request.actionName}  →  $outcome',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  _formatTime(entry.at),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                if (detail != null)
                  Text(detail, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _outcomeLabel(DispatchResponse response) {
    return switch (response) {
      DispatchResponseSuccess() => 'success',
      DispatchResponseIdempotencyHit() => 'idempotency hit',
      DispatchResponseDenied(:final denialKind) => denialKind,
    };
  }

  static Color _outcomeColor(DispatchResponse response) {
    return switch (response) {
      DispatchResponseSuccess() => Colors.green,
      DispatchResponseIdempotencyHit() => Colors.amber,
      DispatchResponseDenied() => Colors.red,
    };
  }

  static String? _outcomeDetail(DispatchResponse response) {
    return switch (response) {
      DispatchResponseSuccess(:final emittedEventIds) =>
        emittedEventIds.isEmpty
            ? null
            : 'emitted ${emittedEventIds.length} event(s)',
      DispatchResponseIdempotencyHit(:final priorEventIds) =>
        'cache hit (${priorEventIds.length} prior event(s))',
      DispatchResponseDenied(
        :final permissionDenied,
        :final requestedName,
        :final errorMessageSanitized,
      ) =>
        permissionDenied != null
            ? 'permission: $permissionDenied'
            : requestedName != null
            ? 'requested: $requestedName'
            : errorMessageSanitized,
    };
  }

  static String _formatTime(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }
}
