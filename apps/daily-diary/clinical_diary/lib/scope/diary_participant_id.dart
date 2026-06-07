// Implements: DIARY-DEV-shared-events-catalog/A
//   The diary's enrolled-participant id, read from the reactive scope's
//   AuthSession. This is the SAME value the diary actions stamp into the event
//   stream (e.g. `dayAggregateId(principal.userId, ...)` in the day-marker
//   action), so reading it here at a write site keeps the payload's
//   `participantId` in lock-step with the aggregate identity.
import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter/widgets.dart';
import 'package:reaction_widgets/reaction_widgets.dart';

/// Reads the enrolled participant id from the reactive scope in [context].
///
/// Returns the active [UserPrincipal.userId] when the participant is
/// authenticated. Pre-enrollment the diary scope still carries a stable local
/// principal (`pre-enrollment`), so this matches the id the actions use for the
/// aggregate identity — recording is never gated on enrollment.
String diaryParticipantId(BuildContext context) {
  final principal = ReActionScope.of(context).authSession.principal;
  if (principal is UserPrincipal) {
    return principal.userId;
  }
  // The local diary scope always resolves a UserPrincipal (enrolled id or the
  // `pre-enrollment` placeholder). A missing/anonymous principal here means the
  // scope is misconfigured; fail loudly rather than silently writing an
  // unattributed entry.
  throw StateError(
    'recording a diary entry requires an identified participant principal',
  );
}
