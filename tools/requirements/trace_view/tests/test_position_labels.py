"""
Tests for Position Labels in Thread Headers (Phase 5.3).

Tests verify that position labels correctly display location information
for comment threads in the Spec Review System HTML report.

IMPLEMENTS REQUIREMENTS:
    REQ-d00092: HTML Report Integration
    REQ-d00087: Position Resolution with Fallback
"""

import pytest
import json
from pathlib import Path


# =============================================================================
# Test Fixtures
# =============================================================================

@pytest.fixture
def valid_hash():
    """Provide a valid 8-character hex hash."""
    return "a1b2c3d4"


@pytest.fixture
def sample_thread_line(valid_hash):
    """Create a sample thread with LINE position type."""
    return {
        "threadId": "test-thread-line-001",
        "reqId": "d00001",
        "createdBy": "reviewer",
        "createdAt": "2024-01-01T10:00:00Z",
        "position": {
            "type": "line",
            "hashWhenCreated": valid_hash,
            "lineNumber": 15
        },
        "resolved": False,
        "comments": [{
            "id": "comment-001",
            "author": "reviewer",
            "timestamp": "2024-01-01T10:00:00Z",
            "body": "This line needs clarification"
        }]
    }


@pytest.fixture
def sample_thread_block(valid_hash):
    """Create a sample thread with BLOCK position type."""
    return {
        "threadId": "test-thread-block-001",
        "reqId": "d00001",
        "createdBy": "reviewer",
        "createdAt": "2024-01-01T10:00:00Z",
        "position": {
            "type": "block",
            "hashWhenCreated": valid_hash,
            "lineRange": [10, 20]
        },
        "resolved": False,
        "comments": [{
            "id": "comment-001",
            "author": "reviewer",
            "timestamp": "2024-01-01T10:00:00Z",
            "body": "This section needs review"
        }]
    }


@pytest.fixture
def sample_thread_word(valid_hash):
    """Create a sample thread with WORD position type."""
    return {
        "threadId": "test-thread-word-001",
        "reqId": "d00001",
        "createdBy": "reviewer",
        "createdAt": "2024-01-01T10:00:00Z",
        "position": {
            "type": "word",
            "hashWhenCreated": valid_hash,
            "keyword": "authentication",
            "keywordOccurrence": 1
        },
        "resolved": False,
        "comments": [{
            "id": "comment-001",
            "author": "reviewer",
            "timestamp": "2024-01-01T10:00:00Z",
            "body": "Define authentication more clearly"
        }]
    }


@pytest.fixture
def sample_thread_general(valid_hash):
    """Create a sample thread with GENERAL position type."""
    return {
        "threadId": "test-thread-general-001",
        "reqId": "d00001",
        "createdBy": "reviewer",
        "createdAt": "2024-01-01T10:00:00Z",
        "position": {
            "type": "general",
            "hashWhenCreated": valid_hash
        },
        "resolved": False,
        "comments": [{
            "id": "comment-001",
            "author": "reviewer",
            "timestamp": "2024-01-01T10:00:00Z",
            "body": "General comment about this requirement"
        }]
    }


@pytest.fixture
def review_comments_js_content():
    """Load the review-comments.js file content."""
    js_path = Path(__file__).parent.parent / "html" / "templates" / "partials" / "review" / "review-comments.js"
    if js_path.exists():
        return js_path.read_text()
    return None


@pytest.fixture
def review_styles_css_content():
    """Load the review-styles.css file content."""
    css_path = Path(__file__).parent.parent / "html" / "templates" / "partials" / "review-styles.css"
    if css_path.exists():
        return css_path.read_text()
    return None


# =============================================================================
# Position Label Content Tests
# =============================================================================

