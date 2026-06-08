import 'package:comms/comms.dart';

/// In-memory `Channel<FcmMessage>` for tests. Records every dispatch and returns
/// a scripted result. Set [nextResult] (or [resultForToken]) to simulate
/// success / failure / unregistered tokens without touching FCM.
class FakeFcmChannel implements Channel<FcmMessage> {
  FakeFcmChannel(
      {this.nextResult = const DispatchResult.success('fake-msg-id')});

  DispatchResult nextResult;
  final Map<String, DispatchResult> resultForToken = <String, DispatchResult>{};
  final List<FcmMessage> sent = <FcmMessage>[];

  /// When set, [dispatch] THROWS this instead of returning a result —
  /// simulates transport faults (ADC/credential resolution, send timeout,
  /// socket errors) that surface as exceptions rather than DispatchResult.
  Object? throwOnDispatch;

  @override
  String get name => 'fake-fcm';

  @override
  Future<DispatchResult> dispatch(FcmMessage message) async {
    sent.add(message);
    final err = throwOnDispatch;
    if (err != null) throw err;
    return resultForToken[message.fcmToken] ?? nextResult;
  }
}
