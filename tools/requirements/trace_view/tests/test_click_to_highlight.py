"""
Tests for Click-to-Highlight Positions Feature (Phase 4.4).

TDD Test Suite: Verifies position label click behavior and highlight rendering.
These tests validate the JavaScript and CSS implementation for click-to-highlight.

Each test function documents which assertion it verifies in its docstring.
The Elspais reporter extracts these references for traceability.

IMPLEMENTS REQUIREMENTS:
    REQ-d00092: HTML Report Integration
    REQ-d00087: Position Resolution with Fallback
"""

from pathlib import Path
import re

import pytest


# =============================================================================
# Test Fixtures
# =============================================================================

@pytest.fixture
def review_comments_js():
    """Load the review-comments.js module content."""
    import trace_view.html as html_module
    html_path = Path(html_module.__file__).parent
    js_path = html_path / "templates" / "partials" / "review" / "review-comments.js"
    return js_path.read_text()


@pytest.fixture
def review_position_js():
    """Load the review-position.js module content."""
    import trace_view.html as html_module
    html_path = Path(html_module.__file__).parent
    js_path = html_path / "templates" / "partials" / "review" / "review-position.js"
    return js_path.read_text()


@pytest.fixture
def review_styles_css():
    """Load the review-styles.css content."""
    import trace_view.html as html_module
    html_path = Path(html_module.__file__).parent
    css_path = html_path / "templates" / "partials" / "review-styles.css"
    return css_path.read_text()


# =============================================================================
# Position Label Template Tests
# =============================================================================

class TestPositionLabelTemplate:
    """Tests for position label HTML template structure."""

    def test_position_label_has_data_thread_id(self, review_comments_js):
        """
        REQ-d00092-CTH-A: Position label template SHALL include data-thread-id
        attribute for click handler targeting.
        """
        # Check that threadTemplate includes data-thread-id on position label
        pattern = r'rs-position-label[^>]*data-thread-id'
        assert re.search(pattern, review_comments_js), \
            "Position label must have data-thread-id attribute"

    def test_position_label_has_data_position_type(self, review_comments_js):
        """
        REQ-d00092-CTH-B: Position label template SHALL include data-position-type
        attribute for type-specific handling.
        """
        pattern = r'rs-position-label[^>]*data-position-type'
        assert re.search(pattern, review_comments_js), \
            "Position label must have data-position-type attribute"

    def test_position_label_has_toggle_tooltip(self, review_comments_js):
        """
        REQ-d00092-CTH-C: Position label template SHALL have tooltip indicating
        toggle behavior.
        """
        assert 'click again to clear' in review_comments_js.lower(), \
            "Position label tooltip should mention toggle behavior"


# =============================================================================
# Click Handler Tests
# =============================================================================

class TestPositionLabelClickHandler:
    """Tests for position label click event handling."""

    def test_position_label_click_handler_exists(self, review_comments_js):
        """
        REQ-d00092-CTH-D: JavaScript SHALL bind click handler to .rs-position-label
        elements.
        """
        assert "'.rs-position-label'" in review_comments_js or \
               '".rs-position-label"' in review_comments_js, \
            "Must have click handler selector for .rs-position-label"

    def test_click_handler_stops_propagation(self, review_comments_js):
        """
        REQ-d00092-CTH-E: Position label click handler SHALL stop event propagation
        to prevent thread click handler from firing.
        """
        assert 'stopPropagation' in review_comments_js, \
            "Click handler must call stopPropagation()"

    def test_click_handler_has_toggle_logic(self, review_comments_js):
        """
        REQ-d00092-CTH-F: Position label click handler SHALL implement toggle
        behavior (click to highlight, click again to clear).
        """
        # Check for active state tracking
        assert 'rs-position-active' in review_comments_js, \
            "Click handler must track active state with rs-position-active class"

    def test_click_handler_clears_other_active_labels(self, review_comments_js):
        """
        REQ-d00092-CTH-G: When activating a position label, handler SHALL clear
        other active position labels.
        """
        # Should have logic to remove rs-position-active from other labels
        pattern = r'querySelectorAll.*rs-position-label.*rs-position-active.*forEach'
        assert re.search(pattern, review_comments_js, re.DOTALL), \
            "Click handler must clear other active position labels"

    def test_click_handler_calls_highlight_function(self, review_comments_js):
        """
        REQ-d00092-CTH-H: Position label click handler SHALL call
        highlightThreadPositionInCard when activating.
        """
        assert 'highlightThreadPositionInCard' in review_comments_js, \
            "Click handler must call highlightThreadPositionInCard"

    def test_click_handler_calls_clear_highlights(self, review_comments_js):
        """
        REQ-d00092-CTH-I: Position label click handler SHALL call
        clearAllPositionHighlights when toggling off.
        """
        assert 'clearAllPositionHighlights' in review_comments_js, \
            "Click handler must call clearAllPositionHighlights for toggle off"


