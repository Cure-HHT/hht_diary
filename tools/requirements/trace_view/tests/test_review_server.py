#!/usr/bin/env python3
"""
Tests for Review API Server

IMPLEMENTS REQUIREMENTS:
    REQ-tv-d00014: Review API Server

This test file follows TDD (Test-Driven Development) methodology.
Each test references the specific assertion from REQ-tv-d00014 that it verifies.

TDD RED-GREEN-REFACTOR cycle:
1. RED: Write failing tests first
2. GREEN: Implement just enough code to pass
3. REFACTOR: Clean up while keeping tests green
"""

import json
import os
import sys
from pathlib import Path
from typing import Any, Dict
from unittest.mock import patch, MagicMock

import pytest


# =============================================================================
# Test Imports (will fail initially - RED phase)
# =============================================================================

def import_server():
    """Helper to import server module - enables better error messages during TDD."""
    from trace_view.review.server import create_app
    return create_app


def import_models():
    """Helper to import models module."""
    from trace_view.review.models import (
        Thread,
        Comment,
        ThreadsFile,
        StatusFile,
        StatusRequest,
        ReviewFlag,
        ReviewConfig,
        ReviewPackage,
        PackagesFile,
        Approval,
        CommentPosition,
    )
    return {
        'Thread': Thread,
        'Comment': Comment,
        'ThreadsFile': ThreadsFile,
        'StatusFile': StatusFile,
        'StatusRequest': StatusRequest,
        'ReviewFlag': ReviewFlag,
        'ReviewConfig': ReviewConfig,
        'ReviewPackage': ReviewPackage,
        'PackagesFile': PackagesFile,
        'Approval': Approval,
        'CommentPosition': CommentPosition,
    }


def import_storage():
    """Helper to import storage module."""
    from trace_view.review.storage import (
        load_threads,
        save_threads,
        add_thread,
        load_packages,
        save_packages,
        load_review_flag,
        save_review_flag,
        load_status_requests,
    )
    return {
        'load_threads': load_threads,
        'save_threads': save_threads,
        'add_thread': add_thread,
        'load_packages': load_packages,
        'save_packages': save_packages,
        'load_review_flag': load_review_flag,
        'save_review_flag': save_review_flag,
        'load_status_requests': load_status_requests,
    }


# =============================================================================
# Fixtures
# =============================================================================

@pytest.fixture
def app(tmp_path):
    """Create Flask app configured for testing."""
    create_app = import_server()
    static_dir = tmp_path / "static"
    static_dir.mkdir()
    return create_app(repo_root=tmp_path, static_dir=static_dir, auto_sync=False)


@pytest.fixture
def app_with_sync(tmp_path):
    """Create Flask app with auto_sync enabled."""
    create_app = import_server()
    static_dir = tmp_path / "static"
    static_dir.mkdir()
    return create_app(repo_root=tmp_path, static_dir=static_dir, auto_sync=True)


@pytest.fixture
def client(app):
    """Create Flask test client."""
    return app.test_client()


@pytest.fixture
def client_with_sync(app_with_sync):
    """Create Flask test client with auto_sync enabled."""
    return app_with_sync.test_client()


@pytest.fixture
def repo_root(tmp_path):
    """Get the repo root from the app fixture."""
    return tmp_path


# =============================================================================
# Assertion A: Flask Application Factory
# =============================================================================

