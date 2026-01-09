"""
Integration Tests for the Review System End-to-End.

This module provides comprehensive integration testing for the trace_view review
system, verifying that all components work together correctly. Tests cover:

1. HTML Generation Integration
2. Review Panel Structure
3. JavaScript Module Integration
4. Data Flow Integration
5. CSS Integration

IMPLEMENTS REQUIREMENTS:
    REQ-d00092: HTML Report Integration

TDD Pattern: Tests written to verify the review system components integrate
properly for end-to-end functionality.
"""

import json
import re
from pathlib import Path
from typing import Dict

import pytest


# =============================================================================
# Test Fixtures
# =============================================================================

@pytest.fixture
def htmlerator_module():
    """Load the HTML generator module."""
    from trace_view.html.generator import HTMLGenerator
    return HTMLGenerator


@pytest.fixture
def sample_requirements():
    """Create sample requirements for testing."""
    from trace_view.models import Requirement
    return {
        "p00001": Requirement(
            id="p00001",
            title="Test PRD Requirement",
            level="PRD",
            status="Active",
            body="Test body content for PRD requirement.",
            rationale="Test rationale",
            implements=set(),
            file_path=Path("prd-test.md"),
            line_number=1
        ),
        "d00001": Requirement(
            id="d00001",
            title="Test DEV Requirement",
            level="DEV",
            status="Draft",
            body="Test body content for DEV requirement.",
            rationale="Test rationale",
            implements={"p00001"},
            file_path=Path("dev-test.md"),
            line_number=1
        ),
    }


@pytest.fixture
def sample_repo_root(tmp_path):
    """Create a temporary repo root for testing."""
    spec_dir = tmp_path / "spec"
    spec_dir.mkdir()
    (spec_dir / "prd-test.md").write_text("# REQ-p00001: Test\n\nTest content")
    (spec_dir / "dev-test.md").write_text("# REQ-d00001: Test\n\nTest content")
    return tmp_path


@pytest.fixture
def htmlerator(htmlerator_module, sample_requirements, sample_repo_root):
    """Create a configured HTMLGenerator instance."""
    return htmlerator_module(
        requirements=sample_requirements,
        repo_root=sample_repo_root
    )


@pytest.fixture
def generated_html_with_review_mode(htmlerator):
    """Generate HTML output with review mode enabled."""
    return htmlerator.generate(
        embed_content=True,
        edit_mode=True,
        review_mode=True
    )


@pytest.fixture
def generated_html_without_review_mode(htmlerator):
    """Generate HTML output without review mode."""
    return htmlerator.generate(
        embed_content=True,
        edit_mode=False,
        review_mode=False
    )


@pytest.fixture
def base_html_content():
    """Load the base.html template content."""
    import trace_view.html as html_module
    html_path = Path(html_module.__file__).parent
    template_path = html_path / "templates" / "base.html"
    return template_path.read_text()


@pytest.fixture
def review_styles_content():
    """Load the review-styles.css content."""
    import trace_view.html as html_module
    html_path = Path(html_module.__file__).parent
    styles_path = html_path / "templates" / "partials" / "review-styles.css"
    return styles_path.read_text()


@pytest.fixture
def review_js_files() -> Dict[str, str]:
    """Load all review JavaScript module files."""
    import trace_view.html as html_module
    html_path = Path(html_module.__file__).parent
    review_dir = html_path / "templates" / "partials" / "review"
    js_files = {}
    for js_file in review_dir.glob("*.js"):
        js_files[js_file.name] = js_file.read_text()
    return js_files


@pytest.fixture
def all_review_js_content(review_js_files) -> str:
    """Concatenate all review JS files for combined testing."""
    return "\n".join(review_js_files.values())


# =============================================================================
# 1. HTML Generation Integration Tests
# =============================================================================

