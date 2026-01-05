#!/usr/bin/env python3
"""
Spec Review API Server for TraceView

Flask-based API server for the review system that handles:
- Thread creation and comment persistence
- Status change requests and approvals
- Review flag management
- Git sync operations

IMPLEMENTS REQUIREMENTS:
    REQ-d00088: Review Storage Operations
    REQ-d00093: Review Mode Server
"""

from pathlib import Path
from typing import Optional

from flask import Flask, request, jsonify
from flask_cors import CORS

from .models import (
    Thread,
    ReviewFlag,
    StatusRequest,
    Approval,
    normalize_req_id,
)
from .storage import (
    load_threads,
    add_thread,
    add_comment_to_thread,
    resolve_thread,
    unresolve_thread,
    load_review_flag,
    save_review_flag,
    load_status_requests,
    create_status_request,
    add_approval,
    load_config,
)
from .branches import (
    commit_and_push_reviews,
    get_sync_status,
)


def create_app(repo_root: Path, auto_sync: bool = True) -> Flask:
    """
    Create Flask app with review API endpoints.

    Args:
        repo_root: Repository root path for .reviews/ storage
        auto_sync: Whether to auto-commit and push after write operations

    Returns:
        Flask application
    """
    app = Flask(__name__)
    CORS(app)  # Enable CORS for browser requests

    # Store repo_root in app config
    app.config['REPO_ROOT'] = repo_root
    app.config['AUTO_SYNC'] = auto_sync

    def trigger_auto_sync(message: str, user: str = 'system') -> Optional[dict]:
        """
        Trigger auto-sync if enabled.

        Args:
            message: Commit message describing the change
            user: Username for commit attribution

        Returns:
            dict with sync result, or None if auto-sync disabled
        """
        if not app.config.get('AUTO_SYNC'):
            return None

        repo = app.config['REPO_ROOT']
        return commit_and_push_reviews(repo, message, user)

    # ==========================================================================
    # Health Check
    # ==========================================================================

    @app.route('/api/health', methods=['GET'])
    def health_check():
        """Health check endpoint"""
        repo = app.config['REPO_ROOT']
        return jsonify({
            'status': 'ok',
            'repo_root': str(repo),
            'reviews_dir': str(repo / '.reviews')
        })

    # ==========================================================================
    # Review Data API
    # ==========================================================================

    @app.route('/api/reviews', methods=['GET'])
    def get_all_reviews():
        """Get all review data (threads, flags, requests)"""
        repo = app.config['REPO_ROOT']
        reviews_dir = repo / '.reviews' / 'reqs'

        result = {
            'threads': {},
            'flags': {},
            'requests': {},
            'config': load_config(repo).to_dict()
        }

        if reviews_dir.exists():
            for req_dir in reviews_dir.iterdir():
                if req_dir.is_dir():
                    req_id = req_dir.name

                    # Load threads
                    threads_file = load_threads(repo, req_id)
                    if threads_file.threads:
                        result['threads'][req_id] = [t.to_dict() for t in threads_file.threads]

                    # Load flags
                    flag = load_review_flag(repo, req_id)
                    if flag.flaggedForReview:
                        result['flags'][req_id] = flag.to_dict()

                    # Load status requests
                    status_file = load_status_requests(repo, req_id)
                    if status_file.requests:
                        result['requests'][req_id] = [r.to_dict() for r in status_file.requests]

        return jsonify(result)

    @app.route('/api/reviews/reqs/<req_id>', methods=['GET'])
    def get_req_reviews(req_id):
        """Get review data for a specific requirement"""
        repo = app.config['REPO_ROOT']
        normalized_id = normalize_req_id(req_id)

        threads_file = load_threads(repo, normalized_id)
        flag = load_review_flag(repo, normalized_id)
        status_file = load_status_requests(repo, normalized_id)

        return jsonify({
            'threads': [t.to_dict() for t in threads_file.threads],
            'flag': flag.to_dict() if flag.flaggedForReview else None,
            'requests': [r.to_dict() for r in status_file.requests]
        })

    # ==========================================================================
    # Thread API
    # ==========================================================================

    @app.route('/api/reviews/reqs/<req_id>/threads', methods=['POST'])
    def create_thread_endpoint(req_id):
        """Create a new comment thread"""
        repo = app.config['REPO_ROOT']
        normalized_id = normalize_req_id(req_id)
        data = request.get_json(silent=True)

        if not data:
            return jsonify({'error': 'No data provided'}), 400

        try:
            thread = Thread.from_dict(data)
            add_thread(repo, normalized_id, thread)

            # Auto-sync after creating thread
            user = thread.createdBy or 'system'
            sync_result = trigger_auto_sync(f"New thread on REQ-{normalized_id}", user)

            response = {'success': True, 'thread': thread.to_dict()}
            if sync_result:
                response['sync'] = sync_result

            return jsonify(response), 201
        except Exception as e:
            return jsonify({'error': str(e)}), 400

    @app.route('/api/reviews/reqs/<req_id>/threads/<thread_id>/comments', methods=['POST'])
    def add_comment_endpoint(req_id, thread_id):
        """Add a comment to an existing thread"""
        repo = app.config['REPO_ROOT']
        normalized_id = normalize_req_id(req_id)
        data = request.get_json(silent=True)

        if not data:
            return jsonify({'error': 'No data provided'}), 400

        try:
            # Extract author and body from the comment data
            author = data.get('author')
            body = data.get('body')

            if not author:
                return jsonify({'error': 'Comment author is required'}), 400
            if not body:
                return jsonify({'error': 'Comment body is required'}), 400

            comment = add_comment_to_thread(repo, normalized_id, thread_id, author, body)

            # Auto-sync after adding comment
            sync_result = trigger_auto_sync(f"Comment on REQ-{normalized_id}", author)

            response = {'success': True, 'comment': comment.to_dict()}
            if sync_result:
                response['sync'] = sync_result

            return jsonify(response), 201
        except Exception as e:
            return jsonify({'error': str(e)}), 400

    @app.route('/api/reviews/reqs/<req_id>/threads/<thread_id>/resolve', methods=['POST'])
    def resolve_thread_endpoint(req_id, thread_id):
        """Resolve a thread"""
        repo = app.config['REPO_ROOT']
        normalized_id = normalize_req_id(req_id)
        data = request.get_json(silent=True) or {}
        user = data.get('user', 'anonymous')

        try:
            resolve_thread(repo, normalized_id, thread_id, user)

            # Auto-sync after resolving thread
            sync_result = trigger_auto_sync(f"Resolved thread on REQ-{normalized_id}", user)

            response = {'success': True}
            if sync_result:
                response['sync'] = sync_result

            return jsonify(response), 200
        except Exception as e:
            return jsonify({'error': str(e)}), 400

    @app.route('/api/reviews/reqs/<req_id>/threads/<thread_id>/unresolve', methods=['POST'])
    def unresolve_thread_endpoint(req_id, thread_id):
        """Unresolve a thread"""
        repo = app.config['REPO_ROOT']
        normalized_id = normalize_req_id(req_id)
        data = request.get_json(silent=True) or {}
        user = data.get('user', 'anonymous')

        try:
            unresolve_thread(repo, normalized_id, thread_id)

            # Auto-sync after unresolving thread
            sync_result = trigger_auto_sync(f"Unresolved thread on REQ-{normalized_id}", user)

            response = {'success': True}
            if sync_result:
                response['sync'] = sync_result

            return jsonify(response), 200
        except Exception as e:
            return jsonify({'error': str(e)}), 400

    # ==========================================================================
    # Review Flag API
    # ==========================================================================

    @app.route('/api/reviews/reqs/<req_id>/flag', methods=['GET'])
    def get_flag(req_id):
        """Get review flag for a requirement"""
        repo = app.config['REPO_ROOT']
        normalized_id = normalize_req_id(req_id)
        flag = load_review_flag(repo, normalized_id)
        return jsonify(flag.to_dict())

    @app.route('/api/reviews/reqs/<req_id>/flag', methods=['POST'])
    def set_flag(req_id):
        """Set review flag for a requirement"""
        repo = app.config['REPO_ROOT']
        normalized_id = normalize_req_id(req_id)
        data = request.get_json(silent=True)

        if not data:
            return jsonify({'error': 'No data provided'}), 400

        try:
            flag = ReviewFlag.from_dict(data)
            flag.reqId = normalized_id
            save_review_flag(repo, normalized_id, flag)

            # Auto-sync after flagging
            user = flag.flaggedBy or 'system'
            sync_result = trigger_auto_sync(f"Flagged REQ-{normalized_id} for review", user)

            response = {'success': True, 'flag': flag.to_dict()}
            if sync_result:
                response['sync'] = sync_result

            return jsonify(response), 200
        except Exception as e:
            return jsonify({'error': str(e)}), 400

    @app.route('/api/reviews/reqs/<req_id>/flag', methods=['DELETE'])
    def clear_flag(req_id):
        """Clear review flag for a requirement"""
        repo = app.config['REPO_ROOT']
        normalized_id = normalize_req_id(req_id)
        data = request.get_json(silent=True) or {}
        user = data.get('user', 'anonymous')

        # Create an unflagged ReviewFlag
        flag = ReviewFlag(
            flaggedForReview=False,
            flaggedBy='',
            flaggedAt='',
            reason='',
            scope=[]
        )
        save_review_flag(repo, normalized_id, flag)

        # Auto-sync after clearing flag
        sync_result = trigger_auto_sync(f"Cleared flag on REQ-{normalized_id}", user)

        response = {'success': True}
        if sync_result:
            response['sync'] = sync_result

        return jsonify(response), 200

    # ==========================================================================
    # Status Request API
    # ==========================================================================

    @app.route('/api/reviews/reqs/<req_id>/requests', methods=['GET'])
    def get_status_requests_endpoint(req_id):
        """Get status change requests for a requirement"""
        repo = app.config['REPO_ROOT']
        normalized_id = normalize_req_id(req_id)
        status_file = load_status_requests(repo, normalized_id)
        return jsonify([r.to_dict() for r in status_file.requests])

    @app.route('/api/reviews/reqs/<req_id>/requests', methods=['POST'])
    def create_status_request_endpoint(req_id):
        """Create a status change request"""
        repo = app.config['REPO_ROOT']
        normalized_id = normalize_req_id(req_id)
        data = request.get_json(silent=True)

        if not data:
            return jsonify({'error': 'No data provided'}), 400

        try:
            status_request = StatusRequest.from_dict(data)
            create_status_request(repo, normalized_id, status_request)

            # Auto-sync after creating status request
            user = status_request.requestedBy or 'system'
            sync_result = trigger_auto_sync(
                f"Status change request for REQ-{normalized_id}: {status_request.fromStatus} → {status_request.toStatus}",
                user
            )

            response = {'success': True, 'request': status_request.to_dict()}
            if sync_result:
                response['sync'] = sync_result

            return jsonify(response), 201
        except Exception as e:
            return jsonify({'error': str(e)}), 400

    @app.route('/api/reviews/reqs/<req_id>/requests/<request_id>/approvals', methods=['POST'])
    def add_approval_endpoint(req_id, request_id):
        """Add an approval to a status change request"""
        repo = app.config['REPO_ROOT']
        normalized_id = normalize_req_id(req_id)
        data = request.get_json(silent=True)

        if not data:
            return jsonify({'error': 'No data provided'}), 400

        try:
            # Extract fields from the approval data
            user = data.get('user')
            decision = data.get('decision')
            comment = data.get('comment')

            if not user:
                return jsonify({'error': 'Approval user is required'}), 400
            if not decision:
                return jsonify({'error': 'Approval decision is required'}), 400

            # Call storage function with individual fields
            approval = add_approval(repo, normalized_id, request_id, user, decision, comment)

            # Auto-sync after adding approval
            sync_result = trigger_auto_sync(
                f"Approval on REQ-{normalized_id} status request: {decision}",
                user
            )

            response = {'success': True, 'approval': approval.to_dict()}
            if sync_result:
                response['sync'] = sync_result

            return jsonify(response), 201
        except Exception as e:
            return jsonify({'error': str(e)}), 400

    # ==========================================================================
    # Git Sync API
    # ==========================================================================

    @app.route('/api/reviews/sync/status', methods=['GET'])
    def get_sync_status_endpoint():
        """Get the current sync status"""
        repo = app.config['REPO_ROOT']
        status = get_sync_status(repo)
        status['auto_sync_enabled'] = app.config.get('AUTO_SYNC', True)
        return jsonify(status)

    @app.route('/api/reviews/sync/push', methods=['POST'])
    def sync_push():
        """Manually trigger a sync (commit and push)"""
        repo = app.config['REPO_ROOT']
        data = request.get_json() or {}
        user = data.get('user', 'manual')
        message = data.get('message', 'Manual sync')

        result = commit_and_push_reviews(repo, message, user)
        return jsonify(result)

    return app


