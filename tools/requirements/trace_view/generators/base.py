"""
Base generator for trace-view.

Provides the main TraceViewGenerator class that orchestrates
requirement parsing, implementation scanning, and output generation.

NOTE: This currently wraps TraceabilityGenerator for backward compatibility.
Once HTML extraction is complete, this will become the primary implementation.
"""

from pathlib import Path
from typing import Dict, List, Optional

from ..models import Requirement
from ..git_state import (
    get_requirements_via_cli,
    get_git_modified_files,
    get_git_changed_vs_main,
    get_committed_req_locations,
    set_git_modified_files,
)
from ..scanning import scan_implementation_files
from ..coverage import calculate_coverage, generate_coverage_report, get_implementation_status
from .csv import generate_csv, generate_planning_csv
from .markdown import generate_markdown


class TraceViewGenerator:
    """Generates traceability matrices.

    This is the main entry point for generating traceability reports.
    Supports multiple output formats: markdown, html, csv.

    Args:
        spec_dir: Path to the spec directory containing requirement files
        impl_dirs: List of directories to scan for implementation references
        sponsor: Sponsor name for sponsor-specific reports
        mode: Report mode ('core', 'sponsor', 'combined')
        repo_root: Repository root path for relative path calculation
    """

    # Version number - increment with each change
    VERSION = 16

    # Map parsed levels to uppercase for consistency
    LEVEL_MAP = {
        'PRD': 'PRD',
        'Ops': 'OPS',
        'Dev': 'DEV'
    }

    def __init__(
        self,
        spec_dir: Path,
        impl_dirs: Optional[List[Path]] = None,
        sponsor: Optional[str] = None,
        mode: str = 'core',
        repo_root: Optional[Path] = None
    ):
        self.spec_dir = spec_dir
        self.requirements: Dict[str, Requirement] = {}
        self.impl_dirs = impl_dirs or []
        self.sponsor = sponsor
        self.mode = mode
        self.repo_root = repo_root or spec_dir.parent
        self._base_path = ''

    def generate(
        self,
        format: str = 'markdown',
        output_file: Optional[Path] = None,
        embed_content: bool = False,
        edit_mode: bool = False,
        review_mode: bool = False
    ):
        """Generate traceability matrix in specified format.

        Args:
            format: Output format ('markdown', 'html', 'csv')
            output_file: Path to write output (default: traceability_matrix.{ext})
            embed_content: If True, embed full requirement content in HTML
            edit_mode: If True, include edit mode UI in HTML output
            review_mode: If True, include review mode UI in HTML output
        """
        # Initialize git state
        self._init_git_state()

        # Parse requirements
        print(f"🔍 Scanning {self.spec_dir} for requirements...")
        self._parse_requirements()

        if not self.requirements:
            print("⚠️  No requirements found")
            return

        print(f"📋 Found {len(self.requirements)} requirements")

        # Pre-detect cycles and mark affected requirements
        self._detect_and_mark_cycles()

        # Scan implementation files
        if self.impl_dirs:
            print(f"🔎 Scanning implementation files...")
            scan_implementation_files(
                self.requirements,
                self.impl_dirs,
                self.repo_root,
                self.mode,
                self.sponsor
            )

        print(f"📝 Generating {format.upper()} traceability matrix...")

        # Determine output path and extension
        if format == 'html':
            ext = '.html'
        elif format == 'csv':
            ext = '.csv'
        else:
            ext = '.md'

        if output_file is None:
            output_file = Path(f'traceability_matrix{ext}')

        # Calculate relative path for links
        self._calculate_base_path(output_file)

        # Generate content
        if format == 'html':
            from ..html import HTMLGenerator
            html_gen = HTMLGenerator(
                requirements=self.requirements,
                base_path=self._base_path,
                mode=self.mode,
                sponsor=self.sponsor,
                version=self.VERSION,
                repo_root=self.repo_root
            )
            content = html_gen.generate(embed_content=embed_content, edit_mode=edit_mode, review_mode=review_mode)
        elif format == 'csv':
            content = generate_csv(self.requirements)
        else:
            content = generate_markdown(
                self.requirements,
                self._base_path
            )

        output_file.write_text(content)
        print(f"✅ Traceability matrix written to: {output_file}")

    def _init_git_state(self):
        """Initialize git state for requirement status detection."""
        modified_files, untracked_files = get_git_modified_files(self.repo_root)
        uncommitted = modified_files | untracked_files
        branch_changed = get_git_changed_vs_main(self.repo_root)
        branch_changed = branch_changed | uncommitted
        committed_req_locations = get_committed_req_locations(self.repo_root)
        set_git_modified_files(uncommitted, untracked_files, branch_changed, committed_req_locations)

        # Report uncommitted changes
        if uncommitted:
            spec_uncommitted = [f for f in uncommitted if f.startswith('spec/')]
            if spec_uncommitted:
                print(f"📝 Uncommitted spec files: {len(spec_uncommitted)}")

        # Report branch changes vs main
        if branch_changed:
            spec_branch = [f for f in branch_changed if f.startswith('spec/')]
            if spec_branch:
                print(f"🔀 Spec files changed vs main: {len(spec_branch)}")

    def _parse_requirements(self):
        """Parse all requirements using elspais CLI."""
        reqs_json = get_requirements_via_cli()

        if not reqs_json:
            print("   ⚠️  No requirements found (elspais returned empty)")
            return

        roadmap_count = 0
        conflict_count = 0
        cycle_count = 0

        for req_id, data in reqs_json.items():
            req = Requirement.from_elspais_json(req_id, data)

            if req.is_roadmap:
                roadmap_count += 1
            if req.is_conflict:
                conflict_count += 1
                print(f"   ⚠️  Conflict: {req_id} conflicts with {req.conflict_with}")
            if req.is_cycle:
                cycle_count += 1

            self.requirements[req.id] = req

        if roadmap_count > 0:
            print(f"   🗺️  Found {roadmap_count} roadmap requirements")
        if conflict_count > 0:
            print(f"   ⚠️  Found {conflict_count} conflicts")
        if cycle_count > 0:
            print(f"   🔄 Found {cycle_count} requirements in dependency cycles")

    def _detect_and_mark_cycles(self):
        """Clear implements for cycle members so they appear as orphaned."""
        cycle_count = 0
        for req_id, req in self.requirements.items():
            if req.is_cycle and req.implements:
                req.implements = []
                cycle_count += 1

        if cycle_count > 0:
            print(f"   ⚠️  {cycle_count} requirements marked as cyclic (shown as orphaned items)")

    def _calculate_base_path(self, output_file: Path):
        """Calculate relative path from output file location to repo root."""
        try:
            output_dir = output_file.resolve().parent
            repo_root = self.repo_root.resolve()

            try:
                rel_path = output_dir.relative_to(repo_root)
                depth = len(rel_path.parts)
                if depth == 0:
                    self._base_path = ''
                else:
                    self._base_path = '../' * depth
            except ValueError:
                self._base_path = f'file://{repo_root}/'
        except Exception:
            self._base_path = '../'

    def _generate_planning_csv(self) -> str:
        """Generate planning CSV with actionable requirements."""
        # Create callback functions that close over self.requirements
        get_status = lambda req_id: get_implementation_status(self.requirements, req_id)
        calc_coverage = lambda req_id: calculate_coverage(self.requirements, req_id)
        return generate_planning_csv(self.requirements, get_status, calc_coverage)

    def _scan_implementation_files(self):
        """Scan implementation files for requirement references.

        This method wraps the scanning function for use by CLI and other callers.
        """
        if self.impl_dirs:
            scan_implementation_files(
                self.requirements,
                self.impl_dirs,
                self.repo_root,
                self.mode,
                self.sponsor
            )

    def _generate_coverage_report(self) -> str:
        """Generate coverage report showing implementation status."""
        return generate_coverage_report(self.requirements)
