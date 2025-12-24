#!/usr/bin/env python3
"""
Tests for review packages integration with HTML report.

Tests the integration of package management into the review system,
including HTML injection and JavaScript module loading.

IMPLEMENTS REQUIREMENTS:
    REQ-d00092: HTML Report Integration (package management)
"""

import pytest
from pathlib import Path


class TestGetPackagesPanelHtml:
    """Test get_packages_panel_html function"""

    def test_returns_html_string(self):
        """Should return HTML string with packages panel structure"""
        from tools.spec_review.review_integration import get_packages_panel_html
        html = get_packages_panel_html()

        assert isinstance(html, str)
        assert len(html) > 0

    def test_contains_panel_structure(self):
        """Should contain the required panel elements"""
        from tools.spec_review.review_integration import get_packages_panel_html
        html = get_packages_panel_html()

        # Check for main panel container
        assert 'review-packages-panel' in html
        assert 'reviewPackagesPanel' in html

        # Check for header
        assert 'packages-header' in html
        assert 'Review Packages' in html

        # Check for content area
        assert 'packages-content' in html
        assert 'package-list' in html

        # Check for create button
        assert '+ New Package' in html or 'New Package' in html

        # Check for collapse icon
        assert 'collapse-icon' in html

    def test_onclick_handlers_present(self):
        """Should have onclick handlers for interactivity"""
        from tools.spec_review.review_integration import get_packages_panel_html
        html = get_packages_panel_html()

        # Toggle panel
        assert 'togglePackagesPanel' in html

        # Create package
        assert 'showCreatePackageDialog' in html


class TestReviewJsFilesIncludesPackages:
    """Test that review-packages.js is included in JS files list"""

    def test_includes_packages_js(self):
        """Should include review-packages.js in the list"""
        from tools.spec_review.review_integration import get_review_js_files

        js_files = get_review_js_files()
        file_names = [f.name for f in js_files]

        assert 'review-packages.js' in file_names

    def test_packages_js_exists(self):
        """The review-packages.js file should exist"""
        from tools.spec_review.review_integration import get_review_js_files

        js_files = get_review_js_files()
        packages_file = next((f for f in js_files if f.name == 'review-packages.js'), None)

        assert packages_file is not None
        assert packages_file.exists()


class TestPackagesCssStyles:
    """Test that CSS styles for packages panel are included"""

    def test_css_includes_packages_panel_styles(self):
        """CSS should include styles for packages panel"""
        from tools.spec_review.review_integration import get_review_css

        css = get_review_css()

        # Check for main panel styles
        assert '.review-packages-panel' in css
        assert '.packages-header' in css
        assert '.packages-content' in css
        assert '.package-list' in css
        assert '.package-item' in css
        assert '.package-name' in css
        assert '.package-count' in css

    def test_css_includes_visibility_toggle(self):
        """CSS should hide panel when review mode is not active"""
        from tools.spec_review.review_integration import get_review_css

        css = get_review_css()

        # Should be hidden by default
        assert 'display: none' in css or 'display:none' in css

        # Should show when review mode active
        assert 'body.review-mode-active .review-packages-panel' in css


class TestPackagesJsContent:
    """Test the content of review-packages.js"""

    @pytest.fixture
    def packages_js_content(self):
        """Read the packages JS file content"""
        js_dir = Path(__file__).parent.parent / 'js'
        packages_file = js_dir / 'review-packages.js'
        return packages_file.read_text()

    def test_exports_required_functions(self, packages_js_content):
        """Should export all required functions to ReviewSystem"""
        required_exports = [
            'fetchPackages',
            'createPackage',
            'deletePackage',
            'setActivePackage',
            'addReqToPackage',
            'removeReqFromPackage',
            'addReqToActivePackage',
            'renderPackagesPanel',
            'togglePackagesPanel',
            'showCreatePackageDialog',
            'initPackagesPanel',
            'applyPackageFilter',
        ]

        for fn_name in required_exports:
            assert f'RS.{fn_name}' in packages_js_content or \
                   f"RS['{fn_name}']" in packages_js_content, \
                   f"Missing export: {fn_name}"

    def test_uses_api_endpoints(self, packages_js_content):
        """Should use correct API endpoints"""
        assert '/api/reviews/packages' in packages_js_content

    def test_has_filter_function(self, packages_js_content):
        """Should have package filter functionality"""
        assert 'applyPackageFilter' in packages_js_content
        assert 'filterReqIds' in packages_js_content or 'filter' in packages_js_content
