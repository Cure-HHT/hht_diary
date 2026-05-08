// IMPLEMENTS REQUIREMENTS:
//   REQ-d00166-A+B+C+D+E+F — Action interface contract.
//   REQ-d00170 (Idempotency Contract) — Idempotency.none policy.

import 'package:event_sourcing/event_sourcing.dart';
import 'package:meta/meta.dart';
import 'package:uuid/uuid.dart';

@immutable
class HelpInput {
  const HelpInput({required this.message});
  final String message;
}

@immutable
class HelpResult {
  const HelpResult({required this.helpTicketId});
  final String helpTicketId;

  Map<String, Object?> toJson() => <String, Object?>{
    'helpTicketId': helpTicketId,
  };
}

class RequestHelpAction extends Action<HelpInput, HelpResult> {
  RequestHelpAction({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  @override
  String get name => 'RequestHelpAction';

  @override
  String get description =>
      'Anyone (including anonymous callers) requests help; emits one '
      'help_request event on a fresh help_ticket aggregate.';

  @override
  Set<Permission> get permissions => <Permission>{
    const Permission('help.ask', scope: ScopeClass.global),
  };

  @override
  Idempotency get idempotency => Idempotency.none;

  @override
  HelpInput parseInput(Map<String, Object?> raw) {
    final message = raw['message'];
    if (message is! String) {
      throw const FormatException(
        'RequestHelpAction expects "message": String',
      );
    }
    return HelpInput(message: message);
  }

  @override
  void validate(HelpInput input) {
    if (input.message.trim().isEmpty) {
      throw ArgumentError.value(input.message, 'message', 'must be non-empty');
    }
  }

  @override
  Future<ExecutionResult<HelpResult>> execute(
    HelpInput input,
    ActionContext ctx,
  ) async {
    final ticketId = _uuid.v4();
    return ExecutionResult<HelpResult>(
      result: HelpResult(helpTicketId: ticketId),
      events: <EventDraft>[
        EventDraft(
          aggregateType: 'help_ticket',
          aggregateId: ticketId,
          entryType: 'help_request',
          eventType: 'help_request',
          data: <String, dynamic>{'message': input.message},
        ),
      ],
    );
  }
}
