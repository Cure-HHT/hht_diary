// Drain triggers for the new-stack native outbound sync (I2a).
//
// The post-action-submit drain is already wired through `bootstrapEventStore`'s
// `syncCycleTrigger` (fire-and-forget after every append). This installer adds
// the remaining foreground trigger sources, mirroring the legacy
// `installTriggers`:
//
//   - app-resume      (WidgetsBindingObserver -> AppLifecycleState.resumed)
//   - connectivity    (no-connectivity -> connected transition)
//   - periodic timer  (foreground only)
//
// Each trigger routes into the same [onTrigger] callback (typically
// `DiaryScopeRuntime.syncCycle.call`). Triggers are serialized so overlapping
// events queue rather than running concurrent cycles.

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';

// ---------------------------------------------------------------------------
// Test-seam typedefs (not part of the public API).
// ---------------------------------------------------------------------------

/// Creates a [WidgetsBindingObserver] that calls [onResumed] when the lifecycle
/// transitions to [AppLifecycleState.resumed] and calls [onForegroundChange]
/// with the new foreground-ness on every lifecycle change.
@visibleForTesting
typedef DiaryLifecycleObserverFactory =
    WidgetsBindingObserver Function(
      VoidCallback onResumed,
      ValueChanged<bool> onForegroundChange,
    );

/// Creates a [Timer.periodic]-style timer.
@visibleForTesting
typedef DiaryPeriodicTimerFactory =
    Timer Function(Duration interval, VoidCallback onTick);

/// Returns the stream of connectivity-change events.
@visibleForTesting
typedef DiaryConnectivityStreamFactory =
    Stream<List<ConnectivityResult>> Function();

// ---------------------------------------------------------------------------
// Production defaults
// ---------------------------------------------------------------------------

WidgetsBindingObserver _defaultLifecycleObserverFactory(
  VoidCallback onResumed,
  ValueChanged<bool> onForegroundChange,
) => _DiaryLifecycleObserver(
  onResumed: onResumed,
  onForegroundChange: onForegroundChange,
);

Timer _defaultPeriodicTimerFactory(Duration interval, VoidCallback onTick) =>
    Timer.periodic(interval, (_) => onTick());

Stream<List<ConnectivityResult>> _defaultConnectivityStream() =>
    Connectivity().onConnectivityChanged;

// ---------------------------------------------------------------------------
// Public surface
// ---------------------------------------------------------------------------

/// Handle returned by [installDiarySyncTriggers]. Call [dispose] to cancel
/// every subscription, timer, and lifecycle observer that was installed.
class DiarySyncTriggerHandles {
  /// Creates a [DiarySyncTriggerHandles] with the given [dispose] callback.
  DiarySyncTriggerHandles({required Future<void> Function() dispose})
    : _dispose = dispose;

  final Future<void> Function() _dispose;

  /// Cancels all installed triggers. Safe to call multiple times.
  Future<void> dispose() => _dispose();
}

/// Installs the foreground drain triggers for the new-stack outbound sync.
///
/// [onTrigger] is awaited serially — overlapping trigger events queue rather
/// than running concurrent cycles. Returns a [DiarySyncTriggerHandles] whose
/// [DiarySyncTriggerHandles.dispose] cancels every source.
Future<DiarySyncTriggerHandles> installDiarySyncTriggers({
  required Future<void> Function() onTrigger,
  Duration periodicInterval = const Duration(minutes: 15),
  // --- test seams (use production defaults when omitted) ---
  DiaryLifecycleObserverFactory? lifecycleObserverFactory,
  DiaryPeriodicTimerFactory? periodicTimerFactory,
  DiaryConnectivityStreamFactory? connectivityStreamFactory,
}) async {
  final resolvedLifecycleFactory =
      lifecycleObserverFactory ?? _defaultLifecycleObserverFactory;
  final resolvedTimerFactory =
      periodicTimerFactory ?? _defaultPeriodicTimerFactory;
  final resolvedConnectivityStream =
      connectivityStreamFactory ?? _defaultConnectivityStream;

  // Serial trigger guard: each fireTrigger() call is enqueued and runs in order.
  var chain = Future<void>.value();
  var disposed = false;

  void fireTrigger() {
    if (disposed) return;
    chain = chain
        .then((_) async {
          if (disposed) return;
          await onTrigger();
        })
        .catchError((Object e, StackTrace st) {
          debugPrint('[DiarySyncTriggers] onTrigger failed: $e\n$st');
        });
  }

  // Track foreground state (starts true; the observer will update it).
  var inForeground = true;

  // ---- A. Lifecycle observer ----
  final observer = resolvedLifecycleFactory(fireTrigger, (bool isInForeground) {
    inForeground = isInForeground;
  });
  WidgetsBinding.instance.addObserver(observer);

  // ---- B. Periodic timer (foreground only) ----
  final timer = resolvedTimerFactory(periodicInterval, () {
    if (inForeground) {
      fireTrigger();
    }
  });

  // ---- C. Connectivity (no-connectivity -> connected transition) ----
  List<ConnectivityResult>? previousConnectivity;
  final connectivitySub = resolvedConnectivityStream().listen((results) {
    final wasNone =
        previousConnectivity == null ||
        previousConnectivity!.every((r) => r == ConnectivityResult.none);
    final isNone = results.every((r) => r == ConnectivityResult.none);
    if (wasNone && !isNone) {
      fireTrigger();
    }
    previousConnectivity = results;
  });

  Future<void> doDispose() async {
    disposed = true;
    WidgetsBinding.instance.removeObserver(observer);
    timer.cancel();
    await connectivitySub.cancel();
  }

  return DiarySyncTriggerHandles(dispose: doDispose);
}

// ---------------------------------------------------------------------------
// Internal lifecycle observer
// ---------------------------------------------------------------------------

class _DiaryLifecycleObserver extends WidgetsBindingObserver {
  _DiaryLifecycleObserver({
    required this.onResumed,
    required this.onForegroundChange,
  });

  final VoidCallback onResumed;
  final ValueChanged<bool> onForegroundChange;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final isInForeground = state == AppLifecycleState.resumed;
    onForegroundChange(isInForeground);
    if (state == AppLifecycleState.resumed) {
      onResumed();
    }
  }
}
