"""
Tests for Review System 3-Column Layout (REQ-d00092).

TDD Red Phase: These tests are written BEFORE the implementation.
They verify the 3-column layout adaptation for the Spec Review System.

Each test function documents which assertion it verifies in its docstring.
The Elspais reporter extracts these references for traceability.

IMPLEMENTS REQUIREMENTS:
    REQ-d00092: HTML Report Integration (3-column layout)
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
def review_js_files():
    """Load all review JavaScript module files."""
    import trace_view.html as html_module
    html_path = Path(html_module.__file__).parent
    review_dir = html_path / "templates" / "partials" / "review"
    js_files = {}
    for js_file in review_dir.glob("*.js"):
        js_files[js_file.name] = js_file.read_text()
    return js_files


# =============================================================================
# HTML Structure Tests
# =============================================================================

class TestReviewColumnHTML:
    """Tests for review column HTML structure in base.html."""

    def test_review_column_has_id(self, base_html_content):
        """
        REQ-d00092-A: The review column div SHALL have id="review-column".
        """
        assert 'id="review-column"' in base_html_content, \
            "Missing review-column div with id"

    def test_review_column_has_class(self, base_html_content):
        """
        REQ-d00092-B: The review column div SHALL have class="review-column".
        """
        assert 'class="review-column' in base_html_content, \
            "Missing review-column class on div"

    def test_review_resize_handle_exists(self, base_html_content):
        """
        REQ-d00092-C: The review column SHALL contain a resize handle div with
        id="reviewResizeHandle".
        """
        assert 'id="reviewResizeHandle"' in base_html_content, \
            "Missing reviewResizeHandle div inside review column"

    def test_review_resize_handle_inside_review_column(self, base_html_content):
        """
        REQ-d00092-D: The reviewResizeHandle SHALL be positioned inside the
        review-column div structure.
        """
        # Find the review-column div and verify handle is inside it
        import re
        # Match the review-column div and its contents
        pattern = r'<div[^>]*id="review-column"[^>]*>.*?id="reviewResizeHandle"'
        match = re.search(pattern, base_html_content, re.DOTALL)
        assert match is not None, \
            "reviewResizeHandle must be inside review-column div"

    def test_review_column_conditional_on_review_mode(self, base_html_content):
        """
        REQ-d00092-E: The review column SHALL only be rendered when review_mode
        is enabled via Jinja2 conditional.
        """
        # Check that review-column is inside a review_mode conditional block
        assert '{% if review_mode %}' in base_html_content, \
            "Missing review_mode conditional"
        # Verify the conditional wraps the review column
        import re
        pattern = r'{%\s*if\s+review_mode\s*%}.*?id="review-column"'
        match = re.search(pattern, base_html_content, re.DOTALL)
        assert match is not None, \
            "review-column must be inside review_mode conditional"


# =============================================================================
# CSS Tests
# =============================================================================

class TestReviewColumnCSS:
    """Tests for review column CSS styling."""

    def test_review_column_class_exists(self, review_styles_content):
        """
        REQ-d00092-F: The CSS SHALL define a .review-column class.
        """
        assert '.review-column' in review_styles_content, \
            "Missing .review-column CSS class"

    def test_review_column_width(self, review_styles_content):
        """
        REQ-d00092-G: The .review-column SHALL have an initial width of 350px.
        """
        import re
        # Look for width in .review-column block
        pattern = r'\.review-column\s*\{[^}]*width:\s*350px'
        match = re.search(pattern, review_styles_content, re.DOTALL)
        assert match is not None, \
            ".review-column must have width: 350px"

    def test_review_column_min_width(self, review_styles_content):
        """
        REQ-d00092-H: The .review-column SHALL have min-width of 250px.
        """
        import re
        pattern = r'\.review-column\s*\{[^}]*min-width:\s*250px'
        match = re.search(pattern, review_styles_content, re.DOTALL)
        assert match is not None, \
            ".review-column must have min-width: 250px"

    def test_review_column_max_width(self, review_styles_content):
        """
        REQ-d00092-I: The .review-column SHALL have max-width of 50vw.
        """
        import re
        pattern = r'\.review-column\s*\{[^}]*max-width:\s*50vw'
        match = re.search(pattern, review_styles_content, re.DOTALL)
        assert match is not None, \
            ".review-column must have max-width: 50vw"

    def test_review_column_flex_layout(self, review_styles_content):
        """
        REQ-d00092-J: The .review-column SHALL use flexbox column layout.
        """
        import re
        pattern = r'\.review-column\s*\{[^}]*display:\s*flex'
        match = re.search(pattern, review_styles_content, re.DOTALL)
        assert match is not None, \
            ".review-column must have display: flex"

        pattern = r'\.review-column\s*\{[^}]*flex-direction:\s*column'
        match = re.search(pattern, review_styles_content, re.DOTALL)
        assert match is not None, \
            ".review-column must have flex-direction: column"

    def test_review_column_hidden_class(self, review_styles_content):
        """
        REQ-d00092-K: The CSS SHALL define .review-column.hidden with
        display: none.
        """
        import re
        pattern = r'\.review-column\.hidden\s*\{[^}]*display:\s*none'
        match = re.search(pattern, review_styles_content, re.DOTALL)
        assert match is not None, \
            ".review-column.hidden must have display: none"

    def test_review_column_border(self, review_styles_content):
        """
        REQ-d00092-L: The .review-column SHALL have a left border for visual
        separation from the REQ panel.
        """
        import re
        pattern = r'\.review-column\s*\{[^}]*border-left:'
        match = re.search(pattern, review_styles_content, re.DOTALL)
        assert match is not None, \
            ".review-column must have border-left"

    def test_review_column_box_shadow(self, review_styles_content):
        """
        REQ-d00092-M: The .review-column SHALL have a box-shadow for depth.
        """
        import re
        pattern = r'\.review-column\s*\{[^}]*box-shadow:'
        match = re.search(pattern, review_styles_content, re.DOTALL)
        assert match is not None, \
            ".review-column must have box-shadow"

    def test_review_resize_handle_css(self, review_styles_content):
        """
        REQ-d00092-N: The CSS SHALL define a .review-resize-handle class for
        the resize handle.
        """
        # The handle may use a generic class or specific ID selector
        assert ('.review-resize-handle' in review_styles_content or
                '#reviewResizeHandle' in review_styles_content or
                '.resize-handle' in review_styles_content), \
            "Missing resize handle CSS"


# =============================================================================
# JavaScript Tests
# =============================================================================

class TestReviewColumnResize:
    """Tests for review column resize JavaScript functionality."""

    def test_review_resize_js_exists(self, review_js_files):
        """
        REQ-d00092-O: A JavaScript module SHALL exist for review column resize.
        """
        # Check if any JS file contains review resize functionality
        has_resize = False
        for name, content in review_js_files.items():
            if 'reviewResizeHandle' in content or 'review-column' in content:
                if 'mousedown' in content and 'mousemove' in content:
                    has_resize = True
                    break
        assert has_resize, \
            "No review resize JavaScript module found"

    def test_review_resize_initializes(self, review_js_files):
        """
        REQ-d00092-P: The resize module SHALL initialize with mousedown handler
        on the resize handle.
        """
        found_init = False
        for content in review_js_files.values():
            if 'reviewResizeHandle' in content and 'mousedown' in content:
                found_init = True
                break
        assert found_init, \
            "Resize module must attach mousedown handler to reviewResizeHandle"

    def test_review_resize_uses_col_resize_cursor(self, review_js_files):
        """
        REQ-d00092-Q: The resize module SHALL set cursor to col-resize during
        dragging.
        """
        found_cursor = False
        for content in review_js_files.values():
            if 'col-resize' in content:
                found_cursor = True
                break
        assert found_cursor, \
            "Resize module must use col-resize cursor during drag"

    def test_review_resize_prevents_user_select(self, review_js_files):
        """
        REQ-d00092-R: The resize module SHALL disable user-select during drag.
        """
        found_user_select = False
        for content in review_js_files.values():
            if 'userSelect' in content and 'none' in content:
                found_user_select = True
                break
        assert found_user_select, \
            "Resize module must disable userSelect during drag"

    def test_review_resize_respects_min_width(self, review_js_files):
        """
        REQ-d00092-S: The resize module SHALL enforce minimum width constraint.
        """
        found_min = False
        for content in review_js_files.values():
            if ('Math.max' in content or 'Math.min' in content) and '200' in content:
                found_min = True
                break
        assert found_min, \
            "Resize module must enforce minimum width (200px)"

    def test_review_resize_cleans_up_on_mouseup(self, review_js_files):
        """
        REQ-d00092-T: The resize module SHALL clean up state on mouseup event.
        """
        found_cleanup = False
        for content in review_js_files.values():
            if 'mouseup' in content:
                found_cleanup = True
                break
        assert found_cleanup, \
            "Resize module must handle mouseup for cleanup"


# =============================================================================
# Integration Tests
# =============================================================================

class TestThreeColumnLayout:
    """Integration tests for 3-column layout behavior."""

    def test_app_layout_structure(self, base_html_content):
        """
        REQ-d00092-U: The app-layout container SHALL support a 3-column
        structure with main-content, side-panel, and review-column.
        """
        assert 'class="app-layout"' in base_html_content, \
            "Missing app-layout container"
        assert 'class="main-content"' in base_html_content, \
            "Missing main-content column"
        assert 'id="req-panel"' in base_html_content, \
            "Missing req-panel (side-panel)"
        assert 'id="review-column"' in base_html_content, \
            "Missing review-column"

    def test_review_column_after_req_panel(self, base_html_content):
        """
        REQ-d00092-V: The review-column SHALL appear after the req-panel in
        DOM order for proper visual layout.
        """
        import re
        # req-panel should come before review-column in the document
        req_panel_pos = base_html_content.find('id="req-panel"')
        review_col_pos = base_html_content.find('id="review-column"')
        assert req_panel_pos < review_col_pos, \
            "req-panel must appear before review-column in DOM"
