/// Lexical-scope handle for an atomic write sequence inside a
/// `StorageBackend.transaction` body.
///
/// `Txn` is abstract; concrete backends subclass it with their own
/// transactional state (e.g., a Sembast `Transaction` for `SembastBackend`).
/// Callers never instantiate `Txn` directly — they receive it as the
/// argument to `transaction(body)` and MUST NOT use it after that body
/// returns or throws.
// Implements: REQ-d00117-B — Txn is valid only within the lexical scope of
// its defining transaction() body. Concrete backends are responsible for
// enforcing that constraint and raising an error if the handle escapes.
abstract class Txn {
  const Txn();
}
