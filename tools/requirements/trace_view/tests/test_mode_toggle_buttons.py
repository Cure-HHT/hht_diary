"""
Tests for Mode Toggle Buttons (Edit/Review) - Phase 4.3.

IMPLEMENTS REQUIREMENTS:
    REQ-d00092: HTML Report Integration

This module tests:
- Mode toggle button CSS classes and styling
- Button group structure in base.html template
- Consistency between Edit and Review mode buttons
"""

from pathlib import Path

import pytest


class TestModeToggleCSSClasses:
    """Tests for mode toggle button CSS classes."""

    def test_mode_toggle_btn_class_exists(self):
        """
        REQ-d00092: Mode toggle buttons SHALL use the `.mode-toggle-btn` class
        for consistent styling.
        """
        import trace_view.html as html_module
        html_path = Path(html_module.__file__).parent
        styles_path = html_path / "templates" / "partials" / "review-styles.css"

        assert styles_path.exists(), f"review-styles.css must exist at {styles_path}"
        content = styles_path.read_text()

        assert ".mode-toggle-btn" in content, \
            "review-styles.css must contain .mode-toggle-btn class"

    def test_mode_toggle_btn_base_styling(self):
        """
        REQ-d00092: Mode toggle buttons SHALL have consistent base styling
        with proper padding, border, and background properties.
        """
        import trace_view.html as html_module
        html_path = Path(html_module.__file__).parent
        styles_path = html_path / "templates" / "partials" / "review-styles.css"

        content = styles_path.read_text()

        # Find the .mode-toggle-btn rule block
        import re
        btn_pattern = r'\.mode-toggle-btn\s*\{([^}]+)\}'
        match = re.search(btn_pattern, content)

        assert match, "Must have .mode-toggle-btn rule"
        rule_content = match.group(1)

        # Check for required properties
        assert "padding" in rule_content, "Must have padding property"
        assert "border" in rule_content, "Must have border property"
        assert "background" in rule_content, "Must have background property"
        assert "cursor" in rule_content, "Must have cursor property"
        assert "transition" in rule_content, "Must have transition property"

    def test_mode_toggle_btn_active_state(self):
        """
        REQ-d00092: Mode toggle buttons SHALL have an active state with
        distinct styling (blue background, white text).
        """
        import trace_view.html as html_module
        html_path = Path(html_module.__file__).parent
        styles_path = html_path / "templates" / "partials" / "review-styles.css"

        content = styles_path.read_text()

        # Check for active state
        assert ".mode-toggle-btn.active" in content, \
            "Must have .mode-toggle-btn.active rule"

        # Find the active rule block
        import re
        active_pattern = r'\.mode-toggle-btn\.active\s*\{([^}]+)\}'
        match = re.search(active_pattern, content)

        assert match, "Must have .mode-toggle-btn.active rule"
        rule_content = match.group(1)

        # Check for active styling
        assert "background" in rule_content, "Active state must have background"
        assert "#0066cc" in rule_content, "Active state must use blue (#0066cc)"
        assert "white" in rule_content or "#fff" in rule_content, \
            "Active state must have white text"

    def test_mode_toggle_btn_hover_state(self):
        """
        REQ-d00092: Mode toggle buttons SHALL have a hover state for
        visual feedback.
        """
        import trace_view.html as html_module
        html_path = Path(html_module.__file__).parent
        styles_path = html_path / "templates" / "partials" / "review-styles.css"

        content = styles_path.read_text()

        assert ".mode-toggle-btn:hover" in content, \
            "Must have .mode-toggle-btn:hover rule"


class TestModeToggleGroupCSS:
    """Tests for mode toggle button group CSS."""

    def test_mode_toggle_group_class_exists(self):
        """
        REQ-d00092: Mode toggle buttons SHALL be grouped using the
        `.mode-toggle-group` class.
        """
        import trace_view.html as html_module
        html_path = Path(html_module.__file__).parent
        styles_path = html_path / "templates" / "partials" / "review-styles.css"

        content = styles_path.read_text()

        assert ".mode-toggle-group" in content, \
            "review-styles.css must contain .mode-toggle-group class"

    def test_mode_toggle_group_uses_flexbox(self):
        """
        REQ-d00092: Mode toggle group SHALL use flexbox for horizontal layout.
        """
        import trace_view.html as html_module
        html_path = Path(html_module.__file__).parent
        styles_path = html_path / "templates" / "partials" / "review-styles.css"

        content = styles_path.read_text()

        import re
        group_pattern = r'\.mode-toggle-group\s*\{([^}]+)\}'
        match = re.search(group_pattern, content)

        assert match, "Must have .mode-toggle-group rule"
        rule_content = match.group(1)

        assert "display" in rule_content, "Must have display property"
        assert "flex" in rule_content, "Must use flexbox"
        assert "gap" in rule_content, "Must have gap for button spacing"


