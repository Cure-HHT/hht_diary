# REQ-tv-d00001: Jinja2 Template Architecture

**Level**: Dev | **Status**: Draft | **Implements**: REQ-tv-p00001

## Assertions

A. The HTMLGenerator class SHALL use a Jinja2 Environment for template rendering.

B. Templates SHALL be loaded from a `templates/` subdirectory relative to the `html/` module.

C. The template loader SHALL use FileSystemLoader with the templates directory path.

D. The generator SHALL pass a context dictionary to template rendering containing: requirements data, coverage data, and configuration flags.

E. The base template SHALL define the complete HTML document structure including DOCTYPE, html, head, and body elements.

F. Template rendering SHALL support the `embed_content` flag to control data embedding mode.

G. Template rendering SHALL support the `edit_mode` flag to control edit UI visibility.

H. The generator class SHALL expose a `generate()` method with the same signature as the current implementation: `generate(embed_content: bool = False, edit_mode: bool = False) -> str`.

I. Template errors SHALL be reported with meaningful error messages including template name and line number.

## Rationale

Jinja2 is the industry-standard Python templating engine, used by Flask, Ansible, and many other projects. It provides:
- Clear separation of logic and presentation
- Template inheritance and includes for code reuse
- Excellent IDE support (syntax highlighting, autocomplete)
- Compiled templates for performance
- Well-documented and actively maintained

The FileSystemLoader approach allows templates to be edited as standalone files with proper syntax highlighting, while the `generate()` method signature ensures backward compatibility.

*End* *Jinja2 Template Architecture* | **Hash**: 0141b0f8