class TestHTMLGenerationIntegration:
    """Tests verifying HTML generator produces valid output with review components."""

    def test_generator_produces_valid_html_doctype(self, generated_html_with_review_mode):
        """
        REQ-d00092: Generated HTML SHALL start with valid DOCTYPE declaration.
        """
        assert generated_html_with_review_mode.strip().startswith("<!DOCTYPE html>"), \
            "Generated HTML must start with DOCTYPE"

    def test_generator_produces_complete_html_structure(self, generated_html_with_review_mode):
        """
        REQ-d00092: Generated HTML SHALL contain complete html/head/body structure.
        """
        assert "<html>" in generated_html_with_review_mode, "Must have html tag"
        assert "<head>" in generated_html_with_review_mode, "Must have head tag"
        assert "<body" in generated_html_with_review_mode, "Must have body tag"
        assert "</html>" in generated_html_with_review_mode, "Must close html tag"

    def test_review_mode_includes_review_css(self, generated_html_with_review_mode):
        """
        REQ-d00092: Generated HTML with review_mode SHALL include review-styles.css content.
        """
        # Review mode CSS is embedded in a <style> tag
        assert ".review-column" in generated_html_with_review_mode, \
            "Review mode HTML must include .review-column CSS"
        assert ".mode-toggle-btn" in generated_html_with_review_mode, \
            "Review mode HTML must include .mode-toggle-btn CSS"

    def test_review_mode_includes_all_js_modules(self, generated_html_with_review_mode):
        """
        REQ-d00092: Generated HTML with review_mode SHALL include all required
        JavaScript modules: review-comments.js, review-data.js, review-packages.js,
        review-position.js, review-status.js, review-sync.js, review-resize.js,
        review-line-numbers.js, review-init.js, review-help.js.
        """
        # All JS modules are concatenated into the review_js block
        # Check for markers from each module
        required_modules = [
            ("review-data.js", "ReviewSystem"),
            ("review-position.js", "position"),
            ("review-line-numbers.js", "line"),
            ("review-comments.js", "comment"),
            ("review-status.js", "status"),
            ("review-packages.js", "package"),
            ("review-sync.js", "sync"),
            ("review-help.js", "help"),
            ("review-resize.js", "resize"),
            ("review-init.js", "toggleReviewMode"),
        ]

        for module_name, expected_content in required_modules:
            assert expected_content.lower() in generated_html_with_review_mode.lower(), \
                f"Review mode HTML must include content from {module_name}"

    def test_review_mode_includes_review_panel_structure(self, generated_html_with_review_mode):
        """
        REQ-d00092: Generated HTML with review_mode SHALL include review panel structure.
        """
        assert 'id="review-column"' in generated_html_with_review_mode, \
            "Must have review-column div"
        assert 'id="reviewResizeHandle"' in generated_html_with_review_mode, \
            "Must have reviewResizeHandle"

    def test_non_review_mode_excludes_review_components(self, generated_html_without_review_mode):
        """
        REQ-d00092: Generated HTML without review_mode SHALL NOT include review components.
        """
        assert 'id="review-column"' not in generated_html_without_review_mode, \
            "Non-review mode must not have review-column"
        assert 'id="reviewResizeHandle"' not in generated_html_without_review_mode, \
            "Non-review mode must not have reviewResizeHandle"

    def test_review_mode_body_has_data_attribute(self, generated_html_with_review_mode):
        """
        REQ-d00092: Generated HTML body tag SHALL have data-review-mode="true" when
        review mode is enabled.
        """
        assert 'data-review-mode="true"' in generated_html_with_review_mode, \
            "Body must have data-review-mode attribute when review mode enabled"


# =============================================================================
# 2. Review Panel Structure Tests
# =============================================================================

