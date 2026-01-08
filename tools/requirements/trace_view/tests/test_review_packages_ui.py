"""
Tests for Review Packages UI (REQ-d00092).

TDD Red Phase: These tests verify the Package Management UI integration
in the Spec Review System HTML report.

Each test function documents which assertion it verifies in its docstring.
The Elspais reporter extracts these references for traceability.

IMPLEMENTS REQUIREMENTS:
    REQ-d00092: HTML Report Integration (package management)
"""

from pathlib import Path

import pytest


# =============================================================================
# Test Fixtures
# =============================================================================

@pytest.fixture
def base_html_content():
    """Load the base.html template content."""
    import trace_view.html as html_module
    html_path = Path(html_module.__file__).parent
    base_template = html_path / "templates" / "base.html"
    return base_template.read_text()


@pytest.fixture
def review_styles_content():
    """Load the review-styles.css content."""
    import trace_view.html as html_module
    html_path = Path(html_module.__file__).parent
    styles_path = html_path / "templates" / "partials" / "review-styles.css"
    return styles_path.read_text()


@pytest.fixture
def review_packages_js_content():
    """Load the review-packages.js content."""
    import trace_view.html as html_module
    html_path = Path(html_module.__file__).parent
    js_path = html_path / "templates" / "partials" / "review" / "review-packages.js"
    return js_path.read_text()


# =============================================================================
# HTML Structure Tests - Packages Panel
# =============================================================================

class TestPackagesPanelHTML:
    """Tests for packages panel HTML structure in base.html."""

    def test_packages_panel_has_id(self, base_html_content):
        """
        REQ-d00092-PKG-A: The packages panel div SHALL have id="reviewPackagesPanel".
        """
        assert 'id="reviewPackagesPanel"' in base_html_content, \
            "Missing reviewPackagesPanel div with id"

    def test_packages_panel_has_class(self, base_html_content):
        """
        REQ-d00092-PKG-B: The packages panel div SHALL have class="review-packages-panel".
        """
        assert 'class="review-packages-panel"' in base_html_content, \
            "Missing review-packages-panel class on div"

    def test_packages_panel_inside_review_column(self, base_html_content):
        """
        REQ-d00092-PKG-C: The packages panel SHALL be inside the review-column div.
        """
        import re
        # Match review-column div containing reviewPackagesPanel
        pattern = r'<div[^>]*id="review-column"[^>]*>.*?id="reviewPackagesPanel"'
        match = re.search(pattern, base_html_content, re.DOTALL)
        assert match is not None, \
            "reviewPackagesPanel must be inside review-column div"

    def test_packages_panel_has_header(self, base_html_content):
        """
        REQ-d00092-PKG-D: The packages panel SHALL contain a header div with
        class="packages-header".
        """
        import re
        pattern = r'id="reviewPackagesPanel".*?class="packages-header"'
        match = re.search(pattern, base_html_content, re.DOTALL)
        assert match is not None, \
            "Packages panel must contain header with class packages-header"

    def test_packages_panel_has_content_area(self, base_html_content):
        """
        REQ-d00092-PKG-E: The packages panel SHALL contain a content div with
        class="packages-content".
        """
        import re
        pattern = r'id="reviewPackagesPanel".*?class="packages-content"'
        match = re.search(pattern, base_html_content, re.DOTALL)
        assert match is not None, \
            "Packages panel must contain content area with class packages-content"

    def test_packages_panel_has_package_list(self, base_html_content):
        """
        REQ-d00092-PKG-F: The packages content SHALL contain a div with
        class="package-list" for JS rendering.
        """
        import re
        pattern = r'class="packages-content".*?class="package-list"'
        match = re.search(pattern, base_html_content, re.DOTALL)
        assert match is not None, \
            "Packages content must contain package-list div"


# =============================================================================
# Package Header Tests
# =============================================================================

