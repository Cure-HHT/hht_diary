"""
Tests for Jinja2 template escaping behavior.

IMPLEMENTS REQUIREMENTS:
    REQ-d00015: Traceability Matrix Auto-Generation

These tests ensure that CSS and JavaScript content is NOT HTML-escaped
when embedded in templates, which would break functionality.
"""

import pytest


class TestJinja2Escaping:
    """Test that CSS/JS are not HTML-escaped in generated output."""

    def test_javascript_not_html_escaped(self, htmlerator):
        """JS should not contain &#39; or &#34; HTML entity escapes."""
        html = htmlerator.generate(embed_content=True)

        # Should NOT find HTML-escaped quotes anywhere in the output
        # These would break JavaScript syntax
        assert "&#39;" not in html, "Found HTML-escaped single quotes (&#39;) - JS is broken"
        assert "&#34;" not in html, "Found HTML-escaped double quotes (&#34;) - JS is broken"

    def test_css_font_family_not_escaped(self, htmlerator):
        """CSS font-family declarations should have proper quotes."""
        html = htmlerator.generate()

        # Font-family should appear with proper quotes, not escaped
        # The CSS contains: font-family: 'Segoe UI', ...
        assert "Segoe UI" in html, "Expected font-family declaration in CSS"
        # Should NOT be escaped to &#39;Segoe UI&#39;
        assert "&#39;Segoe UI&#39;" not in html, "Font-family quotes are HTML-escaped"

    def test_javascript_function_syntax_valid(self, htmlerator):
        """Key JS functions should be defined with proper syntax."""
        html = htmlerator.generate(embed_content=True)

        # The TraceView module pattern should be present with proper quotes
        # Looking for: 'use strict' (not &#39;use strict&#39;)
        assert "'use strict'" in html or '"use strict"' in html, \
            "JavaScript 'use strict' directive not found or is escaped"

    def test_json_data_not_double_escaped(self, htmlerator):
        """JSON data block should not have escaped quotes."""
        html = htmlerator.generate(embed_content=True)

        # JSON data is in a script tag with type="application/json"
        # It should contain proper JSON, not HTML-escaped JSON
        assert 'type="application/json"' in html, "JSON data script tag not found"

        # The JSON should have proper structure
        # Should NOT have escaped quotes in the JSON content
        import re
        json_match = re.search(
            r'<script id="req-content-data" type="application/json">(.*?)</script>',
            html,
            re.DOTALL
        )
        if json_match:
            json_content = json_match.group(1)
            assert "&#34;" not in json_content, "JSON data has HTML-escaped double quotes"
            assert "&#39;" not in json_content, "JSON data has HTML-escaped single quotes"
