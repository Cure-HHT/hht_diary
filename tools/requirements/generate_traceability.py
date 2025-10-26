#!/usr/bin/env python3
"""
Requirements Traceability Matrix Generator

Generates traceability matrix showing relationships between requirements
at different levels (PRD -> Ops -> Dev).

Output formats:
- HTML: Interactive web page with collapsible hierarchy (enhanced!)
- Markdown: Documentation-friendly format
- CSV: Spreadsheet import

Features:
- Collapsible requirement hierarchy in HTML view
- Expand/collapse all controls
- Color-coded by requirement level (PRD/Ops/Dev)
- Status badges (Active/Draft/Deprecated)
- Markdown source ensures HTML consistency
"""

import re
import sys
import csv
import json
from pathlib import Path
from typing import Dict, List, Set, Optional
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


class TraceabilityGenerator:
    """Generates traceability matrices"""

    REQ_HEADER_PATTERN = re.compile(r'^###\s+REQ-([pod]\d{5}):\s+(.+)$', re.MULTILINE)
    METADATA_PATTERN = re.compile(
        r'\*\*Level\*\*:\s+(PRD|Ops|Dev)\s+\|\s+\*\*Implements\*\*:\s+([^\|]+)\s+\|\s+\*\*Status\*\*:\s+(Active|Draft|Deprecated)',
        re.MULTILINE
    )

    def __init__(self, spec_dir: Path, test_mapping_file: Optional[Path] = None):
        self.spec_dir = spec_dir
        self.requirements: Dict[str, Requirement] = {}
        self.test_mapping_file = test_mapping_file
        self.test_data: Dict[str, TestInfo] = {}

    def generate(self, format: str = 'markdown', output_file: Path = None):
        """Generate traceability matrix in specified format"""
        print(f"🔍 Scanning {self.spec_dir} for requirements...")
        self._parse_requirements()

        if not self.requirements:
            print("⚠️  No requirements found")
            return

        print(f"📋 Found {len(self.requirements)} requirements")

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
            req_id = match.group(1)
            title = match.group(2).strip()
            line_num = content[:match.start()].count('\n') + 1

            remaining_content = content[match.end():]
            metadata_match = self.METADATA_PATTERN.search(remaining_content[:500])

            if not metadata_match:
                continue

            level = metadata_match.group(1)
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
        lines.append(f"- **Ops Requirements**: {by_level['Ops']}")
        lines.append(f"- **Dev Requirements**: {by_level['Dev']}\n")

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

        html = f"""<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Requirements Traceability Matrix</title>
    <style>
        body {{
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Arial, sans-serif;
            margin: 20px;
            background: #f5f5f5;
        }}
        .container {{
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            padding: 30px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }}
        h1 {{
            color: #333;
            border-bottom: 3px solid #0066cc;
            padding-bottom: 10px;
        }}
        h2 {{
            color: #555;
            margin-top: 30px;
            margin-bottom: 15px;
        }}
        .summary {{
            background: #f8f9fa;
            padding: 15px;
            border-radius: 5px;
            margin: 20px 0;
        }}
        .summary-grid {{
            display: grid;
            grid-template-columns: repeat(3, 1fr);
            gap: 15px;
        }}
        .summary-card {{
            background: white;
            padding: 15px;
            border-radius: 5px;
            text-align: center;
            border-left: 4px solid #0066cc;
        }}
        .summary-card h3 {{
            margin: 0 0 10px 0;
            color: #666;
            font-size: 14px;
        }}
        .summary-card .number {{
            font-size: 32px;
            font-weight: bold;
            color: #0066cc;
        }}
        .controls {{
            margin: 20px 0;
            padding: 15px;
            background: #e9ecef;
            border-radius: 5px;
            display: flex;
            gap: 10px;
            align-items: center;
        }}
        .btn {{
            padding: 8px 16px;
            border: none;
            border-radius: 4px;
            background: #0066cc;
            color: white;
            cursor: pointer;
            font-size: 14px;
            transition: background 0.2s;
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
            margin: 20px 0;
        }}
        .req-item {{
            margin: 10px 0;
            background: #f8f9fa;
            border-radius: 5px;
            border-left: 4px solid #28a745;
            overflow: hidden;
        }}
        .req-item.prd {{ border-left-color: #0066cc; }}
        .req-item.ops {{ border-left-color: #fd7e14; }}
        .req-item.dev {{ border-left-color: #28a745; }}
        .req-item.deprecated {{ opacity: 0.6; }}
        .req-header-container {{
            padding: 15px;
            cursor: pointer;
            user-select: none;
            display: flex;
            align-items: center;
            gap: 10px;
        }}
        .req-header-container:hover {{
            background: #e9ecef;
        }}
        .collapse-icon {{
            font-size: 12px;
            color: #666;
            transition: transform 0.2s;
            flex-shrink: 0;
        }}
        .collapse-icon.collapsed {{
            transform: rotate(-90deg);
        }}
        .req-content {{
            flex: 1;
        }}
        .req-header {{
            font-weight: bold;
            color: #333;
            margin-bottom: 5px;
        }}
        .req-meta {{
            font-size: 13px;
            color: #666;
            margin-top: 5px;
        }}
        .status-badge {{
            display: inline-block;
            padding: 3px 8px;
            border-radius: 3px;
            font-size: 12px;
            font-weight: bold;
            margin-right: 8px;
        }}
        .status-active {{ background: #d4edda; color: #155724; }}
        .status-draft {{ background: #fff3cd; color: #856404; }}
        .status-deprecated {{ background: #f8d7da; color: #721c24; }}
        .test-badge {{
            display: inline-block;
            padding: 3px 8px;
            border-radius: 3px;
            font-size: 11px;
            font-weight: bold;
            margin-right: 8px;
        }}
        .test-passed {{ background: #d4edda; color: #155724; }}
        .test-failed {{ background: #f8d7da; color: #721c24; }}
        .test-not-tested {{ background: #fff3cd; color: #856404; }}
        .test-error {{ background: #f5c2c7; color: #842029; }}
        .test-skipped {{ background: #e2e3e5; color: #41464b; }}
        .child-reqs {{
            margin-left: 30px;
            margin-top: 10px;
            border-left: 2px solid #dee2e6;
            padding-left: 15px;
            display: none;
        }}
        .child-reqs.expanded {{
            display: block;
        }}
        .filter-bar {{
            margin: 20px 0;
            padding: 15px;
            background: #e9ecef;
            border-radius: 5px;
        }}
        .filter-bar label {{
            margin-right: 15px;
        }}
        .level-legend {{
            display: flex;
            gap: 20px;
            margin: 20px 0;
            padding: 10px;
            background: #f8f9fa;
            border-radius: 5px;
        }}
        .legend-item {{
            display: flex;
            align-items: center;
            gap: 8px;
        }}
        .legend-color {{
            width: 20px;
            height: 20px;
            border-radius: 3px;
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
                <h3>Ops Level</h3>
                <div class="number">{by_level['Ops']}</div>
            </div>
            <div class="summary-card">
                <h3>Dev Level</h3>
                <div class="number">{by_level['Dev']}</div>
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

        <div class="controls">
            <button class="btn" onclick="expandAll()">▼ Expand All</button>
            <button class="btn btn-secondary" onclick="collapseAll()">▶ Collapse All</button>
            <span style="margin-left: auto; color: #666; font-size: 14px;">Click any requirement to expand/collapse its children</span>
        </div>

        <h2>Traceability Tree</h2>
        <div class="req-tree" id="reqTree">
"""

        # Add requirements tree
        prd_reqs = [req for req in self.requirements.values() if req.level == 'PRD']
        prd_reqs.sort(key=lambda r: r.id)

        for prd_req in prd_reqs:
            html += self._format_req_tree_html_collapsible(prd_req)

        html += """        </div>
    </div>

    <script>
        // Toggle a single requirement's children
        function toggleRequirement(element) {
            const childReqs = element.nextElementSibling;
            const icon = element.querySelector('.collapse-icon');

            if (childReqs && childReqs.classList.contains('child-reqs')) {
                childReqs.classList.toggle('expanded');
                icon.classList.toggle('collapsed');
            }
        }

        // Expand all requirements
        function expandAll() {
            document.querySelectorAll('.child-reqs').forEach(el => {
                el.classList.add('expanded');
            });
            document.querySelectorAll('.collapse-icon').forEach(el => {
                el.classList.remove('collapsed');
            });
        }

        // Collapse all requirements
        function collapseAll() {
            document.querySelectorAll('.child-reqs').forEach(el => {
                el.classList.remove('expanded');
            });
            document.querySelectorAll('.collapse-icon').forEach(el => {
                el.classList.add('collapsed');
            });
        }

        // Initialize with top-level expanded
        document.addEventListener('DOMContentLoaded', function() {
            // Expand only top-level (PRD) requirements by default
            document.querySelectorAll('.req-tree > .req-item > .child-reqs').forEach(el => {
                el.classList.add('expanded');
            });
            document.querySelectorAll('.req-tree > .req-item .collapse-icon').forEach(el => {
                el.classList.remove('collapsed');
            });
        });
    </script>
</body>
</html>
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
                test_badge = f'<span class="test-badge test-passed" title="{test_count} tests passed">✅ Tested ({test_count})</span>'
            elif test_status == 'failed':
                test_badge = f'<span class="test-badge test-failed" title="{test_count} tests, some failed">❌ Failed ({test_count})</span>'
            elif test_status == 'not_tested':
                test_badge = '<span class="test-badge test-not-tested" title="No tests implemented">⚡ Not Tested</span>'
        else:
            test_badge = '<span class="test-badge test-not-tested" title="No tests implemented">⚡ Not Tested</span>'

        html = f"""
        <div class="req-item {level_class} {status_class if req.status == 'Deprecated' else ''}">
            <div class="req-header-container" onclick="toggleRequirement(this)">
                <span class="collapse-icon">{collapse_icon}</span>
                <div class="req-content">
                    <div class="req-header">
                        REQ-{req.id}: {req.title}
                    </div>
                    <div class="req-meta">
                        <span class="status-badge status-{status_class}">{req.status}</span>
                        {test_badge}
                        Level: {req.level} |
                        File: {req.file_path.name}:{req.line_number}
                    </div>
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
            'Line'
        ])

        # Sort requirements by ID
        sorted_reqs = sorted(self.requirements.values(), key=lambda r: r.id)

        for req in sorted_reqs:
            # Compute children (traced by) dynamically
            children = [
                r.id for r in self.requirements.values()
                if req.id in r.implements
            ]

            writer.writerow([
                req.id,
                req.title,
                req.level,
                req.status,
                ', '.join(req.implements) if req.implements else '-',
                ', '.join(sorted(children)) if children else '-',
                req.file_path.name,
                req.line_number
            ])

        return output.getvalue()

    def _count_by_level(self) -> Dict[str, int]:
        """Count requirements by level"""
        counts = {'PRD': 0, 'Ops': 0, 'Dev': 0}
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
        epilog='Tip: Use --format both to generate both markdown and HTML versions'
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
        help='Path to requirement-test mapping JSON file (default: test_results/requirement_test_mapping.json)'
    )

    args = parser.parse_args()

    # Find spec directory
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
        # Default location
        test_mapping_file = repo_root / 'test_results' / 'requirement_test_mapping.json'

    generator = TraceabilityGenerator(spec_dir, test_mapping_file=test_mapping_file)

    # Handle 'both' format option
    if args.format == 'both':
        print("📊 Generating both Markdown and HTML formats...")
        # Generate markdown
        md_output = args.output if args.output else Path('traceability_matrix.md')
        if md_output.suffix != '.md':
            md_output = md_output.with_suffix('.md')
        generator.generate(format='markdown', output_file=md_output)

        # Generate HTML
        html_output = md_output.with_suffix('.html')
        generator.generate(format='html', output_file=html_output)
    else:
        generator.generate(format=args.format, output_file=args.output)


if __name__ == '__main__':
    main()