class TestPackagesPanelHeader:
    """Tests for packages panel header elements."""

    def test_header_has_collapse_icon(self, base_html_content):
        """
        REQ-d00092-PKG-G: The packages header SHALL contain a collapse icon span.
        """
        import re
        pattern = r'class="packages-header".*?class="collapse-icon"'
        match = re.search(pattern, base_html_content, re.DOTALL)
        assert match is not None, \
            "Packages header must contain collapse-icon span"

    def test_header_has_title(self, base_html_content):
        """
        REQ-d00092-PKG-H: The packages header SHALL contain an h3 title with
        text "Review Packages".
        """
        import re
        pattern = r'class="packages-header".*?<h3>Review Packages</h3>'
        match = re.search(pattern, base_html_content, re.DOTALL)
        assert match is not None, \
            "Packages header must contain h3 with 'Review Packages'"

    def test_header_has_create_button(self, base_html_content):
        """
        REQ-d00092-PKG-I: The packages header SHALL contain a "+ New Package"
        button that calls ReviewSystem.showCreatePackageDialog().
        """
        import re
        pattern = r'class="packages-header".*?<button[^>]*class="create-btn[^"]*"[^>]*>\+ New Package</button>'
        match = re.search(pattern, base_html_content, re.DOTALL)
        assert match is not None, \
            "Packages header must contain '+ New Package' button"

        # Verify onclick handler
        assert 'ReviewSystem.showCreatePackageDialog' in base_html_content, \
            "Create button must call ReviewSystem.showCreatePackageDialog"

    def test_header_has_filter_toggle(self, base_html_content):
        """
        REQ-d00092-PKG-J: The packages header SHALL contain a filter toggle button
        with id="packageFilterToggle".
        """
        assert 'id="packageFilterToggle"' in base_html_content, \
            "Missing packageFilterToggle button"

    def test_filter_toggle_calls_toggle_function(self, base_html_content):
        """
        REQ-d00092-PKG-K: The filter toggle button SHALL call
        ReviewSystem.togglePackageFilter() on click.
        """
        import re
        pattern = r'id="packageFilterToggle"[^>]*onclick="ReviewSystem\.togglePackageFilter\(event\)"'
        match = re.search(pattern, base_html_content, re.DOTALL)
        assert match is not None, \
            "Filter toggle must call ReviewSystem.togglePackageFilter(event)"

    def test_header_has_filter_indicator(self, base_html_content):
        """
        REQ-d00092-PKG-L: The packages header SHALL contain a filter indicator
        span with id="packageFilterIndicator".
        """
        assert 'id="packageFilterIndicator"' in base_html_content, \
            "Missing packageFilterIndicator span"

    def test_header_toggle_on_click(self, base_html_content):
        """
        REQ-d00092-PKG-M: The packages header SHALL toggle the panel when clicked
        via ReviewSystem.togglePackagesPanel().
        """
        import re
        pattern = r'class="packages-header"[^>]*onclick="ReviewSystem\.togglePackagesPanel\(\)"'
        match = re.search(pattern, base_html_content, re.DOTALL)
        assert match is not None, \
            "Packages header must call ReviewSystem.togglePackagesPanel() on click"


# =============================================================================
# CSS Tests - Packages Panel
# =============================================================================

