#!/usr/bin/env python3
"""
Generate Verification Report

Creates comprehensive reports from compliance analysis results.

Usage:
    python3 generate-report.py --input analysis.json --output report.md
    python3 generate-report.py --req-ids d00027,d00028 --format html
    python3 generate-report.py --from-tracking --format markdown
"""

import sys
import json
import argparse
import subprocess
from pathlib import Path
from datetime import datetime
from typing import List, Dict


def get_repo_root() -> Path:
    """
    Get the repository root using git.

    This works even when the script is run from the Claude Code plugin cache,
    as long as the current working directory is within a git repository.
    """
    try:
        result = subprocess.run(
            ['git', 'rev-parse', '--show-toplevel'],
            capture_output=True,
            text=True,
            check=True
        )
        return Path(result.stdout.strip())
    except subprocess.CalledProcessError:
        # Fallback to relative path traversal (works when run from repo directly)
        return Path(__file__).resolve().parents[5]


# Repo root
repo_root = get_repo_root()


def load_analyses_from_file(file_path: Path) -> List[Dict]:
    """Load analysis results from JSON file"""
    with file_path.open('r') as f:
        data = json.load(f)
        return data.get('analyses', [])


def load_from_tracking_file() -> List[Dict]:
    """Load outdated requirements from tracking file"""
    tracking_file = repo_root / 'untracked-notes' / 'outdated-implementations.json'

    if not tracking_file.exists():
        return []

    with tracking_file.open('r') as f:
        data = json.load(f)
        return data.get('outdated_requirements', [])