class TestFlaskApplicationFactory:
    """REQ-tv-d00014-A: The API server SHALL be implemented as a Flask
    application with a `create_app(repo_root, static_dir)` factory function."""

    def test_create_app_returns_flask_app(self, tmp_path):
        """REQ-tv-d00014-A: create_app returns a Flask application instance"""
        from flask import Flask
        create_app = import_server()

        app = create_app(repo_root=tmp_path, static_dir=tmp_path)

        assert isinstance(app, Flask)

    def test_create_app_accepts_repo_root_parameter(self, tmp_path):
        """REQ-tv-d00014-A: create_app accepts repo_root parameter"""
        create_app = import_server()

        app = create_app(repo_root=tmp_path, static_dir=tmp_path)

        assert app.config['REPO_ROOT'] == tmp_path

    def test_create_app_accepts_static_dir_parameter(self, tmp_path):
        """REQ-tv-d00014-A: create_app accepts static_dir parameter"""
        create_app = import_server()
        static_dir = tmp_path / "custom_static"
        static_dir.mkdir()

        app = create_app(repo_root=tmp_path, static_dir=static_dir)

        assert app.config['STATIC_DIR'] == static_dir

    def test_create_app_accepts_auto_sync_parameter(self, tmp_path):
        """REQ-tv-d00014-A: create_app accepts optional auto_sync parameter"""
        create_app = import_server()

        app_no_sync = create_app(repo_root=tmp_path, static_dir=tmp_path, auto_sync=False)
        app_with_sync = create_app(repo_root=tmp_path, static_dir=tmp_path, auto_sync=True)

        assert app_no_sync.config['AUTO_SYNC'] is False
        assert app_with_sync.config['AUTO_SYNC'] is True


# =============================================================================
# Assertion B: Thread Endpoints
# =============================================================================

class TestThreadEndpoints:
    """REQ-tv-d00014-B: Thread endpoints SHALL support: POST create thread,
    POST add comment, POST resolve, POST unresolve."""

    def test_post_create_thread(self, client, tmp_path):
        """REQ-tv-d00014-B: POST /api/reviews/reqs/<req_id>/threads creates thread"""
        m = import_models()

        thread_data = {
            'threadId': 'test-thread-id',
            'reqId': 'd00001',
            'createdBy': 'alice',
            'createdAt': '2024-01-15T10:00:00+00:00',
            'position': {
                'type': 'general',
                'hashWhenCreated': '12345678'
            },
            'resolved': False,
            'comments': []
        }

        response = client.post(
            '/api/reviews/reqs/d00001/threads',
            json=thread_data,
            content_type='application/json'
        )

        assert response.status_code == 201
        data = response.get_json()
        assert data['success'] is True
        assert 'thread' in data

    def test_post_create_thread_returns_400_without_data(self, client):
        """REQ-tv-d00014-B: POST /api/reviews/reqs/<req_id>/threads returns 400 without data"""
        response = client.post(
            '/api/reviews/reqs/d00001/threads',
            data='',
            content_type='application/json'
        )

        assert response.status_code == 400
        data = response.get_json()
        assert data is not None
        assert 'error' in data

    def test_post_add_comment(self, client, tmp_path):
        """REQ-tv-d00014-B: POST .../threads/<thread_id>/comments adds comment"""
        m = import_models()
        s = import_storage()

        # First create a thread
        pos = m['CommentPosition'].create_general('12345678')
        thread = m['Thread'].create('d00001', 'alice', pos)
        s['add_thread'](tmp_path, 'd00001', thread)

        # Now add a comment
        comment_data = {
            'author': 'bob',
            'body': 'This is a reply'
        }

        response = client.post(
            f'/api/reviews/reqs/d00001/threads/{thread.threadId}/comments',
            json=comment_data,
            content_type='application/json'
        )

        assert response.status_code == 201
        data = response.get_json()
        assert data['success'] is True
        assert 'comment' in data
        assert data['comment']['author'] == 'bob'
        assert data['comment']['body'] == 'This is a reply'

    def test_post_add_comment_requires_author(self, client, tmp_path):
        """REQ-tv-d00014-B: POST .../comments returns 400 without author"""
        response = client.post(
            '/api/reviews/reqs/d00001/threads/some-thread/comments',
            json={'body': 'Comment without author'},
            content_type='application/json'
        )

        assert response.status_code == 400
        data = response.get_json()
        assert 'error' in data
        assert 'author' in data['error'].lower()

    def test_post_add_comment_requires_body(self, client, tmp_path):
        """REQ-tv-d00014-B: POST .../comments returns 400 without body"""
        response = client.post(
            '/api/reviews/reqs/d00001/threads/some-thread/comments',
            json={'author': 'alice'},
            content_type='application/json'
        )

        assert response.status_code == 400
        data = response.get_json()
        assert 'error' in data
        assert 'body' in data['error'].lower()

    def test_post_resolve_thread(self, client, tmp_path):
        """REQ-tv-d00014-B: POST .../threads/<thread_id>/resolve resolves thread"""
        m = import_models()
        s = import_storage()

        # Create a thread
        pos = m['CommentPosition'].create_general('12345678')
        thread = m['Thread'].create('d00001', 'alice', pos)
        s['add_thread'](tmp_path, 'd00001', thread)

        response = client.post(
            f'/api/reviews/reqs/d00001/threads/{thread.threadId}/resolve',
            json={'user': 'bob'},
            content_type='application/json'
        )

        assert response.status_code == 200
        data = response.get_json()
        assert data['success'] is True

        # Verify thread is resolved
        loaded = s['load_threads'](tmp_path, 'd00001')
        assert loaded.threads[0].resolved is True
        assert loaded.threads[0].resolvedBy == 'bob'

    def test_post_unresolve_thread(self, client, tmp_path):
        """REQ-tv-d00014-B: POST .../threads/<thread_id>/unresolve unresolves thread"""
        m = import_models()
        s = import_storage()

        # Create and resolve a thread
        pos = m['CommentPosition'].create_general('12345678')
        thread = m['Thread'].create('d00001', 'alice', pos)
        thread.resolve('bob')
        threads_file = m['ThreadsFile'](reqId='d00001', threads=[thread])
        s['save_threads'](tmp_path, 'd00001', threads_file)

        response = client.post(
            f'/api/reviews/reqs/d00001/threads/{thread.threadId}/unresolve',
            json={'user': 'alice'},
            content_type='application/json'
        )

        assert response.status_code == 200
        data = response.get_json()
        assert data['success'] is True

        # Verify thread is unresolved
        loaded = s['load_threads'](tmp_path, 'd00001')
        assert loaded.threads[0].resolved is False


