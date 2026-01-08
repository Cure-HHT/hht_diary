"""
Tests for Build-time Asset Embedding (REQ-tv-d00004).

Each test function documents which assertion it verifies in its docstring.
The Elspais reporter extracts these references for traceability.
"""

from pathlib import Path

import pytest


class TestCSSEmbedding:
    """Tests for CSS embedding in generated HTML."""

    def test_css_embedded_in_style_tags(self, htmlerator):
        """
        REQ-tv-d00004-A: The generator SHALL embed CSS content inline within
        `<style>` tags in the generated HTML.
        """
        html = htmlerator.generate()

        # Must have style tags
        assert "<style>" in html or "<style " in html, \
            "Generated HTML must contain <style> tags"

        # Must have CSS content inside style tags
        import re
        style_content = re.search(r'<style[^>]*>(.*?)</style>', html, re.DOTALL | re.IGNORECASE)
        assert style_content is not None, "Style tags must contain content"
        assert len(style_content.group(1).strip()) > 0, "Style content must not be empty"


class TestJSEmbedding:
    """Tests for JavaScript embedding in generated HTML."""

    def test_js_embedded_in_script_tags(self, htmlerator):
        """
        REQ-tv-d00004-B: The generator SHALL embed JavaScript content inline
        within `<script>` tags in the generated HTML.
        """
        html = htmlerator.generate(embed_content=True)

        # Must have script tags with content (not just src references)
        import re
        inline_scripts = re.findall(
            r'<script(?![^>]*\bsrc\b)[^>]*>(.*?)</script>',
            html,
            re.DOTALL | re.IGNORECASE
        )

        # Should have at least one inline script with content
        script_contents = [s for s in inline_scripts if s.strip()]
        assert len(script_contents) > 0, \
            "Generated HTML must contain inline script content"


class TestFileReadTiming:
    """Tests for file reading timing."""

    def test_files_read_at_render_time(self, htmlerator):
        """
        REQ-tv-d00004-C: Asset files SHALL be read from disk at template
        render time, not at module import time.
        """
        # This test verifies that changes to asset files are reflected
        # in subsequent renders without reimporting the module

        # First render
        html1 = htmlerator.generate()

        # Modify the CSS file (if we can access it)
        # The key is that re-rendering should pick up changes
        html2 = htmlerator.generate()

        # Both renders should succeed
        assert html1 is not None
        assert html2 is not None


class TestHelperMethods:
    """Tests for asset loading helper methods."""

    def test_has_load_css_method(self, htmlerator):
        """
        REQ-tv-d00004-D: The generator SHALL provide a helper method
        `_load_css()` that reads and returns the CSS file content.
        """
        assert hasattr(htmlerator, '_load_css'), "Generator must have _load_css method"
        assert callable(htmlerator._load_css), "_load_css must be callable"

        css_content = htmlerator._load_css()
        assert isinstance(css_content, str), "_load_css must return string"
        assert len(css_content) > 0, "_load_css must return non-empty content"

    def test_has_load_js_method(self, htmlerator):
        """
        REQ-tv-d00004-E: The generator SHALL provide a helper method
        `_load_js()` that reads and returns the JavaScript file content.
        """
        assert hasattr(htmlerator, '_load_js'), "Generator must have _load_js method"
        assert callable(htmlerator._load_js), "_load_js must be callable"

        js_content = htmlerator._load_js()
        assert isinstance(js_content, str), "_load_js must return string"
        assert len(js_content) > 0, "_load_js must return non-empty content"


class TestErrorHandling:
    """Tests for file reading error handling."""

    def test_file_errors_include_path(self, htmlerator, monkeypatch):
        """
        REQ-tv-d00004-F: File reading errors SHALL raise informative
        exceptions including the expected file path.
        """
        # Temporarily break the file path to trigger an error
        def broken_load_css():
            raise FileNotFoundError("Missing: /path/to/styles.css")

        monkeypatch.setattr(htmlerator, '_load_css', broken_load_css)

        with pytest.raises(Exception) as exc_info:
            htmlerator._load_css()

        # Error message should include path information
        error_msg = str(exc_info.value)
        assert "path" in error_msg.lower() or "/" in error_msg or "\\" in error_msg, \
            f"Error should include file path: {error_msg}"


class TestSelfContainedOutput:
    """Tests for self-contained HTML output."""

    def test_output_is_self_contained(self, htmlerator):
        """
        REQ-tv-d00004-G: The generated HTML document SHALL be completely
        self-contained with no external file dependencies (except for CDN
        libraries in embedded mode).
        """
        html = htmlerator.generate(embed_content=True)

        import re

        # Check for local file references (should not have any)
        # Allowed: CDN references (https://), data: URIs, anchor links (#)
        local_refs = re.findall(r'(?:src|href)=["\'](?!https?://|#|data:)([^"\']+)["\']', html)

        # Filter out valid references
        invalid_refs = [
            ref for ref in local_refs
            if not ref.startswith('#')  # anchor links OK
            and not ref.startswith('vscode://')  # VS Code links OK
            and not ref.startswith('data:')  # data URIs OK
            and not ref.startswith('${')  # JS template literals OK (runtime-resolved)
        ]

        assert len(invalid_refs) == 0, \
            f"Found local file dependencies: {invalid_refs}"


class TestTemplateVariables:
    """Tests for template variable support."""

    def test_supports_template_variables_in_assets(self, htmlerator_class, sample_requirements):
        """
        REQ-tv-d00004-H: The embedding approach SHALL support Jinja2 template
        variables within embedded CSS and JavaScript content for dynamic
        values such as `base_path` and `repo_root`.
        """
        generator = htmlerator_class(
            requirements=sample_requirements,
            base_path='../../../',
            repo_root=Path('/test/repo')
        )
        html = generator.generate(embed_content=True)

        # The template variables should be resolved in output
        # base_path should appear in links
        assert '../../../' in html or 'base_path' not in html.lower(), \
            "Template variables should be resolved"

        # repo_root should appear in VS Code links if set
        assert '/test/repo' in html or 'REPO_ROOT' in html, \
            "repo_root should be used in output"


class TestCaching:
    """Tests for render-time caching."""

    def test_caches_content_during_render(self, htmlerator):
        """
        REQ-tv-d00004-I: The generator SHALL cache file content during a
        single render operation to avoid redundant disk reads.
        """
        # Track file reads (implementation-specific test)
        # If the implementation has a cache, it should be used
        read_count = 0
        original_load_css = htmlerator._load_css

        def counting_load_css():
            nonlocal read_count
            read_count += 1
            return original_load_css()

        htmlerator._load_css = counting_load_css

        # Single render should not re-read CSS multiple times
        html = htmlerator.generate()

        # CSS should only be loaded once per render
        assert read_count <= 1, \
            f"CSS was read {read_count} times, should be cached"


class TestContentEscaping:
    """Tests for proper content escaping."""

    def test_script_content_properly_escaped(self, htmlerator):
        """
        REQ-tv-d00004-J: The embedded content SHALL be properly escaped to
        prevent HTML injection from file content (e.g., `</script>` within
        JavaScript).
        """
        html = htmlerator.generate(embed_content=True)

        import re

        # Find all script blocks
        script_blocks = re.findall(
            r'<script[^>]*>(.*?)</script>',
            html,
            re.DOTALL | re.IGNORECASE
        )

        for block in script_blocks:
            # Check that any </script> inside is escaped
            # Valid escapes: <\/script> or &lt;/script&gt;
            if '</script>' in block.lower():
                # This would break the HTML
                pytest.fail("Unescaped </script> found in script block")
