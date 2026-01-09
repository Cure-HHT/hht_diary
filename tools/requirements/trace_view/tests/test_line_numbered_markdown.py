"""
Tests for Phase 5.2: Line-Numbered Markdown View

IMPLEMENTS REQUIREMENTS:
    REQ-d00092: HTML Report Integration (Phase 5.2)

This module tests:
- Line number generation from markdown source
- JavaScript function availability
- CSS class generation
- Click handler integration
"""

import pytest
from pathlib import Path
import re


# =============================================================================
# Test Fixtures
# =============================================================================

@pytest.fixture
def review_line_numbers_js():
    """Load the review-line-numbers.js source code."""
    js_path = (
        Path(__file__).parent.parent /
        "html" / "templates" / "partials" / "review" / "review-line-numbers.js"
    )
    if not js_path.exists():
        pytest.skip("review-line-numbers.js not found")
    return js_path.read_text()


@pytest.fixture
def review_init_js():
    """Load the review-init.js source code."""
    js_path = (
        Path(__file__).parent.parent /
        "html" / "templates" / "partials" / "review" / "review-init.js"
    )
    if not js_path.exists():
        pytest.skip("review-init.js not found")
    return js_path.read_text()


@pytest.fixture
def review_css():
    """Load the review-styles.css source code."""
    css_path = (
        Path(__file__).parent.parent /
        "html" / "templates" / "partials" / "review-styles.css"
    )
    if not css_path.exists():
        pytest.skip("review-styles.css not found")
    return css_path.read_text()


@pytest.fixture
def generator_py():
    """Load the generator.py source code."""
    py_path = (
        Path(__file__).parent.parent /
        "html" / "generator.py"
    )
    if not py_path.exists():
        pytest.skip("generator.py not found")
    return py_path.read_text()


# =============================================================================
# REQ-d00092-A: Line Numbers Module Structure
# =============================================================================

class TestLineNumbersModuleStructure:
    """Test that review-line-numbers.js has required structure."""

    def test_module_exists(self, review_line_numbers_js):
        """
        REQ-d00092-A: Line numbers module SHALL exist.
        """
        assert len(review_line_numbers_js) > 0

    def test_exports_convert_function(self, review_line_numbers_js):
        """
        REQ-d00092-A: Module SHALL export convertToLineNumberedView function.
        """
        assert "RS.convertToLineNumberedView" in review_line_numbers_js
        assert "function convertToLineNumberedView" in review_line_numbers_js

    def test_exports_apply_function(self, review_line_numbers_js):
        """
        REQ-d00092-A: Module SHALL export applyLineNumbersToCard function.
        """
        assert "RS.applyLineNumbersToCard" in review_line_numbers_js
        assert "function applyLineNumbersToCard" in review_line_numbers_js

    def test_exports_get_selection(self, review_line_numbers_js):
        """
        REQ-d00092-A: Module SHALL export getLineSelection function.
        """
        assert "RS.getLineSelection" in review_line_numbers_js
        assert "function getLineSelection" in review_line_numbers_js

    def test_exports_clear_functions(self, review_line_numbers_js):
        """
        REQ-d00092-A: Module SHALL export clearLineSelection and clearAllLineSelections.
        """
        assert "RS.clearLineSelection" in review_line_numbers_js
        assert "RS.clearAllLineSelections" in review_line_numbers_js


# =============================================================================
# REQ-d00092-B: Line Number HTML Generation
# =============================================================================

class TestLineNumberHTMLGeneration:
    """Test that line number HTML is generated correctly."""

    def test_generates_container_div(self, review_line_numbers_js):
        """
        REQ-d00092-B: Function SHALL generate rs-line-numbers-container div.
        """
        assert "rs-line-numbers-container" in review_line_numbers_js

    def test_generates_lines_table(self, review_line_numbers_js):
        """
        REQ-d00092-B: Function SHALL generate rs-lines-table structure.
        """
        assert "rs-lines-table" in review_line_numbers_js

    def test_generates_line_row(self, review_line_numbers_js):
        """
        REQ-d00092-B: Function SHALL generate rs-line-row for each line.
        """
        assert "rs-line-row" in review_line_numbers_js
        assert 'data-line=' in review_line_numbers_js

    def test_generates_line_number_cell(self, review_line_numbers_js):
        """
        REQ-d00092-B: Function SHALL generate rs-line-number cell.
        """
        assert "rs-line-number" in review_line_numbers_js

    def test_generates_line_text_cell(self, review_line_numbers_js):
        """
        REQ-d00092-B: Function SHALL generate rs-line-text cell.
        """
        assert "rs-line-text" in review_line_numbers_js

    def test_generates_hint_bar(self, review_line_numbers_js):
        """
        REQ-d00092-B: Function SHALL generate rs-line-numbers-hint bar.
        """
        assert "rs-line-numbers-hint" in review_line_numbers_js


