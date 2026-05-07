// IMPLEMENTS REQUIREMENTS:
//   REQ-d00172-A: Permission scope class enumeration. Closed set of three.

/// The session-context precondition a permission attaches to.
///
/// - [global]: no precondition; the principal's session state doesn't
///   restrict whether the permission may be exercised.
/// - [site]: the principal must have a non-null `activeSite`.
/// - [self]: the principal must be authenticated (non-null `userId`).
///
/// Adding a value here is a deliberate code-plus-REQ change.
enum ScopeClass { global, site, self }
