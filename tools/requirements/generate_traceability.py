#!/usr/bin/env python3
"""
Requirements Traceability Matrix Generator

Generates traceability matrix showing relationships between requirements
at different levels (PRD -> Ops -> Dev).

Scans both specification files and implementation files:
- spec/*.md: Requirement definitions
- database/*.sql: Database implementation
- apps/**/*.dart: Flutter apps (future)
- sponsor/{name}/**/*: Sponsor-specific implementations

Multi-Sponsor Support (Phase 3):
- Core mode: Scan only core directories (exclude /sponsor/)
- Sponsor mode: Scan specific sponsor + core directories
- Combined mode: Scan all directories (core + all sponsors)
- Supports sponsor-specific REQ IDs: REQ-{SPONSOR}-{p|o|d}NNNNN (e.g., REQ-CAL-d00001)

Output formats:
- HTML: Interactive web page with collapsible hierarchy (enhanced!)
- Markdown: Documentation-friendly format
- CSV: Spreadsheet import

Features:
- Collapsible requirement hierarchy in HTML view
- Expand/collapse all controls
- Color-coded by requirement level (PRD/Ops/Dev)
- Status badges (Active/Draft/Deprecated)
- Implementation file tracking (which files implement which requirements)
- Markdown source ensures HTML consistency
- Sponsor-aware directory scanning and filtering
"""

import re
import sys
import csv
import json
from pathlib import Path
from typing import Dict, List, Set, Optional, Tuple
from dataclasses import dataclass, field
from datetime import datetime

@dataclass
class TestInfo:
    """Represents test coverage for a requirement"""
    test_count: int = 0
    manual_test_count: int = 0
    test_status: str = "not_tested"  # not_tested, passed, failed, error, skipped
    test_details: List[Dict] = field(default_factory=list)
    notes: str = ""

@dataclass
class Requirement:
    """Represents a parsed requirement"""
    id: str
    title: str
    level: str
    implements: List[str]
    status: str
    file_path: Path
    line_number: int
    test_info: Optional[TestInfo] = None
    implementation_files: List[Tuple[str, int]] = field(default_factory=list)  # (file_path, line_number) tuples for files that implement this requirement


