// Implements: REQ-d00164-A+B+C+D+E — clinical_diary sync triggers.
//   Lifecycle resumed, periodic timer (foreground only), connectivity
//   restored, FCM onMessage and onMessageOpenedApp. No background isolate.

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';

// ---------------------------------------------------------------------------
// Test-seam typedefs
//
// These are NOT exported as part of the public API. They exist solely so
// integration / unit tests can inject controllable streams and a fake timer
// without touching real OS / Firebase / network stacks.
//
// Production code uses [_defaultLifecycleObserverFactory],
// [_defaultPeriodicTimerFactory], [_defaultConnectivityStream],
// [_defaultFcmOnMessageStream] and [_defaultFcmOnOpenedStream].
// ---------------------------------------------------------------------------

/// Creates a [WidgetsBindingObserver] that calls [onResumed] when the
/// lifecycle transitions to [AppLifecycleState.resumed] and calls
/// [onForegroundChange] with the new foreground-ness on every lifecycle
/// change.
@visibleForTesting
typedef LifecycleObserverFactory =
    WidgetsBindingObserver Function(
      VoidCallback onResumed,
      ValueChanged<bool> onForegroundChange,
    );

/// Creates a [Timer.periodic]-style timer.  Receives the interval and a
/// zero-argument callback (not the [Timer] instance, for simplicity).
@visibleForTesting
typedef PeriodicTimerFactory =
    Timer Function(Duration interval, VoidCallback onTick);

/// Returns the stream of connectivity-change events.
@visibleForTesting
typedef ConnectivityStreamFactory = Stream<List<ConnectivityResult>> Function();

/// Returns the stream of foreground FCM messages.
@visibleForTesting
typedef FcmOnMessageStreamFactory = Stream<RemoteMessage> Function();

/// Returns the stream of FCM messages that opened the app from background.
@visibleForTesting
typedef FcmOnOpenedStreamFactory = Stream<RemoteMessage> Function();

// ---------------------------------------------------------------------------
// Production defaults
// ---------------------------------------------------------------------------

WidgetsBindingObserver _defaultLifecycleObserverFactory(
  VoidCallback onResumed,
  ValueChanged<bool> onForegroundChange,
) => _LifecycleObserver(
  onResumed: onResumed,
  onForegroundChange: onForegroundChange,
);

Timer _defaultPeriodicTimerFactory(Duration interval, VoidCallback onTick) =>
    Timer.periodic(interval, (_) => onTick());

Stream<List<ConnectivityResult>> _defaultConnectivityStream() =>
    Connectivity().onConnectivityChanged;

Stream<RemoteMessage> _defaultFcmOnMessageStream() =>
    FirebaseMessaging.onMessage;

Stream<RemoteMessage> _defaultFcmOnOpenedStream() =>
    FirebaseMessaging.onMessageOpenedApp;

// ---------------------------------------------------------------------------
// Public surface
// ---------------------------------------------------------------------------

/// Handle returned by [installTriggers]. Call [dispose] to cancel every
/// subscription, timer, and lifecycle observer that was installed.
class TriggerHandles {
  /// Creates a [TriggerHandles] with the given [dispose] callback. The
  /// optional [noteActivity] hook is supplied by adaptive-mode installs;
  /// fixed-interval installs leave it null and [TriggerHandles.noteActivity]
  /// becomes a no-op.
  TriggerHandles({
    required Future<void> Function() dispose,
    void Function()? noteActivity,
  }) : _dispose = dispose,
       _noteActivity = noteActivity;

  final Future<void> Function() _dispose;
  final void Function()? _noteActivity;

  /// Cancels all installed triggers. Safe to call multiple times.
  Future<void> dispose() => _dispose();

  /// Records a user-activity event. In adaptive mode this resets the
  /// periodic timer's backoff to the 2s tier; in fixed-interval mode it
  /// is a no-op. Safe to call from any context (e.g. a root-level
  /// pointer-down listener).
  void noteActivity() => _noteActivity?.call();
}

