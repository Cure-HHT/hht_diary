# REQ-tv-d00004: Build-time Asset Embedding

**Level**: Dev | **Status**: Draft | **Implements**: REQ-tv-p00001

## Assertions

A. The generator SHALL embed CSS content inline within `<style>` tags in the generated HTML.

B. The generator SHALL embed JavaScript content inline within `<script>` tags in the generated HTML.

C. Asset files SHALL be read from disk at template render time, not at module import time.

D. The generator SHALL provide a helper method `_load_css()` that reads and returns the CSS file content.

E. The generator SHALL provide a helper method `_load_js()` that reads and returns the JavaScript file content.

F. File reading errors SHALL raise informative exceptions including the expected file path.

G. The generated HTML document SHALL be completely self-contained with no external file dependencies (except for CDN libraries in embedded mode).

H. The embedding approach SHALL support Jinja2 template variables within embedded CSS and JavaScript content for dynamic values such as `base_path` and `repo_root`.

I. The generator SHALL cache file content during a single render operation to avoid redundant disk reads.

J. The embedded content SHALL be properly escaped to prevent HTML injection from file content (e.g., `</script>` within JavaScript).

## Rationale

The goal is to develop with separate files for IDE support while producing a single self-contained HTML file for portability. This "develop separate, embed at build time" approach provides:
- IDE support during development
- Single-file distribution for end users
- No web server required to view reports
- Works offline after generation

The caching and lazy loading approach ensures:
- Files are read only when needed
- Multiple templates can share the same CSS/JS without re-reading
- Fresh content on each render (no stale module-level cache)

*End* *Build-time Asset Embedding* | **Hash**: 177c0fd7
