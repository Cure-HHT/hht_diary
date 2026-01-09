"""
Tests for Help Menu System - Phase 4.5.

IMPLEMENTS REQUIREMENTS:
    REQ-d00092: HTML Report Integration

This module tests:
- Help Menu HTML structure in base.html
- Help Panel HTML structure in base.html
- Help Menu CSS classes in review-styles.css
- Help Panel CSS classes in review-styles.css
- Help System JavaScript exports in review-help.js
"""

import re
from pathlib import Path

import pytest


class TestHelpMenuHTML:
    """Tests for Help Menu HTML structure in base.html."""

    @pytest.fixture
    def base_html_content(self):
        """Load base.html template content."""
        import trace_view.html as html_module
        html_path = Path(html_module.__file__).parent
        template_path = html_path / "templates" / "base.html"
        return template_path.read_text()

    def test_help_menu_container_exists(self, base_html_content):
        """
        REQ-d00092: base.html SHALL contain a help menu container with
        id 'rs-help-menu' when in review mode.
        """
        assert 'id="rs-help-menu"' in base_html_content, \
            "base.html must have help menu container with id='rs-help-menu'"

    def test_help_menu_container_class(self, base_html_content):
        """
        REQ-d00092: Help menu container SHALL use the 'rs-help-menu-container' class.
        """
        assert 'class="rs-help-menu-container"' in base_html_content, \
            "Help menu container must have class='rs-help-menu-container'"

    def test_help_menu_button_exists(self, base_html_content):
        """
        REQ-d00092: Help menu SHALL have a toggle button with id 'rs-help-menu-btn'.
        """
        assert 'id="rs-help-menu-btn"' in base_html_content, \
            "Help menu must have a button with id='rs-help-menu-btn'"

    def test_help_menu_button_onclick(self, base_html_content):
        """
        REQ-d00092: Help menu button SHALL call ReviewSystem.help.toggleHelpMenuFromBtn
        on click.
        """
        assert 'ReviewSystem.help.toggleHelpMenuFromBtn' in base_html_content, \
            "Help menu button must call ReviewSystem.help.toggleHelpMenuFromBtn"

    def test_help_menu_dropdown_exists(self, base_html_content):
        """
        REQ-d00092: Help menu SHALL have a dropdown container with
        id 'rs-help-menu-dropdown'.
        """
        assert 'id="rs-help-menu-dropdown"' in base_html_content, \
            "Help menu must have dropdown with id='rs-help-menu-dropdown'"

    def test_help_menu_has_take_tour_button(self, base_html_content):
        """
        REQ-d00092: Help menu dropdown SHALL have a 'Take Tour' button.
        """
        assert 'id="rs-menu-tour"' in base_html_content, \
            "Help menu must have Take Tour button with id='rs-menu-tour'"
        assert 'Take Tour' in base_html_content, \
            "Help menu must contain 'Take Tour' label"

    def test_help_menu_has_help_panel_button(self, base_html_content):
        """
        REQ-d00092: Help menu dropdown SHALL have a 'Help Panel' button.
        """
        assert 'id="rs-menu-help-panel"' in base_html_content, \
            "Help menu must have Help Panel button with id='rs-menu-help-panel'"
        assert 'Help Panel' in base_html_content, \
            "Help menu must contain 'Help Panel' label"

    def test_help_menu_has_documentation_section(self, base_html_content):
        """
        REQ-d00092: Help menu dropdown SHALL have a Documentation section
        with Quick Start and User Guide links.
        """
        assert 'Documentation' in base_html_content, \
            "Help menu must have Documentation section label"
        assert 'Quick Start' in base_html_content, \
            "Help menu must have Quick Start link"
        assert 'User Guide' in base_html_content, \
            "Help menu must have User Guide link"

    def test_help_menu_conditional_on_review_mode(self, base_html_content):
        """
        REQ-d00092: Help menu SHALL only be rendered when review_mode is enabled.
        """
        # Find the help menu container and check it's wrapped in review_mode conditional
        # Look for {% if review_mode %} before the help menu container
        pattern = r'\{%\s*if\s+review_mode\s*%\}.*?rs-help-menu-container'
        match = re.search(pattern, base_html_content, re.DOTALL)
        assert match, \
            "Help menu container must be conditionally rendered only when review_mode is enabled"