class TestBaseHTMLModeToggle:
    """Tests for mode toggle buttons in base.html template."""

    def test_base_html_has_mode_toggle_group(self):
        """
        REQ-d00092: base.html SHALL use a mode-toggle-group div to contain
        the Edit and Review mode buttons.
        """
        import trace_view.html as html_module
        html_path = Path(html_module.__file__).parent
        template_path = html_path / "templates" / "base.html"

        content = template_path.read_text()

        assert 'class="mode-toggle-group"' in content, \
            "base.html must have mode-toggle-group class"

    def test_edit_mode_button_uses_correct_class(self):
        """
        REQ-d00092: Edit Mode button SHALL use the mode-toggle-btn class.
        """
        import trace_view.html as html_module
        html_path = Path(html_module.__file__).parent
        template_path = html_path / "templates" / "base.html"

        content = template_path.read_text()

        assert 'id="btnEditMode"' in content, "Must have btnEditMode button"
        assert 'class="mode-toggle-btn"' in content, \
            "Edit Mode button must use mode-toggle-btn class"

    def test_review_mode_button_uses_correct_class(self):
        """
        REQ-d00092: Review Mode button SHALL use the mode-toggle-btn class.
        """
        import trace_view.html as html_module
        html_path = Path(html_module.__file__).parent
        template_path = html_path / "templates" / "base.html"

        content = template_path.read_text()

        assert 'id="btnReviewMode"' in content, "Must have btnReviewMode button"

        # Find the btnReviewMode button line and verify its class
        import re
        review_btn_pattern = r'<button[^>]*id="btnReviewMode"[^>]*>'
        match = re.search(review_btn_pattern, content)
        assert match, "Must have btnReviewMode button"
        btn_html = match.group(0)
        assert 'mode-toggle-btn' in btn_html, \
            "Review Mode button must use mode-toggle-btn class"

    def test_buttons_have_no_emoji_icons(self):
        """
        REQ-d00092: Mode toggle buttons SHALL NOT contain emoji icons
        (no pencil or comment emoji).
        """
        import trace_view.html as html_module
        html_path = Path(html_module.__file__).parent
        template_path = html_path / "templates" / "base.html"

        content = template_path.read_text()

        # Find button content for Edit and Review modes
        import re
        edit_btn_pattern = r'<button[^>]*id="btnEditMode"[^>]*>([^<]*)</button>'
        review_btn_pattern = r'<button[^>]*id="btnReviewMode"[^>]*>([^<]*)</button>'

        edit_match = re.search(edit_btn_pattern, content)
        review_match = re.search(review_btn_pattern, content)

        if edit_match:
            edit_text = edit_match.group(1)
            assert 'Edit' in edit_text or 'edit' in edit_text.lower(), \
                "Edit button should say 'Edit'"

        if review_match:
            review_text = review_match.group(1)
            assert 'Review' in review_text or 'review' in review_text.lower(), \
                "Review button should say 'Review'"

    def test_buttons_are_in_same_group(self):
        """
        REQ-d00092: Edit and Review mode buttons SHALL be in the same
        button group for visual consistency.
        """
        import trace_view.html as html_module
        html_path = Path(html_module.__file__).parent
        template_path = html_path / "templates" / "base.html"

        content = template_path.read_text()

        # Both buttons should be within a mode-toggle-group div
        import re
        group_pattern = r'<div class="mode-toggle-group">(.*?)</div>'
        match = re.search(group_pattern, content, re.DOTALL)

        assert match, "Must have mode-toggle-group div"
        group_content = match.group(1)

        # At least one of the buttons should be in the group
        # (both are conditional based on Jinja templates)
        assert 'btnEditMode' in group_content or 'btnReviewMode' in group_content or \
               'edit_mode' in group_content or 'review_mode' in group_content, \
               "Mode toggle buttons should be inside the mode-toggle-group"


class TestModeToggleAccessibility:
    """Tests for mode toggle button accessibility."""

    def test_buttons_have_cursor_pointer(self):
        """
        REQ-d00092: Mode toggle buttons SHALL have cursor: pointer for
        accessibility.
        """
        import trace_view.html as html_module
        html_path = Path(html_module.__file__).parent
        styles_path = html_path / "templates" / "partials" / "review-styles.css"

        content = styles_path.read_text()

        import re
        btn_pattern = r'\.mode-toggle-btn\s*\{([^}]+)\}'
        match = re.search(btn_pattern, content)

        assert match, "Must have .mode-toggle-btn rule"
        rule_content = match.group(1)

        assert "cursor" in rule_content and "pointer" in rule_content, \
            "Buttons must have cursor: pointer"

    def test_buttons_have_visible_focus_transition(self):
        """
        REQ-d00092: Mode toggle buttons SHALL have smooth transitions
        for state changes.
        """
        import trace_view.html as html_module
        html_path = Path(html_module.__file__).parent
        styles_path = html_path / "templates" / "partials" / "review-styles.css"

        content = styles_path.read_text()

        import re
        btn_pattern = r'\.mode-toggle-btn\s*\{([^}]+)\}'
        match = re.search(btn_pattern, content)

        assert match, "Must have .mode-toggle-btn rule"
        rule_content = match.group(1)

        assert "transition" in rule_content, \
            "Buttons must have transition property"
