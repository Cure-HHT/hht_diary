// Verifies: DIARY-DEV-native-outbound-sync/A — drain triggers route into the
//   outbound SyncCycle: app-resume + connectivity-restored fire onTrigger, and
//   the periodic timer is cancellable via dispose. The post-action-submit drain
//   is exercised by the round-trip test (the bootstrap's syncCycleTrigger).

import 'dart:async';

import 'package:clinical_diary/scope/diary_sync_triggers.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// A fake lifecycle observer whose [didChangeAppLifecycleState] the test drives.
class _FakeLifecycle extends WidgetsBindingObserver {
  _FakeLifecycle(this.onResumed, this.onForegroundChange);
  final VoidCallback onResumed;
  final ValueChanged<bool> onForegroundChange;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final fg = state == AppLifecycleState.resumed;
    onForegroundChange(fg);
    if (fg) onResumed();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('app-resume fires a drain', () async {
    var drains = 0;
    late VoidCallback resume;
    final handles = await installDiarySyncTriggers(
      onTrigger: () async => drains++,
      lifecycleObserverFactory: (onResumed, onFg) {
        resume = onResumed;
        return _FakeLifecycle(onResumed, onFg);
      },
      periodicTimerFactory: (_, _) => Timer(const Duration(days: 1), () {}),
      connectivityStreamFactory: () => const Stream.empty(),
    );

    resume();
    await Future<void>.delayed(Duration.zero);
    expect(drains, 1);

    await handles.dispose();
  });

  test('connectivity no-connectivity -> connected fires a drain', () async {
    var drains = 0;
    final controller = StreamController<List<ConnectivityResult>>();
    final handles = await installDiarySyncTriggers(
      onTrigger: () async => drains++,
      lifecycleObserverFactory: _FakeLifecycle.new,
      periodicTimerFactory: (_, _) => Timer(const Duration(days: 1), () {}),
      connectivityStreamFactory: () => controller.stream,
    );

    controller.add([ConnectivityResult.none]);
    await Future<void>.delayed(Duration.zero);
    expect(drains, 0, reason: 'no transition yet');

    controller.add([ConnectivityResult.wifi]);
    await Future<void>.delayed(Duration.zero);
    expect(drains, 1, reason: 'none -> connected transition');

    await controller.close();
    await handles.dispose();
  });

  test('periodic timer is cancelled on dispose', () async {
    var cancelled = false;
    Timer? installed;
    final handles = await installDiarySyncTriggers(
      onTrigger: () async {},
      lifecycleObserverFactory: _FakeLifecycle.new,
      periodicTimerFactory: (interval, onTick) {
        installed = Timer.periodic(interval, (_) => onTick());
        return installed!;
      },
      connectivityStreamFactory: () => const Stream.empty(),
    );

    expect(installed!.isActive, isTrue);
    await handles.dispose();
    cancelled = !installed!.isActive;
    expect(cancelled, isTrue, reason: 'dispose must cancel the periodic timer');
  });

  test('triggers do not fire after dispose', () async {
    var drains = 0;
    late VoidCallback resume;
    final handles = await installDiarySyncTriggers(
      onTrigger: () async => drains++,
      lifecycleObserverFactory: (onResumed, onFg) {
        resume = onResumed;
        return _FakeLifecycle(onResumed, onFg);
      },
      periodicTimerFactory: (_, _) => Timer(const Duration(days: 1), () {}),
      connectivityStreamFactory: () => const Stream.empty(),
    );

    await handles.dispose();
    resume();
    await Future<void>.delayed(Duration.zero);
    expect(drains, 0);
  });
}