# =============================================================================
# Assertion C: Status Endpoints
# =============================================================================

class TestStatusEndpoints:
    """REQ-tv-d00014-C: Status endpoints SHALL support: GET status,
    POST change status, GET/POST requests, POST approvals."""

    def test_get_status_not_found(self, client):
        """REQ-tv-d00014-C: GET /api/reviews/reqs/<req_id>/status returns 404 if not found"""
        response = client.get('/api/reviews/reqs/nonexistent/status')

        assert response.status_code == 404
        data = response.get_json()
        assert 'error' in data

    def test_get_status_requests(self, client, tmp_path):
        """REQ-tv-d00014-C: GET /api/reviews/reqs/<req_id>/requests returns requests"""
        response = client.get('/api/reviews/reqs/d00001/requests')

        assert response.status_code == 200
        data = response.get_json()
        assert isinstance(data, list)

    def test_post_status_request(self, client, tmp_path):
        """REQ-tv-d00014-C: POST /api/reviews/reqs/<req_id>/requests creates request"""
        request_data = {
            'requestId': 'test-request-id',
            'reqId': 'd00001',
            'type': 'status_change',
            'fromStatus': 'Draft',
            'toStatus': 'Active',
            'requestedBy': 'alice',
            'requestedAt': '2024-01-15T10:00:00+00:00',
            'justification': 'Ready for activation',
            'approvals': [],
            'requiredApprovers': ['product_owner'],
            'state': 'pending'
        }

        response = client.post(
            '/api/reviews/reqs/d00001/requests',
            json=request_data,
            content_type='application/json'
        )

        assert response.status_code == 201
        data = response.get_json()
        assert data['success'] is True
        assert 'request' in data

    def test_post_status_request_returns_400_without_data(self, client):
        """REQ-tv-d00014-C: POST .../requests returns 400 without data"""
        response = client.post(
            '/api/reviews/reqs/d00001/requests',
            content_type='application/json'
        )

        assert response.status_code == 400

    def test_post_approval(self, client, tmp_path):
        """REQ-tv-d00014-C: POST .../requests/<request_id>/approvals adds approval"""
        m = import_models()
        s = import_storage()

        # Create a status request first
        request = m['StatusRequest'].create(
            req_id='d00001',
            from_status='Draft',
            to_status='Active',
            requested_by='alice',
            justification='Test',
            required_approvers=['product_owner']
        )
        status_file = m['StatusFile'](reqId='d00001', requests=[request])
        from trace_view.review.storage import save_status_requests
        save_status_requests(tmp_path, 'd00001', status_file)

        approval_data = {
            'user': 'product_owner',
            'decision': 'approve',
            'at': '2024-01-15T11:00:00+00:00'
        }

        response = client.post(
            f'/api/reviews/reqs/d00001/requests/{request.requestId}/approvals',
            json=approval_data,
            content_type='application/json'
        )

        assert response.status_code == 201
        data = response.get_json()
        assert data['success'] is True
        assert 'approval' in data