class TestReviewPanelStructure:
    """Tests verifying review panel HTML structure exists and is properly organized."""

    def test_review_column_container_exists(self, generated_html_with_review_mode):
        """
        REQ-d00092: Review panel SHALL have a container div with id="review-column".
        """
        assert 'id="review-column"' in generated_html_with_review_mode, \
            "Must have review-column container"

    def test_review_column_has_hidden_class_initially(self, base_html_content):
        """
        REQ-d00092: Review column SHALL have 'hidden' class initially in template.
        """
        pattern = r'<div[^>]*id="review-column"[^>]*class="[^"]*hidden[^"]*"'
        match = re.search(pattern, base_html_content)
        assert match, "Review column must have 'hidden' class by default"

    def test_review_resize_handle_exists(self, generated_html_with_review_mode):
        """
        REQ-d00092: Review column SHALL contain a resize handle div.
        """
        assert 'id="reviewResizeHandle"' in generated_html_with_review_mode, \
            "Must have reviewResizeHandle div"
        assert 'class="review-resize-handle"' in generated_html_with_review_mode, \
            "Resize handle must have correct class"

    def test_review_packages_panel_exists(self, generated_html_with_review_mode):
        """
        REQ-d00092: Review column SHALL contain a packages panel.
        """
        assert 'id="reviewPackagesPanel"' in generated_html_with_review_mode, \
            "Must have reviewPackagesPanel"
        assert 'class="review-packages-panel"' in generated_html_with_review_mode, \
            "Packages panel must have correct class"

    def test_review_panel_content_container_exists(self, generated_html_with_review_mode):
        """
        REQ-d00092: Review column SHALL contain a panel content area.
        """
        assert 'id="review-panel-content"' in generated_html_with_review_mode, \
            "Must have review-panel-content container"

    def test_review_panel_no_selection_message_exists(self, generated_html_with_review_mode):
        """
        REQ-d00092: Review panel SHALL have a no-selection placeholder message.
        """
        assert 'id="review-panel-no-selection"' in generated_html_with_review_mode, \
            "Must have no-selection placeholder"

    def test_review_panel_combined_view_exists(self, generated_html_with_review_mode):
        """
        REQ-d00092: Review panel SHALL have a combined status/comments view container.
        """
        assert 'id="review-panel-combined"' in generated_html_with_review_mode, \
            "Must have combined view container"

    def test_help_menu_container_exists(self, generated_html_with_review_mode):
        """
        REQ-d00092: Review mode SHALL include help menu container.
        """
        assert 'id="rs-help-menu"' in generated_html_with_review_mode, \
            "Must have help menu container"

    def test_help_panel_exists(self, generated_html_with_review_mode):
        """
        REQ-d00092: Review mode SHALL include help panel.
        """
        assert 'id="rs-help-panel"' in generated_html_with_review_mode, \
            "Must have help panel"

    def test_mode_toggle_buttons_exist(self, generated_html_with_review_mode):
        """
        REQ-d00092: Review mode SHALL include Edit and Review mode toggle buttons.
        """
        assert 'id="btnEditMode"' in generated_html_with_review_mode, \
            "Must have Edit mode button"
        assert 'id="btnReviewMode"' in generated_html_with_review_mode, \
            "Must have Review mode button"

    def test_mode_toggle_group_container_exists(self, generated_html_with_review_mode):
        """
        REQ-d00092: Mode toggle buttons SHALL be in a mode-toggle-group container.
        """
        assert 'class="mode-toggle-group"' in generated_html_with_review_mode, \
            "Must have mode-toggle-group container"


# =============================================================================
# 3. JavaScript Module Integration Tests
# =============================================================================