# =============================================================================
# Confidence-Based Highlighting Tests
# =============================================================================

class TestConfidenceBasedHighlighting:
    """Tests for confidence-based highlight styling."""

    def test_get_highlight_class_function_exists(self, review_comments_js):
        """
        REQ-d00087-CTH-A: JavaScript SHALL have getHighlightClassForThread function
        to determine confidence-based highlight class.
        """
        assert 'getHighlightClassForThread' in review_comments_js, \
            "Must have getHighlightClassForThread function"

    def test_get_highlight_class_checks_resolved_position(self, review_comments_js):
        """
        REQ-d00087-CTH-B: getHighlightClassForThread SHALL check thread's
        resolvedPosition.confidence property.
        """
        assert 'resolvedPosition' in review_comments_js and 'confidence' in review_comments_js, \
            "Function must check resolvedPosition.confidence"

    def test_get_highlight_class_returns_exact(self, review_comments_js):
        """
        REQ-d00087-CTH-C: getHighlightClassForThread SHALL return 'rs-highlight-exact'
        for EXACT confidence.
        """
        assert 'rs-highlight-exact' in review_comments_js, \
            "Function must return rs-highlight-exact for EXACT confidence"

    def test_get_highlight_class_returns_approximate(self, review_comments_js):
        """
        REQ-d00087-CTH-D: getHighlightClassForThread SHALL return 'rs-highlight-approximate'
        for APPROXIMATE confidence.
        """
        assert 'rs-highlight-approximate' in review_comments_js, \
            "Function must return rs-highlight-approximate for APPROXIMATE confidence"

    def test_get_highlight_class_returns_unanchored(self, review_comments_js):
        """
        REQ-d00087-CTH-E: getHighlightClassForThread SHALL return 'rs-highlight-unanchored'
        for UNANCHORED confidence or GENERAL position type.
        """
        assert 'rs-highlight-unanchored' in review_comments_js, \
            "Function must return rs-highlight-unanchored for UNANCHORED confidence"

    def test_get_confidence_class_function_exists(self, review_comments_js):
        """
        REQ-d00087-CTH-F: JavaScript SHALL have getConfidenceClass function for
        position label styling.
        """
        assert 'getConfidenceClass' in review_comments_js, \
            "Must have getConfidenceClass function"

    def test_get_confidence_class_returns_label_classes(self, review_comments_js):
        """
        REQ-d00087-CTH-G: getConfidenceClass SHALL return rs-confidence-* classes
        for position label styling.
        """
        assert 'rs-confidence-exact' in review_comments_js, \
            "Must return rs-confidence-exact class"
        assert 'rs-confidence-approximate' in review_comments_js, \
            "Must return rs-confidence-approximate class"
        assert 'rs-confidence-unanchored' in review_comments_js, \
            "Must return rs-confidence-unanchored class"


# =============================================================================
# Highlight Application Tests
# =============================================================================

class TestHighlightApplication:
    """Tests for highlight application to REQ card lines."""

    def test_highlight_adds_confidence_class(self, review_comments_js):
        """
        REQ-d00092-CTH-J: highlightThreadPositionInCard SHALL add confidence-specific
        highlight class to target lines.
        """
        # Check that highlightClass is applied to lineRow
        pattern = r'lineRow\.classList\.add.*highlightClass'
        assert re.search(pattern, review_comments_js, re.DOTALL), \
            "Must add confidence-specific highlight class to line rows"

    def test_highlight_adds_comment_highlight_class(self, review_comments_js):
        """
        REQ-d00092-CTH-K: highlightThreadPositionInCard SHALL also add
        rs-comment-highlight class for animation.
        """
        pattern = r'lineRow\.classList\.add.*rs-comment-highlight'
        assert re.search(pattern, review_comments_js, re.DOTALL), \
            "Must add rs-comment-highlight class for animation"

    def test_highlight_sets_thread_id_attribute(self, review_comments_js):
        """
        REQ-d00092-CTH-L: highlightThreadPositionInCard SHALL set
        data-highlight-thread attribute for tracking.
        """
        assert 'data-highlight-thread' in review_comments_js, \
            "Must set data-highlight-thread attribute on highlighted lines"

    def test_highlight_scrolls_to_target(self, review_comments_js):
        """
        REQ-d00092-CTH-M: highlightThreadPositionInCard SHALL scroll to make
        highlighted line visible.
        """
        assert 'scrollIntoView' in review_comments_js, \
            "Must call scrollIntoView to show highlighted line"

    def test_highlight_uses_smooth_scroll(self, review_comments_js):
        """
        REQ-d00092-CTH-N: scrollIntoView SHALL use smooth behavior.
        """
        pattern = r'scrollIntoView.*smooth'
        assert re.search(pattern, review_comments_js, re.DOTALL), \
            "scrollIntoView must use smooth behavior"

    def test_highlight_general_position_highlights_card(self, review_comments_js):
        """
        REQ-d00092-CTH-O: For GENERAL position type, highlightThreadPositionInCard
        SHALL add highlight class to whole REQ card.
        """
        pattern = r'GENERAL.*reqCard\.classList\.add.*rs-highlight-unanchored'
        assert re.search(pattern, review_comments_js, re.DOTALL), \
            "GENERAL position must highlight whole REQ card"