class TestPackagesPanelCSS:
    """Tests for packages panel CSS styling."""

    def test_packages_panel_class_exists(self, review_styles_content):
        """
        REQ-d00092-PKG-N: The CSS SHALL define a .review-packages-panel class.
        """
        assert '.review-packages-panel' in review_styles_content, \
            "Missing .review-packages-panel CSS class"

    def test_packages_panel_hidden_by_default(self, review_styles_content):
        """
        REQ-d00092-PKG-O: The .review-packages-panel SHALL have display: none
        by default (shown via review-mode-active).
        """
        import re
        pattern = r'\.review-packages-panel\s*\{[^}]*display:\s*none'
        match = re.search(pattern, review_styles_content, re.DOTALL)
        assert match is not None, \
            ".review-packages-panel must have display: none by default"

    def test_packages_panel_shown_in_review_mode(self, review_styles_content):
        """
        REQ-d00092-PKG-P: The CSS SHALL show .review-packages-panel when
        body.review-mode-active is set.
        """
        import re
        pattern = r'body\.review-mode-active\s+\.review-packages-panel\s*\{[^}]*display:\s*block'
        match = re.search(pattern, review_styles_content, re.DOTALL)
        assert match is not None, \
            ".review-packages-panel must display:block when review-mode-active"

    def test_packages_header_class_exists(self, review_styles_content):
        """
        REQ-d00092-PKG-Q: The CSS SHALL define a .packages-header class.
        """
        assert '.packages-header' in review_styles_content, \
            "Missing .packages-header CSS class"

    def test_packages_content_class_exists(self, review_styles_content):
        """
        REQ-d00092-PKG-R: The CSS SHALL define a .packages-content class.
        """
        assert '.packages-content' in review_styles_content, \
            "Missing .packages-content CSS class"

    def test_package_list_class_exists(self, review_styles_content):
        """
        REQ-d00092-PKG-S: The CSS SHALL define a .package-list class.
        """
        assert '.package-list' in review_styles_content, \
            "Missing .package-list CSS class"

    def test_package_item_class_exists(self, review_styles_content):
        """
        REQ-d00092-PKG-T: The CSS SHALL define a .package-item class.
        """
        assert '.package-item' in review_styles_content, \
            "Missing .package-item CSS class"

    def test_filter_toggle_class_exists(self, review_styles_content):
        """
        REQ-d00092-PKG-U: The CSS SHALL define a .rs-filter-toggle class.
        """
        assert '.rs-filter-toggle' in review_styles_content, \
            "Missing .rs-filter-toggle CSS class"

    def test_filter_toggle_active_state(self, review_styles_content):
        """
        REQ-d00092-PKG-V: The CSS SHALL define .rs-filter-toggle.active styling.
        """
        import re
        pattern = r'\.rs-filter-toggle\.active'
        match = re.search(pattern, review_styles_content)
        assert match is not None, \
            "Missing .rs-filter-toggle.active CSS"

    def test_packages_collapsed_state(self, review_styles_content):
        """
        REQ-d00092-PKG-W: The CSS SHALL define .review-packages-panel.collapsed
        state hiding .packages-content.
        """
        import re
        pattern = r'\.review-packages-panel\.collapsed\s+\.packages-content'
        match = re.search(pattern, review_styles_content)
        assert match is not None, \
            "Missing collapsed state CSS for packages panel"


# =============================================================================
# JavaScript Tests - Packages Module
# =============================================================================

