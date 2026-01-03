#!/usr/bin/env python3
"""
trace-view: Requirements Traceability Matrix Viewer

Generates interactive traceability matrices showing relationships between
requirements at different levels (PRD -> Ops -> Dev).

Usage:
    python trace_view.py                    # Generate markdown matrix
    python trace_view.py --format html      # Generate HTML matrix
    python trace_view.py --format both      # Generate both formats
    python trace_view.py --help             # Show all options

For more information, see: tools/requirements/README.md
"""

from trace_view import TraceViewGenerator, Requirement
from trace_view.cli import main

if __name__ == '__main__':
    main()
