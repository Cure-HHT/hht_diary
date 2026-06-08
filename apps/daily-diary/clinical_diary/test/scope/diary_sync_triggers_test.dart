// Verifies: DIARY-DEV-native-outbound-sync/A — drain triggers route into the
//   outbound SyncCycle: app-resume + connectivity-restored fire onTrigger, and
//   the periodic timer is cancellable via dispose. The post-action-submit drain
//   is exercised by the round-trip test (the bootstrap's syncCycleTrigger).

import 'dart:async';

import 'package:clinical_diary/scope/diary_sync_triggers.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
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

  test('FCM onMessage fires a drain and records the receipt', () async {
    var drains = 0;
    final receipts = <RemoteMessage>[];
    final fcmMessageController = StreamController<RemoteMessage>();
    final handles = await installDiarySyncTriggers(
      onTrigger: () async => drains++,
      onFcmReceipt: (message) async => receipts.add(message),
      lifecycleObserverFactory: _FakeLifecycle.new,
      periodicTimerFactory: (_, _) => Timer(const Duration(days: 1), () {}),
      connectivityStreamFactory: () => const Stream.empty(),
      fcmOnMessageStreamFactory: () => fcmMessageController.stream,
      fcmOnOpenedStreamFactory: () => const Stream.empty(),
    );

    fcmMessageController.add(
      const RemoteMessage(
        data: {'type': 'questionnaire_assigned', 'flowToken': 'QST000001'},
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(drains, 1, reason: 'FCM message must fire the EVS sync drain');
    expect(receipts, hasLength(1), reason: 'onFcmReceipt must be invoked');
    expect(receipts.single.data['type'], 'questionnaire_assigned');
    expect(receipts.single.data['flowToken'], 'QST000001');

    await fcmMessageController.close();
    await handles.dispose();
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
