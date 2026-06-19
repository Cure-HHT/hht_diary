import 'dart:async';

import 'package:flutter/material.dart';
import 'package:reaction/reaction.dart';

/// Wraps [child] and renders a non-dismissible banner above it whenever the
/// reactive transport has DROPPED after having been connected.
///
/// The reaction client already keeps the last-received rows on screen (the
/// `ViewBuilder` `Stale` state) while reconnecting; this banner is the missing
/// user-visible signal that the data shown reflects the last successful update
/// rather than a live feed. It self-clears when the transport returns to
/// [Connected]. Modeled on the rave-sync paused banner.
///
/// The banner is suppressed until the transport has connected at least once:
/// `RemoteConnection` starts in [Disconnected] before its first WS open, and on
/// initial load there is no "last data received" yet — showing the banner then
/// would be both visually noisy and factually wrong. Once connected, a later
/// drop ([Reconnecting]/[Disconnected]) surfaces the banner.
// Implements: DIARY-BASE-portal-transport-status/A+B
class ConnectionStatusBanner extends StatefulWidget {
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
  State<ConnectionStatusBanner> createState() => _ConnectionStatusBannerState();
}

class _ConnectionStatusBannerState extends State<ConnectionStatusBanner> {
  late ConnectionStatus _status;

  /// Whether the transport has been [Connected] at least once. The banner stays
  /// hidden until then, so a fresh load's pre-connect [Disconnected] does not
  /// render a (wrong) "showing last data received" banner.
  bool _everConnected = false;

  StreamSubscription<ConnectionStatus>? _sub;

  @override
  void initState() {
    super.initState();
    _status = widget.initial;
    _everConnected = widget.initial is Connected;
    _sub = widget.statusStream.listen(_onStatus);
  }

  @override
  void didUpdateWidget(ConnectionStatusBanner old) {
    super.didUpdateWidget(old);
    if (old.statusStream != widget.statusStream) {
      unawaited(_sub?.cancel());
      _sub = widget.statusStream.listen(_onStatus);
    }
  }

  void _onStatus(ConnectionStatus status) {
    if (!mounted) return;
    setState(() {
      _status = status;
      if (status is Connected) _everConnected = true;
    });
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final degraded = _everConnected && _status is! Connected;
    return Column(
      children: <Widget>[
        if (degraded) _banner(context, _status),
        Expanded(child: widget.child),
      ],
    );
  }

  Widget _banner(BuildContext context, ConnectionStatus status) {
    final scheme = Theme.of(context).colorScheme;
    final message = status is Disconnected
        ? 'Disconnected — retrying. Showing the last data received.'
        : 'Reconnecting… Showing the last data received.';
    return Semantics(
      key: const Key('connection-status-banner'),
      identifier: 'connection-status-banner',
      liveRegion: true,
      child: Material(
        color: scheme.errorContainer,
        child: Padding(
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
