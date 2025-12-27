#!/usr/bin/env python3
"""
Spec Review API Server

Flask-based API server for the review system that handles:
- Thread creation and comment persistence
- Status change requests and approvals
- Review flag management

IMPLEMENTS REQUIREMENTS:
    REQ-d00088: Review Storage Operations
    REQ-d00092: HTML Report Integration
    REQ-d00093: Review Mode Server
"""

import json
import os
import sys
from datetime import datetime
from pathlib import Path
from typing import Optional

from flask import Flask, request, jsonify, send_from_directory
from flask_cors import CORS

# Add parent to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

from spec_review.review_storage import (
    load_threads,
    save_threads,
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
from spec_review.status_modifier import (
    change_req_status,
    get_req_status,
)
from spec_review.review_packages import (
    load_packages,
    save_packages,
    create_package,
    get_package,
    update_package,
    delete_package,
    add_req_to_package,
    remove_req_from_package,
    get_active_package,
    set_active_package,
    on_status_changed_to_review,
)
from spec_review.review_branches import (
    commit_and_push_reviews,
    fetch_and_merge_reviews,
    get_sync_status,
    has_reviews_changes,
    ensure_package_branch,
    switch_to_package_branch,
    get_current_package_context,
)
from spec_review.review_merge import (
    get_package_contributors,
    merge_package_review_data,
    fetch_all_package_branches,
)
from spec_review.review_data import (
    Thread,
    Comment,
    CommentPosition,
    ReviewFlag,
    StatusRequest,
    Approval,
    normalize_req_id,
)


def create_app(repo_root: Path, static_dir: Optional[Path] = None, auto_sync: bool = True):
    """
    Create Flask app with review API endpoints.

    Args:
        repo_root: Repository root path for .reviews/ storage
        static_dir: Optional directory to serve static files from
        auto_sync: Whether to auto-commit and push after write operations

    Returns:
        Flask application
    """
    app = Flask(__name__)
    CORS(app)  # Enable CORS for browser requests

    # Store repo_root in app config
    app.config['REPO_ROOT'] = repo_root
    app.config['STATIC_DIR'] = static_dir or repo_root
    app.config['AUTO_SYNC'] = auto_sync

    def trigger_auto_sync(message: str, user: str = 'system'):
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
    # Static File Serving
    # ==========================================================================

    @app.route('/')
    def index():
        """Redirect to the review report"""
        return send_from_directory(
            app.config['STATIC_DIR'],
            'validation-reports/REQ-report-review.html'
        )

    @app.route('/<path:path>')
    def serve_static(path):
        """Serve static files from repo root"""
        return send_from_directory(app.config['STATIC_DIR'], path)

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
    def create_thread(req_id):
        """Create a new comment thread"""
        repo = app.config['REPO_ROOT']
        normalized_id = normalize_req_id(req_id)
        data = request.get_json()

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
    def add_comment(req_id, thread_id):
        """Add a comment to an existing thread"""
        repo = app.config['REPO_ROOT']
        normalized_id = normalize_req_id(req_id)
        data = request.get_json()

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
        data = request.get_json() or {}
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
        data = request.get_json() or {}
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
        data = request.get_json()

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
        data = request.get_json() or {}
        user = data.get('user', 'anonymous')

        flag = ReviewFlag.create(normalized_id)
        flag.flaggedForReview = False
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
    def get_status_requests(req_id):
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
        data = request.get_json()

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
        data = request.get_json()

        if not data:
            return jsonify({'error': 'No data provided'}), 400

        try:
            approval = Approval.from_dict(data)
            add_approval(repo, normalized_id, request_id, approval)

            # Auto-sync after adding approval
            user = approval.user or 'system'
            sync_result = trigger_auto_sync(
                f"Approval on REQ-{normalized_id} status request: {approval.decision}",
                user
            )

            response = {'success': True, 'approval': approval.to_dict()}
            if sync_result:
                response['sync'] = sync_result

            return jsonify(response), 201
        except Exception as e:
            return jsonify({'error': str(e)}), 400

    # ==========================================================================
    # Status Change API (modifies actual spec files)
    # ==========================================================================

    @app.route('/api/reviews/reqs/<req_id>/status', methods=['GET'])
    def get_status(req_id):
        """Get the current status of a requirement from the spec file"""
        repo = app.config['REPO_ROOT']
        normalized_id = normalize_req_id(req_id)

        status = get_req_status(repo, normalized_id)
        if status is None:
            return jsonify({'error': f'REQ-{normalized_id} not found'}), 404

        return jsonify({'reqId': normalized_id, 'status': status})

    @app.route('/api/reviews/reqs/<req_id>/status', methods=['POST'])
    def set_status(req_id):
        """Change the status of a requirement in its spec file"""
        repo = app.config['REPO_ROOT']
        normalized_id = normalize_req_id(req_id)
        data = request.get_json()

        if not data:
            return jsonify({'error': 'No data provided'}), 400

        new_status = data.get('newStatus')
        if not new_status:
            return jsonify({'error': 'newStatus is required'}), 400

        user = data.get('user', 'api')

        result = change_req_status(repo, normalized_id, new_status, user)

        if result.get('success'):
            # If status changed to Review, auto-add to appropriate package
            if new_status == 'Review':
                pkg = on_status_changed_to_review(repo, normalized_id, source='gui')
                if pkg:
                    result['addedToPackage'] = {
                        'packageId': pkg.packageId,
                        'packageName': pkg.name
                    }

            # Auto-sync after status change
            sync_result = trigger_auto_sync(
                f"Changed REQ-{normalized_id} status to {new_status}",
                user
            )
            if sync_result:
                result['sync'] = sync_result

            return jsonify(result), 200
        else:
            return jsonify(result), 400

    # ==========================================================================
    # Review Packages API
    # ==========================================================================

    @app.route('/api/reviews/packages', methods=['GET'])
    def get_packages():
        """Get all review packages"""
        repo = app.config['REPO_ROOT']
        pf = load_packages(repo)
        return jsonify({
            'packages': [p.to_dict() for p in pf.packages],
            'activePackageId': pf.activePackageId
        })

    @app.route('/api/reviews/packages', methods=['POST'])
    def create_package_endpoint():
        """Create a new review package"""
        repo = app.config['REPO_ROOT']
        data = request.get_json()

        if not data:
            return jsonify({'error': 'No data provided'}), 400

        name = data.get('name')
        if not name:
            return jsonify({'error': 'name is required'}), 400

        description = data.get('description', '')
        user = data.get('user', 'api')

        pkg = create_package(repo, name, description, user)

        # Auto-sync after creating package
        sync_result = trigger_auto_sync(f"Created package: {name}", user)

        response = {'success': True, 'package': pkg.to_dict()}
        if sync_result:
            response['sync'] = sync_result

        return jsonify(response), 201

    @app.route('/api/reviews/packages/<package_id>', methods=['GET'])
    def get_package_endpoint(package_id):
        """Get a specific package"""
        repo = app.config['REPO_ROOT']
        pkg = get_package(repo, package_id)

        if not pkg:
            return jsonify({'error': 'Package not found'}), 404

        return jsonify(pkg.to_dict())

    @app.route('/api/reviews/packages/<package_id>', methods=['PUT'])
    def update_package_endpoint(package_id):
        """Update a package"""
        repo = app.config['REPO_ROOT']
        data = request.get_json()

        if not data:
            return jsonify({'error': 'No data provided'}), 400

        user = data.get('user', 'api')
        success = update_package(
            repo,
            package_id,
            name=data.get('name'),
            description=data.get('description')
        )

        if success:
            pkg = get_package(repo, package_id)

            # Auto-sync after updating package
            sync_result = trigger_auto_sync(f"Updated package: {pkg.name}", user)

            response = {'success': True, 'package': pkg.to_dict()}
            if sync_result:
                response['sync'] = sync_result

            return jsonify(response)
        else:
            return jsonify({'error': 'Package not found'}), 404

    @app.route('/api/reviews/packages/<package_id>', methods=['DELETE'])
    def delete_package_endpoint(package_id):
        """Delete a package"""
        repo = app.config['REPO_ROOT']
        data = request.get_json() or {}
        user = data.get('user', 'api')

        # Get package name before deleting
        pkg = get_package(repo, package_id)
        pkg_name = pkg.name if pkg else package_id

        success = delete_package(repo, package_id)

        if success:
            # Auto-sync after deleting package
            sync_result = trigger_auto_sync(f"Deleted package: {pkg_name}", user)

            response = {'success': True}
            if sync_result:
                response['sync'] = sync_result

            return jsonify(response)
        else:
            return jsonify({'error': 'Package not found or is default'}), 400

    @app.route('/api/reviews/packages/<package_id>/reqs/<req_id>', methods=['POST'])
    def add_req_to_package_endpoint(package_id, req_id):
        """Add a REQ to a package"""
        repo = app.config['REPO_ROOT']
        data = request.get_json() or {}
        user = data.get('user', 'api')

        normalized_id = normalize_req_id(req_id)
        success = add_req_to_package(repo, package_id, normalized_id)

        if success:
            # Auto-sync after adding REQ to package
            sync_result = trigger_auto_sync(f"Added REQ-{normalized_id} to package", user)

            response = {'success': True}
            if sync_result:
                response['sync'] = sync_result

            return jsonify(response)
        else:
            return jsonify({'error': 'Package not found'}), 404

    @app.route('/api/reviews/packages/<package_id>/reqs/<req_id>', methods=['DELETE'])
    def remove_req_from_package_endpoint(package_id, req_id):
        """Remove a REQ from a package"""
        repo = app.config['REPO_ROOT']
        data = request.get_json() or {}
        user = data.get('user', 'api')

        normalized_id = normalize_req_id(req_id)
        success = remove_req_from_package(repo, package_id, normalized_id)

        if success:
            # Auto-sync after removing REQ from package
            sync_result = trigger_auto_sync(f"Removed REQ-{normalized_id} from package", user)

            response = {'success': True}
            if sync_result:
                response['sync'] = sync_result

            return jsonify(response)
        else:
            return jsonify({'error': 'Package not found'}), 404

    @app.route('/api/reviews/packages/active', methods=['GET'])
    def get_active_package_endpoint():
        """Get the currently active package"""
        repo = app.config['REPO_ROOT']
        pkg = get_active_package(repo)

        if pkg:
            return jsonify(pkg.to_dict())
        else:
            return jsonify(None)

    @app.route('/api/reviews/packages/active', methods=['PUT'])
    def set_active_package_endpoint():
        """Set the active package"""
        repo = app.config['REPO_ROOT']
        data = request.get_json() or {}
        user = data.get('user', 'api')

        package_id = data.get('packageId') if data else None
        success = set_active_package(repo, package_id)

        if success:
            # Auto-sync after setting active package
            msg = f"Set active package: {package_id}" if package_id else "Cleared active package"
            sync_result = trigger_auto_sync(msg, user)

            response = {'success': True, 'activePackageId': package_id}
            if sync_result:
                response['sync'] = sync_result

            return jsonify(response)
        else:
            return jsonify({'error': 'Package not found'}), 404

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

    @app.route('/api/reviews/sync/fetch', methods=['POST'])
    def sync_fetch():
        """Fetch and merge latest review data from remote"""
        repo = app.config['REPO_ROOT']
        result = fetch_and_merge_reviews(repo)
        return jsonify(result)

    @app.route('/api/reviews/sync/fetch-all-package', methods=['POST'])
    def sync_fetch_all_package():
        """
        Fetch and merge review data from all users' branches for the current package.

        Returns consolidated view of threads, flags, and contributors.
        """
        repo = app.config['REPO_ROOT']

        # Get current package context from branch name
        context = get_current_package_context(repo)
        if not context:
            # Not on a review branch - return empty data
            return jsonify({
                'threads': {},
                'flags': {},
                'contributors': [],
                'error': 'Not on a review branch'
            })

        package_id, _ = context

        # Fetch remote branches first (if remote exists)
        fetch_all_package_branches(repo, package_id)

        # Merge data from all package branches
        merged_data = merge_package_review_data(repo, package_id)
        return jsonify(merged_data)

    # ==========================================================================
    # Package Branch Management API
    # ==========================================================================

    @app.route('/api/reviews/context', methods=['GET'])
    def get_context():
        """
        Get current package/user context from the git branch name.

        Returns null if not on a review branch.
        """
        repo = app.config['REPO_ROOT']
        context = get_current_package_context(repo)

        if context:
            package_id, user = context
            # Get current branch name
            import subprocess
            result = subprocess.run(
                ['git', 'branch', '--show-current'],
                cwd=repo,
                capture_output=True,
                text=True
            )
            branch = result.stdout.strip() if result.returncode == 0 else None

            return jsonify({
                'packageId': package_id,
                'user': user,
                'branch': branch
            })
        else:
            return jsonify(None)

    @app.route('/api/reviews/packages/switch', methods=['POST'])
    def switch_package():
        """
        Switch to a package branch for the current user.

        Creates the branch if it doesn't exist. Stashes uncommitted changes.
        """
        repo = app.config['REPO_ROOT']
        data = request.get_json()

        if not data:
            return jsonify({'error': 'No data provided'}), 400

        package_id = data.get('packageId')
        user = data.get('user')

        if not package_id:
            return jsonify({'error': 'packageId is required'}), 400
        if not user:
            return jsonify({'error': 'user is required'}), 400

        try:
            # Commit any pending changes to current branch first
            if has_reviews_changes(repo):
                commit_and_push_reviews(repo, "Auto-save before switch", user)

            # Switch to the package branch (creates if needed)
            branch = ensure_package_branch(repo, package_id, user)

            return jsonify({
                'success': True,
                'branch': branch,
                'packageId': package_id,
                'user': user
            })
        except Exception as e:
            return jsonify({'error': str(e)}), 500

    @app.route('/api/reviews/packages/<package_id>/contributors', methods=['GET'])
    def get_contributors(package_id):
        """
        Get all users who have branches for this package.

        Returns sorted list of usernames.
        """
        repo = app.config['REPO_ROOT']
        contributors = get_package_contributors(repo, package_id)
        return jsonify({'contributors': contributors})

    # ==========================================================================
    # Health Check
    # ==========================================================================

    @app.route('/api/health', methods=['GET'])
    def health_check():
        """Health check endpoint"""
        return jsonify({
            'status': 'ok',
            'repo_root': str(app.config['REPO_ROOT']),
            'reviews_dir': str(app.config['REPO_ROOT'] / '.reviews')
        })

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
Report:     http://localhost:{args.port}/validation-reports/REQ-report-review.html
Auto-Sync:  {sync_status}

API Endpoints:
  GET  /api/reviews                    - All review data
  GET  /api/reviews/reqs/<id>          - REQ review data
  POST /api/reviews/reqs/<id>/threads  - Create thread
  POST /api/reviews/reqs/<id>/threads/<tid>/comments - Add comment
  POST /api/reviews/reqs/<id>/requests - Create status request
  POST /api/reviews/reqs/<id>/requests/<rid>/approvals - Add approval
  GET  /api/reviews/reqs/<id>/status   - Get REQ status from spec file
  POST /api/reviews/reqs/<id>/status   - Change REQ status in spec file
  GET  /api/reviews/packages           - List all packages
  POST /api/reviews/packages           - Create new package
  GET  /api/reviews/packages/active    - Get active package
  PUT  /api/reviews/packages/active    - Set active package
  GET  /api/reviews/sync/status        - Get sync status
  POST /api/reviews/sync/push          - Manual sync (commit + push)
  POST /api/reviews/sync/fetch         - Fetch from remote

Press Ctrl+C to stop
""")

    app.run(host=args.host, port=args.port, debug=args.debug)


if __name__ == '__main__':
    main()
