import 'dart:async';

import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:event_sourcing_datastore_demo/lights_materializer.dart';
import 'package:event_sourcing_datastore_demo/widgets/styles.dart';
import 'package:flutter/material.dart';

/// Three RGB "lights" rendered from the `rgb_lights` materialized view.
/// Each light's `is_on` state is toggled on every press of its
/// corresponding button (RED / GREEN / BLUE in the top action bar).
///
/// Subscribes to `backend.watchView('rgb_lights')` (REQ-d00153) so the
/// rendering re-runs only when the view's rows actually change — no
/// timer, no event-stream filter at the panel layer. Demonstrates the
/// reactive read primitive end-to-end: button press → event appended →
/// `LightsMaterializer.applyInTxn` toggles the row → view-mutation
/// post-commit fires `_viewChangesController.add('rgb_lights')` → this
/// panel's stream subscription re-fetches and re-renders.
class LightsPanel extends StatefulWidget {
  const LightsPanel({required this.backend, super.key});

  final StorageBackend backend;

  @override
  State<LightsPanel> createState() => _LightsPanelState();
}

class _LightsPanelState extends State<LightsPanel> {
  StreamSubscription<List<Map<String, Object?>>>? _viewSub;
  Map<String, _LightState> _state = const <String, _LightState>{};

  @override
  void initState() {
    super.initState();
    _viewSub = widget.backend.watchView(LightsMaterializer.viewKey).listen((
      rows,
    ) {
      if (!mounted) return;
      setState(() {
        _state = <String, _LightState>{
          for (final row in rows)
            row['color']! as String: _LightState(
              isOn: (row['is_on'] as bool?) ?? false,
              lastToggledAt: row['last_toggled_at'] as String?,
            ),
        };
      });
    });
  }

  @override
  void dispose() {
    _viewSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: DemoColors.bg, border: demoBorder),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text('LIGHTS', style: DemoText.header),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              _light('red', DemoColors.red),
              _light('green', DemoColors.green),
              _light('blue', DemoColors.blue),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'press RED / GREEN / BLUE in the\n'
            'action bar to toggle the matching\n'
            'light. driven by watchView, not poll.',
            style: TextStyle(
              color: DemoColors.pending,
              fontFamily: DemoText.fontFamilyMonospace,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _light(String color, Color paint) {
    final s = _state[color];
    final isOn = s?.isOn ?? false;
    // Off: dimmed to ~15% alpha so the color identity stays visible but
    // the light reads as inactive. On: full brightness with a yellow
    // outline matching the panel's selection cue (DemoColors.selectedOutline).
    final fill = isOn ? paint : paint.withAlpha(38);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: fill,
            border: Border.all(
              color: isOn ? DemoColors.selectedOutline : DemoColors.border,
              width: 3,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          color,
          style: const TextStyle(
            color: DemoColors.fg,
            fontFamily: DemoText.fontFamilyMonospace,
            fontSize: 12,
          ),
        ),
        Text(
          isOn ? 'on' : 'off',
          style: TextStyle(
            color: isOn ? DemoColors.sent : DemoColors.pending,
            fontFamily: DemoText.fontFamilyMonospace,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _LightState {
  const _LightState({required this.isOn, required this.lastToggledAt});
  final bool isOn;
  final String? lastToggledAt;
}