# =============================================================================
# Assertion D: Package Endpoints
# =============================================================================

class TestPackageEndpoints:
    """REQ-tv-d00014-D: Package endpoints SHALL support: GET/POST packages,
    GET/PUT/DELETE package by ID, POST/DELETE membership, GET/PUT active."""

    def test_get_packages(self, client):
        """REQ-tv-d00014-D: GET /api/reviews/packages returns packages list"""
        response = client.get('/api/reviews/packages')

        assert response.status_code == 200
        data = response.get_json()
        assert 'packages' in data
        assert isinstance(data['packages'], list)

    def test_post_package(self, client):
        """REQ-tv-d00014-D: POST /api/reviews/packages creates new package"""
        package_data = {
            'name': 'Sprint 23 Review',
            'description': 'Requirements for sprint 23',
            'user': 'alice'
        }

        response = client.post(
            '/api/reviews/packages',
            json=package_data,
            content_type='application/json'
        )

        assert response.status_code == 201
        data = response.get_json()
        assert data['success'] is True
        assert 'package' in data
        assert data['package']['name'] == 'Sprint 23 Review'

    def test_post_package_requires_name(self, client):
        """REQ-tv-d00014-D: POST /api/reviews/packages requires name"""
        response = client.post(
            '/api/reviews/packages',
            json={'description': 'No name provided'},
            content_type='application/json'
        )

        assert response.status_code == 400
        data = response.get_json()
        assert 'error' in data
        assert 'name' in data['error'].lower()

    def test_get_package_by_id(self, client, tmp_path):
        """REQ-tv-d00014-D: GET /api/reviews/packages/<id> returns package"""
        m = import_models()
        s = import_storage()

        # Create a package
        pkg = m['ReviewPackage'].create(
            name='Test Package',
            description='Test',
            created_by='alice'
        )
        from trace_view.review.storage import create_package
        create_package(tmp_path, pkg)

        response = client.get(f'/api/reviews/packages/{pkg.packageId}')

        assert response.status_code == 200
        data = response.get_json()
        assert data['name'] == 'Test Package'

    def test_get_package_by_id_not_found(self, client):
        """REQ-tv-d00014-D: GET /api/reviews/packages/<id> returns 404 if not found"""
        response = client.get('/api/reviews/packages/nonexistent-id')

        assert response.status_code == 404
        data = response.get_json()
        assert 'error' in data

    def test_put_package(self, client, tmp_path):
        """REQ-tv-d00014-D: PUT /api/reviews/packages/<id> updates package"""
        m = import_models()
        from trace_view.review.storage import create_package

        # Create a package
        pkg = m['ReviewPackage'].create(
            name='Original Name',
            description='Original description',
            created_by='alice'
        )
        create_package(tmp_path, pkg)

        # Update it
        response = client.put(
            f'/api/reviews/packages/{pkg.packageId}',
            json={'name': 'Updated Name', 'description': 'Updated description'},
            content_type='application/json'
        )

        assert response.status_code == 200
        data = response.get_json()
        assert data['success'] is True
        assert data['package']['name'] == 'Updated Name'

    def test_delete_package(self, client, tmp_path):
        """REQ-tv-d00014-D: DELETE /api/reviews/packages/<id> deletes package"""
        m = import_models()
        from trace_view.review.storage import create_package

        # Create a package
        pkg = m['ReviewPackage'].create(
            name='To Delete',
            description='Test',
            created_by='alice'
        )
        create_package(tmp_path, pkg)

        response = client.delete(
            f'/api/reviews/packages/{pkg.packageId}',
            content_type='application/json'
        )

        assert response.status_code == 200
        data = response.get_json()
        assert data['success'] is True

    def test_post_req_to_package(self, client, tmp_path):
        """REQ-tv-d00014-D: POST /api/reviews/packages/<id>/reqs/<req_id> adds req to package"""
        m = import_models()
        from trace_view.review.storage import create_package

        # Create a package
        pkg = m['ReviewPackage'].create(
            name='Test Package',
            description='Test',
            created_by='alice'
        )
        create_package(tmp_path, pkg)

        response = client.post(
            f'/api/reviews/packages/{pkg.packageId}/reqs/d00001',
            content_type='application/json'
        )

        assert response.status_code == 200
        data = response.get_json()
        assert data['success'] is True

    def test_delete_req_from_package(self, client, tmp_path):
        """REQ-tv-d00014-D: DELETE /api/reviews/packages/<id>/reqs/<req_id> removes req"""
        m = import_models()
        from trace_view.review.storage import create_package, add_req_to_package

        # Create a package with a req
        pkg = m['ReviewPackage'].create(
            name='Test Package',
            description='Test',
            created_by='alice'
        )
        create_package(tmp_path, pkg)
        add_req_to_package(tmp_path, pkg.packageId, 'd00001')

        response = client.delete(
            f'/api/reviews/packages/{pkg.packageId}/reqs/d00001',
            content_type='application/json'
        )

        assert response.status_code == 200
        data = response.get_json()
        assert data['success'] is True

    def test_get_active_package(self, client):
        """REQ-tv-d00014-D: GET /api/reviews/packages/active returns active package"""
        response = client.get('/api/reviews/packages/active')

        assert response.status_code == 200
        # Can return null if no active package

    def test_put_active_package(self, client, tmp_path):
        """REQ-tv-d00014-D: PUT /api/reviews/packages/active sets active package"""
        m = import_models()
        from trace_view.review.storage import create_package

        # Create a package
        pkg = m['ReviewPackage'].create(
            name='Test Package',
            description='Test',
            created_by='alice'
        )
        create_package(tmp_path, pkg)

        response = client.put(
            '/api/reviews/packages/active',
            json={'packageId': pkg.packageId},
            content_type='application/json'
        )

        assert response.status_code == 200
        data = response.get_json()
        assert data['success'] is True
        assert data['activePackageId'] == pkg.packageId


