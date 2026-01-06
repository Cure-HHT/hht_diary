# REQ-tv-d00014: Review API Server

**Level**: Dev | **Status**: Draft | **Implements**: REQ-tv-p00002

## Assertions

A. The API server SHALL be implemented as a Flask application with a `create_app(repo_root, static_dir)` factory function.

B. Thread endpoints SHALL support: `POST /api/reviews/reqs/{id}/threads` (create), `POST /api/reviews/reqs/{id}/threads/{tid}/comments` (add comment), `POST /api/reviews/reqs/{id}/threads/{tid}/resolve` (resolve), `POST /api/reviews/reqs/{id}/threads/{tid}/unresolve` (unresolve).

C. Status endpoints SHALL support: `GET /api/reviews/reqs/{id}/status` (get status), `POST /api/reviews/reqs/{id}/status` (change status in spec file), `GET /api/reviews/reqs/{id}/requests` (list requests), `POST /api/reviews/reqs/{id}/requests` (create request), `POST /api/reviews/reqs/{id}/requests/{rid}/approvals` (add approval).

D. Package endpoints SHALL support: `GET /api/reviews/packages` (list), `POST /api/reviews/packages` (create), `GET/PUT/DELETE /api/reviews/packages/{id}` (CRUD), `POST/DELETE /api/reviews/packages/{id}/reqs/{req_id}` (membership), `GET/PUT /api/reviews/packages/active` (active package).

E. Sync endpoints SHALL support: `GET /api/reviews/sync/status` (sync status), `POST /api/reviews/sync/push` (commit and push), `POST /api/reviews/sync/fetch` (fetch from remote), `POST /api/reviews/sync/fetch-all-package` (fetch all user branches).

F. The server SHALL enable CORS for cross-origin requests from the HTML viewer.

G. The server SHALL serve static files from the configured static directory at the root path.

H. All write endpoints SHALL optionally trigger auto-sync based on configuration.

I. Error responses SHALL use appropriate HTTP status codes and include JSON error details.

J. The server SHALL provide a `/api/health` endpoint for health checks.

## Rationale

The Flask API provides a lightweight HTTP interface for the review UI. The endpoint structure follows REST conventions with resource-oriented URLs. Auto-sync enables automatic git commits on each change for users who prefer immediate persistence, while manual sync is available for batched workflows.

*End* *Review API Server* | **Hash**: 00000000