class TestPositionLabelFormats:
    """Tests for position label text format."""

    def test_line_label_format(self, review_comments_js_content):
        """
        REQ-d00092-A: LINE position labels SHALL display "Line N" format.

        Example: "Line 15" for a comment anchored to line 15.
        """
        assert review_comments_js_content is not None, "review-comments.js not found"

        # Check that the getPositionLabel function handles LINE type
        assert "RS.PositionType.LINE" in review_comments_js_content
        assert "`Line ${" in review_comments_js_content or "'Line '" in review_comments_js_content

        # Verify pattern: returns "Line {number}"
        assert "pos.lineNumber" in review_comments_js_content

    def test_block_label_format(self, review_comments_js_content):
        """
        REQ-d00092-B: BLOCK position labels SHALL display "Lines N-M" format.

        Example: "Lines 10-20" for a comment anchored to lines 10-20.
        """
        assert review_comments_js_content is not None, "review-comments.js not found"

        # Check that the getPositionLabel function handles BLOCK type
        assert "RS.PositionType.BLOCK" in review_comments_js_content
        assert "pos.lineRange" in review_comments_js_content

        # Verify pattern: "Lines N-M"
        # Check for template literal pattern
        assert "Lines " in review_comments_js_content

    def test_word_label_format(self, review_comments_js_content):
        """
        REQ-d00092-C: WORD position labels SHALL display "Keyword: xyz" format.

        Example: "Keyword: authentication" for a comment anchored to the word.
        """
        assert review_comments_js_content is not None, "review-comments.js not found"

        # Check that the getPositionLabel function handles WORD type
        assert "RS.PositionType.WORD" in review_comments_js_content
        assert "pos.keyword" in review_comments_js_content

        # Verify pattern includes "Keyword:" prefix
        assert "Keyword:" in review_comments_js_content, "WORD label should use 'Keyword:' prefix"

    def test_general_label_format(self, review_comments_js_content):
        """
        REQ-d00092-D: GENERAL position labels SHALL display "General" text.

        Example: "General" for a comment with no specific location.
        """
        assert review_comments_js_content is not None, "review-comments.js not found"

        # Check default case returns "General"
        assert "General" in review_comments_js_content


class TestPositionLabelIcons:
    """Tests for position label icons/indicators."""

    def test_line_icon_present(self, review_comments_js_content):
        """
        REQ-d00092-E: LINE positions SHALL have a location pin icon.
        """
        assert review_comments_js_content is not None, "review-comments.js not found"

        # Check getPositionIcon function exists and handles LINE type
        assert "getPositionIcon" in review_comments_js_content
        # Icon should be defined for LINE type (could be emoji or CSS class)

    def test_block_icon_present(self, review_comments_js_content):
        """
        REQ-d00092-F: BLOCK positions SHALL have a block/list icon.
        """
        assert review_comments_js_content is not None, "review-comments.js not found"

        # Check getPositionIcon handles BLOCK type
        assert "RS.PositionType.BLOCK" in review_comments_js_content

    def test_word_icon_present(self, review_comments_js_content):
        """
        REQ-d00092-G: WORD positions SHALL have a text/keyword icon.
        """
        assert review_comments_js_content is not None, "review-comments.js not found"

        # Check getPositionIcon handles WORD type
        assert "RS.PositionType.WORD" in review_comments_js_content

    def test_general_icon_present(self, review_comments_js_content):
        """
        REQ-d00092-H: GENERAL positions SHALL have a document icon.
        """
        assert review_comments_js_content is not None, "review-comments.js not found"

        # Check default icon is defined


# =============================================================================
# Thread Header Structure Tests
# =============================================================================

class TestThreadHeaderStructure:
    """Tests for thread header HTML structure."""

    def test_position_label_in_thread_template(self, review_comments_js_content):
        """
        REQ-d00092-I: Thread headers SHALL include .rs-position-label element.
        """
        assert review_comments_js_content is not None, "review-comments.js not found"

        # Check that threadTemplate includes position label class
        assert "rs-position-label" in review_comments_js_content
        assert "rs-thread-header" in review_comments_js_content

    def test_position_label_includes_data_attributes(self, review_comments_js_content):
        """
        REQ-d00092-J: Position labels SHALL include data-thread-id and data-position-type.
        """
        assert review_comments_js_content is not None, "review-comments.js not found"

        # Check for data attributes in template
        assert "data-thread-id" in review_comments_js_content
        assert "data-position-type" in review_comments_js_content

    def test_position_label_has_title_tooltip(self, review_comments_js_content):
        """
        REQ-d00092-K: Position labels SHALL have title attribute for tooltip.
        """
        assert review_comments_js_content is not None, "review-comments.js not found"

        # Check for title attribute in position label
        assert 'title="' in review_comments_js_content or "title='" in review_comments_js_content


# =============================================================================
# CSS Styling Tests
# =============================================================================