class TestHelpPanelHTML:
    """Tests for Help Panel HTML structure in base.html."""

    @pytest.fixture
    def base_html_content(self):
        """Load base.html template content."""
        import trace_view.html as html_module
        html_path = Path(html_module.__file__).parent
        template_path = html_path / "templates" / "base.html"
        return template_path.read_text()

    def test_help_panel_container_exists(self, base_html_content):
        """
        REQ-d00092: base.html SHALL contain a help panel container with
        id 'rs-help-panel'.
        """
        assert 'id="rs-help-panel"' in base_html_content, \
            "base.html must have help panel container with id='rs-help-panel'"

    def test_help_panel_has_hidden_class(self, base_html_content):
        """
        REQ-d00092: Help panel SHALL be initially hidden with the 'hidden' class.
        """
        # Find the help panel element and check it has hidden class
        pattern = r'<div[^>]*class="rs-help-panel hidden"[^>]*id="rs-help-panel"'
        match = re.search(pattern, base_html_content)
        assert match, "Help panel must have 'hidden' class by default"

    def test_help_panel_has_header(self, base_html_content):
        """
        REQ-d00092: Help panel SHALL have a header with 'Help' title and close button.
        """
        assert 'class="rs-help-panel-header"' in base_html_content, \
            "Help panel must have header with class='rs-help-panel-header'"
        # Look for Help text in h3 tag
        pattern = r'<h3>Help</h3>'
        assert re.search(pattern, base_html_content), \
            "Help panel header must contain 'Help' title"

    def test_help_panel_has_search_input(self, base_html_content):
        """
        REQ-d00092: Help panel SHALL have a search input for filtering help content.
        """
        assert 'id="rs-help-search"' in base_html_content, \
            "Help panel must have search input with id='rs-help-search'"
        assert 'class="rs-help-search-input"' in base_html_content, \
            "Help panel must have search input with class='rs-help-search-input'"

    def test_help_panel_search_calls_filter(self, base_html_content):
        """
        REQ-d00092: Help panel search input SHALL call ReviewSystem.help.filterHelpContent
        on input.
        """
        assert 'ReviewSystem.help.filterHelpContent' in base_html_content, \
            "Help panel search must call ReviewSystem.help.filterHelpContent"

    def test_help_panel_has_sections_container(self, base_html_content):
        """
        REQ-d00092: Help panel SHALL have a sections container with
        id 'rs-help-sections'.
        """
        assert 'id="rs-help-sections"' in base_html_content, \
            "Help panel must have sections container with id='rs-help-sections'"

    def test_help_panel_has_footer(self, base_html_content):
        """
        REQ-d00092: Help panel SHALL have a footer with documentation links.
        """
        assert 'class="rs-help-footer"' in base_html_content, \
            "Help panel must have footer with class='rs-help-footer'"
        assert 'class="rs-help-links"' in base_html_content, \
            "Help panel footer must have links container"

    def test_help_panel_conditional_on_review_mode(self, base_html_content):
        """
        REQ-d00092: Help panel SHALL only be rendered when review_mode is enabled.
        """
        # Find the help panel block and check it's wrapped in review_mode conditional
        pattern = r'\{%\s*if\s+review_mode\s*%\}.*?rs-help-panel'
        match = re.search(pattern, base_html_content, re.DOTALL)
        assert match, \
            "Help panel must be conditionally rendered only when review_mode is enabled"


class TestHelpMenuCSS:
    """Tests for Help Menu CSS classes in review-styles.css."""

    @pytest.fixture
    def styles_content(self):
        """Load review-styles.css content."""
        import trace_view.html as html_module
        html_path = Path(html_module.__file__).parent
        styles_path = html_path / "templates" / "partials" / "review-styles.css"
        return styles_path.read_text()

    def test_help_menu_container_class_exists(self, styles_content):
        """
        REQ-d00092: CSS SHALL define the .rs-help-menu-container class.
        """
        assert ".rs-help-menu-container" in styles_content, \
            "CSS must define .rs-help-menu-container class"

    def test_help_menu_btn_class_exists(self, styles_content):
        """
        REQ-d00092: CSS SHALL define the .rs-help-menu-btn class.
        """
        assert ".rs-help-menu-btn" in styles_content, \
            "CSS must define .rs-help-menu-btn class"

    def test_help_menu_dropdown_class_exists(self, styles_content):
        """
        REQ-d00092: CSS SHALL define the .rs-help-menu-dropdown class.
        """
        assert ".rs-help-menu-dropdown" in styles_content, \
            "CSS must define .rs-help-menu-dropdown class"

    def test_help_menu_dropdown_has_open_state(self, styles_content):
        """
        REQ-d00092: CSS SHALL define an open state for the dropdown.
        """
        assert ".rs-help-menu-dropdown.open" in styles_content, \
            "CSS must define .rs-help-menu-dropdown.open class"

    def test_help_menu_item_class_exists(self, styles_content):
        """
        REQ-d00092: CSS SHALL define the .rs-help-menu-item class.
        """
        assert ".rs-help-menu-item" in styles_content, \
            "CSS must define .rs-help-menu-item class"

    def test_help_menu_section_class_exists(self, styles_content):
        """
        REQ-d00092: CSS SHALL define the .rs-help-menu-section class.
        """
        assert ".rs-help-menu-section" in styles_content, \
            "CSS must define .rs-help-menu-section class"