class TraceabilityGenerator:
    """Generates traceability matrices"""

    # Updated to support sponsor-specific REQ IDs: REQ-{SPONSOR}-{p|o|d}NNNNN (e.g., REQ-CAL-d00001)
    # Also supports core REQ IDs: REQ-{p|o|d}NNNNN (e.g., REQ-d00027)
    REQ_HEADER_PATTERN = re.compile(r'^#+\s+REQ-(?:([A-Z]+)-)?([pod]\d{5}):\s+(.+)$', re.MULTILINE)
    METADATA_PATTERN = re.compile(
        r'\*\*Level\*\*:\s+(PRD|Ops|Dev)\s+\|\s+\*\*Implements\*\*:\s+([^\|]+)\s+\|\s+\*\*Status\*\*:\s+(Active|Draft|Deprecated)',
        re.MULTILINE
    )

    # Map parsed levels to uppercase for consistency
    LEVEL_MAP = {
        'PRD': 'PRD',
        'Ops': 'OPS',
        'Dev': 'DEV'
    }

    def __init__(self, spec_dir: Path, test_mapping_file: Optional[Path] = None, impl_dirs: Optional[List[Path]] = None,
                 sponsor: Optional[str] = None, mode: str = 'core'):
        self.spec_dir = spec_dir
        self.requirements: Dict[str, Requirement] = {}
        self.test_mapping_file = test_mapping_file
        self.test_data: Dict[str, TestInfo] = {}
        self.impl_dirs = impl_dirs or []  # Directories containing implementation files
        self.sponsor = sponsor  # Sponsor name (e.g., 'callisto', 'titan')
        self.mode = mode  # Report mode: 'core', 'sponsor', 'combined'

    def generate(self, format: str = 'markdown', output_file: Path = None):
        """Generate traceability matrix in specified format"""
        print(f"🔍 Scanning {self.spec_dir} for requirements...")
        self._parse_requirements()

        if not self.requirements:
            print("⚠️  No requirements found")
            return

        print(f"📋 Found {len(self.requirements)} requirements")

        # Scan implementation files for requirement references
        if self.impl_dirs:
            print(f"🔎 Scanning implementation files...")
            self._scan_implementation_files()

        # Load test data if mapping file provided
        if self.test_mapping_file and self.test_mapping_file.exists():
            print(f"📊 Loading test results from {self.test_mapping_file}...")
            self._load_test_data()
        else:
            print("⚠️  No test mapping file provided - all requirements marked as 'not tested'")
        print(f"📝 Generating {format.upper()} traceability matrix...")

        if format == 'html':
            content = self._generate_html()
            ext = '.html'
        elif format == 'csv':
            content = self._generate_csv()
            ext = '.csv'
        else:
            content = self._generate_markdown()
            ext = '.md'

        # Determine output path
        if output_file is None:
            output_file = Path(f'traceability_matrix{ext}')

        output_file.write_text(content)
        print(f"✅ Traceability matrix written to: {output_file}")

    def _parse_requirements(self):
        """Parse all requirements from spec files"""
        for spec_file in self.spec_dir.glob('*.md'):
            if spec_file.name == 'requirements-format.md':
                continue

            self._parse_file(spec_file)

    def _parse_file(self, file_path: Path):
        """Parse requirements from a single file"""
        try:
            content = file_path.read_text(encoding='utf-8')
        except UnicodeDecodeError:
            # Try with error handling for non-UTF8 files
            content = file_path.read_text(encoding='utf-8', errors='ignore')

        for match in self.REQ_HEADER_PATTERN.finditer(content):
            sponsor_prefix = match.group(1)  # May be None for core requirements
            req_id_core = match.group(2)  # The core part (e.g., 'd00027')
            title = match.group(3).strip()
            line_num = content[:match.start()].count('\n') + 1

            # Build full requirement ID (with sponsor prefix if present)
            if sponsor_prefix:
                req_id = f"{sponsor_prefix}-{req_id_core}"
            else:
                req_id = req_id_core

            remaining_content = content[match.end():]
            metadata_match = self.METADATA_PATTERN.search(remaining_content[:500])

            if not metadata_match:
                continue

            level_raw = metadata_match.group(1)
            level = self.LEVEL_MAP.get(level_raw, level_raw)  # Normalize to uppercase
            implements_str = metadata_match.group(2).strip()
            status = metadata_match.group(3)

            implements = []
            if implements_str != '-':
                implements = [
                    impl.strip()
                    for impl in implements_str.split(',')
                    if impl.strip()
                ]

            req = Requirement(
                id=req_id,
                title=title,
                level=level,
                implements=implements,
                status=status,
                file_path=file_path,
                line_number=line_num
            )

            self.requirements[req_id] = req

    def _scan_implementation_files(self):
        """Scan implementation files for requirement references"""
        # Pattern to match requirement references in code comments
        # Matches: REQ-p00001, REQ-o00042, REQ-d00156, REQ-CAL-d00001
        req_ref_pattern = re.compile(r'REQ-(?:([A-Z]+)-)?([pod]\d{5})')

        total_files_scanned = 0
        total_refs_found = 0

        for impl_dir in self.impl_dirs:
            if not impl_dir.exists():
                print(f"   ⚠️  Implementation directory not found: {impl_dir}")
                continue

            # Apply mode-based filtering
            if self._should_skip_directory(impl_dir):
                print(f"   ⏭️  Skipping directory (mode={self.mode}): {impl_dir}")
                continue

            # Determine file patterns based on directory
            if impl_dir.name == 'database':
                patterns = ['*.sql']
            elif impl_dir.name in ['diary_app', 'portal_app']:
                patterns = ['**/*.dart']
            else:
                # Default: scan common code file types
                patterns = ['**/*.dart', '**/*.sql', '**/*.py', '**/*.js', '**/*.ts']

            for pattern in patterns:
                for file_path in impl_dir.glob(pattern):
                    if file_path.is_file():
                        # Skip files in sponsor directories if not in the right mode
                        if self._should_skip_file(file_path):
                            continue

                        total_files_scanned += 1
                        refs = self._scan_file_for_requirements(file_path, req_ref_pattern)
                        total_refs_found += len(refs)

        print(f"   ✅ Scanned {total_files_scanned} implementation files")
        print(f"   📌 Found {total_refs_found} requirement references")

    def _scan_file_for_requirements(self, file_path: Path, pattern: re.Pattern) -> Set[str]:
        """Scan a single implementation file for requirement references"""
        try:
            content = file_path.read_text(encoding='utf-8')
        except (UnicodeDecodeError, PermissionError):
            # Skip files that can't be read
            return set()

        # Find all requirement IDs referenced in this file with their line numbers
        referenced_reqs = set()
        rel_path = file_path.relative_to(file_path.parent.parent)  # Relative to repo root

        for match in pattern.finditer(content):
            sponsor_prefix = match.group(1)  # May be None for core requirements
            req_id_core = match.group(2)  # The core part (e.g., 'd00027')

            # Build full requirement ID (with sponsor prefix if present)
            if sponsor_prefix:
                req_id = f"{sponsor_prefix}-{req_id_core}"
            else:
                req_id = req_id_core

            referenced_reqs.add(req_id)

            # Calculate line number from match position
            line_num = content[:match.start()].count('\n') + 1

            # Add (file_path, line_number) tuple to requirement's implementation_files
            if req_id in self.requirements:
                impl_entry = (str(rel_path), line_num)
                # Avoid duplicates (same file, same line)
                if impl_entry not in self.requirements[req_id].implementation_files:
                    self.requirements[req_id].implementation_files.append(impl_entry)

        return referenced_reqs

    def _should_skip_directory(self, dir_path: Path) -> bool:
        """Check if a directory should be skipped based on mode"""
        # Check if directory is under /sponsor/
        try:
            # Try to get relative path from repo root
            parts = dir_path.parts
            if 'sponsor' in parts:
                sponsor_idx = parts.index('sponsor')
                if sponsor_idx + 1 < len(parts):
                    dir_sponsor = parts[sponsor_idx + 1]

                    # In core mode, skip all sponsor directories
                    if self.mode == 'core':
                        return True

                    # In sponsor mode, skip sponsor directories that don't match our sponsor
                    if self.mode == 'sponsor' and self.sponsor and dir_sponsor != self.sponsor:
                        return True

            return False
        except (ValueError, IndexError):
            return False

    def _should_skip_file(self, file_path: Path) -> bool:
        """Check if a file should be skipped based on mode"""
        # Check if file is under /sponsor/
        try:
            parts = file_path.parts
            if 'sponsor' in parts:
                sponsor_idx = parts.index('sponsor')
                if sponsor_idx + 1 < len(parts):
                    file_sponsor = parts[sponsor_idx + 1]

                    # In core mode, skip all sponsor files
                    if self.mode == 'core':
                        return True

                    # In sponsor mode, skip sponsor files that don't match our sponsor
                    if self.mode == 'sponsor' and self.sponsor and file_sponsor != self.sponsor:
                        return True

            return False
        except (ValueError, IndexError):
            return False

    def _generate_markdown(self) -> str:
        """Generate markdown traceability matrix"""
        lines = []
        lines.append("# Requirements Traceability Matrix")
        lines.append(f"\n**Generated**: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        lines.append(f"**Total Requirements**: {len(self.requirements)}\n")

        # Summary by level
        by_level = self._count_by_level()
        lines.append("## Summary\n")
        lines.append(f"- **PRD Requirements**: {by_level['PRD']}")
        lines.append(f"- **OPS Requirements**: {by_level['OPS']}")
        lines.append(f"- **DEV Requirements**: {by_level['DEV']}\n")

        # Full traceability tree
        lines.append("## Traceability Tree\n")

        # Start with top-level PRD requirements
        prd_reqs = [req for req in self.requirements.values() if req.level == 'PRD']
        prd_reqs.sort(key=lambda r: r.id)

        for prd_req in prd_reqs:
            lines.append(self._format_req_tree_md(prd_req, indent=0))

        # Orphaned ops/dev requirements
        orphaned = self._find_orphaned_requirements()
        if orphaned:
            lines.append("\n## Orphaned Requirements\n")
            lines.append("*(Requirements not linked from any parent)*\n")
            for req in orphaned:
                lines.append(f"- **REQ-{req.id}**: {req.title} ({req.level}) - {req.file_path.name}")

        return '\n'.join(lines)

    def _format_req_tree_md(self, req: Requirement, indent: int) -> str:
        """Format requirement and its children as markdown tree"""
        lines = []
        prefix = "  " * indent

        # Format current requirement
        status_emoji = {
            'Active': '✅',
            'Draft': '🚧',
            'Deprecated': '⚠️'
        }
        emoji = status_emoji.get(req.status, '❓')

        lines.append(
            f"{prefix}- {emoji} **REQ-{req.id}**: {req.title}\n"
            f"{prefix}  - Level: {req.level} | Status: {req.status}\n"
            f"{prefix}  - File: {req.file_path.name}:{req.line_number}"
        )

        # Format implementation files as nested list with clickable links
        if req.implementation_files:
            lines.append(f"{prefix}  - **Implemented in**:")
            for file_path, line_num in req.implementation_files:
                # Create markdown link to file with line number anchor
                # Format: [database/schema.sql:42](../database/schema.sql#L42)
                link = f"[{file_path}:{line_num}](../{file_path}#L{line_num})"
                lines.append(f"{prefix}    - {link}")

        # Find and format children
        children = [
            r for r in self.requirements.values()
            if req.id in r.implements
        ]
        children.sort(key=lambda r: r.id)

        if children:
            for child in children:
                lines.append(self._format_req_tree_md(child, indent + 1))

        return '\n'.join(lines)

    def _generate_html(self) -> str:
        """Generate interactive HTML traceability matrix from markdown source"""
        # First generate markdown to ensure consistency
        markdown_content = self._generate_markdown()

        # Parse markdown for HTML rendering
        by_level = self._count_by_level()

        # Collect all unique topics from requirements
        all_topics = set()
        for req in self.requirements.values():
            topic = req.file_path.stem.split('-', 1)[1] if '-' in req.file_path.stem else req.file_path.stem
            all_topics.add(topic)
        sorted_topics = sorted(all_topics)

        html = f"""<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Requirements Traceability Matrix</title>
    <style>
        body {{
            font-family: 'Segoe UI', 'Roboto', 'Helvetica Neue', Arial, sans-serif;
            font-size: 13px;
            line-height: 1.4;
            margin: 15px;
            background: #f8f9fa;
        }}
        .container {{
            max-width: 1400px;
            margin: 0 auto;
            background: white;
            padding: 20px;
            border-radius: 6px;
            box-shadow: 0 1px 3px rgba(0,0,0,0.08);
        }}
        h1 {{
            font-size: 20px;
            font-weight: 600;
            color: #2c3e50;
            border-bottom: 2px solid #0066cc;
            padding-bottom: 8px;
            margin: 0 0 15px 0;
        }}
        h2 {{
            font-size: 16px;
            font-weight: 600;
            color: #34495e;
            margin: 20px 0 10px 0;
        }}
        .summary {{
            background: #f8f9fa;
            padding: 10px 15px;
            border-radius: 4px;
            margin: 15px 0;
            font-size: 12px;
        }}
        .summary p {{
            margin: 4px 0;
        }}
        .summary-grid {{
            display: grid;
            grid-template-columns: repeat(3, 1fr);
            gap: 10px;
            margin: 15px 0;
        }}
        .summary-card {{
            background: white;
            padding: 10px;
            border-radius: 4px;
            text-align: center;
            border-left: 3px solid #0066cc;
        }}
        .summary-card h3 {{
            margin: 0 0 6px 0;
            color: #7f8c8d;
            font-size: 11px;
            font-weight: 500;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }}
        .summary-card .number {{
            font-size: 24px;
            font-weight: 600;
            color: #0066cc;
        }}
        .controls {{
            margin: 15px 0;
            padding: 10px;
            background: #e9ecef;
            border-radius: 4px;
            display: flex;
            gap: 8px;
            align-items: center;
        }}
        .btn {{
            padding: 6px 12px;
            border: none;
            border-radius: 3px;
            background: #0066cc;
            color: white;
            cursor: pointer;
            font-size: 12px;
            font-weight: 500;
            transition: background 0.15s;
        }}
        .btn:hover {{
            background: #0052a3;
        }}
        .btn-secondary {{
            background: #6c757d;
        }}
        .btn-secondary:hover {{
            background: #5a6268;
        }}
        .req-tree {{
            margin: 15px 0;
        }}
        .req-item {{
            margin: 2px 0;
            background: #ffffff;
            border-left: 3px solid #28a745;
            overflow: hidden;
        }}
        .req-item.prd {{ border-left-color: #0066cc; }}
        .req-item.ops {{ border-left-color: #fd7e14; }}
        .req-item.dev {{ border-left-color: #28a745; }}
        .req-item.deprecated {{ opacity: 0.6; }}
        .req-header-container {{
            padding: 6px 10px;
            cursor: pointer;
            user-select: none;
            display: flex;
            align-items: center;
            gap: 8px;
        }}
        .req-header-container:hover {{
            background: #f8f9fa;
        }}
        /* Indentation based on hierarchy level (20px per level) */
        .req-item[data-indent="0"] .req-header-container {{
            padding-left: 10px;
        }}
        .req-item[data-indent="1"] .req-header-container {{
            padding-left: 30px;
        }}
        .req-item[data-indent="2"] .req-header-container {{
            padding-left: 50px;
        }}
        .req-item[data-indent="3"] .req-header-container {{
            padding-left: 70px;
        }}
        .req-item[data-indent="4"] .req-header-container {{
            padding-left: 90px;
        }}
        .req-item[data-indent="5"] .req-header-container {{
            padding-left: 110px;
        }}
        /* Cap indent at level 5 for any deeper nesting */
        .req-item[data-indent="6"] .req-header-container,
        .req-item[data-indent="7"] .req-header-container,
        .req-item[data-indent="8"] .req-header-container,
        .req-item[data-indent="9"] .req-header-container {{
            padding-left: 110px;
        }}
        .collapse-icon {{
            font-size: 10px;
            color: #6c757d;
            transition: transform 0.15s;
            flex-shrink: 0;
            width: 12px;
            text-align: center;
        }}
        .collapse-icon.collapsed {{
            transform: rotate(-90deg);
        }}
        .req-content {{
            flex: 1;
            display: grid;
            grid-template-columns: 130px 1fr 60px 90px 60px 180px;
            align-items: center;
            gap: 12px;
            min-width: 0;
        }}
        .req-id {{
            font-weight: 600;
            color: #0066cc;
            font-size: 12px;
            font-family: 'Consolas', 'Monaco', monospace;
        }}
        .req-header {{
            font-weight: 500;
            color: #2c3e50;
            font-size: 13px;
            overflow: hidden;
            text-overflow: ellipsis;
            white-space: nowrap;
        }}
        .req-level {{
            font-size: 11px;
            color: #7f8c8d;
            text-align: center;
        }}
        .req-badges {{
            display: flex;
            gap: 4px;
            align-items: center;
        }}
        .req-status {{
            font-size: 11px;
            color: #7f8c8d;
            text-align: center;
        }}
        .req-location {{
            font-size: 11px;
            color: #7f8c8d;
            overflow: hidden;
            text-overflow: ellipsis;
            white-space: nowrap;
        }}
        .impl-files {{
            margin: 8px 0 8px 40px;
            padding: 8px 12px;
            background: #f8f9fa;
            border-left: 3px solid #6c757d;
            font-size: 11px;
        }}
        .impl-files-header {{
            font-weight: 600;
            color: #495057;
            margin-bottom: 6px;
            font-size: 10px;
            text-transform: uppercase;
        }}
        .impl-file-item {{
            padding: 3px 0;
            font-family: 'Consolas', 'Monaco', monospace;
        }}
        .impl-file-item a {{
            color: #0066cc;
            text-decoration: none;
        }}
        .impl-file-item a:hover {{
            text-decoration: underline;
        }}
        .status-badge {{
            display: inline-block;
            padding: 2px 6px;
            border-radius: 2px;
            font-size: 10px;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.3px;
        }}
        .status-active {{ background: #d4edda; color: #155724; }}
        .status-draft {{ background: #fff3cd; color: #856404; }}
        .status-deprecated {{ background: #f8d7da; color: #721c24; }}
        .test-badge {{
            display: inline-block;
            padding: 2px 6px;
            border-radius: 2px;
            font-size: 10px;
            font-weight: 600;
        }}
        .test-passed {{ background: #d4edda; color: #155724; }}
        .test-failed {{ background: #f8d7da; color: #721c24; }}
        .test-not-tested {{ background: #fff3cd; color: #856404; }}
        .test-error {{ background: #f5c2c7; color: #842029; }}
        .test-skipped {{ background: #e2e3e5; color: #41464b; }}
        /* Collapsed items hidden via class */
        .req-item.collapsed-by-parent {{
            display: none;
        }}
        .impl-files.collapsed-by-parent {{
            display: none;
        }}
        .filter-header {{
            display: grid;
            grid-template-columns: 130px 1fr 60px 90px 60px 180px;
            align-items: center;
            gap: 12px;
            padding: 8px 10px 8px 42px;
            background: #e9ecef;
            border-bottom: 2px solid #dee2e6;
            margin-bottom: 8px;
            position: sticky;
            top: 0;
            z-index: 10;
        }}
        .filter-column {{
            display: flex;
            flex-direction: column;
            gap: 4px;
        }}
        .filter-label {{
            font-size: 10px;
            font-weight: 600;
            color: #495057;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }}
        .filter-column input, .filter-column select {{
            padding: 3px 6px;
            border: 1px solid #ced4da;
            border-radius: 2px;
            font-size: 11px;
            background: white;
            width: 100%;
            box-sizing: border-box;
        }}
        .filter-column input::placeholder {{
            color: #adb5bd;
            font-size: 10px;
        }}
        .filter-controls {{
            margin: 15px 0;
            padding: 10px;
            background: #f8f9fa;
            border-radius: 4px;
            display: flex;
            gap: 10px;
            align-items: center;
        }}
        .filter-stats {{
            margin-left: auto;
            font-size: 11px;
            color: #6c757d;
            font-weight: 500;
        }}
        .req-item.filtered-out {{
            display: none !important;
        }}
        .level-legend {{
            display: flex;
            gap: 15px;
            margin: 15px 0;
            padding: 8px 12px;
            background: #f8f9fa;
            border-radius: 4px;
            font-size: 12px;
        }}
        .legend-item {{
            display: flex;
            align-items: center;
            gap: 6px;
        }}
        .legend-color {{
            width: 16px;
            height: 16px;
            border-radius: 2px;
        }}
        .legend-color.prd {{ background: #0066cc; }}
        .legend-color.ops {{ background: #fd7e14; }}
        .legend-color.dev {{ background: #28a745; }}
    </style>
</head>
<body>
    <div class="container">
        <h1>Requirements Traceability Matrix</h1>
        <div class="summary">
            <p><strong>Generated:</strong> {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}</p>
            <p><strong>Total Requirements:</strong> {len(self.requirements)}</p>
        </div>

        <div class="summary-grid">
            <div class="summary-card">
                <h3>PRD Level</h3>
                <div class="number">{by_level['PRD']}</div>
            </div>
            <div class="summary-card">
                <h3>OPS Level</h3>
                <div class="number">{by_level['OPS']}</div>
            </div>
            <div class="summary-card">
                <h3>DEV Level</h3>
                <div class="number">{by_level['DEV']}</div>
            </div>
        </div>

        <div class="level-legend">
            <div class="legend-item">
                <div class="legend-color prd"></div>
                <span>PRD (Product Requirements)</span>
            </div>
            <div class="legend-item">
                <div class="legend-color ops"></div>
                <span>Ops (Operations)</span>
            </div>
            <div class="legend-item">
                <div class="legend-color dev"></div>
                <span>Dev (Development)</span>
            </div>
        </div>

        <div class="filter-controls">
            <button class="btn" onclick="expandAll()">▼ Expand All</button>
            <button class="btn btn-secondary" onclick="collapseAll()">▶ Collapse All</button>
            <button class="btn btn-secondary" onclick="clearFilters()">Clear Filters</button>
            <span class="filter-stats" id="filterStats"></span>
        </div>

        <h2>Traceability Tree</h2>

        <div class="filter-header">
            <div class="filter-column">
                <div class="filter-label">REQ ID</div>
                <input type="text" id="filterReqId" placeholder="Filter..." oninput="applyFilters()">
            </div>
            <div class="filter-column">
                <div class="filter-label">Title</div>
                <input type="text" id="filterTitle" placeholder="Search title..." oninput="applyFilters()">
            </div>
            <div class="filter-column">
                <div class="filter-label">Level</div>
                <select id="filterLevel" onchange="applyFilters()">
                    <option value="">All</option>
                    <option value="PRD">PRD</option>
                    <option value="OPS">OPS</option>
                    <option value="DEV">DEV</option>
                </select>
            </div>
            <div class="filter-column">
                <div class="filter-label">Status</div>
                <select id="filterStatus" onchange="applyFilters()">
                    <option value="">All</option>
                    <option value="Active">Active</option>
                    <option value="Draft">Draft</option>
                    <option value="Deprecated">Deprecated</option>
                </select>
            </div>
            <div class="filter-column">
                <div class="filter-label">Tests</div>
            </div>
            <div class="filter-column">
                <div class="filter-label">Topic</div>
                <select id="filterTopic" onchange="applyFilters()">
                    <option value="">All</option>
"""

        # Add topic options dynamically
        for topic in sorted_topics:
            html += f'                    <option value="{topic}">{topic}</option>\n'

        html += """                </select>
            </div>
        </div>

        <div class="req-tree" id="reqTree">
"""

        # Add requirements as flat list (hierarchy via indentation)
        flat_list = self._build_flat_requirement_list()
        for req_data in flat_list:
            html += self._format_req_flat_html(req_data)

        html += """        </div>
    </div>

    <script>
        // Track collapsed state for each requirement instance
        const collapsedInstances = new Set();

        // Toggle a single requirement instance's children
        function toggleRequirement(element) {
            const item = element.closest('.req-item');
            const instanceId = item.dataset.instanceId;
            const icon = element.querySelector('.collapse-icon');

            if (!icon.textContent) return; // No children to collapse

            if (collapsedInstances.has(instanceId)) {
                // Expand
                collapsedInstances.delete(instanceId);
                icon.classList.remove('collapsed');
                showDescendants(instanceId);
            } else {
                // Collapse
                collapsedInstances.add(instanceId);
                icon.classList.add('collapsed');
                hideDescendants(instanceId);
            }
        }

        // Hide all descendants of a requirement instance
        function hideDescendants(parentInstanceId) {
            // Hide child requirements
            document.querySelectorAll(`[data-parent-instance-id="${parentInstanceId}"]`).forEach(child => {
                child.classList.add('collapsed-by-parent');
                // Recursively hide descendants' descendants
                hideDescendants(child.dataset.instanceId);
            });

            // Also hide implementation files of the parent requirement
            const parentItem = document.querySelector(`[data-instance-id="${parentInstanceId}"]`);
            if (parentItem) {
                const implFiles = parentItem.querySelector('.impl-files');
                if (implFiles) {
                    implFiles.classList.add('collapsed-by-parent');
                }
            }
        }

        // Show immediate children of a requirement instance only (not grandchildren)
        function showDescendants(parentInstanceId) {
            // Show child requirements
            document.querySelectorAll(`[data-parent-instance-id="${parentInstanceId}"]`).forEach(child => {
                child.classList.remove('collapsed-by-parent');
                // Do NOT recursively show grandchildren - they stay hidden until their parent is expanded
            });

            // Also show implementation files of the parent requirement
            const parentItem = document.querySelector(`[data-instance-id="${parentInstanceId}"]`);
            if (parentItem) {
                const implFiles = parentItem.querySelector('.impl-files');
                if (implFiles) {
                    implFiles.classList.remove('collapsed-by-parent');
                }
            }
        }

        // Expand all requirements
        function expandAll() {
            collapsedInstances.clear();
            document.querySelectorAll('.req-item').forEach(item => {
                item.classList.remove('collapsed-by-parent');
            });
            document.querySelectorAll('.collapse-icon').forEach(el => {
                el.classList.remove('collapsed');
            });
        }

        // Collapse all requirements
        function collapseAll() {
            document.querySelectorAll('.req-item').forEach(item => {
                if (item.querySelector('.collapse-icon').textContent) {
                    collapsedInstances.add(item.dataset.instanceId);
                    hideDescendants(item.dataset.instanceId);
                    item.querySelector('.collapse-icon').classList.add('collapsed');
                }
            });
        }

        // Apply filters (simple flat filtering with duplicate detection)
        function applyFilters() {
            const reqIdFilter = document.getElementById('filterReqId').value.toLowerCase().trim();
            const titleFilter = document.getElementById('filterTitle').value.toLowerCase().trim();
            const levelFilter = document.getElementById('filterLevel').value;
            const statusFilter = document.getElementById('filterStatus').value;
            const topicFilter = document.getElementById('filterTopic').value.toLowerCase().trim();

            // Check if any filter is active
            const anyFilterActive = reqIdFilter || titleFilter || levelFilter || statusFilter || topicFilter;

            let visibleCount = 0;
            let totalCount = 0;
            const seenReqIds = new Set();  // Track which req IDs we've already shown

            // Simple iteration: show/hide each item based on filters
            document.querySelectorAll('.req-item').forEach(item => {
                totalCount++;
                const reqId = item.dataset.reqId.toLowerCase();
                const level = item.dataset.level;
                const topic = item.dataset.topic.toLowerCase();
                const status = item.dataset.status;
                const title = item.dataset.title.toLowerCase();

                let matches = true;

                // Apply all filters
                if (reqIdFilter && !reqId.includes(reqIdFilter)) matches = false;
                if (titleFilter && !title.includes(titleFilter)) matches = false;
                if (levelFilter && level !== levelFilter) matches = false;
                if (statusFilter && status !== statusFilter) matches = false;

                // Topic filter: matches exact topic or hierarchical sub-topics
                // e.g., "security" matches "security", "security-RBAC", "security-RLS"
                if (topicFilter && topic !== topicFilter && !topic.startsWith(topicFilter + '-')) {
                    matches = false;
                }

                // Check for duplicates: if filtering and we've already shown this req ID, hide this occurrence
                if (matches && anyFilterActive && seenReqIds.has(reqId)) {
                    matches = false;  // Hide duplicate
                }

                // Simple show/hide - no hierarchy complexity!
                if (matches) {
                    item.classList.remove('filtered-out');
                    // If any filter is active, ignore collapse state and show matching items
                    if (anyFilterActive) {
                        item.classList.remove('collapsed-by-parent');
                        seenReqIds.add(reqId);  // Mark this req ID as shown
                    }
                    visibleCount++;
                } else {
                    item.classList.add('filtered-out');
                }
            });

            // Update stats
            document.getElementById('filterStats').textContent =
                `Showing ${visibleCount} of ${totalCount} requirements`;
        }

        // Clear all filters
        function clearFilters() {
            document.getElementById('filterReqId').value = '';
            document.getElementById('filterTitle').value = '';
            document.getElementById('filterLevel').value = '';
            document.getElementById('filterStatus').value = '';
            document.getElementById('filterTopic').value = '';
            applyFilters();
        }

        // Initialize
        document.addEventListener('DOMContentLoaded', function() {
            // Start with everything collapsed except top level
            // First, hide all children of all items with children
            document.querySelectorAll('.req-item').forEach(item => {
                const instanceId = item.dataset.instanceId;
                const icon = item.querySelector('.collapse-icon');

                if (icon && icon.textContent) {
                    // This item has children - collapse it
                    collapsedInstances.add(instanceId);
                    hideDescendants(instanceId);
                    icon.classList.add('collapsed');
                }
            });

            // Initialize filter stats
            applyFilters();
        });
    </script>
</body>
</html>
"""
        return html

    def _build_flat_requirement_list(self) -> List[dict]:
        """Build a flat list of requirements with hierarchy information"""
        flat_list = []
        self._instance_counter = 0  # Track unique instance IDs

        # Start with top-level PRD requirements
        prd_reqs = [req for req in self.requirements.values() if req.level == 'PRD']
        prd_reqs.sort(key=lambda r: r.id)

        for prd_req in prd_reqs:
            self._add_requirement_and_children(prd_req, flat_list, indent=0, parent_instance_id='')

        return flat_list

    def _add_requirement_and_children(self, req: Requirement, flat_list: List[dict], indent: int, parent_instance_id: str):
        """Recursively add requirement and its children to flat list"""
        # Generate unique instance ID for this occurrence
        instance_id = f"inst_{self._instance_counter}"
        self._instance_counter += 1

        # Find children
        children = [
            r for r in self.requirements.values()
            if req.id in r.implements
        ]
        children.sort(key=lambda r: r.id)

        # Add this requirement
        flat_list.append({
            'req': req,
            'indent': indent,
            'instance_id': instance_id,
            'parent_instance_id': parent_instance_id,
            'has_children': len(children) > 0
        })

        # Recursively add children
        for child in children:
            self._add_requirement_and_children(child, flat_list, indent + 1, instance_id)

    def _format_req_flat_html(self, req_data: dict) -> str:
        """Format a single requirement as flat HTML row"""
        req = req_data['req']
        indent = req_data['indent']
        instance_id = req_data['instance_id']
        parent_instance_id = req_data['parent_instance_id']
        has_children = req_data['has_children']

        status_class = req.status.lower()
        level_class = req.level.lower()

        # Only show collapse icon if there are children
        collapse_icon = '▼' if has_children else ''

        # Determine test status
        test_badge = ''
        if req.test_info:
            test_status = req.test_info.test_status
            test_count = req.test_info.test_count + req.test_info.manual_test_count

            if test_status == 'passed':
                test_badge = f'<span class="test-badge test-passed" title="{test_count} tests passed">✅ {test_count}</span>'
            elif test_status == 'failed':
                test_badge = f'<span class="test-badge test-failed" title="{test_count} tests, some failed">❌ {test_count}</span>'
            elif test_status == 'not_tested':
                test_badge = '<span class="test-badge test-not-tested" title="No tests implemented">⚡</span>'
        else:
            test_badge = '<span class="test-badge test-not-tested" title="No tests implemented">⚡</span>'

        # Extract topic from filename
        topic = req.file_path.stem.split('-', 1)[1] if '-' in req.file_path.stem else req.file_path.stem

        # Format implementation files as nested section
        impl_section = ''
        if req.implementation_files:
            impl_section = '<div class="impl-files">'
            impl_section += '<div class="impl-files-header">Implemented in:</div>'
            for file_path, line_num in req.implementation_files:
                # Create clickable link to file (relative path)
                link = f"../{file_path}#L{line_num}"
                impl_section += f'<div class="impl-file-item"><a href="{link}">{file_path}:{line_num}</a></div>'
            impl_section += '</div>'

        # Build HTML for single flat row with unique instance ID
        html = f"""
        <div class="req-item {level_class} {status_class if req.status == 'Deprecated' else ''}" data-req-id="{req.id}" data-instance-id="{instance_id}" data-level="{req.level}" data-indent="{indent}" data-parent-instance-id="{parent_instance_id}" data-topic="{topic}" data-status="{req.status}" data-title="{req.title.lower()}">
            <div class="req-header-container" onclick="toggleRequirement(this)">
                <span class="collapse-icon">{collapse_icon}</span>
                <div class="req-content">
                    <div class="req-id">REQ-{req.id}</div>
                    <div class="req-header">{req.title}</div>
                    <div class="req-level">{req.level}</div>
                    <div class="req-badges">
                        <span class="status-badge status-{status_class}">{req.status}</span>
                    </div>
                    <div class="req-status">{test_badge}</div>
                    <div class="req-location">{req.file_path.name}:{req.line_number}</div>
                </div>
            </div>
            {impl_section}
        </div>
"""
        return html

    def _format_req_tree_html(self, req: Requirement) -> str:
        """Format requirement and children as HTML tree (legacy non-collapsible)"""
        status_class = req.status.lower()
        level_class = req.level.lower()

        html = f"""
        <div class="req-item {level_class} {status_class if req.status == 'Deprecated' else ''}">
            <div class="req-header">
                REQ-{req.id}: {req.title}
            </div>
            <div class="req-meta">
                <span class="status-badge status-{status_class}">{req.status}</span>
                Level: {req.level} |
                File: {req.file_path.name}:{req.line_number}
            </div>
"""

        # Find children
        children = [
            r for r in self.requirements.values()
            if req.id in r.implements
        ]
        children.sort(key=lambda r: r.id)

        if children:
            html += '            <div class="child-reqs">\n'
            for child in children:
                html += self._format_req_tree_html(child)
            html += '            </div>\n'

        html += '        </div>\n'
        return html

    def _format_req_tree_html_collapsible(self, req: Requirement) -> str:
        """Format requirement and children as collapsible HTML tree"""
        status_class = req.status.lower()
        level_class = req.level.lower()

        # Find children
        children = [
            r for r in self.requirements.values()
            if req.id in r.implements
        ]
        children.sort(key=lambda r: r.id)

        # Only show collapse icon if there are children
        collapse_icon = '▼' if children else ''

        # Determine test status
        test_badge = ''
        if req.test_info:
            test_status = req.test_info.test_status
            test_count = req.test_info.test_count + req.test_info.manual_test_count

            if test_status == 'passed':
                test_badge = f'<span class="test-badge test-passed" title="{test_count} tests passed">✅ {test_count}</span>'
            elif test_status == 'failed':
                test_badge = f'<span class="test-badge test-failed" title="{test_count} tests, some failed">❌ {test_count}</span>'
            elif test_status == 'not_tested':
                test_badge = '<span class="test-badge test-not-tested" title="No tests implemented">⚡</span>'
        else:
            test_badge = '<span class="test-badge test-not-tested" title="No tests implemented">⚡</span>'

        # Extract topic from filename (e.g., prd-security.md -> security)
        topic = req.file_path.stem.split('-', 1)[1] if '-' in req.file_path.stem else req.file_path.stem

        html = f"""
        <div class="req-item {level_class} {status_class if req.status == 'Deprecated' else ''}" data-req-id="{req.id}" data-level="{req.level}" data-topic="{topic}" data-status="{req.status}" data-title="{req.title.lower()}">
            <div class="req-header-container" onclick="toggleRequirement(this)">
                <span class="collapse-icon">{collapse_icon}</span>
                <div class="req-content">
                    <div class="req-id">REQ-{req.id}</div>
                    <div class="req-header">{req.title}</div>
                    <div class="req-level">{req.level}</div>
                    <div class="req-badges">
                        <span class="status-badge status-{status_class}">{req.status}</span>
                    </div>
                    <div class="req-status">{test_badge}</div>
                    <div class="req-location">{req.file_path.name}:{req.line_number}</div>
                </div>
            </div>
"""

        if children:
            html += '            <div class="child-reqs">\n'
            for child in children:
                html += self._format_req_tree_html_collapsible(child)
            html += '            </div>\n'

        html += '        </div>\n'
        return html

    def _load_test_data(self):
        """Load test coverage data from JSON mapping file"""
        try:
            with open(self.test_mapping_file, 'r') as f:
                data = json.load(f)

            mappings = data.get('mappings', {})

            for req_id, test_data in mappings.items():
                tests = test_data.get('tests', [])
                manual_tests = test_data.get('manual_tests', [])
                coverage = test_data.get('coverage', 'not_tested')
                notes = test_data.get('notes', '')

                test_info = TestInfo(
                    test_count=len(tests),
                    manual_test_count=len(manual_tests),
                    test_status=coverage,
                    test_details=tests + manual_tests,
                    notes=notes
                )

                # Attach test info to requirement
                if req_id in self.requirements:
                    self.requirements[req_id].test_info = test_info

            tested = sum(1 for r in self.requirements.values() if r.test_info and r.test_info.test_count > 0)
            print(f"   ✅ Loaded test data for {len(mappings)} requirements")
            print(f"   📊 Test coverage: {tested}/{len(self.requirements)} requirements have tests")

        except Exception as e:
            print(f"   ⚠️  Error loading test data: {e}")
            print(f"   All requirements will be marked as 'not tested'")

    def _generate_csv(self) -> str:
        """Generate CSV traceability matrix"""
        from io import StringIO
        output = StringIO()
        writer = csv.writer(output)

        # Header
        writer.writerow([
            'Requirement ID',
            'Title',
            'Level',
            'Status',
            'Implements',
            'Traced By',
            'File',
            'Line',
            'Implementation Files'
        ])

        # Sort requirements by ID
        sorted_reqs = sorted(self.requirements.values(), key=lambda r: r.id)

        for req in sorted_reqs:
            # Compute children (traced by) dynamically
            children = [
                r.id for r in self.requirements.values()
                if req.id in r.implements
            ]

            # Format implementation files as "file:line" strings
            impl_files_str = ', '.join([f'{path}:{line}' for path, line in req.implementation_files]) if req.implementation_files else '-'

            writer.writerow([
                req.id,
                req.title,
                req.level,
                req.status,
                ', '.join(req.implements) if req.implements else '-',
                ', '.join(sorted(children)) if children else '-',
                req.file_path.name,
                req.line_number,
                impl_files_str
            ])

        return output.getvalue()

    def _count_by_level(self) -> Dict[str, int]:
        """Count requirements by level"""
        counts = {'PRD': 0, 'OPS': 0, 'DEV': 0}
        for req in self.requirements.values():
            if req.status == 'Active':  # Only count active requirements
                counts[req.level] = counts.get(req.level, 0) + 1
        return counts

    def _find_orphaned_requirements(self) -> List[Requirement]:
        """Find requirements not linked from any parent"""
        implemented = set()
        for req in self.requirements.values():
            implemented.update(req.implements)

        orphaned = []
        for req in self.requirements.values():
            # Skip PRD requirements (they're top-level)
            if req.level == 'PRD':
                continue
            # Skip if this requirement is implemented by someone
            if req.id in implemented:
                continue
            # Skip if it has no parent (should have one)
            if not req.implements:
                orphaned.append(req)

        return sorted(orphaned, key=lambda r: r.id)


def main():
    """Main entry point"""
    import argparse

    parser = argparse.ArgumentParser(
        description='Generate requirements traceability matrix with test coverage',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog='''
Tip: Use --format both to generate both markdown and HTML versions

Examples:
  # Generate matrix for current repo
  python generate_traceability.py

  # Generate matrix for a different repo
  python generate_traceability.py --path /path/to/other/repo

  # Generate for sibling repo with HTML output
  python generate_traceability.py --path ../sibling-repo --format html
'''
    )
    parser.add_argument(
        '--format',
        choices=['markdown', 'html', 'csv', 'both'],
        default='markdown',
        help='Output format (default: markdown). Use "both" for markdown + HTML'
    )
    parser.add_argument(
        '--output',
        type=Path,
        help='Output file path (default: traceability_matrix.{format})'
    )
    parser.add_argument(
        '--test-mapping',
        type=Path,
        help='Path to requirement-test mapping JSON file (default: build-reports/templates/requirement_test_mapping.template.json)'
    )
    parser.add_argument(
        '--sponsor',
        type=str,
        help='Sponsor name for sponsor-specific reports (e.g., "callisto", "titan"). Required when --mode is "sponsor"'
    )
    parser.add_argument(
        '--mode',
        choices=['core', 'sponsor', 'combined'],
        default='core',
        help='Report mode: "core" (exclude sponsor code), "sponsor" (specific sponsor + core), "combined" (all code)'
    )
    parser.add_argument(
        '--output-dir',
        type=Path,
        help='Output directory path (overrides default based on mode)'
    )
    parser.add_argument(
        '--path',
        type=Path,
        help='Path to repository root (default: auto-detect from script location)'
    )

    args = parser.parse_args()

    # Validate sponsor argument
    if args.mode == 'sponsor' and not args.sponsor:
        print("Error: --sponsor is required when --mode is 'sponsor'")
        sys.exit(1)

    # Find spec directory
    if args.path:
        repo_root = args.path.resolve()
    else:
        script_dir = Path(__file__).parent
        repo_root = script_dir.parent.parent
    spec_dir = repo_root / 'spec'

    if not spec_dir.exists():
        print(f"❌ Spec directory not found: {spec_dir}")
        sys.exit(1)

    # Determine test mapping file
    if args.test_mapping:
        test_mapping_file = args.test_mapping
    else:
        # Default location (template file for reference)
        test_mapping_file = repo_root / 'build-reports' / 'templates' / 'requirement_test_mapping.template.json'

    # Collect implementation directories to scan based on mode
    impl_dirs = []

    if args.mode == 'core':
        # Core mode: scan core directories only (exclude /sponsor/)
        print(f"Mode: CORE - scanning core directories only")
        database_dir = repo_root / 'database'
        if database_dir.exists():
            impl_dirs.append(database_dir)

        # Scan apps directory if it exists
        apps_dir = repo_root / 'apps'
        if apps_dir.exists():
            impl_dirs.append(apps_dir)

    elif args.mode == 'sponsor':
        # Sponsor mode: scan specific sponsor + core directories
        print(f"Mode: SPONSOR ({args.sponsor}) - scanning sponsor + core directories")

        # Add sponsor directory
        sponsor_dir = repo_root / 'sponsor' / args.sponsor
        if not sponsor_dir.exists():
            print(f"Warning: Sponsor directory not found: {sponsor_dir}")
        else:
            impl_dirs.append(sponsor_dir)

        # Also scan core directories
        database_dir = repo_root / 'database'
        if database_dir.exists():
            impl_dirs.append(database_dir)

        apps_dir = repo_root / 'apps'
        if apps_dir.exists():
            impl_dirs.append(apps_dir)

    elif args.mode == 'combined':
        # Combined mode: scan ALL directories (core + all sponsors)
        print(f"Mode: COMBINED - scanning all directories")

        # Add core directories
        database_dir = repo_root / 'database'
        if database_dir.exists():
            impl_dirs.append(database_dir)

        apps_dir = repo_root / 'apps'
        if apps_dir.exists():
            impl_dirs.append(apps_dir)

        # Add all sponsor directories
        sponsor_root = repo_root / 'sponsor'
        if sponsor_root.exists():
            for sponsor_dir in sponsor_root.iterdir():
                if sponsor_dir.is_dir() and not sponsor_dir.name.startswith('.'):
                    impl_dirs.append(sponsor_dir)
                    print(f"   Including sponsor: {sponsor_dir.name}")

    generator = TraceabilityGenerator(
        spec_dir,
        test_mapping_file=test_mapping_file,
        impl_dirs=impl_dirs,
        sponsor=args.sponsor,
        mode=args.mode
    )

    # Determine output path based on --output-dir, --output, or defaults
    if args.output:
        # Explicit output file specified
        output_file = args.output
    elif args.output_dir:
        # Output directory specified - construct filename
        output_dir = args.output_dir
        output_dir.mkdir(parents=True, exist_ok=True)
        if args.format == 'both':
            output_file = output_dir / 'traceability_matrix.md'
        else:
            ext = '.html' if args.format == 'html' else ('.csv' if args.format == 'csv' else '.md')
            output_file = output_dir / f'traceability_matrix{ext}'
    else:
        # Use default output path based on mode
        if args.mode == 'core':
            output_dir = repo_root / 'build-reports' / 'combined' / 'traceability'
        elif args.mode == 'sponsor':
            output_dir = repo_root / 'build-reports' / args.sponsor / 'traceability'
        elif args.mode == 'combined':
            output_dir = repo_root / 'build-reports' / 'combined' / 'traceability'

        output_dir.mkdir(parents=True, exist_ok=True)

        if args.format == 'both':
            output_file = output_dir / 'traceability_matrix.md'
        else:
            ext = '.html' if args.format == 'html' else ('.csv' if args.format == 'csv' else '.md')
            output_file = output_dir / f'traceability_matrix{ext}'

    # Handle 'both' format option
    if args.format == 'both':
        print("Generating both Markdown and HTML formats...")
        # Generate markdown
        md_output = output_file if output_file.suffix == '.md' else output_file.with_suffix('.md')
        generator.generate(format='markdown', output_file=md_output)

        # Generate HTML
        html_output = md_output.with_suffix('.html')
        generator.generate(format='html', output_file=html_output)
    else:
        generator.generate(format=args.format, output_file=output_file)


if __name__ == '__main__':
    main()
