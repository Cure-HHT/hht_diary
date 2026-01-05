#!/usr/bin/env python3
"""
Pre-PR Compliance Check

Unified script for checking requirement compliance before PR creation.
Works both locally and in GitHub Actions.

Local usage:
    python3 pre-pr-compliance-check.py
    python3 pre-pr-compliance-check.py --format markdown
    python3 pre-pr-compliance-check.py --strict  # Exit non-zero if issues found

GitHub Actions usage:
    python3 pre-pr-compliance-check.py --github-action
    # Outputs markdown to GITHUB_STEP_SUMMARY and sets output variables

Environment Detection:
    - GITHUB_ACTIONS=true: Running in GitHub Actions
    - GITHUB_STEP_SUMMARY: Path to write job summary
    - GITHUB_OUTPUT: Path to write output variables
"""

import sys
import os
import json
import argparse
from pathlib import Path
from datetime import datetime
from typing import List, Dict, Any, Optional

# Import shared utilities
from common import get_repo_root, load_tracking_file

# Setup paths
repo_root = get_repo_root()


def is_github_actions() -> bool:
    """Check if running in GitHub Actions"""
    return os.environ.get('GITHUB_ACTIONS', '').lower() == 'true'


def detect_changed_requirements() -> Dict[str, Any]:
    """
    Detect requirements that have changed (hash mismatch with INDEX.md).

    Returns dict with changed_requirements, new_requirements, etc.
    """
    try:
        # Run detect-changes.py as subprocess since it has a hyphen in the name
        import subprocess
        script_path = Path(__file__).parent / 'detect-changes.py'
        result = subprocess.run(
            ['python3', str(script_path), '--format', 'json'],
            capture_output=True,
            text=True,
            timeout=30
        )
        if result.returncode == 0:
            return json.loads(result.stdout)
        else:
            return {
                'error': result.stderr,
                'changed_requirements': [],
                'new_requirements': [],
                'missing_from_index': [],
                'summary': {'changed_count': 0, 'new_count': 0, 'missing_count': 0}
            }
    except Exception as e:
        return {
            'error': str(e),
            'changed_requirements': [],
            'new_requirements': [],
            'missing_from_index': [],
            'summary': {'changed_count': 0, 'new_count': 0, 'missing_count': 0}
        }


def get_outdated_implementations() -> List[Dict]:
    """
    Get requirements tracked as having outdated implementations.

    Returns list of outdated requirement entries from tracking file.
    """
    try:
        data = load_tracking_file()
        return data.get('outdated_requirements', [])
    except FileNotFoundError:
        return []


def run_compliance_analysis(req_id: str, use_claude_code: bool = False) -> Optional[Dict]:
    """
    Run AI compliance analysis for a requirement.

    Args:
        req_id: Requirement ID to analyze
        use_claude_code: Use Claude Code CLI instead of Anthropic API

    Returns analysis dict or None if analysis unavailable.
    """
    import shutil

    # Check if any AI backend is available
    has_api_key = bool(os.environ.get('ANTHROPIC_API_KEY'))
    has_claude_code = shutil.which('claude') is not None

    if not has_api_key and not has_claude_code and not use_claude_code:
        return None

    try:
        import subprocess
        script_path = Path(__file__).parent / 'analyze-compliance.py'

        cmd = ['python3', str(script_path), req_id, '--auto-scan', '--format', 'json']
        if use_claude_code:
            cmd.append('--use-claude-code')

        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=120,  # AI analysis can take time
            env={**os.environ}  # Pass through environment
        )

        if result.returncode == 0:
            data = json.loads(result.stdout)
            analyses = data.get('analyses', [])
            if analyses:
                return analyses[0]  # Return first analysis
            return {
                'req_id': req_id,
                'status': 'no_implementations',
                'message': f'No implementations found for REQ-{req_id}'
            }
        else:
            return {
                'req_id': req_id,
                'status': 'error',
                'message': result.stderr[:200] if result.stderr else 'Analysis failed'
            }
    except Exception as e:
        return {
            'req_id': req_id,
            'status': 'error',
            'message': str(e)
        }