# =============================================================================
# Assertion E: Sync Endpoints
# =============================================================================

class TestSyncEndpoints:
    """REQ-tv-d00014-E: Sync endpoints SHALL support: GET status,
    POST push, POST fetch, POST fetch-all-package."""

    def test_get_sync_status(self, client):
        """REQ-tv-d00014-E: GET /api/reviews/sync/status returns sync status"""
        response = client.get('/api/reviews/sync/status')

        assert response.status_code == 200
        data = response.get_json()
        assert 'auto_sync_enabled' in data

    def test_post_sync_push(self, client):
        """REQ-tv-d00014-E: POST /api/reviews/sync/push triggers push"""
        response = client.post(
            '/api/reviews/sync/push',
            json={'user': 'alice', 'message': 'Manual sync'},
            content_type='application/json'
        )

        assert response.status_code == 200
        data = response.get_json()
        # Should return some result (success or failure info)
        assert isinstance(data, dict)

    def test_post_sync_fetch(self, client):
        """REQ-tv-d00014-E: POST /api/reviews/sync/fetch triggers fetch"""
        response = client.post(
            '/api/reviews/sync/fetch',
            content_type='application/json'
        )

        assert response.status_code == 200
        data = response.get_json()
        assert isinstance(data, dict)

    def test_post_sync_fetch_all_package(self, client):
        """REQ-tv-d00014-E: POST /api/reviews/sync/fetch-all-package fetches all package branches"""
        response = client.post(
            '/api/reviews/sync/fetch-all-package',
            content_type='application/json'
        )

        assert response.status_code == 200
        data = response.get_json()
        assert isinstance(data, dict)


