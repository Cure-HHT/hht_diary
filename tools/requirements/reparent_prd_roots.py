#!/usr/bin/env python3
"""One-shot, idempotent re-parenting of the 40 PRD roots under the BASE apex.

CUR-1451 Phase 2: the URS-v1 spec tree had 40 PRD requirements with no parent.
This inserts a `**Refines**:` edge on each, laddering them under the new
`DIARY-BASE-*` apex/pillar/intermediate nodes. Additive only — it never edits
PRD prose, and it skips any block that already declares a `**Refines**:`.

Run from the repo root:  python3 tools/requirements/reparent_prd_roots.py
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
SPEC = REPO / "spec"

# Each current PRD root -> the single BASE node it should Refines:.
PARENT = {
    # mobile diary application
    "DIARY-PRD-mobile-application": "DIARY-BASE-mobile-diary-application",
    "DIARY-PRD-diary-start-day": "DIARY-BASE-mobile-diary-application",
    "DIARY-PRD-privacy-policy": "DIARY-BASE-mobile-diary-application",
    "DIARY-PRD-epistaxis-capture-standard": "DIARY-BASE-mobile-diary-application",
    "DIARY-PRD-entry-time-restrictions": "DIARY-BASE-mobile-diary-application",
    "DIARY-PRD-entry-duration-check": "DIARY-BASE-mobile-diary-application",
    "DIARY-PRD-entry-overlap-resolution": "DIARY-BASE-mobile-diary-application",
    # mobile notifications
    "DIARY-PRD-notification-disconnection": "DIARY-BASE-mobile-notifications",
    "DIARY-PRD-notification-incomplete-record-lock": "DIARY-BASE-mobile-notifications",
    "DIARY-PRD-notification-portal-sent-questionnaire": "DIARY-BASE-mobile-notifications",
    "DIARY-PRD-notification-yesterday-entry": "DIARY-BASE-mobile-notifications",
    "DIARY-PRD-notification-ongoing-epistaxis": "DIARY-BASE-mobile-notifications",
    "DIARY-PRD-notification-historical-gap": "DIARY-BASE-mobile-notifications",
    # sponsor portal
    "DIARY-PRD-user-account-create": "DIARY-BASE-sponsor-portal",
    "DIARY-PRD-administrator-settings": "DIARY-BASE-sponsor-portal",
    "DIARY-PRD-reason-field-constraints": "DIARY-BASE-sponsor-portal",
    # participant lifecycle
    "DIARY-PRD-linking-code-lifecycle": "DIARY-BASE-participant-lifecycle",
    "DIARY-PRD-participant-registration": "DIARY-BASE-participant-lifecycle",
    "DIARY-PRD-participant-link-new": "DIARY-BASE-participant-lifecycle",
    "DIARY-PRD-participant-disconnection": "DIARY-BASE-participant-lifecycle",
    "DIARY-PRD-participant-reconnection": "DIARY-BASE-participant-lifecycle",
    "DIARY-PRD-participant-mark-not-participating": "DIARY-BASE-participant-lifecycle",
    "DIARY-PRD-participant-reactivate": "DIARY-BASE-participant-lifecycle",
    "DIARY-PRD-linking-code-entry-errors": "DIARY-BASE-participant-lifecycle",
    # clinical questionnaires
    "DIARY-PRD-questionnaire-system": "DIARY-BASE-clinical-questionnaires",
    "DIARY-PRD-questionnaire-daily-epistaxis": "DIARY-BASE-clinical-questionnaires",
    "DIARY-PRD-questionnaire-nose-hht": "DIARY-BASE-clinical-questionnaires",
    "DIARY-PRD-questionnaire-hht-qol": "DIARY-BASE-clinical-questionnaires",
    "DIARY-PRD-questionnaire-portal-sent-rules": "DIARY-BASE-clinical-questionnaires",
    "DIARY-PRD-questionnaire-versioning": "DIARY-BASE-clinical-questionnaires",
    "DIARY-PRD-questionnaire-score-calculation": "DIARY-BASE-clinical-questionnaires",
    # access control and identity (under compliance)
    "DIARY-PRD-rbac-customizable": "DIARY-BASE-access-control-identity",
    "DIARY-PRD-user-authentication": "DIARY-BASE-access-control-identity",
    "DIARY-PRD-password-requirements": "DIARY-BASE-access-control-identity",
    "DIARY-PRD-two-factor-authentication": "DIARY-BASE-access-control-identity",
    "DIARY-PRD-password-forgot": "DIARY-BASE-access-control-identity",
    "DIARY-PRD-session-management": "DIARY-BASE-access-control-identity",
    # compliance and data integrity (direct)
    "DIARY-PRD-evidence-timestamp-attestation": "DIARY-BASE-compliance-data-integrity",
    "DIARY-PRD-system-validation-traceability": "DIARY-BASE-compliance-data-integrity",
    "DIARY-PRD-sla-disaster-recovery": "DIARY-BASE-compliance-data-integrity",
    "DIARY-PRD-platform-operations-monitoring": "DIARY-BASE-compliance-data-integrity",
    # participant-facing help
    "DIARY-PRD-help-resources": "DIARY-BASE-mobile-diary-application",
    # NOTE: DIARY-PRD-configuration-precedence and DIARY-PRD-notification-behavior
    # are intentionally NOT re-parented here. The migration mapping marks both as
    # cross-cutting *templates*; they will be flagged **Template** (and satisfied
    # by their instances) in the templates pass. Templates cannot be Refined into
    # or carry an outbound Refines, so they remain structural roots by design.
}

HEAD = re.compile(r"^#{1,3}\s+(DIARY-PRD-[a-z0-9-]+)\s*:")
META = re.compile(r"^\*\*Level\*\*:")
NEXT_HEAD = re.compile(r"^#{1,3}\s+DIARY-")
REFINES = re.compile(r"^\*\*Refines\*\*:")


def main() -> int:
    remaining = dict(PARENT)
    changed = 0
    skipped = 0
    for md in SPEC.glob("*.md"):
        lines = md.read_text(encoding="utf-8").splitlines(keepends=True)
        out: list[str] = []
        i = 0
        n = len(lines)
        file_dirty = False
        while i < n:
            line = lines[i]
            m = HEAD.match(line)
            if not m or m.group(1) not in remaining:
                out.append(line)
                i += 1
                continue
            req_id = m.group(1)
            parent = remaining[req_id]
            # Scan this block for an existing Refines and the metadata line.
            j = i + 1
            meta_idx = None
            has_refines = False
            while j < n and not NEXT_HEAD.match(lines[j]):
                if META.match(lines[j]):
                    meta_idx = j
                if REFINES.match(lines[j]):
                    has_refines = True
                j += 1
            # Emit the block, inserting Refines after the metadata line.
            for k in range(i, j):
                out.append(lines[k])
                if k == meta_idx and not has_refines:
                    out.append(f"**Refines**: {parent}\n")
            if has_refines:
                skipped += 1
            elif meta_idx is None:
                print(f"  WARN no **Level** line for {req_id} in {md.name}")
            else:
                changed += 1
                file_dirty = True
            del remaining[req_id]
            i = j
        if file_dirty:
            md.write_text("".join(out), encoding="utf-8")
    print(f"re-parented: {changed}  already-had-refines: {skipped}")
    if remaining:
        print(f"  NOT FOUND ({len(remaining)}): {', '.join(sorted(remaining))}")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
