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
from spec_review.review_data import (
    Thread,
    Comment,
    CommentPosition,
    ReviewFlag,
    StatusRequest,
    Approval,
    normalize_req_id,
)


def create_app(repo_root: Path, static_dir: Optional[Path] = None):
    """
    Create Flask app with review API endpoints.

    Args:
        repo_root: Repository root path for .reviews/ storage
        static_dir: Optional directory to serve static files from

    Returns:
        Flask application
    """
    app = Flask(__name__)
    CORS(app)  # Enable CORS for browser requests

    # Store repo_root in app config
    app.config['REPO_ROOT'] = repo_root
    app.config['STATIC_DIR'] = static_dir or repo_root

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
            return jsonify({'success': True, 'thread': thread.to_dict()}), 201
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
            return jsonify({'success': True, 'comment': comment.to_dict()}), 201
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
            return jsonify({'success': True}), 200
        except Exception as e:
            return jsonify({'error': str(e)}), 400

    @app.route('/api/reviews/reqs/<req_id>/threads/<thread_id>/unresolve', methods=['POST'])
    def unresolve_thread_endpoint(req_id, thread_id):
        """Unresolve a thread"""
        repo = app.config['REPO_ROOT']
        normalized_id = normalize_req_id(req_id)

        try:
            unresolve_thread(repo, normalized_id, thread_id)
            return jsonify({'success': True}), 200
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
            return jsonify({'success': True, 'flag': flag.to_dict()}), 200
        except Exception as e:
            return jsonify({'error': str(e)}), 400

    @app.route('/api/reviews/reqs/<req_id>/flag', methods=['DELETE'])
    def clear_flag(req_id):
        """Clear review flag for a requirement"""
        repo = app.config['REPO_ROOT']
        normalized_id = normalize_req_id(req_id)

        flag = ReviewFlag.create(normalized_id)
        flag.flaggedForReview = False
        save_review_flag(repo, normalized_id, flag)
        return jsonify({'success': True}), 200

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
            return jsonify({'success': True, 'request': status_request.to_dict()}), 201
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
            return jsonify({'success': True, 'approval': approval.to_dict()}), 201
        except Exception as e:
            return jsonify({'error': str(e)}), 400

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

    args = parser.parse_args()

    app = create_app(args.repo.resolve())

    print(f"""
======================================
  Spec Review API Server
======================================

Repository: {args.repo.resolve()}
Server:     http://{args.host}:{args.port}
Report:     http://localhost:{args.port}/validation-reports/REQ-report-review.html

API Endpoints:
  GET  /api/reviews                    - All review data
  GET  /api/reviews/reqs/<id>          - REQ review data
  POST /api/reviews/reqs/<id>/threads  - Create thread
  POST /api/reviews/reqs/<id>/threads/<tid>/comments - Add comment
  POST /api/reviews/reqs/<id>/requests - Create status request
  POST /api/reviews/reqs/<id>/requests/<rid>/approvals - Add approval

Press Ctrl+C to stop
""")

    app.run(host=args.host, port=args.port, debug=args.debug)


if __name__ == '__main__':
    main()