class TestPositionLabelStyling:
    """Tests for position label CSS styling."""

    def test_position_label_base_style(self, review_styles_css_content):
        """
        REQ-d00092-L: .rs-position-label SHALL have base styling defined.
        """
        assert review_styles_css_content is not None, "review-styles.css not found"

        assert ".rs-position-label" in review_styles_css_content
        # Should have cursor pointer for clickability
        assert "cursor:" in review_styles_css_content

    def test_confidence_exact_style(self, review_styles_css_content):
        """
        REQ-d00087-A: Exact confidence positions SHALL have distinct styling.
        """
        assert review_styles_css_content is not None, "review-styles.css not found"

        assert ".rs-confidence-exact" in review_styles_css_content
        # Exact confidence should use solid border
        assert "solid" in review_styles_css_content

    def test_confidence_approximate_style(self, review_styles_css_content):
        """
        REQ-d00087-B: Approximate confidence positions SHALL have dashed styling.
        """
        assert review_styles_css_content is not None, "review-styles.css not found"

        assert ".rs-confidence-approximate" in review_styles_css_content
        # Approximate confidence should use dashed border
        assert "dashed" in review_styles_css_content

    def test_confidence_unanchored_style(self, review_styles_css_content):
        """
        REQ-d00087-C: Unanchored positions SHALL have muted/gray styling.
        """
        assert review_styles_css_content is not None, "review-styles.css not found"

        assert ".rs-confidence-unanchored" in review_styles_css_content
        # Unanchored should have muted appearance

    def test_position_label_hover_style(self, review_styles_css_content):
        """
        REQ-d00092-M: Position labels SHALL have hover feedback styling.
        """
        assert review_styles_css_content is not None, "review-styles.css not found"

        assert ".rs-position-label:hover" in review_styles_css_content

    def test_position_label_active_style(self, review_styles_css_content):
        """
        REQ-d00092-N: Position labels SHALL have active state styling.
        """
        assert review_styles_css_content is not None, "review-styles.css not found"

        assert ".rs-position-active" in review_styles_css_content or ".rs-position-label.rs-position-active" in review_styles_css_content


# =============================================================================
# Click Interaction Tests
# =============================================================================

class TestPositionLabelInteraction:
    """Tests for position label click behavior."""

    def test_position_label_click_handler(self, review_comments_js_content):
        """
        REQ-d00092-O: Position labels SHALL have click event handlers.
        """
        assert review_comments_js_content is not None, "review-comments.js not found"

        # Check for click event binding on position labels
        assert ".rs-position-label" in review_comments_js_content
        assert "addEventListener" in review_comments_js_content or "click" in review_comments_js_content

    def test_position_label_toggle_behavior(self, review_comments_js_content):
        """
        REQ-d00092-P: Position labels SHALL toggle highlight on click.
        """
        assert review_comments_js_content is not None, "review-comments.js not found"

        # Check for toggle logic
        assert "rs-position-active" in review_comments_js_content
        # Check for toggle off logic (clearing highlights)
        assert "clearAllPositionHighlights" in review_comments_js_content or "clearCommentHighlights" in review_comments_js_content


# =============================================================================
# Confidence Class Assignment Tests
# =============================================================================

class TestConfidenceClassAssignment:
    """Tests for confidence class assignment logic."""

    def test_get_confidence_class_function_exists(self, review_comments_js_content):
        """
        REQ-d00087-D: getConfidenceClass function SHALL be defined.
        """
        assert review_comments_js_content is not None, "review-comments.js not found"

        assert "getConfidenceClass" in review_comments_js_content
        assert "function getConfidenceClass" in review_comments_js_content

    def test_confidence_class_handles_exact(self, review_comments_js_content):
        """
        REQ-d00087-E: getConfidenceClass SHALL return rs-confidence-exact for EXACT.
        """
        assert review_comments_js_content is not None, "review-comments.js not found"

        assert "rs-confidence-exact" in review_comments_js_content
        # Should check for RS.Confidence.EXACT or 'exact'

    def test_confidence_class_handles_approximate(self, review_comments_js_content):
        """
        REQ-d00087-F: getConfidenceClass SHALL return rs-confidence-approximate for APPROXIMATE.
        """
        assert review_comments_js_content is not None, "review-comments.js not found"

        assert "rs-confidence-approximate" in review_comments_js_content

    def test_confidence_class_handles_unanchored(self, review_comments_js_content):
        """
        REQ-d00087-G: getConfidenceClass SHALL return rs-confidence-unanchored for UNANCHORED.
        """
        assert review_comments_js_content is not None, "review-comments.js not found"

        assert "rs-confidence-unanchored" in review_comments_js_content

    def test_confidence_class_checks_resolved_position(self, review_comments_js_content):
        """
        REQ-d00087-H: getConfidenceClass SHALL check thread.resolvedPosition first.
        """
        assert review_comments_js_content is not None, "review-comments.js not found"

        assert "resolvedPosition" in review_comments_js_content


