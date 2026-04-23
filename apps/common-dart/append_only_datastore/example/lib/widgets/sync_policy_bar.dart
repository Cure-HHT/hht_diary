import 'dart:math';

import 'package:append_only_datastore/append_only_datastore.dart';
import 'package:append_only_datastore_demo/widgets/styles.dart';
import 'package:flutter/material.dart';

// Validated by: JNY-04 (transient disconnect), JNY-05 (policy tuning).
class SyncPolicyBar extends StatefulWidget {
  const SyncPolicyBar({required this.notifier, super.key});

  final ValueNotifier<SyncPolicy> notifier;

  @override
  State<SyncPolicyBar> createState() => _SyncPolicyBarState();
}

class _SyncPolicyBarState extends State<SyncPolicyBar> {
  @override
  void initState() {
    super.initState();
    widget.notifier.addListener(_onChange);
  }

  @override
  void dispose() {
    widget.notifier.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (!mounted) return;
    setState(() {});
  }

  SyncPolicy _copy({
    Duration? initialBackoff,
    double? backoffMultiplier,
    Duration? maxBackoff,
    double? jitterFraction,
    int? maxAttempts,
  }) {
    final p = widget.notifier.value;
    return SyncPolicy(
      initialBackoff: initialBackoff ?? p.initialBackoff,
      backoffMultiplier: backoffMultiplier ?? p.backoffMultiplier,
      maxBackoff: maxBackoff ?? p.maxBackoff,
      jitterFraction: jitterFraction ?? p.jitterFraction,
      maxAttempts: maxAttempts ?? p.maxAttempts,
      periodicInterval: p.periodicInterval,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.notifier.value;
    return Container(
      decoration: BoxDecoration(color: DemoColors.bg, border: demoBorder),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: <Widget>[
          const SizedBox(
            width: 100,
            child: Text('policy', style: TextStyle(color: DemoColors.accent)),
          ),
          _slider(
            label: 'init',
            value: p.initialBackoff.inMilliseconds.toDouble(),
            min: 100,
            max: 30000,
            display: '${p.initialBackoff.inMilliseconds}ms',
            onChanged: (v) => widget.notifier.value = _copy(
              initialBackoff: Duration(milliseconds: v.round()),
            ),
          ),
          _slider(
            label: 'mult',
            value: p.backoffMultiplier,
            min: 1.0,
            max: 5.0,
            display: p.backoffMultiplier.toStringAsFixed(2),
            onChanged: (v) =>
                widget.notifier.value = _copy(backoffMultiplier: v),
          ),
          _slider(
            label: 'max',
            value: p.maxBackoff.inMilliseconds.toDouble(),
            min: 1000,
            max: 120000,
            display: '${p.maxBackoff.inSeconds}s',
            onChanged: (v) => widget.notifier.value = _copy(
              maxBackoff: Duration(milliseconds: v.round()),
            ),
          ),
          _slider(
            label: 'jit',
            value: p.jitterFraction,
            min: 0.0,
            max: 1.0,
            display: p.jitterFraction.toStringAsFixed(2),
            onChanged: (v) => widget.notifier.value = _copy(jitterFraction: v),
          ),
          _slider(
            label: 'attempts',
            // Log-scaled slider for maxAttempts: map [0, 1] → [1, 1_000_000].
            value: log(p.maxAttempts) / log(1000000),
            min: 0,
            max: 1,
            display: p.maxAttempts.toString(),
            onChanged: (v) => widget.notifier.value = _copy(
              maxAttempts: max(1, pow(1000000, v).round()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _slider({
    required String label,
    required double value,
    required double min,
    required double max,
    required String display,
    required ValueChanged<double> onChanged,
  }) {
    return Expanded(
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 60,
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
            width: 72,
            child: Text(
              display,
              style: const TextStyle(color: DemoColors.fg, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}
