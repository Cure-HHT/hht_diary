import 'package:flutter/material.dart';
import 'package:reaction/reaction.dart';

/// Wraps [child] and renders a non-dismissible banner above it whenever the
/// reactive transport is not [Connected].
///
/// The reaction client already keeps the last-received rows on screen (the
/// `ViewBuilder` `Stale` state) while reconnecting; this banner is the missing
/// user-visible signal that the data shown reflects the last successful update
/// rather than a live feed. It self-clears when the transport returns to
/// [Connected] (the client's auto-reconnect having re-replayed a fresh
/// snapshot). Modeled on the rave-sync paused banner.
// Implements: DIARY-GUI-portal-transport-status/A+B
class ConnectionStatusBanner extends StatelessWidget {
  const ConnectionStatusBanner({
    super.key,
    required this.statusStream,
    required this.child,
    this.initial = const Connected(),
  });

  /// Transport-status transitions, typically `ReActionScope.of(context)
  /// .connectionStatusStream`.
  final Stream<ConnectionStatus> statusStream;

  /// Content rendered below the banner (the screen body).
  final Widget child;

  /// Status to assume before the first stream event — typically the scope's
  /// current `connectionStatus`.
  final ConnectionStatus initial;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ConnectionStatus>(
      stream: statusStream,
      initialData: initial,
      builder: (context, snapshot) {
        final status = snapshot.data ?? const Connected();
        final degraded = status is! Connected;
        return Column(
          children: <Widget>[
            if (degraded) _banner(context, status),
            Expanded(child: child),
          ],
        );
      },
    );
  }

  Widget _banner(BuildContext context, ConnectionStatus status) {
    final scheme = Theme.of(context).colorScheme;
    final message = status is Disconnected
        ? 'Disconnected — retrying. Showing the last data received.'
        : 'Reconnecting… Showing the last data received.';
    return Semantics(
      identifier: 'connection-status-banner',
      liveRegion: true,
      child: Material(
        color: scheme.errorContainer,
        child: Padding(
          key: const Key('connection-status-banner'),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: <Widget>[
              Icon(Icons.cloud_off, size: 18, color: scheme.onErrorContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(color: scheme.onErrorContainer),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