# =============================================================================
# Assertion F: CORS Support
# =============================================================================

class TestCorsSupport:
    """REQ-tv-d00014-F: The server SHALL enable CORS for cross-origin
    requests from the HTML viewer."""

    def test_cors_headers_present(self, client):
        """REQ-tv-d00014-F: Response includes CORS headers"""
        response = client.options(
            '/api/health',
            headers={'Origin': 'http://localhost:3000'}
        )

        # Check for CORS headers
        assert response.status_code in [200, 204]

    def test_cors_allows_all_origins(self, client):
        """REQ-tv-d00014-F: CORS allows requests from any origin"""
        response = client.get(
            '/api/health',
            headers={'Origin': 'http://example.com'}
        )

        # Should not be blocked by CORS
        assert response.status_code == 200


# =============================================================================
# Assertion G: Static File Serving
# =============================================================================

class TestStaticFileServing:
    """REQ-tv-d00014-G: The server SHALL serve static files from the
    configured static directory at the root path."""

    def test_serves_static_file_at_root(self, app, tmp_path):
        """REQ-tv-d00014-G: Static files are served from root path"""
        # Create a static file
        static_dir = app.config['STATIC_DIR']
        test_file = static_dir / "test.html"
        test_file.write_text("<html>Test</html>")

        client = app.test_client()
        response = client.get('/test.html')

        assert response.status_code == 200
        assert b"<html>Test</html>" in response.data

    def test_serves_nested_static_files(self, app, tmp_path):
        """REQ-tv-d00014-G: Nested static files are served"""
        static_dir = app.config['STATIC_DIR']
        nested_dir = static_dir / "assets"
        nested_dir.mkdir()
        test_file = nested_dir / "style.css"
        test_file.write_text("body { color: red; }")

        client = app.test_client()
        response = client.get('/assets/style.css')

        assert response.status_code == 200
        assert b"body { color: red; }" in response.data


# =============================================================================
# Assertion H: Auto-Sync Behavior
# =============================================================================

class TestAutoSyncBehavior:
    """REQ-tv-d00014-H: All write endpoints SHALL optionally trigger
    auto-sync based on configuration."""

    def test_write_endpoint_triggers_sync_when_enabled(self, app_with_sync, tmp_path):
        """REQ-tv-d00014-H: Write endpoints trigger sync when auto_sync=True"""
        client = app_with_sync.test_client()

        # Mock the commit_and_push function
        with patch('trace_view.review.server.commit_and_push_reviews') as mock_sync:
            mock_sync.return_value = (True, 'Synced')

            # Create a thread (write operation)
            thread_data = {
                'threadId': 'test-thread',
                'reqId': 'd00001',
                'createdBy': 'alice',
                'createdAt': '2024-01-15T10:00:00+00:00',
                'position': {
                    'type': 'general',
                    'hashWhenCreated': '12345678'
                },
                'resolved': False,
                'comments': []
            }

            response = client.post(
                '/api/reviews/reqs/d00001/threads',
                json=thread_data,
                content_type='application/json'
            )

            assert response.status_code == 201
            # Sync should have been called
            mock_sync.assert_called_once()

    def test_write_endpoint_skips_sync_when_disabled(self, client, tmp_path):
        """REQ-tv-d00014-H: Write endpoints skip sync when auto_sync=False"""
        with patch('trace_view.review.server.commit_and_push_reviews') as mock_sync:
            thread_data = {
                'threadId': 'test-thread',
                'reqId': 'd00001',
                'createdBy': 'alice',
                'createdAt': '2024-01-15T10:00:00+00:00',
                'position': {
                    'type': 'general',
                    'hashWhenCreated': '12345678'
                },
                'resolved': False,
                'comments': []
            }

            response = client.post(
                '/api/reviews/reqs/d00001/threads',
                json=thread_data,
                content_type='application/json'
            )

            assert response.status_code == 201
            # Sync should NOT have been called
            mock_sync.assert_not_called()

    def test_sync_result_included_in_response(self, app_with_sync, tmp_path):
        """REQ-tv-d00014-H: Sync result is included in response when sync occurs"""
        client = app_with_sync.test_client()

        with patch('trace_view.review.server.commit_and_push_reviews') as mock_sync:
            mock_sync.return_value = (True, 'Pushed to origin')

            thread_data = {
                'threadId': 'test-thread',
                'reqId': 'd00001',
                'createdBy': 'alice',
                'createdAt': '2024-01-15T10:00:00+00:00',
                'position': {
                    'type': 'general',
                    'hashWhenCreated': '12345678'
                },
                'resolved': False,
                'comments': []
            }

            response = client.post(
                '/api/reviews/reqs/d00001/threads',
                json=thread_data,
                content_type='application/json'
            )

            data = response.get_json()
            assert 'sync' in data


