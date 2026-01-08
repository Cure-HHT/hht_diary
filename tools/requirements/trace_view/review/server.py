#!/usr/bin/env python3
"""
Review API Server for trace_view

Flask-based API server for the review system that handles:
- Thread creation and comment persistence
- Status change requests and approvals
- Review flag management
- Package management
- Git sync operations

IMPLEMENTS REQUIREMENTS:
    REQ-tv-d00014: Review API Server
"""

from pathlib import Path
from typing import Optional, Tuple

from flask import Flask, request, jsonify, send_from_directory
from flask_cors import CORS

from .models import (
    Thread,
    Comment,
    CommentPosition,
    ThreadsFile,
    StatusFile,
    StatusRequest,
    ReviewFlag,
    ReviewConfig,
    ReviewPackage,
    PackagesFile,
    Approval,
    now_iso,
)
from .storage import (
    load_threads,
    save_threads,
    add_thread,
    add_comment_to_thread,
    resolve_thread,
    unresolve_thread,
    load_status_requests,
    save_status_requests,
    create_status_request,
    add_approval,
    mark_request_applied,
    load_review_flag,
    save_review_flag,
    load_packages,
    save_packages,
    create_package,
    update_package,
    delete_package,
    add_req_to_package,
    remove_req_from_package,
    load_config,
    normalize_req_id,
)
from .branches import (
    commit_and_push_reviews,
    fetch_package_branches,
    get_current_package_context,
    list_package_branches,
    has_reviews_changes,
)
from .status import get_req_status, change_req_status