class TestJavaScriptModuleIntegration:
    """Tests verifying all JavaScript modules integrate properly."""

    def test_all_js_modules_exist(self):
        """
        REQ-d00092: All required review JavaScript modules SHALL exist.
        """
        import trace_view.html as html_module
        html_path = Path(html_module.__file__).parent
        review_dir = html_path / "templates" / "partials" / "review"

        required_files = [
            "review-comments.js",
            "review-data.js",
            "review-packages.js",
            "review-position.js",
            "review-status.js",
            "review-sync.js",
            "review-resize.js",
            "review-line-numbers.js",
            "review-init.js",
            "review-help.js",
        ]

        for filename in required_files:
            js_path = review_dir / filename
            assert js_path.exists(), f"Required JS module {filename} must exist"

    def test_js_modules_export_to_reviewsystem_namespace(self, all_review_js_content):
        """
        REQ-d00092: All JS modules SHALL export to the ReviewSystem namespace.
        """
        assert "window.ReviewSystem" in all_review_js_content, \
            "JS modules must use window.ReviewSystem namespace"

    def test_toggle_review_mode_function_exported(self, all_review_js_content):
        """
        REQ-d00092: ReviewSystem SHALL export toggleReviewMode function.
        """
        assert "toggleReviewMode" in all_review_js_content, \
            "Must export toggleReviewMode function"
        # Check it's assigned to RS (ReviewSystem)
        pattern = r'RS\.toggleReviewMode\s*='
        assert re.search(pattern, all_review_js_content), \
            "toggleReviewMode must be exported to ReviewSystem"

    def test_select_req_for_review_function_exported(self, all_review_js_content):
        """
        REQ-d00092: ReviewSystem SHALL export selectReqForReview function.
        """
        assert "selectReqForReview" in all_review_js_content, \
            "Must export selectReqForReview function"
        pattern = r'RS\.selectReqForReview\s*='
        assert re.search(pattern, all_review_js_content), \
            "selectReqForReview must be exported to ReviewSystem"

    def test_toggle_help_panel_function_exported(self, all_review_js_content):
        """
        REQ-d00092: ReviewSystem.help SHALL export toggleHelpPanel function.
        """
        assert "toggleHelpPanel" in all_review_js_content, \
            "Must export toggleHelpPanel function"

    def test_is_review_mode_active_function_exported(self, all_review_js_content):
        """
        REQ-d00092: ReviewSystem SHALL export isReviewModeActive function.
        """
        assert "isReviewModeActive" in all_review_js_content, \
            "Must export isReviewModeActive function"

    def test_init_packages_panel_function_exported(self, all_review_js_content):
        """
        REQ-d00092: ReviewSystem SHALL export initPackagesPanel function.
        """
        assert "initPackagesPanel" in all_review_js_content, \
            "Must export initPackagesPanel function"

    def test_render_thread_list_function_exported(self, all_review_js_content):
        """
        REQ-d00092: ReviewSystem SHALL export renderThreadList function.
        """
        assert "renderThreadList" in all_review_js_content, \
            "Must export renderThreadList function"

    def test_render_status_panel_function_exported(self, all_review_js_content):
        """
        REQ-d00092: ReviewSystem SHALL export renderStatusPanel function.
        """
        assert "renderStatusPanel" in all_review_js_content, \
            "Must export renderStatusPanel function"

    def test_apply_line_numbers_to_card_function_exported(self, all_review_js_content):
        """
        REQ-d00092: ReviewSystem SHALL export applyLineNumbersToCard function.
        """
        assert "applyLineNumbersToCard" in all_review_js_content, \
            "Must export applyLineNumbersToCard function"

    def test_js_modules_use_iife_pattern(self, review_js_files):
        """
        REQ-d00092: All JS modules SHALL use IIFE pattern for encapsulation.
        """
        for filename, content in review_js_files.items():
            # Allow for different IIFE patterns: (function(RS){})() or (function(){})()
            has_iife = "(function(RS)" in content or "(function(" in content
            assert has_iife, f"{filename} must use IIFE pattern"

    def test_review_init_auto_initializes(self, review_js_files):
        """
        REQ-d00092: review-init.js SHALL auto-initialize when DOM is ready.
        """
        init_content = review_js_files.get("review-init.js", "")
        assert "DOMContentLoaded" in init_content or "document.readyState" in init_content, \
            "review-init.js must auto-initialize on DOM ready"


# =============================================================================
# 4. Data Flow Integration Tests
# =============================================================================

