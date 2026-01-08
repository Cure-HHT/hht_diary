# REQ-tv-d00015: Status Modifier

**Level**: Dev | **Status**: Draft | **Implements**: REQ-tv-p00002

## Assertions

A. `find_req_in_file(file_path, req_id)` SHALL locate a requirement in a spec file and return the status line information.

B. `get_req_status(repo_root, req_id)` SHALL read and return the current status value from the spec file.

C. `change_req_status(repo_root, req_id, new_status, user)` SHALL update the status value in the spec file atomically.

D. Status values SHALL be validated against the allowed set: Draft, Active, Deprecated.

E. The status modifier SHALL preserve all other content and formatting when changing status.

F. The status modifier SHALL update the requirement's content hash footer after status changes.

G. Failed status changes SHALL NOT leave the spec file in a corrupted or partial state.

## Rationale

The status modifier enables the review workflow to complete the cycle by applying approved status changes directly to the spec files. This maintains the spec files as the authoritative source while the review system provides the approval workflow around changes.

Atomic updates ensure that interrupted operations don't corrupt spec files, which are the source of truth for requirements.

*End* *Status Modifier* | **Hash**: 00000000