def generate_report(
    changed_reqs: Dict[str, Any],
    outdated: List[Dict],
    analyses: List[Dict],
    format_type: str = 'text'
) -> str:
    """Generate compliance report in specified format."""

    if format_type == 'json':
        return json.dumps({
            'generated_at': datetime.now().isoformat(),
            'changed_requirements': changed_reqs,
            'outdated_implementations': outdated,
            'analyses': analyses,
            'summary': {
                'changed_count': changed_reqs.get('summary', {}).get('changed_count', 0),
                'outdated_count': len(outdated),
                'analyses_count': len(analyses),
                'has_issues': bool(changed_reqs.get('changed_requirements') or outdated)
            }
        }, indent=2)

    elif format_type == 'markdown':
        lines = []
        lines.append("# Pre-PR Compliance Check")
        lines.append("")
        lines.append(f"**Generated**: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        lines.append("")

        # Summary
        changed_count = changed_reqs.get('summary', {}).get('changed_count', 0)
        outdated_count = len(outdated)

        if changed_count == 0 and outdated_count == 0:
            lines.append("## :white_check_mark: All Clear")
            lines.append("")
            lines.append("No requirement changes or outdated implementations detected.")
            return '\n'.join(lines)

        lines.append("## Summary")
        lines.append("")
        lines.append(f"| Metric | Count |")
        lines.append(f"|--------|-------|")
        lines.append(f"| Changed Requirements | {changed_count} |")
        lines.append(f"| Outdated Implementations | {outdated_count} |")
        lines.append(f"| AI Analyses Run | {len(analyses)} |")
        lines.append("")

        # Changed Requirements
        if changed_reqs.get('changed_requirements'):
            lines.append("## :warning: Changed Requirements")
            lines.append("")
            lines.append("These requirements have been modified since last INDEX.md update:")
            lines.append("")
            for req in changed_reqs['changed_requirements']:
                lines.append(f"- **REQ-{req['req_id']}**: {req['title']}")
                lines.append(f"  - File: `{req['file']}`")
                lines.append(f"  - Hash: `{req['old_hash']}` → `{req['new_hash']}`")
            lines.append("")

        # Outdated Implementations
        if outdated:
            lines.append("## :x: Outdated Implementations")
            lines.append("")
            lines.append("These implementations may not satisfy their updated requirements:")
            lines.append("")
            for item in outdated:
                lines.append(f"- **REQ-{item['req_id']}**: {item.get('title', 'Unknown')}")
                lines.append(f"  - File: `{item.get('file', 'Unknown')}`")
                lines.append(f"  - Detected: {item.get('detected_at', 'Unknown')}")
            lines.append("")

        # AI Analyses
        if analyses:
            lines.append("## :robot: AI Compliance Analysis")
            lines.append("")
            for analysis in analyses:
                if analysis.get('status') == 'error':
                    lines.append(f"### REQ-{analysis['req_id']}: Error")
                    lines.append(f"> {analysis.get('message', 'Unknown error')}")
                elif analysis.get('status') == 'no_implementations':
                    lines.append(f"### REQ-{analysis['req_id']}: No Implementations")
                    lines.append(f"> {analysis.get('message', 'No implementations found')}")
                else:
                    status_icon = ":white_check_mark:" if analysis.get('still_compliant') else ":x:"
                    risk_icons = {'LOW': ':green_circle:', 'MEDIUM': ':yellow_circle:', 'HIGH': ':red_circle:'}
                    risk_icon = risk_icons.get(analysis.get('risk_level', ''), ':white_circle:')

                    lines.append(f"### REQ-{analysis['req_id']}")
                    lines.append("")
                    lines.append(f"- **Status**: {status_icon} {'Compliant' if analysis.get('still_compliant') else 'Non-Compliant'}")
                    lines.append(f"- **Risk**: {risk_icon} {analysis.get('risk_level', 'Unknown')}")
                    lines.append(f"- **File**: `{analysis.get('file', 'Unknown')}`")
                    lines.append(f"- **Confidence**: {analysis.get('confidence', 'Unknown')}")
                    lines.append("")

                    if analysis.get('changes_summary'):
                        lines.append(f"**Summary**: {analysis['changes_summary']}")
                        lines.append("")

                    if analysis.get('required_changes'):
                        lines.append("**Required Changes**:")
                        for change in analysis['required_changes']:
                            lines.append(f"- {change}")
                        lines.append("")
                lines.append("---")
                lines.append("")

        # Action Items
        lines.append("## Next Steps")
        lines.append("")
        if changed_count > 0:
            lines.append("1. Review changed requirements above")
            lines.append("2. Update implementations if needed")
            lines.append("3. Run `elspais hash update` to update INDEX.md")
        if outdated_count > 0:
            lines.append("4. Verify implementations satisfy requirements")
            lines.append("5. Run `python3 .../mark-verified.py REQ-xxx` to clear outdated status")

        return '\n'.join(lines)

    else:  # text format
        lines = []
        lines.append("=" * 60)
        lines.append("PRE-PR COMPLIANCE CHECK")
        lines.append("=" * 60)
        lines.append("")

        changed_count = changed_reqs.get('summary', {}).get('changed_count', 0)
        outdated_count = len(outdated)

        if changed_count == 0 and outdated_count == 0:
            lines.append("All Clear - No issues detected")
            return '\n'.join(lines)

        if changed_reqs.get('changed_requirements'):
            lines.append(f"Changed Requirements ({changed_count}):")
            for req in changed_reqs['changed_requirements']:
                lines.append(f"  - REQ-{req['req_id']}: {req['title']}")
                lines.append(f"    {req['old_hash']} -> {req['new_hash']}")
            lines.append("")

        if outdated:
            lines.append(f"Outdated Implementations ({outdated_count}):")
            for item in outdated:
                lines.append(f"  - REQ-{item['req_id']}: {item.get('file', 'Unknown')}")
            lines.append("")

        if analyses:
            lines.append("AI Analysis Results:")
            for analysis in analyses:
                status = "PASS" if analysis.get('still_compliant') else "FAIL"
                lines.append(f"  - REQ-{analysis['req_id']}: {status} ({analysis.get('risk_level', '?')} risk)")
            lines.append("")

        return '\n'.join(lines)


def write_github_outputs(report: str, has_issues: bool, summary: Dict[str, Any]):
    """Write outputs for GitHub Actions."""

    # Write to job summary
    summary_path = os.environ.get('GITHUB_STEP_SUMMARY')
    if summary_path:
        with open(summary_path, 'a') as f:
            f.write(report)
            f.write('\n')

    # Write output variables
    output_path = os.environ.get('GITHUB_OUTPUT')
    if output_path:
        with open(output_path, 'a') as f:
            f.write(f"has_issues={'true' if has_issues else 'false'}\n")
            f.write(f"changed_count={summary.get('changed_count', 0)}\n")
            f.write(f"outdated_count={summary.get('outdated_count', 0)}\n")
            # Multiline output for report
            f.write(f"report<<EOF\n{report}\nEOF\n")


def main():
    parser = argparse.ArgumentParser(
        description='Pre-PR compliance check for requirement changes',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    # Local usage
    %(prog)s
    %(prog)s --format markdown
    %(prog)s --strict --with-analysis

    # GitHub Actions
    %(prog)s --github-action

Environment Variables:
    ANTHROPIC_API_KEY    Required for AI compliance analysis
    GITHUB_ACTIONS       Auto-detected when running in GitHub Actions
    GITHUB_STEP_SUMMARY  Path to write job summary (set by GitHub)
    GITHUB_OUTPUT        Path to write output variables (set by GitHub)
        """
    )

    parser.add_argument(
        '--format',
        choices=['text', 'markdown', 'json'],
        default='text',
        help='Output format (default: text, or markdown in GitHub Actions)'
    )

    parser.add_argument(
        '--github-action',
        action='store_true',
        help='Run in GitHub Actions mode (auto-detected if GITHUB_ACTIONS=true)'
    )

    parser.add_argument(
        '--strict',
        action='store_true',
        help='Exit with non-zero code if issues are found'
    )

    parser.add_argument(
        '--with-analysis',
        action='store_true',
        help='Run AI compliance analysis (requires ANTHROPIC_API_KEY)'
    )

    parser.add_argument(
        '--post-comment',
        action='store_true',
        help='Post report as PR comment (GitHub Actions only, requires gh CLI)'
    )

    parser.add_argument(
        '--use-claude-code',
        action='store_true',
        help='Use Claude Code CLI instead of Anthropic API for analysis'
    )

    args = parser.parse_args()

    # Auto-detect GitHub Actions
    in_github_actions = args.github_action or is_github_actions()

    # Default to markdown in GitHub Actions
    format_type = args.format
    if in_github_actions and args.format == 'text':
        format_type = 'markdown'

    try:
        # Gather data
        print("Detecting changed requirements...", file=sys.stderr)
        changed_reqs = detect_changed_requirements()

        print("Checking outdated implementations...", file=sys.stderr)
        outdated = get_outdated_implementations()

        # Run AI analysis if requested and available
        analyses = []
        if args.with_analysis:
            import shutil
            has_api_key = bool(os.environ.get('ANTHROPIC_API_KEY'))
            has_claude_code = shutil.which('claude') is not None
            use_cc = args.use_claude_code

            if has_api_key or has_claude_code or use_cc:
                backend = "Claude Code CLI" if (use_cc or (not has_api_key and has_claude_code)) else "Anthropic API"
                print(f"Running AI compliance analysis via {backend}...", file=sys.stderr)

                # Analyze changed requirements
                for req in changed_reqs.get('changed_requirements', []):
                    print(f"  Analyzing REQ-{req['req_id']}...", file=sys.stderr)
                    analysis = run_compliance_analysis(req['req_id'], use_claude_code=use_cc)
                    if analysis:
                        analyses.append(analysis)

                # Analyze outdated implementations
                for item in outdated:
                    if item['req_id'] not in [a['req_id'] for a in analyses]:
                        print(f"  Analyzing REQ-{item['req_id']}...", file=sys.stderr)
                        analysis = run_compliance_analysis(item['req_id'], use_claude_code=use_cc)
                        if analysis:
                            analyses.append(analysis)
            else:
                print("Skipping AI analysis (no ANTHROPIC_API_KEY and Claude Code CLI not found)", file=sys.stderr)

        # Generate report
        report = generate_report(changed_reqs, outdated, analyses, format_type)

        # Determine if there are issues
        has_issues = bool(
            changed_reqs.get('changed_requirements') or
            outdated or
            any(not a.get('still_compliant', True) for a in analyses)
        )

        summary = {
            'changed_count': changed_reqs.get('summary', {}).get('changed_count', 0),
            'outdated_count': len(outdated),
            'has_issues': has_issues
        }

        # Output
        if in_github_actions:
            write_github_outputs(report, has_issues, summary)

        print(report)

        # Post as PR comment if requested
        if args.post_comment and in_github_actions:
            pr_number = os.environ.get('GITHUB_PR_NUMBER') or os.environ.get('PR_NUMBER')
            if pr_number:
                import subprocess
                subprocess.run(
                    ['gh', 'pr', 'comment', pr_number, '--body', report],
                    check=False
                )

        # Exit code
        if args.strict and has_issues:
            return 1

        return 0

    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        return 1


if __name__ == '__main__':
    sys.exit(main())