# =============================================================================
# REQ-d00092-C: Line Selection Handlers
# =============================================================================

class TestLineSelectionHandlers:
    """Test line selection functionality."""

    def test_single_line_selection(self, review_line_numbers_js):
        """
        REQ-d00092-C: Module SHALL support single line selection.
        """
        assert "function selectSingleLine" in review_line_numbers_js
        assert "selectedLineNumber" in review_line_numbers_js

    def test_range_selection(self, review_line_numbers_js):
        """
        REQ-d00092-C: Module SHALL support range selection (shift-click).
        """
        assert "function selectLineRange" in review_line_numbers_js
        assert "selectedLineRange" in review_line_numbers_js

    def test_click_handler(self, review_line_numbers_js):
        """
        REQ-d00092-C: Module SHALL handle line click events.
        """
        assert "function handleLineClick" in review_line_numbers_js

    def test_dispatches_selection_event(self, review_line_numbers_js):
        """
        REQ-d00092-C: Module SHALL dispatch rs:line-selected event.
        """
        assert "rs:line-selected" in review_line_numbers_js

    def test_shift_click_for_range(self, review_line_numbers_js):
        """
        REQ-d00092-C: Module SHALL detect shift-click for range selection.
        """
        assert "event.shiftKey" in review_line_numbers_js


# =============================================================================
# REQ-d00092-D: CSS Styles for Line Numbers
# =============================================================================

class TestLineNumbersCSS:
    """Test that required CSS styles exist."""

    def test_line_numbers_container_style(self, review_css):
        """
        REQ-d00092-D: CSS SHALL define .rs-line-numbers-container.
        """
        assert ".rs-line-numbers-container" in review_css

    def test_lines_table_style(self, review_css):
        """
        REQ-d00092-D: CSS SHALL define .rs-lines-table.
        """
        assert ".rs-lines-table" in review_css

    def test_line_row_style(self, review_css):
        """
        REQ-d00092-D: CSS SHALL define .rs-line-row.
        """
        assert ".rs-line-row" in review_css

    def test_line_number_style(self, review_css):
        """
        REQ-d00092-D: CSS SHALL define .rs-line-number.
        """
        assert ".rs-line-number" in review_css

    def test_line_text_style(self, review_css):
        """
        REQ-d00092-D: CSS SHALL define .rs-line-text.
        """
        assert ".rs-line-text" in review_css

    def test_selected_line_style(self, review_css):
        """
        REQ-d00092-D: CSS SHALL define .rs-line-row.selected.
        """
        assert ".rs-line-row.selected" in review_css

    def test_line_hint_style(self, review_css):
        """
        REQ-d00092-D: CSS SHALL define .rs-line-numbers-hint.
        """
        assert ".rs-line-numbers-hint" in review_css

    def test_hint_visible_in_review_mode(self, review_css):
        """
        REQ-d00092-D: Hint bar SHALL be visible in review mode.
        """
        assert ".review-mode-active .rs-line-numbers-hint" in review_css


# =============================================================================
# REQ-d00092-E: Review Init Module
# =============================================================================

class TestReviewInitModule:
    """Test that review-init.js orchestrates review mode."""

    def test_module_exists(self, review_init_js):
        """
        REQ-d00092-E: Review init module SHALL exist.
        """
        assert len(review_init_js) > 0

    def test_exports_toggle_review_mode(self, review_init_js):
        """
        REQ-d00092-E: Module SHALL export toggleReviewMode function.
        """
        assert "RS.toggleReviewMode" in review_init_js
        assert "function toggleReviewMode" in review_init_js

    def test_exports_select_req_for_review(self, review_init_js):
        """
        REQ-d00092-E: Module SHALL export selectReqForReview function.
        """
        assert "RS.selectReqForReview" in review_init_js
        assert "function selectReqForReview" in review_init_js

    def test_exports_is_review_mode_active(self, review_init_js):
        """
        REQ-d00092-E: Module SHALL export isReviewModeActive function.
        """
        assert "RS.isReviewModeActive" in review_init_js

    def test_applies_line_numbers_on_selection(self, review_init_js):
        """
        REQ-d00092-E: Module SHALL apply line numbers when REQ is selected.
        """
        assert "applyLineNumbersToReqCard" in review_init_js

    def test_dispatches_review_mode_event(self, review_init_js):
        """
        REQ-d00092-E: Module SHALL dispatch rs:review-mode-changed event.
        """
        assert "rs:review-mode-changed" in review_init_js


# =============================================================================
# REQ-d00092-F: Generator Integration
# =============================================================================