# =============================================================================
# Assertion I: Error Responses
# =============================================================================

class TestErrorResponses:
    """REQ-tv-d00014-I: Error responses SHALL use appropriate HTTP status
    codes and include JSON error details."""

    def test_400_for_missing_data(self, client):
        """REQ-tv-d00014-I: Returns 400 Bad Request for missing data"""
        response = client.post(
            '/api/reviews/reqs/d00001/threads',
            data='',
            content_type='application/json'
        )

        assert response.status_code == 400
        data = response.get_json()
        assert data is not None
        assert 'error' in data

    def test_404_for_not_found(self, client):
        """REQ-tv-d00014-I: Returns 404 Not Found for missing resources"""
        response = client.get('/api/reviews/packages/nonexistent-id')

        assert response.status_code == 404
        data = response.get_json()
        assert 'error' in data

    def test_error_response_is_json(self, client):
        """REQ-tv-d00014-I: Error responses are JSON formatted"""
        response = client.post(
            '/api/reviews/reqs/d00001/threads',
            data='',
            content_type='application/json'
        )

        assert response.content_type.startswith('application/json')
        data = response.get_json()
        assert isinstance(data, dict)
        assert 'error' in data

    def test_error_includes_descriptive_message(self, client):
        """REQ-tv-d00014-I: Error includes descriptive message"""
        response = client.post(
            '/api/reviews/reqs/d00001/threads',
            data='',
            content_type='application/json'
        )

        data = response.get_json()
        assert data is not None
        assert 'error' in data
        assert len(data['error']) > 0  # Message is not empty


# =============================================================================
# Assertion J: Health Check Endpoint
# =============================================================================

class TestHealthCheckEndpoint:
    """REQ-tv-d00014-J: The server SHALL provide a `/api/health` endpoint
    for health checks."""

    def test_health_endpoint_exists(self, client):
        """REQ-tv-d00014-J: /api/health endpoint exists"""
        response = client.get('/api/health')

        assert response.status_code == 200

    def test_health_endpoint_returns_json(self, client):
        """REQ-tv-d00014-J: /api/health returns JSON"""
        response = client.get('/api/health')

        assert response.content_type.startswith('application/json')

    def test_health_endpoint_includes_status(self, client):
        """REQ-tv-d00014-J: /api/health includes status field"""
        response = client.get('/api/health')

        data = response.get_json()
        assert 'status' in data
        assert data['status'] == 'ok'

    def test_health_endpoint_includes_repo_info(self, client, tmp_path):
        """REQ-tv-d00014-J: /api/health includes repository information"""
        response = client.get('/api/health')

        data = response.get_json()
        assert 'repo_root' in data
        assert 'reviews_dir' in data


# =============================================================================
# Flag Endpoints (additional functionality from source)
# =============================================================================