class TestDataFlowIntegration:
    """Tests verifying data flows correctly between components."""

    def test_review_data_json_block_exists(self, generated_html_with_review_mode):
        """
        REQ-d00092: Generated HTML SHALL include a JSON data block for review state.
        """
        assert 'id="review-data"' in generated_html_with_review_mode, \
            "Must have review-data JSON block"
        assert 'type="application/json"' in generated_html_with_review_mode, \
            "Review data block must have correct type"

    def test_review_data_loaded_to_window(self, generated_html_with_review_mode):
        """
        REQ-d00092: Review data SHALL be loaded to window.REVIEW_DATA.
        """
        assert "window.REVIEW_DATA" in generated_html_with_review_mode, \
            "Review data must be loaded to window.REVIEW_DATA"

    def test_review_api_url_set(self, generated_html_with_review_mode):
        """
        REQ-d00092: Review API URL SHALL be set in window.REVIEW_API_URL.
        """
        assert "window.REVIEW_API_URL" in generated_html_with_review_mode, \
            "Review API URL must be set"

    def test_review_data_has_required_structure(self, htmlerator):
        """
        REQ-d00092: Review data context SHALL include required structure keys.
        """
        context = htmlerator._build_render_context(
            embed_content=True,
            edit_mode=True,
            review_mode=True
        )

        # Parse the review JSON data
        review_data = json.loads(context['review_json_data'])

        assert "threads" in review_data, "Review data must have 'threads' key"
        assert "flags" in review_data, "Review data must have 'flags' key"
        assert "requests" in review_data, "Review data must have 'requests' key"
        assert "config" in review_data, "Review data must have 'config' key"

    def test_req_content_data_exists_in_embed_mode(self, generated_html_with_review_mode):
        """
        REQ-d00092: When embed_content is True, REQ_CONTENT_DATA SHALL exist.
        """
        assert "window.REQ_CONTENT_DATA" in generated_html_with_review_mode, \
            "REQ content data must be loaded when embed_content is True"

    def test_render_context_includes_review_css(self, htmlerator):
        """
        REQ-d00092: Render context SHALL include review_css when review mode enabled.
        """
        context = htmlerator._build_render_context(
            embed_content=True,
            edit_mode=True,
            review_mode=True
        )

        assert "review_css" in context, "Context must have review_css key"
        assert len(context["review_css"]) > 0, "review_css must not be empty"
        assert ".review-column" in context["review_css"], \
            "review_css must contain .review-column class"

    def test_render_context_includes_review_js(self, htmlerator):
        """
        REQ-d00092: Render context SHALL include review_js when review mode enabled.
        """
        context = htmlerator._build_render_context(
            embed_content=True,
            edit_mode=True,
            review_mode=True
        )

        assert "review_js" in context, "Context must have review_js key"
        assert len(context["review_js"]) > 0, "review_js must not be empty"
        assert "ReviewSystem" in context["review_js"], \
            "review_js must contain ReviewSystem"


# =============================================================================
# 5. CSS Integration Tests
# =============================================================================

class TestCSSIntegration:
    """Tests verifying CSS classes are properly defined and integrated."""

    def test_review_column_class_defined(self, review_styles_content):
        """
        REQ-d00092: CSS SHALL define .review-column class.
        """
        assert ".review-column" in review_styles_content, \
            "CSS must define .review-column class"

    def test_review_column_has_required_properties(self, review_styles_content):
        """
        REQ-d00092: .review-column class SHALL have width, min-width, max-width.
        """
        # Extract .review-column block
        pattern = r'\.review-column\s*\{([^}]+)\}'
        match = re.search(pattern, review_styles_content)
        assert match, "Must have .review-column rule"

        rule_content = match.group(1)
        assert "width:" in rule_content, "Must have width property"
        assert "min-width:" in rule_content, "Must have min-width property"
        assert "max-width:" in rule_content, "Must have max-width property"

    def test_review_column_hidden_class_defined(self, review_styles_content):
        """
        REQ-d00092: CSS SHALL define .review-column.hidden with display: none.
        """
        pattern = r'\.review-column\.hidden\s*\{[^}]*display:\s*none'
        match = re.search(pattern, review_styles_content)
        assert match, ".review-column.hidden must have display: none"

    def test_mode_toggle_btn_class_defined(self, review_styles_content):
        """
        REQ-d00092: CSS SHALL define .mode-toggle-btn class.
        """
        assert ".mode-toggle-btn" in review_styles_content, \
            "CSS must define .mode-toggle-btn class"

    def test_mode_toggle_btn_active_state_defined(self, review_styles_content):
        """
        REQ-d00092: CSS SHALL define .mode-toggle-btn.active state.
        """
        assert ".mode-toggle-btn.active" in review_styles_content, \
            "CSS must define .mode-toggle-btn.active state"

    def test_mode_toggle_btn_hover_state_defined(self, review_styles_content):
        """
        REQ-d00092: CSS SHALL define .mode-toggle-btn:hover state.
        """
        assert ".mode-toggle-btn:hover" in review_styles_content, \
            "CSS must define .mode-toggle-btn:hover state"

    def test_mode_toggle_group_class_defined(self, review_styles_content):
        """
        REQ-d00092: CSS SHALL define .mode-toggle-group class.
        """
        assert ".mode-toggle-group" in review_styles_content, \
            "CSS must define .mode-toggle-group class"

    def test_review_resize_handle_class_defined(self, review_styles_content):
        """
        REQ-d00092: CSS SHALL define .review-resize-handle class.
        """
        assert ".review-resize-handle" in review_styles_content, \
            "CSS must define .review-resize-handle class"

    def test_position_label_class_defined(self, review_styles_content):
        """
        REQ-d00092: CSS SHALL define .rs-position-label class for position labels.
        """
        assert ".rs-position-label" in review_styles_content, \
            "CSS must define .rs-position-label class"

    def test_position_label_confidence_classes_defined(self, review_styles_content):
        """
        REQ-d00092: CSS SHALL define confidence-based position label classes.
        """
        assert ".rs-confidence-exact" in review_styles_content, \
            "CSS must define .rs-confidence-exact class"
        assert ".rs-confidence-approximate" in review_styles_content, \
            "CSS must define .rs-confidence-approximate class"
        assert ".rs-confidence-unanchored" in review_styles_content, \
            "CSS must define .rs-confidence-unanchored class"

    def test_highlight_classes_defined(self, review_styles_content):
        """
        REQ-d00092: CSS SHALL define highlight classes for different confidence levels.
        """
        assert ".rs-highlight-exact" in review_styles_content, \
            "CSS must define .rs-highlight-exact class"
        assert ".rs-highlight-approximate" in review_styles_content, \
            "CSS must define .rs-highlight-approximate class"
        assert ".rs-highlight-unanchored" in review_styles_content, \
            "CSS must define .rs-highlight-unanchored class"

    def test_packages_panel_class_defined(self, review_styles_content):
        """
        REQ-d00092: CSS SHALL define .review-packages-panel class.
        """
        assert ".review-packages-panel" in review_styles_content, \
            "CSS must define .review-packages-panel class"

    def test_help_panel_class_defined(self, review_styles_content):
        """
        REQ-d00092: CSS SHALL define .rs-help-panel class.
        """
        assert ".rs-help-panel" in review_styles_content, \
            "CSS must define .rs-help-panel class"

    def test_help_menu_classes_defined(self, review_styles_content):
        """
        REQ-d00092: CSS SHALL define help menu classes.
        """
        assert ".rs-help-menu-container" in review_styles_content, \
            "CSS must define .rs-help-menu-container class"
        assert ".rs-help-menu-btn" in review_styles_content, \
            "CSS must define .rs-help-menu-btn class"
        assert ".rs-help-menu-dropdown" in review_styles_content, \
            "CSS must define .rs-help-menu-dropdown class"