def generate_markdown_report(analyses: List[Dict], title: str = "Requirement Verification Report") -> str:
    """Generate markdown format report"""
    lines = []

    # Header
    lines.append(f"# {title}")
    lines.append("")
    lines.append(f"**Generated**: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    lines.append("")

    if not analyses:
        lines.append("No analyses to report.")
        return '\n'.join(lines)

    # Executive Summary
    lines.append("## Executive Summary")
    lines.append("")

    total = len(analyses)
    compliant = sum(1 for a in analyses if a.get('still_compliant', True))
    non_compliant = total - compliant

    high_risk = sum(1 for a in analyses if a.get('risk_level') == 'HIGH')
    medium_risk = sum(1 for a in analyses if a.get('risk_level') == 'MEDIUM')
    low_risk = sum(1 for a in analyses if a.get('risk_level') == 'LOW')

    lines.append(f"- **Total Requirements Analyzed**: {total}")
    lines.append(f"- **Compliant**: {compliant} ({compliant/total*100:.0f}%)")
    lines.append(f"- **Non-Compliant**: {non_compliant} ({non_compliant/total*100:.0f}%)")
    lines.append(f"- **Risk Level**: HIGH={high_risk}, MEDIUM={medium_risk}, LOW={low_risk}")
    lines.append("")

    # Detailed Findings
    lines.append("## Detailed Findings")
    lines.append("")

    for i, analysis in enumerate(analyses, 1):
        req_id = analysis.get('req_id', 'unknown')
        file = analysis.get('file', 'unknown')
        compliant = analysis.get('still_compliant', True)
        risk = analysis.get('risk_level', 'UNKNOWN')
        summary = analysis.get('changes_summary', '')
        changes = analysis.get('required_changes', [])
        recommendations = analysis.get('recommendations', '')

        status_icon = "✅" if compliant else "❌"

        lines.append(f"### [{i}] REQ-{req_id}")
        lines.append("")
        lines.append(f"**File**: `{file}`")
        lines.append(f"**Status**: {status_icon} {'COMPLIANT' if compliant else 'NON-COMPLIANT'}")
        lines.append(f"**Risk**: {risk}")
        lines.append("")

        if summary:
            lines.append(f"**Summary**: {summary}")
            lines.append("")

        if changes:
            lines.append("**Required Changes**:")
            for change in changes:
                lines.append(f"- {change}")
            lines.append("")

        if recommendations:
            lines.append("**Recommendations**:")
            lines.append(recommendations)
            lines.append("")

        lines.append("---")
        lines.append("")

    # Action Items
    lines.append("## Action Items")
    lines.append("")

    high_priority = [a for a in analyses if a.get('risk_level') == 'HIGH' and not a.get('still_compliant', True)]
    medium_priority = [a for a in analyses if a.get('risk_level') == 'MEDIUM' and not a.get('still_compliant', True)]
    low_priority = [a for a in analyses if a.get('risk_level') == 'LOW' and not a.get('still_compliant', True)]

    if high_priority:
        lines.append(f"### High Priority ({len(high_priority)})")
        for a in high_priority:
            lines.append(f"- [ ] Update `{a['file']}` for REQ-{a['req_id']}")
        lines.append("")

    if medium_priority:
        lines.append(f"### Medium Priority ({len(medium_priority)})")
        for a in medium_priority:
            lines.append(f"- [ ] Review `{a['file']}` for REQ-{a['req_id']}")
        lines.append("")

    if low_priority:
        lines.append(f"### Low Priority ({len(low_priority)})")
        for a in low_priority:
            lines.append(f"- [ ] Consider updating `{a['file']}` for REQ-{a['req_id']}")
        lines.append("")

    return '\n'.join(lines)


def generate_html_report(analyses: List[Dict], title: str = "Requirement Verification Report") -> str:
    """Generate HTML format report"""
    html = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{title}</title>
    <style>
        body {{ font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; margin: 40px; }}
        h1 {{ color: #333; }}
        h2 {{ color: #555; border-bottom: 2px solid #eee; padding-bottom: 10px; }}
        .summary {{ background: #f5f5f5; padding: 20px; border-radius: 5px; margin: 20px 0; }}
        .finding {{ border: 1px solid #ddd; padding: 15px; margin: 15px 0; border-radius: 5px; }}
        .compliant {{ border-left: 4px solid #4CAF50; }}
        .non-compliant {{ border-left: 4px solid #f44336; }}
        .risk-high {{ color: #f44336; font-weight: bold; }}
        .risk-medium {{ color: #FF9800; font-weight: bold; }}
        .risk-low {{ color: #4CAF50; font-weight: bold; }}
        code {{ background: #f5f5f5; padding: 2px 6px; border-radius: 3px; }}
        ul {{ line-height: 1.6; }}
    </style>
</head>
<body>
    <h1>{title}</h1>
    <p><strong>Generated:</strong> {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}</p>
"""

    if not analyses:
        html += "    <p>No analyses to report.</p>\n"
        html += "</body>\n</html>"
        return html

    # Executive Summary
    total = len(analyses)
    compliant = sum(1 for a in analyses if a.get('still_compliant', True))
    non_compliant = total - compliant
    high_risk = sum(1 for a in analyses if a.get('risk_level') == 'HIGH')
    medium_risk = sum(1 for a in analyses if a.get('risk_level') == 'MEDIUM')
    low_risk = sum(1 for a in analyses if a.get('risk_level') == 'LOW')

    html += """
    <div class="summary">
        <h2>Executive Summary</h2>
        <ul>
"""
    html += f"            <li><strong>Total Analyzed:</strong> {total}</li>\n"
    html += f"            <li><strong>Compliant:</strong> {compliant} ({compliant/total*100:.0f}%)</li>\n"
    html += f"            <li><strong>Non-Compliant:</strong> {non_compliant} ({non_compliant/total*100:.0f}%)</li>\n"
    html += f"            <li><strong>Risk:</strong> HIGH={high_risk}, MEDIUM={medium_risk}, LOW={low_risk}</li>\n"
    html += """        </ul>
    </div>
"""

    # Detailed Findings
    html += "    <h2>Detailed Findings</h2>\n"

    for i, analysis in enumerate(analyses, 1):
        req_id = analysis.get('req_id', 'unknown')
        file = analysis.get('file', 'unknown')
        compliant = analysis.get('still_compliant', True)
        risk = analysis.get('risk_level', 'UNKNOWN')
        summary = analysis.get('changes_summary', '')
        changes = analysis.get('required_changes', [])

        status_class = 'compliant' if compliant else 'non-compliant'
        status_text = 'COMPLIANT' if compliant else 'NON-COMPLIANT'
        risk_class = f'risk-{risk.lower()}'

        html += f'    <div class="finding {status_class}">\n'
        html += f'        <h3>[{i}] REQ-{req_id}</h3>\n'
        html += f'        <p><strong>File:</strong> <code>{file}</code></p>\n'
        html += f'        <p><strong>Status:</strong> {status_text}</p>\n'
        html += f'        <p><strong>Risk:</strong> <span class="{risk_class}">{risk}</span></p>\n'

        if summary:
            html += f'        <p><strong>Summary:</strong> {summary}</p>\n'

        if changes:
            html += '        <p><strong>Required Changes:</strong></p>\n'
            html += '        <ul>\n'
            for change in changes:
                html += f'            <li>{change}</li>\n'
            html += '        </ul>\n'

        html += '    </div>\n'

    html += "</body>\n</html>"
    return html


def generate_json_report(analyses: List[Dict]) -> str:
    """Generate JSON format report"""
    report = {
        'generated_at': datetime.now().isoformat(),
        'total_analyzed': len(analyses),
        'summary': {
            'compliant': sum(1 for a in analyses if a.get('still_compliant', True)),
            'non_compliant': sum(1 for a in analyses if not a.get('still_compliant', True)),
            'high_risk': sum(1 for a in analyses if a.get('risk_level') == 'HIGH'),
            'medium_risk': sum(1 for a in analyses if a.get('risk_level') == 'MEDIUM'),
            'low_risk': sum(1 for a in analyses if a.get('risk_level') == 'LOW'),
        },
        'analyses': analyses
    }
    return json.dumps(report, indent=2)


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(
        description='Generate verification reports from analysis results',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    # From analysis file:
    %(prog)s --input analysis.json --output report.md

    # From tracking file:
    %(prog)s --from-tracking --format markdown --output report.md

    # HTML report:
    %(prog)s --input analysis.json --format html --output report.html

    # JSON report:
    %(prog)s --input analysis.json --format json --output report.json
        """
    )

    parser.add_argument(
        '--input',
        type=Path,
        help='Input analysis JSON file'
    )

    parser.add_argument(
        '--from-tracking',
        action='store_true',
        help='Load from tracking file (outdated-implementations.json)'
    )

    parser.add_argument(
        '--format',
        choices=['markdown', 'html', 'json'],
        default='markdown',
        help='Report format (default: markdown)'
    )

    parser.add_argument(
        '--output',
        type=Path,
        help='Output file (default: stdout)'
    )

    parser.add_argument(
        '--title',
        default='Requirement Verification Report',
        help='Report title'
    )

    args = parser.parse_args()

    if not args.input and not args.from_tracking:
        print("Error: Must specify --input or --from-tracking", file=sys.stderr)
        return 1

    try:
        # Load analyses
        analyses = []

        if args.from_tracking:
            tracking_items = load_from_tracking_file()
            # Convert tracking items to analysis format
            for item in tracking_items:
                analyses.append({
                    'req_id': item['req_id'],
                    'file': item['file'],
                    'changes_summary': f"Hash changed: {item['old_hash']} → {item['new_hash']}",
                    'still_compliant': False,  # Assume needs review
                    'risk_level': 'MEDIUM',
                    'required_changes': ['Review implementation against updated requirement'],
                    'recommendations': f"Review {item['title']} implementation",
                    'analyzed_at': item['detected_at'],
                    'confidence': 'MEDIUM'
                })
        elif args.input:
            analyses = load_analyses_from_file(args.input)

        # Generate report
        if args.format == 'markdown':
            report = generate_markdown_report(analyses, args.title)
        elif args.format == 'html':
            report = generate_html_report(analyses, args.title)
        elif args.format == 'json':
            report = generate_json_report(analyses)
        else:
            report = generate_markdown_report(analyses, args.title)

        # Output
        if args.output:
            args.output.write_text(report)
            print(f"✅ Report generated: {args.output}")
        else:
            print(report)

        return 0

    except Exception as e:
        print(f"❌ Error: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        return 1


if __name__ == '__main__':
    sys.exit(main())
