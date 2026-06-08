import 'package:comms/comms.dart';

/// One recorded [PushChannel.send] call.
class SentPush {
  SentPush(this.target, this.message);
  final PushTarget target;
  final PushMessage message;
}

/// In-memory [PushChannel] for tests. Records every send and returns a scripted
/// result. Set [nextResult] (or [resultForToken], keyed by the routing token)
/// to simulate success / failure / unregistered without touching a real
/// transport. Transport-neutral replacement for the old FakeFcmChannel.
class FakePushChannel implements PushChannel {
  FakePushChannel(
      {this.nextResult = const DispatchResult.success('fake-msg-id')});

  DispatchResult nextResult;
  final Map<String, DispatchResult> resultForToken = <String, DispatchResult>{};
  final List<SentPush> sent = <SentPush>[];

  /// When set, [send] THROWS this instead of returning a result — simulates
  /// transport faults (ADC/credential resolution, send timeout, socket errors)
  /// that surface as exceptions rather than a DispatchResult.
  Object? throwOnSend;

  @override
  String get name => 'fake-push';

  @override
  Future<DispatchResult> send(PushTarget target, PushMessage message) async {
    sent.add(SentPush(target, message));
    final err = throwOnSend;
    if (err != null) throw err;
    return resultForToken[target.routingToken] ?? nextResult;
  }
}