# =============================================================================
# Clear Highlights Tests
# =============================================================================

class TestClearHighlights:
    """Tests for highlight clearing functionality."""

    def test_clear_all_position_highlights_exists(self, review_comments_js):
        """
        REQ-d00092-CTH-P: JavaScript SHALL have clearAllPositionHighlights function.
        """
        assert 'clearAllPositionHighlights' in review_comments_js, \
            "Must have clearAllPositionHighlights function"

    def test_clear_all_removes_card_highlight(self, review_comments_js):
        """
        REQ-d00092-CTH-Q: clearAllPositionHighlights SHALL remove highlight class
        from REQ card (for GENERAL position).
        """
        pattern = r"reqCard\.classList\.remove.*rs-highlight-unanchored"
        assert re.search(pattern, review_comments_js, re.DOTALL), \
            "Must remove rs-highlight-unanchored from reqCard"

    def test_clear_comment_highlights_clears_all_classes(self, review_comments_js):
        """
        REQ-d00092-CTH-R: clearCommentHighlights SHALL remove all confidence-based
        highlight classes.
        """
        # Check for all highlight classes in the clear function
        assert 'rs-comment-highlight' in review_comments_js, "Must clear rs-comment-highlight"
        assert 'rs-highlight-exact' in review_comments_js, "Must clear rs-highlight-exact"
        assert 'rs-highlight-approximate' in review_comments_js, "Must clear rs-highlight-approximate"
        assert 'rs-highlight-unanchored' in review_comments_js, "Must clear rs-highlight-unanchored"
        assert 'rs-highlight-active' in review_comments_js, "Must clear rs-highlight-active"

    def test_clear_comment_highlights_removes_thread_attribute(self, review_comments_js):
        """
        REQ-d00092-CTH-S: clearCommentHighlights SHALL remove data-highlight-thread
        attribute.
        """
        assert "removeAttribute('data-highlight-thread')" in review_comments_js or \
               'removeAttribute("data-highlight-thread")' in review_comments_js, \
            "Must remove data-highlight-thread attribute"


# =============================================================================
# CSS Styling Tests
# =============================================================================

class TestHighlightCSS:
    """Tests for highlight CSS styling."""

    def test_css_has_exact_highlight_style(self, review_styles_css):
        """
        REQ-d00092-CTH-T: CSS SHALL define .rs-highlight-exact with yellow solid
        border styling.
        """
        pattern = r'\.rs-highlight-exact\s*\{[^}]*border[^}]*solid'
        assert re.search(pattern, review_styles_css, re.DOTALL), \
            ".rs-highlight-exact must have solid border"

    def test_css_has_approximate_highlight_style(self, review_styles_css):
        """
        REQ-d00092-CTH-U: CSS SHALL define .rs-highlight-approximate with orange
        dashed border styling.
        """
        pattern = r'\.rs-highlight-approximate\s*\{[^}]*border[^}]*dashed'
        assert re.search(pattern, review_styles_css, re.DOTALL), \
            ".rs-highlight-approximate must have dashed border"

    def test_css_has_unanchored_highlight_style(self, review_styles_css):
        """
        REQ-d00092-CTH-V: CSS SHALL define .rs-highlight-unanchored with gray
        background styling.
        """
        pattern = r'\.rs-highlight-unanchored\s*\{[^}]*background'
        assert re.search(pattern, review_styles_css, re.DOTALL), \
            ".rs-highlight-unanchored must have gray background"

    def test_css_has_active_highlight_style(self, review_styles_css):
        """
        REQ-d00092-CTH-W: CSS SHALL define .rs-highlight-active with blue styling
        for selected state.
        """
        pattern = r'\.rs-highlight-active\s*\{[^}]*#2196f3'
        assert re.search(pattern, review_styles_css, re.DOTALL) or \
               re.search(r'\.rs-highlight-active\s*\{[^}]*blue', review_styles_css, re.DOTALL | re.IGNORECASE), \
            ".rs-highlight-active must have blue styling"


# =============================================================================
# Position Label CSS Tests
# =============================================================================

