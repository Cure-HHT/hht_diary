"""
Tests for Combined Comments & Status View (Phase 5.1).

TDD Red Phase: These tests are written BEFORE the implementation changes.
They verify the combined view structure replaces the tabbed view.

IMPLEMENTS REQUIREMENTS:
    REQ-d00092: HTML Report Integration (Combined View without tabs)
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


# =============================================================================
# HTML Structure Tests - Combined View
# =============================================================================

class TestCombinedViewHTML:
    """Tests for combined comments & status view HTML structure."""

    def test_combined_view_container_exists(self, base_html_content):
        """
        REQ-d00092: The review panel SHALL have a combined view container
        with id="review-panel-combined".
        """
        assert 'id="review-panel-combined"' in base_html_content, \
            "Missing review-panel-combined container"

    def test_combined_view_has_class(self, base_html_content):
        """
        REQ-d00092: The combined view container SHALL have class
        "review-panel-combined".
        """
        assert 'class="review-panel-combined"' in base_html_content, \
            "Missing review-panel-combined class"

    def test_status_section_exists(self, base_html_content):
        """
        REQ-d00092: The combined view SHALL have a status section with
        id="rs-status-section".
        """
        assert 'id="rs-status-section"' in base_html_content, \
            "Missing rs-status-section"

    def test_status_section_has_class(self, base_html_content):
        """
        REQ-d00092: The status section SHALL have class "rs-status-section".
        """
        assert 'class="rs-status-section"' in base_html_content, \
            "Missing rs-status-section class"

    def test_comments_section_exists(self, base_html_content):
        """
        REQ-d00092: The combined view SHALL have a comments section with
        id="rs-comments-section".
        """
        assert 'id="rs-comments-section"' in base_html_content, \
            "Missing rs-comments-section"

    def test_comments_section_has_class(self, base_html_content):
        """
        REQ-d00092: The comments section SHALL have class "rs-comments-section".
        """
        assert 'class="rs-comments-section"' in base_html_content, \
            "Missing rs-comments-section class"

    def test_section_divider_exists(self, base_html_content):
        """
        REQ-d00092: The combined view SHALL have a divider between status
        and comments sections with class "rs-section-divider".
        """
        assert 'class="rs-section-divider"' in base_html_content, \
            "Missing rs-section-divider"

    def test_status_section_has_header(self, base_html_content):
        """
        REQ-d00092: The status section SHALL have a section header with
        class "rs-section-header".
        """
        import re
        # Find status section and verify it contains a section header
        pattern = r'id="rs-status-section"[^>]*>.*?class="rs-section-header"'
        match = re.search(pattern, base_html_content, re.DOTALL)
        assert match is not None, \
            "Status section must contain rs-section-header"

    def test_comments_section_has_header(self, base_html_content):
        """
        REQ-d00092: The comments section SHALL have a section header with
        class "rs-section-header".
        """
        import re
        # Find comments section and verify it contains a section header
        pattern = r'id="rs-comments-section"[^>]*>.*?class="rs-section-header"'
        match = re.search(pattern, base_html_content, re.DOTALL)
        assert match is not None, \
            "Comments section must contain rs-section-header"

    def test_status_section_before_divider(self, base_html_content):
        """
        REQ-d00092: The status section SHALL appear before the divider
        in DOM order.
        """
        status_pos = base_html_content.find('id="rs-status-section"')
        divider_pos = base_html_content.find('class="rs-section-divider"')
        assert status_pos < divider_pos, \
            "Status section must appear before divider"

    def test_divider_before_comments_section(self, base_html_content):
        """
        REQ-d00092: The divider SHALL appear before the comments section
        in DOM order.
        """
        divider_pos = base_html_content.find('class="rs-section-divider"')
        comments_pos = base_html_content.find('id="rs-comments-section"')
        assert divider_pos < comments_pos, \
            "Divider must appear before comments section"

    def test_no_tabs_in_review_panel(self, base_html_content):
        """
        REQ-d00092: The combined view SHALL NOT use tabs (no tab-related
        classes like rs-tab-container, rs-tab-btn, etc.).
        """
        assert 'rs-tab-container' not in base_html_content, \
            "Combined view should not use tabs"
        assert 'rs-tab-btn' not in base_html_content, \
            "Combined view should not have tab buttons"
        assert 'rs-tabs' not in base_html_content, \
            "Combined view should not have tabs element"

    def test_add_comment_button_exists(self, base_html_content):
        """
        REQ-d00092: The comments section header SHALL have an Add Comment
        button with id="rs-add-comment-btn".
        """
        assert 'id="rs-add-comment-btn"' in base_html_content, \
            "Missing Add Comment button"

    def test_status_content_container_exists(self, base_html_content):
        """
        REQ-d00092: The status section SHALL have a content container
        with id="rs-status-content".
        """
        assert 'id="rs-status-content"' in base_html_content, \
            "Missing rs-status-content container"

    def test_comments_content_container_exists(self, base_html_content):
        """
        REQ-d00092: The comments section SHALL have a content container
        with id="rs-comments-content".
        """
        assert 'id="rs-comments-content"' in base_html_content, \
            "Missing rs-comments-content container"


# =============================================================================
# CSS Tests - Section Header
# =============================================================================

class TestSectionHeaderCSS:
    """Tests for section header CSS styling."""

    def test_section_header_class_exists(self, review_styles_content):
        """
        REQ-d00092: The CSS SHALL define a .rs-section-header class.
        """
        assert '.rs-section-header' in review_styles_content, \
            "Missing .rs-section-header CSS class"

    def test_section_header_uses_flexbox(self, review_styles_content):
        """
        REQ-d00092: The .rs-section-header SHALL use flexbox layout.
        """
        import re
        pattern = r'\.rs-section-header\s*\{[^}]*display:\s*flex'
        match = re.search(pattern, review_styles_content, re.DOTALL)
        assert match is not None, \
            ".rs-section-header must have display: flex"

    def test_section_header_justify_content(self, review_styles_content):
        """
        REQ-d00092: The .rs-section-header SHALL use justify-content:
        space-between for button alignment.
        """
        import re
        pattern = r'\.rs-section-header\s*\{[^}]*justify-content:\s*space-between'
        match = re.search(pattern, review_styles_content, re.DOTALL)
        assert match is not None, \
            ".rs-section-header must have justify-content: space-between"

    def test_section_header_align_items(self, review_styles_content):
        """
        REQ-d00092: The .rs-section-header SHALL use align-items: center.
        """
        import re
        pattern = r'\.rs-section-header\s*\{[^}]*align-items:\s*center'
        match = re.search(pattern, review_styles_content, re.DOTALL)
        assert match is not None, \
            ".rs-section-header must have align-items: center"

    def test_section_header_has_border_bottom(self, review_styles_content):
        """
        REQ-d00092: The .rs-section-header SHALL have a bottom border.
        """
        import re
        pattern = r'\.rs-section-header\s*\{[^}]*border-bottom:'
        match = re.search(pattern, review_styles_content, re.DOTALL)
        assert match is not None, \
            ".rs-section-header must have border-bottom"

    def test_section_header_h4_styling(self, review_styles_content):
        """
        REQ-d00092: The .rs-section-header h4 SHALL have specific styling
        with no margin and appropriate font-size/weight.
        """
        assert '.rs-section-header h4' in review_styles_content, \
            "Missing .rs-section-header h4 rule"

        import re
        pattern = r'\.rs-section-header h4\s*\{[^}]*margin:\s*0'
        match = re.search(pattern, review_styles_content, re.DOTALL)
        assert match is not None, \
            ".rs-section-header h4 must have margin: 0"


# =============================================================================
# CSS Tests - Section Divider
# =============================================================================

class TestSectionDividerCSS:
    """Tests for section divider CSS styling."""

    def test_section_divider_class_exists(self, review_styles_content):
        """
        REQ-d00092: The CSS SHALL define a .rs-section-divider class.
        """
        assert '.rs-section-divider' in review_styles_content, \
            "Missing .rs-section-divider CSS class"

    def test_section_divider_has_height(self, review_styles_content):
        """
        REQ-d00092: The .rs-section-divider SHALL have a defined height.
        """
        import re
        pattern = r'\.rs-section-divider\s*\{[^}]*height:'
        match = re.search(pattern, review_styles_content, re.DOTALL)
        assert match is not None, \
            ".rs-section-divider must have height property"

    def test_section_divider_has_background(self, review_styles_content):
        """
        REQ-d00092: The .rs-section-divider SHALL have a background or
        background-color for visual separation.
        """
        import re
        pattern = r'\.rs-section-divider\s*\{[^}]*background'
        match = re.search(pattern, review_styles_content, re.DOTALL)
        assert match is not None, \
            ".rs-section-divider must have background property"


# =============================================================================
# CSS Tests - Status Section
# =============================================================================

class TestStatusSectionCSS:
    """Tests for status section CSS styling."""

    def test_status_section_class_exists(self, review_styles_content):
        """
        REQ-d00092: The CSS SHALL define a .rs-status-section class.
        """
        assert '.rs-status-section' in review_styles_content, \
            "Missing .rs-status-section CSS class"


# =============================================================================
# CSS Tests - Comments Section
# =============================================================================

class TestCommentsSectionCSS:
    """Tests for comments section CSS styling."""

    def test_comments_section_class_exists(self, review_styles_content):
        """
        REQ-d00092: The CSS SHALL define a .rs-comments-section class.
        """
        assert '.rs-comments-section' in review_styles_content, \
            "Missing .rs-comments-section CSS class"

    def test_comments_section_flex_grow(self, review_styles_content):
        """
        REQ-d00092: The .rs-comments-section SHALL grow to fill available
        space using flex: 1 or similar.
        """
        import re
        pattern = r'\.rs-comments-section\s*\{[^}]*flex:\s*1'
        match = re.search(pattern, review_styles_content, re.DOTALL)
        assert match is not None, \
            ".rs-comments-section must have flex: 1 for growth"


# =============================================================================
# CSS Tests - Combined View Container
# =============================================================================

class TestCombinedViewContainerCSS:
    """Tests for combined view container CSS styling."""

    def test_combined_view_class_exists(self, review_styles_content):
        """
        REQ-d00092: The CSS SHALL define a .review-panel-combined class.
        """
        assert '.review-panel-combined' in review_styles_content, \
            "Missing .review-panel-combined CSS class"

    def test_combined_view_uses_flexbox(self, review_styles_content):
        """
        REQ-d00092: The .review-panel-combined SHALL use flexbox column
        layout for vertical stacking.
        """
        import re
        pattern = r'\.review-panel-combined\s*\{[^}]*display:\s*flex'
        match = re.search(pattern, review_styles_content, re.DOTALL)
        assert match is not None, \
            ".review-panel-combined must have display: flex"

        pattern = r'\.review-panel-combined\s*\{[^}]*flex-direction:\s*column'
        match = re.search(pattern, review_styles_content, re.DOTALL)
        assert match is not None, \
            ".review-panel-combined must have flex-direction: column"


# =============================================================================
# Integration Tests
# =============================================================================

class TestCombinedViewIntegration:
    """Integration tests for combined view layout."""

    def test_combined_view_inside_review_panel(self, base_html_content):
        """
        REQ-d00092: The combined view SHALL be inside the review-panel-content
        container.
        """
        import re
        pattern = r'id="review-panel-content"[^>]*>.*?id="review-panel-combined"'
        match = re.search(pattern, base_html_content, re.DOTALL)
        assert match is not None, \
            "Combined view must be inside review-panel-content"

    def test_no_selection_message_exists(self, base_html_content):
        """
        REQ-d00092: The review panel SHALL show a no-selection message
        when no requirement is selected.
        """
        assert 'id="review-panel-no-selection"' in base_html_content, \
            "Missing no-selection message container"

    def test_combined_view_hidden_by_default(self, base_html_content):
        """
        REQ-d00092: The combined view SHALL be hidden by default
        (style="display: none" or via JS).
        """
        import re
        pattern = r'id="review-panel-combined"[^>]*style="[^"]*display:\s*none'
        match = re.search(pattern, base_html_content, re.DOTALL)
        assert match is not None, \
            "Combined view should be hidden by default"