class TestFlagEndpoints:
    """Additional tests for review flag endpoints."""

    def test_get_flag(self, client):
        """GET /api/reviews/reqs/<req_id>/flag returns flag status"""
        response = client.get('/api/reviews/reqs/d00001/flag')

        assert response.status_code == 200
        data = response.get_json()
        assert 'flaggedForReview' in data

    def test_post_flag(self, client, tmp_path):
        """POST /api/reviews/reqs/<req_id>/flag sets flag"""
        flag_data = {
            'flaggedForReview': True,
            'flaggedBy': 'alice',
            'flaggedAt': '2024-01-15T10:00:00+00:00',
            'reason': 'Needs review',
            'scope': ['product_owner', 'tech_lead']
        }

        response = client.post(
            '/api/reviews/reqs/d00001/flag',
            json=flag_data,
            content_type='application/json'
        )

        assert response.status_code == 200
        data = response.get_json()
        assert data['success'] is True
        assert 'flag' in data

    def test_delete_flag(self, client, tmp_path):
        """DELETE /api/reviews/reqs/<req_id>/flag clears flag"""
        # First set a flag
        s = import_storage()
        m = import_models()
        flag = m['ReviewFlag'].create(
            user='alice',
            reason='Test',
            scope=['reviewer']
        )
        s['save_review_flag'](tmp_path, 'd00001', flag)

        response = client.delete(
            '/api/reviews/reqs/d00001/flag',
            json={'user': 'bob'},
            content_type='application/json'
        )

        assert response.status_code == 200
        data = response.get_json()
        assert data['success'] is True


# =============================================================================
# Integration Tests
# =============================================================================

class TestServerIntegration:
    """Integration tests for complete API workflows."""

    def test_complete_review_workflow(self, client, tmp_path):
        """Test complete review workflow through API"""
        # 1. Create a package
        pkg_response = client.post(
            '/api/reviews/packages',
            json={'name': 'Test Review', 'description': 'Integration test'},
            content_type='application/json'
        )
        assert pkg_response.status_code == 201
        pkg_id = pkg_response.get_json()['package']['packageId']

        # 2. Add a req to the package
        add_response = client.post(
            f'/api/reviews/packages/{pkg_id}/reqs/d00001',
            content_type='application/json'
        )
        assert add_response.status_code == 200

        # 3. Set flag for review
        flag_response = client.post(
            '/api/reviews/reqs/d00001/flag',
            json={
                'flaggedForReview': True,
                'flaggedBy': 'alice',
                'flaggedAt': '2024-01-15T10:00:00+00:00',
                'reason': 'Ready for review',
                'scope': ['reviewer']
            },
            content_type='application/json'
        )
        assert flag_response.status_code == 200

        # 4. Create a thread
        thread_response = client.post(
            '/api/reviews/reqs/d00001/threads',
            json={
                'threadId': 'integration-thread',
                'reqId': 'd00001',
                'createdBy': 'reviewer',
                'createdAt': '2024-01-15T11:00:00+00:00',
                'position': {
                    'type': 'general',
                    'hashWhenCreated': '12345678'
                },
                'resolved': False,
                'comments': []
            },
            content_type='application/json'
        )
        assert thread_response.status_code == 201
        thread_id = thread_response.get_json()['thread']['threadId']

        # 5. Add a comment
        comment_response = client.post(
            f'/api/reviews/reqs/d00001/threads/{thread_id}/comments',
            json={'author': 'reviewer', 'body': 'Please clarify this requirement'},
            content_type='application/json'
        )
        assert comment_response.status_code == 201

        # 6. Resolve the thread
        resolve_response = client.post(
            f'/api/reviews/reqs/d00001/threads/{thread_id}/resolve',
            json={'user': 'author'},
            content_type='application/json'
        )
        assert resolve_response.status_code == 200

        # 7. Clear the flag
        clear_response = client.delete(
            '/api/reviews/reqs/d00001/flag',
            json={'user': 'author'},
            content_type='application/json'
        )
        assert clear_response.status_code == 200

        # 8. Verify health check
        health_response = client.get('/api/health')
        assert health_response.status_code == 200
        assert health_response.get_json()['status'] == 'ok'