class TestPositionLabelCSS:
    """Tests for position label CSS styling."""

    def test_css_has_position_label_cursor(self, review_styles_css):
        """
        REQ-d00092-CTH-X: CSS SHALL define .rs-position-label with cursor: pointer.
        """
        pattern = r'\.rs-position-label\s*\{[^}]*cursor:\s*pointer'
        assert re.search(pattern, review_styles_css, re.DOTALL), \
            ".rs-position-label must have cursor: pointer"

    def test_css_has_position_label_hover(self, review_styles_css):
        """
        REQ-d00092-CTH-Y: CSS SHALL define .rs-position-label:hover with visual
        feedback.
        """
        assert '.rs-position-label:hover' in review_styles_css, \
            "Must have .rs-position-label:hover style"

    def test_css_has_position_label_active_state(self, review_styles_css):
        """
        REQ-d00092-CTH-Z: CSS SHALL define .rs-position-label.rs-position-active
        for active state styling.
        """
        assert '.rs-position-active' in review_styles_css, \
            "Must have .rs-position-active class style"

    def test_css_has_confidence_label_styles(self, review_styles_css):
        """
        REQ-d00087-CTH-H: CSS SHALL define confidence-based position label styles:
        rs-confidence-exact, rs-confidence-approximate, rs-confidence-unanchored.
        """
        assert '.rs-confidence-exact' in review_styles_css, \
            "Must have .rs-confidence-exact style"
        assert '.rs-confidence-approximate' in review_styles_css, \
            "Must have .rs-confidence-approximate style"
        assert '.rs-confidence-unanchored' in review_styles_css, \
            "Must have .rs-confidence-unanchored style"

    def test_css_has_highlight_animation(self, review_styles_css):
        """
        REQ-d00092-CTH-AA: CSS SHALL define animation for highlighted lines
        to draw attention.
        """
        assert '@keyframes' in review_styles_css and 'highlight' in review_styles_css.lower(), \
            "Must have highlight animation keyframes"


# =============================================================================
# Integration Tests
# =============================================================================

class TestClickToHighlightIntegration:
    """Integration tests for complete click-to-highlight feature."""

    def test_exports_highlight_function(self, review_comments_js):
        """
        REQ-d00092-CTH-AB: ReviewSystem namespace SHALL export
        highlightThreadPositionInCard function.
        """
        assert 'RS.highlightThreadPositionInCard' in review_comments_js, \
            "Must export highlightThreadPositionInCard to RS namespace"

    def test_exports_clear_all_highlights_function(self, review_comments_js):
        """
        REQ-d00092-CTH-AC: ReviewSystem namespace SHALL export
        clearAllPositionHighlights function.
        """
        assert 'RS.clearAllPositionHighlights' in review_comments_js, \
            "Must export clearAllPositionHighlights to RS namespace"

    def test_exports_clear_comment_highlights_function(self, review_comments_js):
        """
        REQ-d00092-CTH-AD: ReviewSystem namespace SHALL export
        clearCommentHighlights function.
        """
        assert 'RS.clearCommentHighlights' in review_comments_js, \
            "Must export clearCommentHighlights to RS namespace"

    def test_position_label_in_bind_thread_events(self, review_comments_js):
        """
        REQ-d00092-CTH-AE: bindThreadEvents function SHALL set up position label
        click handlers.
        """
        # Check that bindThreadEvents contains position label click handling
        pattern = r'bindThreadEvents.*rs-position-label.*click'
        assert re.search(pattern, review_comments_js, re.DOTALL), \
            "bindThreadEvents must set up position label click handlers"

    def test_implements_req_d00092(self, review_comments_js):
        """
        REQ-d00092: JavaScript SHALL have requirement traceability comment
        referencing REQ-d00092.
        """
        assert 'REQ-d00092' in review_comments_js, \
            "Must have REQ-d00092 traceability comment"

    def test_implements_req_d00087(self, review_comments_js):
        """
        REQ-d00087: JavaScript SHALL have requirement traceability comment
        referencing REQ-d00087 for position resolution.
        """
        assert 'REQ-d00087' in review_comments_js, \
            "Must have REQ-d00087 traceability comment"

    def test_css_implements_req_d00092(self, review_styles_css):
        """
        REQ-d00092: CSS SHALL have requirement traceability comment
        referencing REQ-d00092.
        """
        assert 'REQ-d00092' in review_styles_css, \
            "CSS must have REQ-d00092 traceability comment"

    def test_css_implements_req_d00087(self, review_styles_css):
        """
        REQ-d00087: CSS SHALL have requirement traceability comment
        referencing REQ-d00087 for position confidence styles.
        """
        assert 'REQ-d00087' in review_styles_css, \
            "CSS must have REQ-d00087 traceability comment"