class TestHelpPanelCSS:
    """Tests for Help Panel CSS classes in review-styles.css."""

    @pytest.fixture
    def styles_content(self):
        """Load review-styles.css content."""
        import trace_view.html as html_module
        html_path = Path(html_module.__file__).parent
        styles_path = html_path / "templates" / "partials" / "review-styles.css"
        return styles_path.read_text()

    def test_help_panel_class_exists(self, styles_content):
        """
        REQ-d00092: CSS SHALL define the .rs-help-panel class.
        """
        assert ".rs-help-panel" in styles_content, \
            "CSS must define .rs-help-panel class"

    def test_help_panel_header_class_exists(self, styles_content):
        """
        REQ-d00092: CSS SHALL define the .rs-help-panel-header class.
        """
        assert ".rs-help-panel-header" in styles_content, \
            "CSS must define .rs-help-panel-header class"

    def test_help_panel_search_class_exists(self, styles_content):
        """
        REQ-d00092: CSS SHALL define the .rs-help-search class.
        """
        assert ".rs-help-search" in styles_content, \
            "CSS must define .rs-help-search class"

    def test_help_panel_sections_class_exists(self, styles_content):
        """
        REQ-d00092: CSS SHALL define the .rs-help-sections class.
        """
        assert ".rs-help-sections" in styles_content, \
            "CSS must define .rs-help-sections class"

    def test_help_panel_section_class_exists(self, styles_content):
        """
        REQ-d00092: CSS SHALL define the .rs-help-section class.
        """
        assert ".rs-help-section" in styles_content, \
            "CSS must define .rs-help-section class"

    def test_help_panel_footer_class_exists(self, styles_content):
        """
        REQ-d00092: CSS SHALL define the .rs-help-footer class.
        """
        assert ".rs-help-footer" in styles_content, \
            "CSS must define .rs-help-footer class"


class TestHelpSystemJavaScript:
    """Tests for Help System JavaScript exports in review-help.js."""

    @pytest.fixture
    def js_content(self):
        """Load review-help.js content."""
        import trace_view.html as html_module
        html_path = Path(html_module.__file__).parent
        js_path = html_path / "templates" / "partials" / "review" / "review-help.js"
        return js_path.read_text()

    def test_help_system_exports_init(self, js_content):
        """
        REQ-d00092: Help system SHALL export an init function.
        """
        # Check exports section
        pattern = r'RS\.help\s*=\s*\{[^}]*\binit\b'
        assert re.search(pattern, js_content), \
            "Help system must export 'init' function"

    def test_help_system_exports_toggleHelpPanel(self, js_content):
        """
        REQ-d00092: Help system SHALL export a toggleHelpPanel function.
        """
        pattern = r'RS\.help\s*=\s*\{[^}]*\btoggleHelpPanel\b'
        assert re.search(pattern, js_content), \
            "Help system must export 'toggleHelpPanel' function"

    def test_help_system_exports_toggleHelpMenuFromBtn(self, js_content):
        """
        REQ-d00092: Help system SHALL export a toggleHelpMenuFromBtn function
        for HTML onclick handlers.
        """
        pattern = r'RS\.help\s*=\s*\{[^}]*\btoggleHelpMenuFromBtn\b'
        assert re.search(pattern, js_content), \
            "Help system must export 'toggleHelpMenuFromBtn' function"

    def test_help_system_exports_startTour(self, js_content):
        """
        REQ-d00092: Help system SHALL export a startTour function.
        """
        pattern = r'RS\.help\s*=\s*\{[^}]*\bstartTour\b'
        assert re.search(pattern, js_content), \
            "Help system must export 'startTour' function"

    def test_help_system_exports_filterHelpContent(self, js_content):
        """
        REQ-d00092: Help system SHALL export a filterHelpContent function.
        """
        pattern = r'RS\.help\s*=\s*\{[^}]*\bfilterHelpContent\b'
        assert re.search(pattern, js_content), \
            "Help system must export 'filterHelpContent' function"

    def test_help_system_exports_showOnboarding(self, js_content):
        """
        REQ-d00092: Help system SHALL export a showOnboarding function.
        """
        pattern = r'RS\.help\s*=\s*\{[^}]*\bshowOnboarding\b'
        assert re.search(pattern, js_content), \
            "Help system must export 'showOnboarding' function"

    def test_help_system_exports_renderHelpPanelContent(self, js_content):
        """
        REQ-d00092: Help system SHALL export a renderHelpPanelContent function.
        """
        pattern = r'RS\.help\s*=\s*\{[^}]*\brenderHelpPanelContent\b'
        assert re.search(pattern, js_content), \
            "Help system must export 'renderHelpPanelContent' function"


