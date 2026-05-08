// IMPLEMENTS REQUIREMENTS:
//   REQ-d00166-A+B+C+D+E+F — Action interface contract.
//   REQ-d00170 (Idempotency Contract) — Idempotency.none policy.
//   REQ-d00172 — site-scoped permission (ScopeClass.site).

import 'package:event_sourcing/event_sourcing.dart';
import 'package:meta/meta.dart';
import 'package:uuid/uuid.dart';

@immutable
class PressGreenInput {
  const PressGreenInput();
}

@immutable
class PressGreenResult {
  const PressGreenResult({required this.eventId});

  final String eventId;

  Map<String, Object?> toJson() => <String, Object?>{'eventId': eventId};
}

class PressGreenButtonAction extends Action<PressGreenInput, PressGreenResult> {
  PressGreenButtonAction({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  @override
  String get name => 'PressGreenButtonAction';

  @override
  String get description =>
      'GreenTeam presses the green button. Site-scoped; '
      'no idempotency (every press is a fresh event).';

  @override
  Set<Permission> get permissions => <Permission>{
    const Permission('buttons.press.green', scope: ScopeClass.site),
  };

  @override
  Idempotency get idempotency => Idempotency.none;

  @override
  PressGreenInput parseInput(Map<String, Object?> raw) =>
      const PressGreenInput();

  @override
  void validate(PressGreenInput input) {
    // no-op: PressGreenInput has no fields to validate.
  }

  @override
  Future<ExecutionResult<PressGreenResult>> execute(
    PressGreenInput input,
    ActionContext ctx,
  ) async {
    final id = _uuid.v4();
    return ExecutionResult<PressGreenResult>(
      result: PressGreenResult(eventId: id),
      events: <EventDraft>[
        EventDraft(
          aggregateType: 'green_button_press',
          aggregateId: id,
          entryType: 'green_button_press',
          eventType: 'green_button_pressed',
          data: const <String, dynamic>{},
        ),
      ],
    );
  }
}
