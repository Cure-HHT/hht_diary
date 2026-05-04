/// External callback invoked by the lib before every materialization fold.
/// See REQ-d00140-G+H.
///
/// The lib calls this with the event's authoring `entryTypeVersion` as
/// [fromVersion] and the view's stored target version (per
/// `view_target_versions`) as [toVersion], regardless of whether they're
/// equal. The returned map is passed to the materializer as `promotedData`.
///
/// The lib treats this function as opaque: it does not compose chains,
/// inspect the result, or interpret [fromVersion]/[toVersion] direction.
/// A thrown exception propagates through the materialization pipeline and
/// rolls back the transaction (per REQ-d00140-E+H).
///
/// Promoters MUST return a new map and MUST NOT mutate [data] in place.
/// The lib does not defend against in-place mutation; a mutating promoter
/// would corrupt the in-memory `StoredEvent` that subsequent materializers
/// receive.
// Implements: REQ-d00140-G.
typedef EntryPromoter =
    Map<String, Object?> Function({
      required String entryType,
      required int fromVersion,
      required int toVersion,
      required Map<String, Object?> data,
    });

/// Identity promoter — returns [data] unchanged. Useful for tests and for
/// materializers whose registered targets always equal authoring versions.
// Implements: REQ-d00140-G — identity helper.
Map<String, Object?> identityPromoter({
  required String entryType,
  required int fromVersion,
  required int toVersion,
  required Map<String, Object?> data,
}) => data;