# =============================================================================
# 6. End-to-End Flow Tests
# =============================================================================

class TestEndToEndFlow:
    """Tests verifying complete end-to-end workflows work correctly."""

    def test_review_mode_toggle_workflow_components_present(
        self, generated_html_with_review_mode
    ):
        """
        REQ-d00092: All components for review mode toggle workflow SHALL be present.
        """
        # Button to toggle
        assert 'id="btnReviewMode"' in generated_html_with_review_mode, \
            "Must have review mode toggle button"

        # Column that gets shown/hidden
        assert 'id="review-column"' in generated_html_with_review_mode, \
            "Must have review column"

        # Body class toggle
        assert 'data-review-mode="true"' in generated_html_with_review_mode, \
            "Must have data-review-mode attribute"

        # JS function to handle toggle
        assert 'toggleReviewMode' in generated_html_with_review_mode, \
            "Must have toggleReviewMode function"

    def test_req_selection_workflow_components_present(
        self, generated_html_with_review_mode
    ):
        """
        REQ-d00092: All components for REQ selection workflow SHALL be present.
        """
        # REQ tree for clicking
        assert 'id="reqTree"' in generated_html_with_review_mode, \
            "Must have reqTree"

        # Panel to show selected REQ
        assert 'id="review-panel-content"' in generated_html_with_review_mode, \
            "Must have review panel content"

        # No-selection state
        assert 'id="review-panel-no-selection"' in generated_html_with_review_mode, \
            "Must have no-selection placeholder"

        # Combined view for selected REQ
        assert 'id="review-panel-combined"' in generated_html_with_review_mode, \
            "Must have combined view"

        # JS function for selection
        assert 'selectReqForReview' in generated_html_with_review_mode, \
            "Must have selectReqForReview function"

    def test_help_system_workflow_components_present(
        self, generated_html_with_review_mode
    ):
        """
        REQ-d00092: All components for help system workflow SHALL be present.
        """
        # Help menu
        assert 'id="rs-help-menu"' in generated_html_with_review_mode, \
            "Must have help menu"
        assert 'id="rs-help-menu-btn"' in generated_html_with_review_mode, \
            "Must have help menu button"
        assert 'id="rs-help-menu-dropdown"' in generated_html_with_review_mode, \
            "Must have help menu dropdown"

        # Help panel
        assert 'id="rs-help-panel"' in generated_html_with_review_mode, \
            "Must have help panel"

        # JS functions
        assert 'toggleHelpPanel' in generated_html_with_review_mode, \
            "Must have toggleHelpPanel function"

    def test_packages_workflow_components_present(
        self, generated_html_with_review_mode
    ):
        """
        REQ-d00092: All components for packages workflow SHALL be present.
        """
        # Packages panel
        assert 'id="reviewPackagesPanel"' in generated_html_with_review_mode, \
            "Must have packages panel"

        # Package list container
        assert 'class="package-list"' in generated_html_with_review_mode, \
            "Must have package list"

        # Package filter toggle
        assert 'id="packageFilterToggle"' in generated_html_with_review_mode, \
            "Must have package filter toggle"

        # JS function
        assert 'togglePackagesPanel' in generated_html_with_review_mode, \
            "Must have togglePackagesPanel function reference"

    def test_comments_workflow_components_present(
        self, generated_html_with_review_mode
    ):
        """
        REQ-d00092: All components for comments workflow SHALL be present.
        """
        # Comments section
        assert 'id="rs-comments-section"' in generated_html_with_review_mode, \
            "Must have comments section"

        # Comments content container
        assert 'id="rs-comments-content"' in generated_html_with_review_mode, \
            "Must have comments content container"

        # Add comment button
        assert 'id="rs-add-comment-btn"' in generated_html_with_review_mode, \
            "Must have add comment button"

        # JS function
        assert 'renderThreadList' in generated_html_with_review_mode, \
            "Must have renderThreadList function"

    def test_status_workflow_components_present(
        self, generated_html_with_review_mode
    ):
        """
        REQ-d00092: All components for status workflow SHALL be present.
        """
        # Status section
        assert 'id="rs-status-section"' in generated_html_with_review_mode, \
            "Must have status section"

        # Status content container
        assert 'id="rs-status-content"' in generated_html_with_review_mode, \
            "Must have status content container"

        # JS function
        assert 'renderStatusPanel' in generated_html_with_review_mode, \
            "Must have renderStatusPanel function"


