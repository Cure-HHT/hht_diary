import 'dart:async';

import 'package:flutter/foundation.dart';

/// Drives the client-side inactivity soft-timer that MIRRORS the server's
/// authoritative idle window. The server stays the single enforcement point;
/// this controller is UX only — it shows the pre-timeout warning, throttles a
/// keep-alive on activity, and triggers the expiry path at the window's end.
///
/// Flutter-widget-free so it is unit-testable with `fake_async`.
// Implements: DIARY-PRD-session-management/I+K
// Implements: DIARY-GUI-portal-session-expiry/A+B
class SessionTimeoutController extends ChangeNotifier {
  SessionTimeoutController({
    required this.idleTimeout,
    required this.warningLead,
    required Future<void> Function() onKeepAlive,
    required Future<void> Function() onExpired,
    Duration keepAliveThrottle = const Duration(minutes: 1),
    Duration expiryGrace = const Duration(seconds: 2),
  }) : _onKeepAlive = onKeepAlive,
       _onExpired = onExpired,
       _keepAliveThrottle = keepAliveThrottle,
       _expiryGrace = expiryGrace;

  final Duration idleTimeout;
  final Duration warningLead;
  final Future<void> Function() _onKeepAlive;
  final Future<void> Function() _onExpired;
  final Duration _keepAliveThrottle;

  /// The client fires the expiry path [_expiryGrace] AFTER the nominal idle
  /// window so a proactive reconnect is guaranteed to cross the server's strict
  /// `> idleTimeout` check (otherwise an exactly-at-boundary reconnect could
  /// re-auth successfully and silently keep the user signed in).
  final Duration _expiryGrace;

  Timer? _warningTimer;
  Timer? _expiryTimer;
  Timer? _countdownTimer;
  DateTime? _lastKeepAlive;
  bool _isWarning = false;
  int _secondsLeft = 0;

  bool get isWarning => _isWarning;
  int get secondsLeft => _secondsLeft;

  /// Warn [warningLead] before idle, or at the halfway point when the idle
  /// window is too short to fit the lead (legacy parity).
  Duration get _warningDelay =>
      idleTimeout > warningLead ? idleTimeout - warningLead : idleTimeout ~/ 2;

  /// Begin tracking; schedules the first warning + expiry from now.
  void start() => _reschedule();

  /// Tracked UI activity. Passive activity is ignored once the warning is shown
  /// — only [staySignedIn] extends from there.
  ///
  /// The timer reset is COUPLED to the throttled keep-alive: both happen at most
  /// once per [_keepAliveThrottle]. This (a) avoids cancelling/recreating timers
  /// on every high-frequency pointer/hover/key event, and (b) keeps the client
  /// soft-timer in lockstep with the server's last-seen — which only advances on
  /// a keep-alive — so the client never believes it has more time than the
  /// server grants.
  // Implements: DIARY-GUI-portal-session-expiry/B
  void notifyActivity({DateTime Function() now = DateTime.now}) {
    if (_isWarning) return;
    final t = now();
    if (_lastKeepAlive != null &&
        t.difference(_lastKeepAlive!) < _keepAliveThrottle) {
      return; // within the throttle window — neither touch nor reschedule
    }
    _lastKeepAlive = t;
    _reschedule();
    unawaited(_onKeepAlive());
  }

  /// "Stay signed in" — always extends: immediate keep-alive + full reset.
  // Implements: DIARY-PRD-session-management/K
  void staySignedIn({DateTime Function() now = DateTime.now}) {
    _lastKeepAlive = now();
    unawaited(_onKeepAlive());
    _reschedule();
  }

  /// Stops tracking and clears any active warning (e.g. on logout). Idempotent.
  /// Notifies so a shown warning dialog is reactively dismissed.
  void cancel() {
    _cancelTimers();
    if (_isWarning) {
      _isWarning = false;
      notifyListeners();
    }
  }

  void _reschedule() {
    _cancelTimers();
    if (_isWarning) {
      _isWarning = false;
      notifyListeners();
    }
    _warningTimer = Timer(_warningDelay, _onWarning);
    _expiryTimer = Timer(idleTimeout + _expiryGrace, _onExpiry);
  }

  void _onWarning() {
    _isWarning = true;
    // Counts the nominal warning window only (warningLead); it reaches 0 up to
    // _expiryGrace before _onExpiry fires — the grace is server-timing slack,
    // intentionally not reflected in the countdown.
    _secondsLeft = (idleTimeout - _warningDelay).inSeconds;
    notifyListeners();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft > 0) {
        _secondsLeft--;
        notifyListeners();
      }
      if (_secondsLeft == 0) timer.cancel();
    });
  }

  void _onExpiry() {
    _cancelTimers();
    _isWarning = false;
    notifyListeners();
    unawaited(_onExpired());
  }

  void _cancelTimers() {
    _warningTimer?.cancel();
    _expiryTimer?.cancel();
    _countdownTimer?.cancel();
  }

  @override
  void dispose() {
    _cancelTimers();
    super.dispose();
  }
}
