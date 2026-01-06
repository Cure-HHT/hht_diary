# REQ-tv-d00011: Review Storage Operations

**Level**: Dev | **Status**: Draft | **Implements**: REQ-tv-p00002

## Assertions

A. All JSON file writes SHALL use atomic write operations via temporary file creation followed by rename.

B. Thread storage operations SHALL support: `load_threads()`, `save_threads()`, `add_thread()`, `add_comment_to_thread()`, `resolve_thread()`, and `unresolve_thread()`.

C. Status request storage operations SHALL support: `load_status_requests()`, `save_status_requests()`, `create_status_request()`, `add_approval()`, and `mark_request_applied()`.

D. Review flag storage operations SHALL support: `load_review_flag()` and `save_review_flag()`.

E. Package storage operations SHALL support: `load_packages()`, `save_packages()`, `create_package()`, `update_package()`, `delete_package()`, `add_req_to_package()`, and `remove_req_from_package()`.

F. Config storage operations SHALL support: `load_config()` and `save_config()` for system-wide settings.

G. Merge operations SHALL support: `merge_threads()`, `merge_status_files()`, and `merge_review_flags()` for combining data from multiple user branches.

H. Storage paths SHALL follow the convention: `.reviews/reqs/{normalized-req-id}/threads.json`, `.reviews/reqs/{normalized-req-id}/status.json`, `.reviews/packages.json`, and `.reviews/config.json`.

I. Requirement IDs in paths SHALL be normalized by replacing colons and slashes with underscores.

J. The merge strategy SHALL deduplicate by ID (threadId, requestId) and use timestamp-based conflict resolution for divergent edits.

## Rationale

Atomic writes via temp+rename prevent data corruption from interrupted writes or concurrent access. The normalized path convention ensures filesystem compatibility across operating systems while maintaining readable directory structures.

The merge operations enable the multi-user review workflow where each user works on their own branch and merges are performed when viewing consolidated package data.

*End* *Review Storage Operations* | **Hash**: 00000000
