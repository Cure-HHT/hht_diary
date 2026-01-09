# REQ-tv-p00001: HTML Generator Maintainability

**Level**: PRD | **Status**: Draft | **Implements**: -

## Assertions

A. The HTML generator SHALL produce a single, self-contained HTML file that can be opened in any modern browser without requiring a web server.

B. The HTML generator SHALL support two operational modes: standalone mode with embedded requirement data, and link-only mode with relative URLs to source files.

C. The HTML generator SHALL produce output that is functionally equivalent to the current implementation for all existing use cases.

D. The HTML generator codebase SHALL separate concerns such that HTML structure, CSS styling, and JavaScript behavior can be modified independently.

E. The HTML generator SHALL support IDE syntax highlighting and autocomplete for HTML, CSS, and JavaScript content.

F. The HTML generator SHALL maintain backward compatibility with existing command-line interfaces and configuration options.

G. The HTML generator SHALL support optional edit mode UI for batch requirement operations.

## Rationale

The current HTMLGenerator class in `trace_view/html/generator.py` is a 3,420-line monolith that mixes HTML, CSS, JavaScript, and Python logic. This makes the code difficult to maintain, test, and extend.

The current implementation has several challenges that motivate this refactoring:
- No IDE support for embedded HTML/CSS/JS (all are Python strings)
- Single 1,268-line method (`_generate_html`) with cyclomatic complexity of 598
- Tight coupling prevents independent modification of presentation layers
- Difficult to test components in isolation

The refactoring preserves all current functionality while enabling better developer experience and maintainability.

*End* *HTML Generator Maintainability* | **Hash**: 5dc964a5
