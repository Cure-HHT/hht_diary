/// Mirrors the server-side `mobile_linking_status` enum
/// (see `database/schema.sql` lines 168-174).
///
/// Used to drive UI branches that need to distinguish a "fully disconnected"
/// participant from one whose study coordinator has just issued a new linking code
/// (REQ-p70011/F).
enum MobileLinkingStatus {
  notConnected,
  linkingInProgress,
  connected,
  disconnected,
  notParticipating,
}

// Implements: REQ-p70011/F
MobileLinkingStatus parseMobileLinkingStatus(String? raw) {
  switch (raw) {
    case 'connected':
      return MobileLinkingStatus.connected;
    case 'linking_in_progress':
      return MobileLinkingStatus.linkingInProgress;
    case 'disconnected':
      return MobileLinkingStatus.disconnected;
    case 'not_participating':
      return MobileLinkingStatus.notParticipating;
    case 'not_connected':
    case null:
    default:
      return MobileLinkingStatus.notConnected;
  }
}