class TestGeneratorIntegration:
    """Test that generator.py loads line numbers module."""

    def test_loads_review_line_numbers_js(self, generator_py):
        """
        REQ-d00092-F: Generator SHALL load review-line-numbers.js.
        """
        assert "review-line-numbers.js" in generator_py

    def test_loads_review_init_js(self, generator_py):
        """
        REQ-d00092-F: Generator SHALL load review-init.js.
        """
        assert "review-init.js" in generator_py

    def test_review_init_loaded_last(self, generator_py):
        """
        REQ-d00092-F: review-init.js SHALL be loaded after other modules.
        """
        # Find the js_files list
        match = re.search(r'js_files\s*=\s*\[(.*?)\]', generator_py, re.DOTALL)
        assert match, "Could not find js_files list in generator.py"

        files_block = match.group(1)
        # review-init.js should appear after review-resize.js
        init_pos = files_block.find("review-init.js")
        resize_pos = files_block.find("review-resize.js")
        assert init_pos > resize_pos, "review-init.js should be after review-resize.js"


# =============================================================================
# REQ-d00092-G: Review Mode Toggle Integration
# =============================================================================

class TestReviewModeToggle:
    """Test review mode toggle integration."""

    def test_toggle_updates_body_class(self, review_init_js):
        """
        REQ-d00092-G: Toggle SHALL update body class.
        """
        assert "review-mode-active" in review_init_js
        assert "classList.toggle" in review_init_js

    def test_toggle_updates_button(self, review_init_js):
        """
        REQ-d00092-G: Toggle SHALL update button state.
        """
        assert "btnReviewMode" in review_init_js

    def test_toggle_shows_review_column(self, review_init_js):
        """
        REQ-d00092-G: Toggle SHALL show/hide review column.
        """
        assert "review-column" in review_init_js

    def test_clears_selection_on_deactivate(self, review_init_js):
        """
        REQ-d00092-G: Toggle SHALL clear selection when deactivating.
        """
        assert "clearCurrentSelection" in review_init_js


# =============================================================================
# REQ-d00092-H: Line Selection State
# =============================================================================

class TestLineSelectionState:
    """Test line selection state management."""

    def test_global_line_number_state(self, review_line_numbers_js):
        """
        REQ-d00092-H: Module SHALL expose selectedLineNumber globally.
        """
        assert "window.selectedLineNumber" in review_line_numbers_js

    def test_global_line_range_state(self, review_line_numbers_js):
        """
        REQ-d00092-H: Module SHALL expose selectedLineRange globally.
        """
        assert "window.selectedLineRange" in review_line_numbers_js

    def test_selection_types(self, review_line_numbers_js):
        """
        REQ-d00092-H: getLineSelection SHALL return type, lineNumber, lineRange.
        """
        assert "'line'" in review_line_numbers_js
        assert "'block'" in review_line_numbers_js
        assert "'general'" in review_line_numbers_js


# =============================================================================
# REQ-d00092-I: Keyboard Shortcuts
# =============================================================================

class TestKeyboardShortcuts:
    """Test keyboard shortcut handling."""

    def test_escape_clears_selection(self, review_line_numbers_js):
        """
        REQ-d00092-I: Escape key SHALL clear line selection.
        """
        assert "Escape" in review_line_numbers_js
        assert "clearAllLineSelections" in review_line_numbers_js

    def test_keyboard_handler_bound(self, review_line_numbers_js):
        """
        REQ-d00092-I: Module SHALL bind keydown event listener.
        """
        assert "keydown" in review_line_numbers_js
        assert "handleKeyboard" in review_line_numbers_js


# =============================================================================
# Integration Tests
# =============================================================================

class TestModuleIntegration:
    """Test that all modules work together."""

    def test_line_numbers_exports_to_review_system(self, review_line_numbers_js):
        """
        REQ-d00092: Line numbers module exports to ReviewSystem namespace.
        """
        assert "window.ReviewSystem" in review_line_numbers_js
        assert "(RS)" in review_line_numbers_js

    def test_review_init_calls_line_numbers(self, review_init_js):
        """
        REQ-d00092: Review init calls applyLineNumbersToCard.
        """
        assert "RS.applyLineNumbersToCard" in review_init_js

    def test_review_init_calls_clear_all(self, review_init_js):
        """
        REQ-d00092: Review init calls clearAllLineSelections.
        """
        assert "RS.clearAllLineSelections" in review_init_js

    def test_requirement_header_present(self, review_line_numbers_js, review_init_js):
        """
        REQ-d00092: Both modules SHALL have IMPLEMENTS REQUIREMENTS header.
        """
        assert "IMPLEMENTS REQUIREMENTS" in review_line_numbers_js
        assert "REQ-d00092" in review_line_numbers_js
        assert "IMPLEMENTS REQUIREMENTS" in review_init_js
        assert "REQ-d00092" in review_init_js
