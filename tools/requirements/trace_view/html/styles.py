"""
CSS styles for trace-view HTML generation.

This module consolidates all CSS generation for the HTML traceability viewer.
The CSS is organized into sections:
- Code viewer styles
- Legend modal styles
- File picker modal styles
- Side panel styles

TODO: This module currently contains placeholder strings. The full CSS
extraction from generate_traceability.py is pending (Phase 7 of refactoring).
"""

# CSS constants will be populated in full extraction
# For now, the TraceabilityGenerator methods are used directly

CODE_VIEWER_CSS = """
/* Code Viewer Modal - see generate_traceability._generate_code_viewer_css() */
"""

LEGEND_MODAL_CSS = """
/* Legend Modal - see generate_traceability._generate_legend_modal_css() */
"""

FILE_PICKER_MODAL_CSS = """
/* File Picker Modal - see generate_traceability._generate_file_picker_modal_css() */
"""

SIDE_PANEL_CSS = """
/* Side Panel - see generate_traceability._generate_side_panel_css() */
"""


def get_all_css() -> str:
    """Get all CSS styles combined.

    TODO: Implement full CSS extraction.
    """
    return CODE_VIEWER_CSS + LEGEND_MODAL_CSS + FILE_PICKER_MODAL_CSS + SIDE_PANEL_CSS
