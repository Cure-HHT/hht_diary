// IMPLEMENTS REQUIREMENTS:
//   REQ-d00166-A+B+C+D+E+F — Action interface contract.
//   REQ-d00170 (Idempotency Contract) — Idempotency.none policy.
//   REQ-d00172 — site-scoped permission (ScopeClass.site).

import 'package:event_sourcing/event_sourcing.dart';
import 'package:meta/meta.dart';
import 'package:uuid/uuid.dart';

@immutable
class PressBlueInput {
  const PressBlueInput();
}

@immutable
class PressBlueResult {
  const PressBlueResult({required this.eventId});

  final String eventId;

  Map<String, Object?> toJson() => <String, Object?>{'eventId': eventId};
}

class PressBlueButtonAction extends Action<PressBlueInput, PressBlueResult> {
  PressBlueButtonAction({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  @override
  String get name => 'PressBlueButtonAction';

  @override
  String get description =>
      'BlueTeam presses the blue button. Site-scoped; '
      'no idempotency (every press is a fresh event).';

  @override
  Set<Permission> get permissions => <Permission>{
    const Permission('buttons.press.blue', scope: ScopeClass.site),
  };

  @override
  Idempotency get idempotency => Idempotency.none;

  @override
  PressBlueInput parseInput(Map<String, Object?> raw) => const PressBlueInput();

  @override
  void validate(PressBlueInput input) {
    // no-op: PressBlueInput has no fields to validate.
  }

  @override
  Future<ExecutionResult<PressBlueResult>> execute(
    PressBlueInput input,
    ActionContext ctx,
  ) async {
    final id = _uuid.v4();
    return ExecutionResult<PressBlueResult>(
      result: PressBlueResult(eventId: id),
      events: <EventDraft>[
        EventDraft(
          aggregateType: 'blue_button_press',
          aggregateId: id,
          entryType: 'blue_button_press',
          eventType: 'blue_button_pressed',
          data: const <String, dynamic>{},
        ),
      ],
    );
  }
}
