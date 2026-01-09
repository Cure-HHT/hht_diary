"""
trace-view: Requirements Traceability Matrix Viewer

A modular package for generating interactive traceability matrices
showing relationships between requirements at different levels.
"""

__version__ = "1.0.0"

# Git state management
from .git_state import (
    GitState,
    get_requirements_via_cli,
    get_elspais_config,
    get_git_modified_files,
    get_git_changed_vs_main,
    get_committed_req_locations,
    set_git_modified_files,
)

# Data models
from .models import Requirement, TestInfo, TraceabilityRequirement

# Coverage calculation
from .coverage import (
    count_by_level,
    find_orphaned_requirements,
    calculate_coverage,
    get_implementation_status,
    generate_coverage_report,
)

# Implementation scanning
from .scanning import scan_implementation_files

# Generator
from .generators import TraceViewGenerator