class TestHelpSystemIntegration:
    """Tests for Help System integration with the Review System."""

    @pytest.fixture
    def js_content(self):
        """Load review-help.js content."""
        import trace_view.html as html_module
        html_path = Path(html_module.__file__).parent
        js_path = html_path / "templates" / "partials" / "review" / "review-help.js"
        return js_path.read_text()

    def test_help_system_uses_iife_pattern(self, js_content):
        """
        REQ-d00092: Help system SHALL use IIFE pattern for encapsulation.
        """
        # Check for IIFE wrapping ReviewSystem
        assert "(function(RS)" in js_content, \
            "Help system must use IIFE pattern"
        assert "window.ReviewSystem = window.ReviewSystem || {}" in js_content, \
            "Help system must attach to window.ReviewSystem"

    def test_help_system_loads_help_json(self, js_content):
        """
        REQ-d00092: Help system SHALL load help data from JSON files.
        """
        assert "loadHelpData" in js_content, \
            "Help system must have loadHelpData function"
        assert "tooltips.json" in js_content, \
            "Help system must load tooltips.json"
        assert "onboarding.json" in js_content, \
            "Help system must load onboarding.json"
        assert "help-panel.json" in js_content, \
            "Help system must load help-panel.json"

    def test_help_system_sets_up_global_handlers(self, js_content):
        """
        REQ-d00092: Help system SHALL set up global event handlers for
        keyboard shortcuts and click-outside behavior.
        """
        assert "setupGlobalHelpHandlers" in js_content, \
            "Help system must have setupGlobalHelpHandlers function"
        assert "document.addEventListener" in js_content, \
            "Help system must add document event listeners"

    def test_help_system_keyboard_shortcut(self, js_content):
        """
        REQ-d00092: Help system SHALL support '?' keyboard shortcut
        to toggle help panel.
        """
        # Check for ? key handler
        pattern = r'e\.key\s*===?\s*[\'"]?\?[\'"]?'
        assert re.search(pattern, js_content), \
            "Help system must handle '?' key press"

    def test_help_system_escape_closes_panel(self, js_content):
        """
        REQ-d00092: Help system SHALL close help panel when Escape is pressed.
        """
        assert "Escape" in js_content, \
            "Help system must handle Escape key"


class TestHelpJSONFiles:
    """Tests for Help JSON data files."""

    def test_help_panel_json_exists(self):
        """
        REQ-d00092: help-panel.json SHALL exist in the help directory.
        """
        import trace_view.html as html_module
        html_path = Path(html_module.__file__).parent
        json_path = html_path / "templates" / "partials" / "review" / "help" / "help-panel.json"
        assert json_path.exists(), \
            f"help-panel.json must exist at {json_path}"

    def test_tooltips_json_exists(self):
        """
        REQ-d00092: tooltips.json SHALL exist in the help directory.
        """
        import trace_view.html as html_module
        html_path = Path(html_module.__file__).parent
        json_path = html_path / "templates" / "partials" / "review" / "help" / "tooltips.json"
        assert json_path.exists(), \
            f"tooltips.json must exist at {json_path}"

    def test_onboarding_json_exists(self):
        """
        REQ-d00092: onboarding.json SHALL exist in the help directory.
        """
        import trace_view.html as html_module
        html_path = Path(html_module.__file__).parent
        json_path = html_path / "templates" / "partials" / "review" / "help" / "onboarding.json"
        assert json_path.exists(), \
            f"onboarding.json must exist at {json_path}"

    def test_help_panel_json_valid(self):
        """
        REQ-d00092: help-panel.json SHALL be valid JSON with required structure.
        """
        import json
        import trace_view.html as html_module
        html_path = Path(html_module.__file__).parent
        json_path = html_path / "templates" / "partials" / "review" / "help" / "help-panel.json"

        with open(json_path) as f:
            data = json.load(f)

        assert "helpPanel" in data, "help-panel.json must have 'helpPanel' key"
        assert "sections" in data["helpPanel"], "helpPanel must have 'sections'"
        assert len(data["helpPanel"]["sections"]) > 0, "helpPanel must have at least one section"