# =============================================================================
# 7. Module Loading Order Tests
# =============================================================================

class TestModuleLoadingOrder:
    """Tests verifying JavaScript modules are loaded in correct dependency order."""

    def test_js_modules_loaded_in_dependency_order(self):
        """
        REQ-d00092: JavaScript modules SHALL be loaded in dependency order.
        """
        from trace_view.html.generator import HTMLGenerator

        # Create a minimal generator to access _load_review_js
        generator = HTMLGenerator.__new__(HTMLGenerator)
        generator.repo_root = None

        # Get template directory
        import trace_view.html as html_module
        template_dir = Path(html_module.__file__).parent / "templates"
        from jinja2 import Environment, FileSystemLoader, select_autoescape
        generator.env = Environment(
            loader=FileSystemLoader(template_dir),
            autoescape=select_autoescape(['html', 'xml']),
        )

        # Call the method and verify module order
        review_js = generator._load_review_js()

        # Check that review-data.js comes before modules that depend on it
        data_pos = review_js.find("review-data.js")
        init_pos = review_js.find("review-init.js")

        assert data_pos < init_pos, \
            "review-data.js must be loaded before review-init.js"

        # review-init.js should be last (orchestrates others)
        # Check it's after other modules
        position_pos = review_js.find("review-position.js")
        comments_pos = review_js.find("review-comments.js")
        status_pos = review_js.find("review-status.js")

        assert init_pos > position_pos, \
            "review-init.js must be loaded after review-position.js"
        assert init_pos > comments_pos, \
            "review-init.js must be loaded after review-comments.js"
        assert init_pos > status_pos, \
            "review-init.js must be loaded after review-status.js"