class TestPackagesJavaScript:
    """Tests for review-packages.js module functionality."""

    def test_module_exports_render_function(self, review_packages_js_content):
        """
        REQ-d00092-PKG-X: The review-packages.js SHALL export
        RS.renderPackagesPanel function.
        """
        assert 'RS.renderPackagesPanel' in review_packages_js_content, \
            "Missing RS.renderPackagesPanel export"

    def test_module_exports_toggle_panel_function(self, review_packages_js_content):
        """
        REQ-d00092-PKG-Y: The review-packages.js SHALL export
        RS.togglePackagesPanel function.
        """
        assert 'RS.togglePackagesPanel' in review_packages_js_content, \
            "Missing RS.togglePackagesPanel export"

    def test_module_exports_toggle_filter_function(self, review_packages_js_content):
        """
        REQ-d00092-PKG-Z: The review-packages.js SHALL export
        RS.togglePackageFilter function.
        """
        assert 'RS.togglePackageFilter' in review_packages_js_content, \
            "Missing RS.togglePackageFilter export"

    def test_module_exports_create_dialog_function(self, review_packages_js_content):
        """
        REQ-d00092-PKG-AA: The review-packages.js SHALL export
        RS.showCreatePackageDialog function.
        """
        assert 'RS.showCreatePackageDialog' in review_packages_js_content, \
            "Missing RS.showCreatePackageDialog export"

    def test_module_exports_set_active_function(self, review_packages_js_content):
        """
        REQ-d00092-PKG-AB: The review-packages.js SHALL export
        RS.setActivePackage function.
        """
        assert 'RS.setActivePackage' in review_packages_js_content, \
            "Missing RS.setActivePackage export"

    def test_render_targets_package_list(self, review_packages_js_content):
        """
        REQ-d00092-PKG-AC: The renderPackagesPanel function SHALL target the
        reviewPackagesPanel element.
        """
        assert "getElementById('reviewPackagesPanel')" in review_packages_js_content or \
               'getElementById("reviewPackagesPanel")' in review_packages_js_content, \
            "renderPackagesPanel must get reviewPackagesPanel element"

    def test_toggle_updates_collapsed_class(self, review_packages_js_content):
        """
        REQ-d00092-PKG-AD: The togglePackagesPanel function SHALL toggle the
        'collapsed' class on the panel.
        """
        assert "'collapsed'" in review_packages_js_content or \
               '"collapsed"' in review_packages_js_content, \
            "togglePackagesPanel must handle 'collapsed' class"

    def test_filter_toggle_updates_active_class(self, review_packages_js_content):
        """
        REQ-d00092-PKG-AE: The togglePackageFilter function SHALL toggle the
        'active' class on the filter button.
        """
        import re
        pattern = r"packageFilterToggle.*?\.active|\.active.*?packageFilterToggle"
        # Or look for classList.toggle with 'active'
        has_active = "'active'" in review_packages_js_content or \
                     '"active"' in review_packages_js_content
        assert has_active, \
            "togglePackageFilter must toggle 'active' class"

    def test_module_initializes_packages_state(self, review_packages_js_content):
        """
        REQ-d00092-PKG-AF: The module SHALL initialize RS.packages state object.
        """
        assert 'RS.packages' in review_packages_js_content, \
            "Module must initialize RS.packages state"

    def test_packages_state_has_items_array(self, review_packages_js_content):
        """
        REQ-d00092-PKG-AG: RS.packages SHALL have an items array for package data.
        """
        import re
        pattern = r'RS\.packages\s*=\s*\{[^}]*items:\s*\[\]'
        match = re.search(pattern, review_packages_js_content, re.DOTALL)
        assert match is not None, \
            "RS.packages must have items array"

    def test_packages_state_has_active_id(self, review_packages_js_content):
        """
        REQ-d00092-PKG-AH: RS.packages SHALL have an activeId property.
        """
        import re
        pattern = r'RS\.packages\s*=\s*\{[^}]*activeId:'
        match = re.search(pattern, review_packages_js_content, re.DOTALL)
        assert match is not None, \
            "RS.packages must have activeId property"

    def test_packages_state_has_filter_enabled(self, review_packages_js_content):
        """
        REQ-d00092-PKG-AI: RS.packages SHALL have a filterEnabled property.
        """
        import re
        pattern = r'RS\.packages\s*=\s*\{[^}]*filterEnabled:'
        match = re.search(pattern, review_packages_js_content, re.DOTALL)
        assert match is not None, \
            "RS.packages must have filterEnabled property"


# =============================================================================
# Integration Tests
# =============================================================================

class TestPackagesIntegration:
    """Integration tests for packages panel within review system."""

    def test_packages_panel_before_review_panel(self, base_html_content):
        """
        REQ-d00092-PKG-AJ: The reviewPackagesPanel SHALL appear before the
        review-panel div in DOM order.
        """
        packages_pos = base_html_content.find('id="reviewPackagesPanel"')
        review_panel_pos = base_html_content.find('class="review-panel"')
        assert packages_pos < review_panel_pos, \
            "reviewPackagesPanel must appear before review-panel in DOM"

    def test_packages_panel_after_resize_handle(self, base_html_content):
        """
        REQ-d00092-PKG-AK: The reviewPackagesPanel SHALL appear after the
        reviewResizeHandle in DOM order.
        """
        resize_handle_pos = base_html_content.find('id="reviewResizeHandle"')
        packages_pos = base_html_content.find('id="reviewPackagesPanel"')
        assert resize_handle_pos < packages_pos, \
            "reviewResizeHandle must appear before reviewPackagesPanel in DOM"

    def test_packages_panel_conditional_on_review_mode(self, base_html_content):
        """
        REQ-d00092-PKG-AL: The packages panel SHALL only be rendered when
        review_mode is enabled (inside review_mode conditional).
        """
        import re
        # Packages panel should be inside the review_mode block
        pattern = r'{%\s*if\s+review_mode\s*%}.*?id="reviewPackagesPanel"'
        match = re.search(pattern, base_html_content, re.DOTALL)
        assert match is not None, \
            "reviewPackagesPanel must be inside review_mode conditional"