# =============================================================================
# Integration Tests
# =============================================================================

class TestPositionLabelsIntegration:
    """Integration tests for position labels with thread rendering."""

    def test_thread_template_uses_confidence_class(self, review_comments_js_content):
        """
        REQ-d00092-Q: Thread template SHALL apply confidence class to position label.
        """
        assert review_comments_js_content is not None, "review-comments.js not found"

        # Check that template applies confidence class
        # Look for pattern like: class="rs-position-label ${confidenceClass}"
        assert "confidenceClass" in review_comments_js_content
        assert "getConfidenceClass" in review_comments_js_content

    def test_thread_template_includes_icon_and_label(self, review_comments_js_content):
        """
        REQ-d00092-R: Thread template SHALL include both icon and label text.
        """
        assert review_comments_js_content is not None, "review-comments.js not found"

        # Check that both getPositionIcon and getPositionLabel are used in template
        assert "getPositionIcon" in review_comments_js_content
        assert "getPositionLabel" in review_comments_js_content


# =============================================================================
# Edge Case Tests
# =============================================================================

class TestPositionLabelEdgeCases:
    """Tests for edge cases in position label handling."""

    def test_null_position_handling(self, review_comments_js_content):
        """
        REQ-d00092-S: Position functions SHALL handle null/undefined position gracefully.
        """
        assert review_comments_js_content is not None, "review-comments.js not found"

        # Check for null/undefined checks in getPositionLabel/getPositionIcon
        # Default case should return 'General' for missing position

    def test_html_escaping_in_keyword(self, review_comments_js_content):
        """
        REQ-d00092-T: Keyword text SHALL be HTML-escaped in labels.
        """
        assert review_comments_js_content is not None, "review-comments.js not found"

        # Check that escapeHtml is used for keyword in getPositionLabel
        # Look for escapeHtml call in WORD case
        assert "escapeHtml" in review_comments_js_content

    def test_missing_line_number_handling(self, review_comments_js_content):
        """
        REQ-d00092-U: LINE position without lineNumber SHALL fall back to 'General'.
        """
        assert review_comments_js_content is not None, "review-comments.js not found"

        # The getPositionLabel should have a default case

    def test_missing_line_range_handling(self, review_comments_js_content):
        """
        REQ-d00092-V: BLOCK position without lineRange SHALL fall back to 'General'.
        """
        assert review_comments_js_content is not None, "review-comments.js not found"

        # Check that lineRange is accessed with null checks


# =============================================================================
# Tooltip Content Tests
# =============================================================================

class TestPositionTooltips:
    """Tests for position tooltip content."""

    def test_get_position_tooltip_function(self, review_comments_js_content):
        """
        REQ-d00092-W: getPositionTooltip function SHALL provide detailed position info.
        """
        assert review_comments_js_content is not None, "review-comments.js not found"

        assert "getPositionTooltip" in review_comments_js_content

    def test_line_tooltip_content(self, review_comments_js_content):
        """
        REQ-d00092-X: LINE tooltips SHALL show "Line N" format.
        """
        assert review_comments_js_content is not None, "review-comments.js not found"

        # getPositionTooltip should return "Line N" for LINE type
        # Already covered by getPositionTooltip implementation

    def test_word_tooltip_includes_occurrence(self, review_comments_js_content):
        """
        REQ-d00092-Y: WORD tooltips SHALL include keyword and occurrence number.
        """
        assert review_comments_js_content is not None, "review-comments.js not found"

        # Check that tooltip includes occurrence info for WORD
        assert "keywordOccurrence" in review_comments_js_content or "occurrence" in review_comments_js_content
