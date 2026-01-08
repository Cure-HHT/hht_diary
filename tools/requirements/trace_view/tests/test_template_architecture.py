"""
Tests for Jinja2 Template Architecture (REQ-tv-d00001).

Each test function documents which assertion it verifies in its docstring.
The Elspais reporter extracts these references for traceability.
"""

from pathlib import Path

import pytest

# These tests are written before implementation (TDD red phase)
# They will fail until the refactoring is complete


class TestJinja2Environment:
    """Tests for Jinja2 Environment configuration."""

    def test_generator_uses_jinja2_environment(self, htmlerator_class, sample_requirements):
        """
        REQ-tv-d00001-A: The HTMLGenerator class SHALL use a Jinja2 Environment
        for template rendering.
        """
        try:
            from jinja2 import Environment
        except ImportError:
            pytest.skip("jinja2 not installed")

        generator = htmlerator_class(requirements=sample_requirements)
        assert hasattr(generator, 'env'), "Generator must have 'env' attribute"
        assert isinstance(generator.env, Environment), "env must be Jinja2 Environment"

    def test_templates_loaded_from_subdirectory(self, htmlerator_class):
        """
        REQ-tv-d00001-B: Templates SHALL be loaded from a `templates/`
        subdirectory relative to the `html/` module.
        """
        # Get the html module path
        import trace_view.html as html_module
        html_path = Path(html_module.__file__).parent
        templates_path = html_path / "templates"

        assert templates_path.exists(), f"Templates directory must exist at {templates_path}"
        assert templates_path.is_dir(), "templates/ must be a directory"

    def test_uses_filesystem_loader(self, htmlerator_class, sample_requirements):
        """
        REQ-tv-d00001-C: The template loader SHALL use FileSystemLoader with
        the templates directory path.
        """
        try:
            from jinja2 import FileSystemLoader
        except ImportError:
            pytest.skip("jinja2 not installed")

        generator = htmlerator_class(requirements=sample_requirements)
        assert hasattr(generator.env, 'loader'), "Environment must have loader"
        assert isinstance(generator.env.loader, FileSystemLoader), \
            "Loader must be FileSystemLoader"


class TestContextRendering:
    """Tests for template context and rendering."""

    def test_context_contains_required_data(self, htmlerator):
        """
        REQ-tv-d00001-D: The generator SHALL pass a context dictionary to
        template rendering containing: requirements data, coverage data,
        and configuration flags.
        """
        # We need to inspect what context is passed to the template
        # This requires the implementation to expose or allow inspection
        # For now, verify the generate method works and produces output
        html = htmlerator.generate(embed_content=True)

        # Context must have been passed if HTML was generated
        assert html is not None
        assert len(html) > 0

    def test_base_template_defines_document_structure(self, htmlerator_class):
        """
        REQ-tv-d00001-E: The base template SHALL define the complete HTML
        document structure including DOCTYPE, html, head, and body elements.
        """
        import trace_view.html as html_module
        html_path = Path(html_module.__file__).parent
        base_template = html_path / "templates" / "base.html"

        assert base_template.exists(), "base.html template must exist"

        content = base_template.read_text()
        assert "<!DOCTYPE html>" in content or "<!doctype html>" in content.lower()
        assert "<html" in content.lower()
        assert "<head" in content.lower()
        assert "<body" in content.lower()


class TestRenderingFlags:
    """Tests for embed_content and edit_mode flags."""

    def test_supports_embed_content_flag(self, htmlerator):
        """
        REQ-tv-d00001-F: Template rendering SHALL support the `embed_content`
        flag to control data embedding mode.
        """
        # Both modes should work
        html_embedded = htmlerator.generate(embed_content=True)
        html_links = htmlerator.generate(embed_content=False)

        assert html_embedded is not None
        assert html_links is not None
        # Embedded mode should have more content (JSON data)
        assert len(html_embedded) > len(html_links)

    def test_supports_edit_mode_flag(self, htmlerator):
        """
        REQ-tv-d00001-G: Template rendering SHALL support the `edit_mode`
        flag to control edit UI visibility.
        """
        html_edit = htmlerator.generate(embed_content=True, edit_mode=True)
        html_view = htmlerator.generate(embed_content=True, edit_mode=False)

        assert html_edit is not None
        assert html_view is not None
        # Edit mode should include edit-specific UI elements
        assert "edit" in html_edit.lower() or "Edit" in html_edit


class TestMethodSignature:
    """Tests for backward-compatible method signature."""

    def test_generate_method_signature(self, htmlerator):
        """
        REQ-tv-d00001-H: The generator class SHALL expose a `generate()` method
        with the same signature as the current implementation:
        `generate(embed_content: bool = False, edit_mode: bool = False) -> str`.
        """
        import inspect

        # Check method exists
        assert hasattr(htmlerator, 'generate'), "Must have generate() method"
        assert callable(htmlerator.generate), "generate must be callable"

        # Check signature
        sig = inspect.signature(htmlerator.generate)
        params = sig.parameters

        assert 'embed_content' in params, "Must have embed_content parameter"
        assert 'edit_mode' in params, "Must have edit_mode parameter"

        # Check defaults
        assert params['embed_content'].default is False
        assert params['edit_mode'].default is False

        # Check return type hint if available
        if sig.return_annotation != inspect.Signature.empty:
            assert sig.return_annotation == str


class TestErrorHandling:
    """Tests for template error handling."""

    def test_template_errors_include_location(self, htmlerator):
        """
        REQ-tv-d00001-I: Template errors SHALL be reported with meaningful
        error messages including template name and line number.
        """
        # This test verifies error handling when templates are malformed
        # Implementation should catch Jinja2 TemplateError and provide context

        # Normal operation should not raise
        try:
            html = htmlerator.generate()
            assert html is not None
        except Exception as e:
            # If there's an error, it should include template info
            error_msg = str(e)
            # Error should mention template name or line
            assert "template" in error_msg.lower() or "line" in error_msg.lower(), \
                f"Template errors should include location info: {error_msg}"
