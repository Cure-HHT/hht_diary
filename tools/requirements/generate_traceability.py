#!/usr/bin/env python3
"""
Requirements Traceability Matrix Generator

Generates traceability matrix showing relationships between requirements
at different levels (PRD -> Ops -> Dev).

Output formats:
- HTML: Interactive web page with filtering
- Markdown: Documentation-friendly format
- CSV: Spreadsheet import
"""

import re
import sys
import csv
from pathlib import Path
from typing import Dict, List, Set
from dataclasses import dataclass
from datetime import datetime

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
    traced_by: List[str]


class TraceabilityGenerator:
    """Generates traceability matrices"""

    REQ_HEADER_PATTERN = re.compile(r'^###\s+REQ-([pod]\d{5}):\s+(.+)$', re.MULTILINE)
    METADATA_PATTERN = re.compile(
        r'\*\*Level\*\*:\s+(PRD|Ops|Dev)\s+\|\s+\*\*Implements\*\*:\s+([^\|]+)\s+\|\s+\*\*Status\*\*:\s+(Active|Draft|Deprecated)',
        re.MULTILINE
    )
    TRACED_BY_PATTERN = re.compile(r'\*\*Traced by\*\*:\s+(.+)$', re.MULTILINE)

    def __init__(self, spec_dir: Path):
        self.spec_dir = spec_dir
        self.requirements: Dict[str, Requirement] = {}

    def generate(self, format: str = 'markdown', output_file: Path = None):
        """Generate traceability matrix in specified format"""
        print(f"🔍 Scanning {self.spec_dir} for requirements...")
        self._parse_requirements()

        if not self.requirements:
            print("⚠️  No requirements found")
            return

        print(f"📋 Found {len(self.requirements)} requirements")
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

            traced_by = []
            traced_match = self.TRACED_BY_PATTERN.search(remaining_content[:1000])
            if traced_match:
                traced_str = traced_match.group(1).strip()
                if traced_str != '-':
                    traced_by = [
                        t.strip()
                        for t in traced_str.split(',')
                        if t.strip()
                    ]

            req = Requirement(
                id=req_id,
                title=title,
                level=level,
                implements=implements,
                status=status,
                file_path=file_path,
                line_number=line_num,
                traced_by=traced_by
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
        """Generate interactive HTML traceability matrix"""
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
        .req-tree {{
            margin: 20px 0;
        }}
        .req-item {{
            margin: 10px 0;
            padding: 15px;
            background: #f8f9fa;
            border-radius: 5px;
            border-left: 4px solid #28a745;
        }}
        .req-item.prd {{ border-left-color: #0066cc; }}
        .req-item.ops {{ border-left-color: #fd7e14; }}
        .req-item.dev {{ border-left-color: #28a745; }}
        .req-item.deprecated {{ opacity: 0.6; }}
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
        }}
        .status-active {{ background: #d4edda; color: #155724; }}
        .status-draft {{ background: #fff3cd; color: #856404; }}
        .status-deprecated {{ background: #f8d7da; color: #721c24; }}
        .child-reqs {{
            margin-left: 30px;
            margin-top: 10px;
            border-left: 2px solid #dee2e6;
            padding-left: 15px;
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
"""
        by_level = self._count_by_level()
        for level, count in by_level.items():
            html += f"""            <div class="summary-card">
                <h3>{level} Level</h3>
                <div class="number">{count}</div>
            </div>
"""

        html += """        </div>

        <h2>Traceability Tree</h2>
        <div class="req-tree">
"""

        # Add requirements tree
        prd_reqs = [req for req in self.requirements.values() if req.level == 'PRD']
        prd_reqs.sort(key=lambda r: r.id)

        for prd_req in prd_reqs:
            html += self._format_req_tree_html(prd_req)

        html += """        </div>
    </div>
</body>
</html>
"""
        return html

    def _format_req_tree_html(self, req: Requirement) -> str:
        """Format requirement and children as HTML tree"""
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
            writer.writerow([
                req.id,
                req.title,
                req.level,
                req.status,
                ', '.join(req.implements) if req.implements else '-',
                ', '.join(req.traced_by) if req.traced_by else '-',
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

    parser = argparse.ArgumentParser(description='Generate requirements traceability matrix')
    parser.add_argument(
        '--format',
        choices=['markdown', 'html', 'csv'],
        default='markdown',
        help='Output format (default: markdown)'
    )
    parser.add_argument(
        '--output',
        type=Path,
        help='Output file path (default: traceability_matrix.{format})'
    )

    args = parser.parse_args()

    # Find spec directory
    script_dir = Path(__file__).parent
    repo_root = script_dir.parent.parent
    spec_dir = repo_root / 'spec'

    if not spec_dir.exists():
        print(f"❌ Spec directory not found: {spec_dir}")
        sys.exit(1)

    generator = TraceabilityGenerator(spec_dir)
    generator.generate(format=args.format, output_file=args.output)


if __name__ == '__main__':
    main()