/// Installs all foreground-only sync triggers for the clinical diary app.
///
/// The [onTrigger] callback is awaited serially — overlapping trigger events
/// queue rather than running concurrently, preventing simultaneous sync
/// cycles.
///
/// Trigger sources:
/// - **A. Lifecycle**: [AppLifecycleState.resumed] fires [onTrigger].
/// - **B. Periodic timer**: fires every [periodicInterval] while in foreground
///   (fixed-interval mode). When [adaptive] is true, the interval depends on
///   recency of activity reported via [TriggerHandles.noteActivity]: 2s for
///   the first 60s, 5s for the next 60s, 15min thereafter.
/// - **C. Connectivity**: fires when network transitions from no-connectivity
///   to any connected state.
/// - **D. FCM onMessage**: fires on every foreground FCM push message.
/// - **E. FCM onMessageOpenedApp**: fires when a notification tap opens the
///   app from background.
///
/// Returns a [TriggerHandles] whose [TriggerHandles.dispose] cancels all
/// sources. In adaptive mode [TriggerHandles.noteActivity] resets the
/// backoff to the 2s tier; in fixed-interval mode it is a no-op.
///
/// Optional parameters annotated `@visibleForTesting` allow tests to inject
/// controllable streams and a fake timer factory instead of the real OS /
/// Firebase stacks.
Future<TriggerHandles> installTriggers({
  required Future<void> Function() onTrigger,
  Duration periodicInterval = const Duration(minutes: 15),
  bool adaptive = false,
  // --- test seams (use production defaults when omitted) ---
  // The named parameters accept values typed by the @visibleForTesting
  // typedefs above; the parameters themselves are not restricted so that
  // clinical_diary_bootstrap.dart can plumb them through from its own
  // @visibleForTesting overrides.
  LifecycleObserverFactory? lifecycleObserverFactory,
  PeriodicTimerFactory? periodicTimerFactory,
  ConnectivityStreamFactory? connectivityStreamFactory,
  FcmOnMessageStreamFactory? fcmOnMessageStreamFactory,
  FcmOnOpenedStreamFactory? fcmOnOpenedStreamFactory,
  DateTime Function()? clock,
}) async {
  final resolvedLifecycleFactory =
      lifecycleObserverFactory ?? _defaultLifecycleObserverFactory;
  final resolvedTimerFactory =
      periodicTimerFactory ?? _defaultPeriodicTimerFactory;
  final resolvedConnectivityStream =
      connectivityStreamFactory ?? _defaultConnectivityStream;
  final resolvedFcmOnMessage =
      fcmOnMessageStreamFactory ?? _defaultFcmOnMessageStream;
  final resolvedFcmOnOpened =
      fcmOnOpenedStreamFactory ?? _defaultFcmOnOpenedStream;

  // Serial trigger guard: each fireTrigger() call is enqueued and runs in
  // order.  This prevents concurrent sync cycles while ensuring every trigger
  // event results in exactly one onTrigger() invocation.
  var chain = Future<void>.value();
  var disposed = false;

  void fireTrigger() {
    if (disposed) return;
    // Errors inside onTrigger are absorbed via .catchError so a single
    // failure (e.g. a network exception bubbling out of syncCycle()) does
    // not poison the chain and silently disable every subsequent trigger
    // for the rest of the session.
    // ignore: prefer_final_locals
    chain = chain
        .then((_) async {
          if (disposed) return;
          await onTrigger();
        })
        .catchError((Object e, StackTrace st) {
          debugPrint('[Triggers] onTrigger failed: $e\n$st');
        });
  }

  // Track foreground state (starts true; the observer will update it).
  var inForeground = true;

  // ---- A. Lifecycle observer ----
  final observer = resolvedLifecycleFactory(
    // onResumed
    fireTrigger,
    // onForegroundChange
    (bool isInForeground) {
      inForeground = isInForeground;
    },
  );
  WidgetsBinding.instance.addObserver(observer);

  // ---- B. Periodic timer ----
  // Two modes:
  //   - Fixed interval (default, prod): Timer.periodic(periodicInterval).
  //     Matches REQ-d00164-B: 15min default cadence while in foreground.
  //   - Adaptive (F.adaptiveSync, non-prod flavors): self-rescheduling
  //     one-shot Timer whose interval is a pure function of time since
  //     last activity (set by TriggerHandles.noteActivity). 2s for the
  //     first 60s, 5s for the next 60s, 15min thereafter. Any activity
  //     event cancels the current Timer and immediately re-arms at 2s.
  Timer? periodicTimer;
  void Function()? noteActivityHook;

  if (adaptive) {
    final resolvedClock = clock ?? DateTime.now;
    var lastActivityAt = resolvedClock();

    Duration intervalFor(Duration since) {
      if (since < const Duration(minutes: 1)) {
        return const Duration(seconds: 2);
      }
      if (since < const Duration(minutes: 2)) {
        return const Duration(seconds: 5);
      }
      return const Duration(minutes: 15);
    }

    void scheduleNext() {
      if (disposed) return;
      final since = resolvedClock().difference(lastActivityAt);
      periodicTimer = Timer(intervalFor(since), () {
        if (disposed) return;
        if (inForeground) {
          fireTrigger();
        }
        scheduleNext();
      });
    }

    noteActivityHook = () {
      if (disposed) return;
      lastActivityAt = resolvedClock();
      periodicTimer?.cancel();
      scheduleNext();
    };

    scheduleNext();
  } else {
    periodicTimer = resolvedTimerFactory(periodicInterval, () {
      if (inForeground) {
        fireTrigger();
      }
    });
  }

  // ---- C. Connectivity ----
  List<ConnectivityResult>? previousConnectivity;

  final connectivitySub = resolvedConnectivityStream().listen((results) {
    final wasNone =
        previousConnectivity == null ||
        previousConnectivity!.every((r) => r == ConnectivityResult.none);
    final isNone = results.every((r) => r == ConnectivityResult.none);

    if (wasNone && !isNone) {
      // Transitioned from no-connectivity → connected.
      fireTrigger();
    }
    previousConnectivity = results;
  });

  // ---- D. FCM onMessage ----
  final fcmMessageSub = resolvedFcmOnMessage().listen((_) => fireTrigger());

  // ---- E. FCM onMessageOpenedApp ----
  final fcmOpenedSub = resolvedFcmOnOpened().listen((_) => fireTrigger());

  // ---- Dispose ----
  Future<void> doDispose() async {
    disposed = true;
    WidgetsBinding.instance.removeObserver(observer);
    periodicTimer?.cancel();
    await connectivitySub.cancel();
    await fcmMessageSub.cancel();
    await fcmOpenedSub.cancel();
  }

  return TriggerHandles(dispose: doDispose, noteActivity: noteActivityHook);
}

// ---------------------------------------------------------------------------
// Internal lifecycle observer
// ---------------------------------------------------------------------------

class _LifecycleObserver extends WidgetsBindingObserver {
  _LifecycleObserver({
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
