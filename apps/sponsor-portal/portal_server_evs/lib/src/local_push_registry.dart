// Implements: DIARY-DEV-pluggable-push-transport/C — the portal's
//   participant -> live-device-connection registry. The local-push WS handler
//   registers a sink per connected diary; LocalSocketPushChannel looks the
//   participant up here at send time to deliver a frame to the live device.

/// A sink that delivers one push frame to a single live device connection.
/// The WS handler supplies a closure that JSON-encodes [frame] onto its
/// WebSocket; tests supply a capturing closure.
typedef LocalPushSink = void Function(Map<String, dynamic> frame);

/// In-memory map of `participantId -> live diary connections`. A participant
/// may have more than one live device (e.g. a Linux client and a web tab), so
/// each id maps to a set of sinks. Purely in-process: the local transport is a
/// single-instance local-stack convenience, not a clustered production path.
class LocalPushRegistry {
  final Map<String, Set<LocalPushSink>> _byParticipant =
      <String, Set<LocalPushSink>>{};

  /// Registers [sink] as a live connection for [participantId]. Returns a
  /// disposer that removes exactly this registration (call it on WS close).
  void Function() register(String participantId, LocalPushSink sink) {
    _byParticipant
        .putIfAbsent(participantId, () => <LocalPushSink>{})
        .add(sink);
    return () => unregister(participantId, sink);
  }

  /// Removes [sink] for [participantId]; drops the participant entry when its
  /// last connection closes.
  void unregister(String participantId, LocalPushSink sink) {
    final sinks = _byParticipant[participantId];
    if (sinks == null) return;
    sinks.remove(sink);
    if (sinks.isEmpty) _byParticipant.remove(participantId);
  }

  /// True when [participantId] has at least one live connection.
  bool hasConnection(String participantId) =>
      _byParticipant[participantId]?.isNotEmpty ?? false;

  /// Delivers [frame] to every live connection of [participantId]. Returns the
  /// number of connections written to (0 when the participant has none).
  int deliver(String participantId, Map<String, dynamic> frame) {
    final sinks = _byParticipant[participantId];
    if (sinks == null || sinks.isEmpty) return 0;
    // Snapshot: a sink may unregister itself synchronously on a write error,
    // mutating the live set mid-iteration. Return the snapshot length so the
    // count reflects how many sinks were actually invoked, not the post-
    // delivery size of the live set.
    final snapshot = sinks.toList();
    for (final sink in snapshot) {
      sink(frame);
    }
    return snapshot.length;
  }
}