def create_app(
    repo_root: Path,
    static_dir: Optional[Path] = None,
    auto_sync: bool = True,
    register_static_routes: bool = True
) -> Flask:
    """
    Create Flask app with review API endpoints.

    REQ-tv-d00014-A: The API server SHALL be implemented as a Flask
    application with a `create_app(repo_root, static_dir)` factory function.

    Args:
        repo_root: Repository root path for .reviews/ storage
        static_dir: Optional directory to serve static files from
        auto_sync: Whether to auto-commit and push after write operations
        register_static_routes: Whether to register default static file routes
            (set to False if caller will define custom static routes)

    Returns:
        Flask application
    """
    app = Flask(__name__)
    # REQ-tv-d00014-F: Enable CORS for cross-origin requests
    CORS(app)

    # Store configuration in app config
    app.config['REPO_ROOT'] = repo_root
    app.config['STATIC_DIR'] = static_dir or repo_root
    app.config['AUTO_SYNC'] = auto_sync

    def trigger_auto_sync(message: str, user: str = 'system') -> Optional[dict]:
        """
        Trigger auto-sync if enabled.

        REQ-tv-d00014-H: All write endpoints SHALL optionally trigger
        auto-sync based on configuration.

        Args:
            message: Commit message describing the change
            user: Username for commit attribution

        Returns:
            dict with sync result, or None if auto-sync disabled
        """
        if not app.config.get('AUTO_SYNC'):
            return None

        repo = app.config['REPO_ROOT']
        success, msg = commit_and_push_reviews(repo, message, user)
        return {'success': success, 'message': msg}

    # ==========================================================================
    # Static File Serving
    # REQ-tv-d00014-G: Serve static files from the configured static directory
    # ==========================================================================

    if register_static_routes:
        @app.route('/')
        def index():
            """Serve index from static directory"""
            return send_from_directory(
                app.config['STATIC_DIR'],
                'index.html'
            )

        @app.route('/<path:path>')
        def serve_static(path):
            """Serve static files from configured static directory"""
            return send_from_directory(app.config['STATIC_DIR'], path)

    # ==========================================================================
    # Health Check
    # REQ-tv-d00014-J: Provide /api/health endpoint for health checks
    # ==========================================================================

    @app.route('/api/health', methods=['GET'])
    def health_check():
        """Health check endpoint"""
        return jsonify({
            'status': 'ok',
            'repo_root': str(app.config['REPO_ROOT']),
            'reviews_dir': str(app.config['REPO_ROOT'] / '.reviews')
        })

    # ==========================================================================
    # Thread API
    # REQ-tv-d00014-B: Thread endpoints for create, comment, resolve, unresolve
    # ==========================================================================

    @app.route('/api/reviews/reqs/<req_id>/threads', methods=['POST'])
    def create_thread_endpoint(req_id):
        """
        Create a new comment thread.

        REQ-tv-d00014-B: POST create thread endpoint.
        """
        repo = app.config['REPO_ROOT']
        normalized_id = normalize_req_id(req_id)
        data = request.get_json(silent=True)

        if not data:
            return jsonify({'error': 'No data provided'}), 400

        try:
            thread = Thread.from_dict(data)
            add_thread(repo, normalized_id, thread)

            # REQ-tv-d00014-H: Auto-sync after write operation
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
        """
        Add a comment to an existing thread.

        REQ-tv-d00014-B: POST add comment endpoint.
        """
        repo = app.config['REPO_ROOT']
        normalized_id = normalize_req_id(req_id)
        data = request.get_json(silent=True)

        if not data:
            return jsonify({'error': 'No data provided'}), 400

        try:
            author = data.get('author')
            body = data.get('body')

            if not author:
                return jsonify({'error': 'Comment author is required'}), 400
            if not body:
                return jsonify({'error': 'Comment body is required'}), 400

            comment = add_comment_to_thread(repo, normalized_id, thread_id, author, body)

            # REQ-tv-d00014-H: Auto-sync after write operation
            sync_result = trigger_auto_sync(f"Comment on REQ-{normalized_id}", author)

            response = {'success': True, 'comment': comment.to_dict()}
            if sync_result:
                response['sync'] = sync_result

            return jsonify(response), 201
        except Exception as e:
            return jsonify({'error': str(e)}), 400

    @app.route('/api/reviews/reqs/<req_id>/threads/<thread_id>/resolve', methods=['POST'])
    def resolve_thread_endpoint(req_id, thread_id):
        """
        Resolve a thread.

        REQ-tv-d00014-B: POST resolve endpoint.
        """
        repo = app.config['REPO_ROOT']
        normalized_id = normalize_req_id(req_id)
        data = request.get_json(silent=True) or {}
        user = data.get('user', 'anonymous')

        try:
            resolve_thread(repo, normalized_id, thread_id, user)

            # REQ-tv-d00014-H: Auto-sync after write operation
            sync_result = trigger_auto_sync(f"Resolved thread on REQ-{normalized_id}", user)

            response = {'success': True}
            if sync_result:
                response['sync'] = sync_result

            return jsonify(response), 200
        except Exception as e:
            return jsonify({'error': str(e)}), 400

    @app.route('/api/reviews/reqs/<req_id>/threads/<thread_id>/unresolve', methods=['POST'])
    def unresolve_thread_endpoint(req_id, thread_id):
        """
        Unresolve a thread.

        REQ-tv-d00014-B: POST unresolve endpoint.
        """
        repo = app.config['REPO_ROOT']
        normalized_id = normalize_req_id(req_id)
        data = request.get_json(silent=True) or {}
        user = data.get('user', 'anonymous')

        try:
            unresolve_thread(repo, normalized_id, thread_id)

            # REQ-tv-d00014-H: Auto-sync after write operation
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
            save_review_flag(repo, normalized_id, flag)

            # REQ-tv-d00014-H: Auto-sync after write operation
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

        flag = ReviewFlag.cleared()
        save_review_flag(repo, normalized_id, flag)

        # REQ-tv-d00014-H: Auto-sync after write operation
        sync_result = trigger_auto_sync(f"Cleared flag on REQ-{normalized_id}", user)

        response = {'success': True}
        if sync_result:
            response['sync'] = sync_result

        return jsonify(response), 200

    # ==========================================================================
    # Status Request API
    # REQ-tv-d00014-C: Status endpoints for GET/POST requests and approvals
    # ==========================================================================

    @app.route('/api/reviews/reqs/<req_id>/status', methods=['GET'])
    def get_status(req_id):
        """
        Get the current status of a requirement from the spec file.

        REQ-tv-d00014-C: GET status endpoint.
        """
        repo = app.config['REPO_ROOT']
        normalized_id = normalize_req_id(req_id)

        status = get_req_status(repo, normalized_id)
        if status is None:
            return jsonify({'error': f'REQ-{normalized_id} not found'}), 404

        return jsonify({'reqId': normalized_id, 'status': status})

    @app.route('/api/reviews/reqs/<req_id>/status', methods=['POST'])
    def set_status(req_id):
        """
        Change the status of a requirement in its spec file.

        REQ-tv-d00014-C: POST change status endpoint.
        """
        repo = app.config['REPO_ROOT']
        normalized_id = normalize_req_id(req_id)
        data = request.get_json(silent=True)

        if not data:
            return jsonify({'error': 'No data provided'}), 400

        new_status = data.get('newStatus')
        if not new_status:
            return jsonify({'error': 'newStatus is required'}), 400

        user = data.get('user', 'api')

        success, message = change_req_status(repo, normalized_id, new_status, user)

        if success:
            # REQ-tv-d00014-H: Auto-sync after write operation
            sync_result = trigger_auto_sync(
                f"Changed REQ-{normalized_id} status to {new_status}",
                user
            )

            response = {'success': True, 'message': message}
            if sync_result:
                response['sync'] = sync_result

            return jsonify(response), 200
        else:
            return jsonify({'success': False, 'error': message}), 400

    @app.route('/api/reviews/reqs/<req_id>/requests', methods=['GET'])
    def get_status_requests(req_id):
        """
        Get status change requests for a requirement.

        REQ-tv-d00014-C: GET requests endpoint.
        """
        repo = app.config['REPO_ROOT']
        normalized_id = normalize_req_id(req_id)
        status_file = load_status_requests(repo, normalized_id)
        return jsonify([r.to_dict() for r in status_file.requests])

    @app.route('/api/reviews/reqs/<req_id>/requests', methods=['POST'])
    def create_status_request_endpoint(req_id):
        """
        Create a status change request.

        REQ-tv-d00014-C: POST requests endpoint.
        """
        repo = app.config['REPO_ROOT']
        normalized_id = normalize_req_id(req_id)
        data = request.get_json(silent=True)

        if not data:
            return jsonify({'error': 'No data provided'}), 400

        try:
            status_request = StatusRequest.from_dict(data)
            create_status_request(repo, normalized_id, status_request)

            # REQ-tv-d00014-H: Auto-sync after write operation
            user = status_request.requestedBy or 'system'
            sync_result = trigger_auto_sync(
                f"Status change request for REQ-{normalized_id}: "
                f"{status_request.fromStatus} -> {status_request.toStatus}",
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
        """
        Add an approval to a status change request.

        REQ-tv-d00014-C: POST approvals endpoint.
        """
        repo = app.config['REPO_ROOT']
        normalized_id = normalize_req_id(req_id)
        data = request.get_json(silent=True)

        if not data:
            return jsonify({'error': 'No data provided'}), 400

        try:
            approval = Approval.from_dict(data)
            add_approval(repo, normalized_id, request_id, approval.user, approval.decision, approval.comment)

            # REQ-tv-d00014-H: Auto-sync after write operation
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
    # Review Packages API
    # REQ-tv-d00014-D: Package endpoints for CRUD and membership
    # ==========================================================================

    @app.route('/api/reviews/packages', methods=['GET'])
    def get_packages():
        """
        Get all review packages.

        REQ-tv-d00014-D: GET packages endpoint.
        """
        repo = app.config['REPO_ROOT']
        pf = load_packages(repo)
        return jsonify({
            'packages': [p.to_dict() for p in pf.packages],
            'activePackageId': pf.activePackageId
        })

    @app.route('/api/reviews/packages', methods=['POST'])
    def create_package_endpoint():
        """
        Create a new review package.

        REQ-tv-d00014-D: POST packages endpoint.
        """
        repo = app.config['REPO_ROOT']
        data = request.get_json(silent=True)

        if not data:
            return jsonify({'error': 'No data provided'}), 400

        name = data.get('name')
        if not name:
            return jsonify({'error': 'name is required'}), 400

        description = data.get('description', '')
        user = data.get('user', 'api')

        pkg = ReviewPackage.create(name, description, user)
        create_package(repo, pkg)

        # REQ-tv-d00014-H: Auto-sync after write operation
        sync_result = trigger_auto_sync(f"Created package: {name}", user)

        response = {'success': True, 'package': pkg.to_dict()}
        if sync_result:
            response['sync'] = sync_result

        return jsonify(response), 201

    @app.route('/api/reviews/packages/<package_id>', methods=['GET'])
    def get_package_endpoint(package_id):
        """
        Get a specific package.

        REQ-tv-d00014-D: GET package by ID endpoint.
        """
        repo = app.config['REPO_ROOT']
        pf = load_packages(repo)
        pkg = pf.get_by_id(package_id)

        if not pkg:
            return jsonify({'error': 'Package not found'}), 404

        return jsonify(pkg.to_dict())

    @app.route('/api/reviews/packages/<package_id>', methods=['PUT'])
    def update_package_endpoint(package_id):
        """
        Update a package.

        REQ-tv-d00014-D: PUT package endpoint.
        """
        repo = app.config['REPO_ROOT']
        data = request.get_json(silent=True)

        if not data:
            return jsonify({'error': 'No data provided'}), 400

        user = data.get('user', 'api')

        # Load existing package
        pf = load_packages(repo)
        pkg = pf.get_by_id(package_id)

        if not pkg:
            return jsonify({'error': 'Package not found'}), 404

        # Update fields
        if 'name' in data:
            pkg.name = data['name']
        if 'description' in data:
            pkg.description = data['description']

        success = update_package(repo, pkg)

        if success:
            # REQ-tv-d00014-H: Auto-sync after write operation
            sync_result = trigger_auto_sync(f"Updated package: {pkg.name}", user)

            response = {'success': True, 'package': pkg.to_dict()}
            if sync_result:
                response['sync'] = sync_result

            return jsonify(response)
        else:
            return jsonify({'error': 'Package not found'}), 404

    @app.route('/api/reviews/packages/<package_id>', methods=['DELETE'])
    def delete_package_endpoint(package_id):
        """
        Delete a package.

        REQ-tv-d00014-D: DELETE package endpoint.
        """
        repo = app.config['REPO_ROOT']
        data = request.get_json(silent=True) or {}
        user = data.get('user', 'api')

        # Get package name before deleting
        pf = load_packages(repo)
        pkg = pf.get_by_id(package_id)
        pkg_name = pkg.name if pkg else package_id

        success = delete_package(repo, package_id)

        if success:
            # REQ-tv-d00014-H: Auto-sync after write operation
            sync_result = trigger_auto_sync(f"Deleted package: {pkg_name}", user)

            response = {'success': True}
            if sync_result:
                response['sync'] = sync_result

            return jsonify(response)
        else:
            return jsonify({'error': 'Package not found or is default'}), 400

    @app.route('/api/reviews/packages/<package_id>/reqs/<req_id>', methods=['POST'])
    def add_req_to_package_endpoint(package_id, req_id):
        """
        Add a REQ to a package.

        REQ-tv-d00014-D: POST membership endpoint.
        """
        repo = app.config['REPO_ROOT']
        data = request.get_json(silent=True) or {}
        user = data.get('user', 'api')

        normalized_id = normalize_req_id(req_id)
        success = add_req_to_package(repo, package_id, normalized_id)

        if success:
            # REQ-tv-d00014-H: Auto-sync after write operation
            sync_result = trigger_auto_sync(f"Added REQ-{normalized_id} to package", user)

            response = {'success': True}
            if sync_result:
                response['sync'] = sync_result

            return jsonify(response)
        else:
            return jsonify({'error': 'Package not found'}), 404

    @app.route('/api/reviews/packages/<package_id>/reqs/<req_id>', methods=['DELETE'])
    def remove_req_from_package_endpoint(package_id, req_id):
        """
        Remove a REQ from a package.

        REQ-tv-d00014-D: DELETE membership endpoint.
        """
        repo = app.config['REPO_ROOT']
        data = request.get_json(silent=True) or {}
        user = data.get('user', 'api')

        normalized_id = normalize_req_id(req_id)
        success = remove_req_from_package(repo, package_id, normalized_id)

        if success:
            # REQ-tv-d00014-H: Auto-sync after write operation
            sync_result = trigger_auto_sync(f"Removed REQ-{normalized_id} from package", user)

            response = {'success': True}
            if sync_result:
                response['sync'] = sync_result

            return jsonify(response)
        else:
            return jsonify({'error': 'Package not found'}), 404

    @app.route('/api/reviews/packages/active', methods=['GET'])
    def get_active_package_endpoint():
        """
        Get the currently active package.

        REQ-tv-d00014-D: GET active endpoint.
        """
        repo = app.config['REPO_ROOT']
        pf = load_packages(repo)
        pkg = pf.get_active()

        if pkg:
            return jsonify(pkg.to_dict())
        else:
            return jsonify(None)

    @app.route('/api/reviews/packages/active', methods=['PUT'])
    def set_active_package_endpoint():
        """
        Set the active package.

        REQ-tv-d00014-D: PUT active endpoint.
        """
        repo = app.config['REPO_ROOT']
        data = request.get_json(silent=True) or {}
        user = data.get('user', 'api')

        package_id = data.get('packageId')

        # Load packages
        pf = load_packages(repo)

        # Validate package exists if setting active
        if package_id and not pf.get_by_id(package_id):
            return jsonify({'error': 'Package not found'}), 404

        # Set active package
        pf.activePackageId = package_id
        save_packages(repo, pf)

        # REQ-tv-d00014-H: Auto-sync after write operation
        msg = f"Set active package: {package_id}" if package_id else "Cleared active package"
        sync_result = trigger_auto_sync(msg, user)

        response = {'success': True, 'activePackageId': package_id}
        if sync_result:
            response['sync'] = sync_result

        return jsonify(response)

    # ==========================================================================
    # Git Sync API
    # REQ-tv-d00014-E: Sync endpoints for status, push, fetch, fetch-all-package
    # ==========================================================================

    @app.route('/api/reviews/sync/status', methods=['GET'])
    def get_sync_status_endpoint():
        """
        Get the current sync status.

        REQ-tv-d00014-E: GET status endpoint.
        """
        repo = app.config['REPO_ROOT']

        # Get basic status info
        has_changes = has_reviews_changes(repo)
        context = get_current_package_context(repo)

        status = {
            'has_changes': has_changes,
            'package_id': context[0] if context else None,
            'user': context[1] if context else None,
            'auto_sync_enabled': app.config.get('AUTO_SYNC', True)
        }

        return jsonify(status)

    @app.route('/api/reviews/sync/push', methods=['POST'])
    def sync_push():
        """
        Manually trigger a sync (commit and push).

        REQ-tv-d00014-E: POST push endpoint.
        """
        repo = app.config['REPO_ROOT']
        data = request.get_json(silent=True) or {}
        user = data.get('user', 'manual')
        message = data.get('message', 'Manual sync')

        success, msg = commit_and_push_reviews(repo, message, user)
        return jsonify({'success': success, 'message': msg})

    @app.route('/api/reviews/sync/fetch', methods=['POST'])
    def sync_fetch():
        """
        Fetch latest review data from remote.

        REQ-tv-d00014-E: POST fetch endpoint.
        """
        repo = app.config['REPO_ROOT']

        # Get current package context
        context = get_current_package_context(repo)
        if context[0]:
            branches = fetch_package_branches(repo, context[0])
            return jsonify({
                'success': True,
                'package_id': context[0],
                'branches_fetched': branches
            })
        else:
            return jsonify({
                'success': True,
                'message': 'Not on a review branch',
                'branches_fetched': []
            })

    @app.route('/api/reviews/sync/fetch-all-package', methods=['POST'])
    def sync_fetch_all_package():
        """
        Fetch and merge review data from all users' branches for the current package.

        REQ-tv-d00014-E: POST fetch-all-package endpoint.
        """
        repo = app.config['REPO_ROOT']

        # Get current package context from branch name
        context = get_current_package_context(repo)
        if not context[0]:
            # Not on a review branch - return empty data
            return jsonify({
                'threads': {},
                'flags': {},
                'contributors': [],
                'error': 'Not on a review branch'
            })

        package_id = context[0]

        # Fetch remote branches (if remote exists)
        branches = fetch_package_branches(repo, package_id)

        # Return information about fetched branches
        return jsonify({
            'success': True,
            'package_id': package_id,
            'branches': branches
        })

    return app


def main():
    """Run the review server"""
    import argparse

    parser = argparse.ArgumentParser(description='Review API Server')
    parser.add_argument('--port', type=int, default=8080, help='Port to run on')
    parser.add_argument('--host', default='0.0.0.0', help='Host to bind to')
    parser.add_argument('--repo', type=Path, default=Path.cwd(), help='Repository root')
    parser.add_argument('--static', type=Path, default=None, help='Static files directory')
    parser.add_argument('--debug', action='store_true', help='Enable debug mode')
    parser.add_argument('--no-auto-sync', action='store_true',
                        help='Disable automatic git commit/push after changes')

    args = parser.parse_args()

    auto_sync = not args.no_auto_sync
    static_dir = args.static or args.repo.resolve()
    app = create_app(args.repo.resolve(), static_dir=static_dir, auto_sync=auto_sync)

    sync_status = "ENABLED" if auto_sync else "DISABLED"
    print(f"""
======================================
  Review API Server
======================================

Repository: {args.repo.resolve()}
Server:     http://{args.host}:{args.port}
Auto-Sync:  {sync_status}

API Endpoints:
  GET  /api/health                    - Health check
  GET  /api/reviews/reqs/<id>/flag    - Get review flag
  POST /api/reviews/reqs/<id>/flag    - Set review flag
  POST /api/reviews/reqs/<id>/threads - Create thread
  POST /api/reviews/reqs/<id>/threads/<tid>/comments - Add comment
  POST /api/reviews/reqs/<id>/threads/<tid>/resolve - Resolve thread
  POST /api/reviews/reqs/<id>/threads/<tid>/unresolve - Unresolve thread
  GET  /api/reviews/reqs/<id>/status  - Get REQ status
  POST /api/reviews/reqs/<id>/status  - Change REQ status
  GET  /api/reviews/reqs/<id>/requests - Get status requests
  POST /api/reviews/reqs/<id>/requests - Create status request
  POST /api/reviews/reqs/<id>/requests/<rid>/approvals - Add approval
  GET  /api/reviews/packages          - List packages
  POST /api/reviews/packages          - Create package
  GET  /api/reviews/packages/<id>     - Get package
  PUT  /api/reviews/packages/<id>     - Update package
  DELETE /api/reviews/packages/<id>   - Delete package
  POST /api/reviews/packages/<id>/reqs/<req_id> - Add REQ to package
  DELETE /api/reviews/packages/<id>/reqs/<req_id> - Remove REQ from package
  GET  /api/reviews/packages/active   - Get active package
  PUT  /api/reviews/packages/active   - Set active package
  GET  /api/reviews/sync/status       - Get sync status
  POST /api/reviews/sync/push         - Manual sync
  POST /api/reviews/sync/fetch        - Fetch from remote
  POST /api/reviews/sync/fetch-all-package - Fetch all package branches

Press Ctrl+C to stop
""")

    app.run(host=args.host, port=args.port, debug=args.debug)


if __name__ == '__main__':
    main()
