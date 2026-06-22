// Implements: DIARY-DEV-native-outbound-sync/C
//
// The native clinical outbound destination ships only entries at or after a
// start watermark. The watermark must be the LATER of Trial Start and the
// device link time.

/// The effective start watermark for the native clinical outbound destination:
/// the later of [trialStartedAt] and [linkedAt].
///
/// Flooring at the link time keeps **pre-link** clinical entries local. Before
/// the device links, day-markers are keyed by the device-local identity (e.g.
/// `<deviceUuid>:<date>`), not the participantId. Such an aggregate id can never
/// satisfy the ingest edge's `{participantId}:` ownership check, so enqueuing it
/// for the portal yields a permanent 403 that wedges the outbound FIFO and halts
/// all sync. Trial Start can precede the link (a coordinator may Start Trial
/// before the participant links their device), so [trialStartedAt] alone is not
/// a safe floor — without the link floor, an entry recorded after Trial Start
/// but before the link would pass the watermark and wedge.
///
/// [linkedAt] is the moment the device adopted the participant identity (the
/// `participant_linked` event timestamp); null when it cannot be determined, in
/// which case the watermark falls back to [trialStartedAt].
DateTime effectiveClinicalStartWatermark({
  required DateTime trialStartedAt,
  DateTime? linkedAt,
}) {
  if (linkedAt != null && linkedAt.isAfter(trialStartedAt)) return linkedAt;
  return trialStartedAt;
}