def main():
    """Run the review server"""
    import argparse

    parser = argparse.ArgumentParser(description='Spec Review API Server')
    parser.add_argument('--port', type=int, default=8080, help='Port to run on')
    parser.add_argument('--host', default='0.0.0.0', help='Host to bind to')
    parser.add_argument('--repo', type=Path, default=Path.cwd(), help='Repository root')
    parser.add_argument('--debug', action='store_true', help='Enable debug mode')
    parser.add_argument('--no-auto-sync', action='store_true',
                        help='Disable automatic git commit/push after changes')

    args = parser.parse_args()

    auto_sync = not args.no_auto_sync
    app = create_app(args.repo.resolve(), auto_sync=auto_sync)

    sync_status = "ENABLED" if auto_sync else "DISABLED"
    print(f"""
======================================
  Spec Review API Server
======================================

Repository: {args.repo.resolve()}
Server:     http://{args.host}:{args.port}
Auto-Sync:  {sync_status}

API Endpoints:
  GET  /api/health                       - Health check
  GET  /api/reviews                      - All review data
  GET  /api/reviews/reqs/<id>            - REQ review data
  POST /api/reviews/reqs/<id>/threads    - Create thread
  POST /api/reviews/reqs/<id>/threads/<tid>/comments - Add comment
  POST /api/reviews/reqs/<id>/threads/<tid>/resolve  - Resolve thread
  POST /api/reviews/reqs/<id>/threads/<tid>/unresolve - Unresolve thread
  GET  /api/reviews/reqs/<id>/flag       - Get flag
  POST /api/reviews/reqs/<id>/flag       - Set flag
  DELETE /api/reviews/reqs/<id>/flag     - Clear flag
  GET  /api/reviews/reqs/<id>/requests   - Get status requests
  POST /api/reviews/reqs/<id>/requests   - Create status request
  POST /api/reviews/reqs/<id>/requests/<rid>/approvals - Add approval
  GET  /api/reviews/sync/status          - Get sync status
  POST /api/reviews/sync/push            - Manual sync

Press Ctrl+C to stop
""")

    app.run(host=args.host, port=args.port, debug=args.debug)


if __name__ == '__main__':
    main()
