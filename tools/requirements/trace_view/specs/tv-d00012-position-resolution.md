# REQ-tv-d00012: Position Resolution

**Level**: Dev | **Status**: Draft | **Implements**: REQ-tv-p00002

## Assertions

A. The position resolution system SHALL resolve CommentPosition anchors to current document coordinates.

B. ResolvedPosition SHALL indicate confidence level: EXACT (hash matches), APPROXIMATE (fallback matched), or UNANCHORED (no match found).

C. When the document hash matches the position's `hashWhenCreated`, the position SHALL resolve with EXACT confidence using stored coordinates.

D. When the document hash differs, the system SHALL attempt fallback resolution using the `fallbackContext` field.

E. For LINE positions, fallback resolution SHALL search for the context string and return the matching line number.

F. For BLOCK positions, fallback resolution SHALL search for the context and expand to include the original block size.

G. For WORD positions, fallback resolution SHALL search for the keyword and return the Nth occurrence based on `keywordOccurrence`.

H. GENERAL positions SHALL always resolve with EXACT confidence since they apply to the entire requirement.

I. ResolvedPosition SHALL include a `resolutionPath` field describing which fallback strategy was used.

J. When no fallback succeeds, the position SHALL resolve as UNANCHORED with the original position preserved for manual re-anchoring.

## Rationale

Position resolution enables comments to "survive" requirement edits. When a requirement is modified, its content hash changes, invalidating stored positions. The fallback strategies attempt to find where the commented content moved to, maintaining the spatial relationship between comments and content.

The confidence levels allow the UI to display visual indicators (e.g., yellow warning for approximate, red for unanchored) so users know when manual review may be needed.

*End* *Position Resolution* | **Hash**: 00000000
