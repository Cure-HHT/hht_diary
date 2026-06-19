/// Server-authoritative email-format rule for staff user accounts:
/// one non-whitespace local part, an @, and a dotted domain.
///
/// Deliberately mirrored (not imported) by the portal UI's form/login
/// gate in `portal_screens` — the packages sit on opposite sides of the
/// trust boundary with no shared pure-Dart ancestor, and the server
/// must enforce the rule regardless of what any client does.
// Implements: DIARY-PRD-user-account-edit/D — email validity is enforced
//   at the action boundary, not only in client forms.
final RegExp _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

bool isValidAccountEmail(String email) => _emailRe.hasMatch(email.trim());
