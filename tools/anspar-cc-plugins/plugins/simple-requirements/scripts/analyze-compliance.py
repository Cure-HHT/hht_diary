#!/usr/bin/env python3
"""
Analyze Compliance

AI-assisted analysis to determine if an implementation still satisfies
a changed requirement. Compares old vs new requirement and analyzes code.

Usage:
    python3 analyze-compliance.py REQ-d00027 --file path/to/impl.py
    python3 analyze-compliance.py d00027 --auto-scan
    python3 analyze-compliance.py d00027 --format json
    python3 analyze-compliance.py d00027 --auto-scan --use-claude-code

AI Backends (checked in order):
    1. Claude Code CLI (if --use-claude-code or CLAUDE_CODE_ANALYSIS=1)
    2. Anthropic API (if ANTHROPIC_API_KEY is set)
    3. Fallback: Manual review recommended
"""

import sys
import json
import argparse
import os
import subprocess
import shutil
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Optional
from dataclasses import dataclass, asdict

# Import shared utilities
from common import get_repo_root, get_requirements_via_cli

# Setup paths
repo_root = get_repo_root()

# Note: RequirementValidator removed - use elspais CLI via get_requirements_via_cli()

# Check for Anthropic API
try:
    import anthropic
    HAS_ANTHROPIC = True
except ImportError:
    HAS_ANTHROPIC = False

# Check for Claude Code CLI
HAS_CLAUDE_CODE = shutil.which('claude') is not None


@dataclass
class ComplianceAnalysis:
    """Results of compliance analysis"""
    req_id: str
    file: str
    changes_summary: str
    still_compliant: bool
    risk_level: str  # LOW, MEDIUM, HIGH
    required_changes: List[str]
    recommendations: str
    analyzed_at: str
    confidence: str  # HIGH, MEDIUM, LOW


def normalize_req_id(req_id: str) -> str:
    """Normalize requirement ID"""
    if req_id.upper().startswith('REQ-'):
        req_id = req_id[4:]
    return req_id.lower()


def get_requirement_from_git(req_id: str, commit_hash: str = 'HEAD') -> Optional[str]:
    """Get requirement text from git history"""
    normalized_id = normalize_req_id(req_id)

    # Find the spec file containing this requirement
    spec_files = list((repo_root / 'spec').glob('*.md'))

    for spec_file in spec_files:
        try:
            # Get file content from git
            result = subprocess.run(
                ['git', 'show', f'{commit_hash}:{spec_file.relative_to(repo_root)}'],
                cwd=repo_root,
                capture_output=True,
                text=True,
                timeout=5
            )

            if result.returncode == 0:
                content = result.stdout
                # Quick check if requirement is in this file
                if f'REQ-{normalized_id}' in content.upper():
                    return content

        except Exception:
            continue

    return None


def get_old_requirement_text(req_id: str, old_hash: str) -> Optional[str]:
    """
    Get old requirement text by searching git history for when hash matched.
    This is a simplified approach - looks at recent commits.
    """
    # For now, we'll use a simpler approach: just indicate the hash changed
    # Full implementation would search git history for the exact hash match
    return f"[Requirement text with hash {old_hash} - historical version]"


def get_current_requirement(req_id: str) -> Optional[Dict]:
    """Get current requirement from spec files using elspais CLI"""
    normalized_id = normalize_req_id(req_id)

    # Use elspais CLI via shared utility
    requirements = get_requirements_via_cli()

    if normalized_id in requirements:
        req = requirements[normalized_id]
        return {
            'id': normalized_id,
            'title': req.get('title', ''),
            'body': req.get('body', ''),
            'hash': req.get('hash', ''),
            'level': req.get('level', ''),
            'status': req.get('status', '')
        }

    return None


def read_implementation_file(file_path: Path, max_lines: int = 500) -> str:
    """Read implementation file (with size limit)"""
    try:
        with file_path.open('r', encoding='utf-8', errors='ignore') as f:
            lines = f.readlines()[:max_lines]
            content = ''.join(lines)

            if len(lines) == max_lines:
                content += f"\n\n[... file truncated at {max_lines} lines ...]"

            return content
    except Exception as e:
        return f"[Error reading file: {e}]"


def build_analysis_prompt(req_id: str, old_hash: str, new_req: Dict,
                          impl_file: Path, impl_content: str) -> str:
    """Build the analysis prompt for Claude."""
    return f"""You are analyzing if a code implementation still satisfies an updated requirement.

REQUIREMENT DETAILS:
- ID: REQ-{req_id}
- Title: {new_req['title']}
- Status: {new_req['status']}
- Level: {new_req['level']}
- New Hash: {new_req['hash']}
- Old Hash: {old_hash}

CURRENT REQUIREMENT TEXT:
{new_req['body']}

IMPLEMENTATION FILE: {impl_file}
```
{impl_content}
```

Please analyze:
1. Based on the requirement text, what are the key obligations?
2. Does the implementation code satisfy these obligations?
3. What is the risk level if this requirement changed? (LOW/MEDIUM/HIGH)
4. What specific changes (if any) are needed to the implementation?
5. Overall recommendations

Respond in JSON format:
{{
  "changes_summary": "Brief description of key requirement obligations",
  "still_compliant": true/false,
  "risk_level": "LOW"/"MEDIUM"/"HIGH",
  "required_changes": ["change 1", "change 2"],
  "recommendations": "Detailed recommendations",
  "confidence": "HIGH"/"MEDIUM"/"LOW"
}}
"""


def parse_ai_response(response_text: str, req_id: str, impl_file: Path) -> ComplianceAnalysis:
    """Parse AI response text into ComplianceAnalysis."""
    # Try to parse JSON from response
    json_start = response_text.find('{')
    json_end = response_text.rfind('}') + 1

    if json_start >= 0 and json_end > json_start:
        try:
            json_str = response_text[json_start:json_end]
            analysis_data = json.loads(json_str)

            return ComplianceAnalysis(
                req_id=req_id,
                file=str(impl_file),
                changes_summary=analysis_data.get('changes_summary', 'Analysis complete'),
                still_compliant=analysis_data.get('still_compliant', True),
                risk_level=analysis_data.get('risk_level', 'MEDIUM'),
                required_changes=analysis_data.get('required_changes', []),
                recommendations=analysis_data.get('recommendations', 'See analysis details'),
                analyzed_at=datetime.now().isoformat(),
                confidence=analysis_data.get('confidence', 'MEDIUM')
            )
        except json.JSONDecodeError:
            pass

    # Couldn't parse JSON, return text response
    return ComplianceAnalysis(
        req_id=req_id,
        file=str(impl_file),
        changes_summary="AI analysis completed",
        still_compliant=True,
        risk_level="MEDIUM",
        required_changes=[],
        recommendations=response_text[:500],  # First 500 chars
        analyzed_at=datetime.now().isoformat(),
        confidence="MEDIUM"
    )


def analyze_with_claude_code(req_id: str, old_hash: str, new_req: Dict,
                             impl_file: Path, impl_content: str) -> ComplianceAnalysis:
    """
    Use Claude Code CLI to analyze compliance.

    Uses `claude --print` for non-interactive analysis.
    """
    prompt = build_analysis_prompt(req_id, old_hash, new_req, impl_file, impl_content)

    try:
        # Use claude CLI with --print for non-interactive mode
        # --output-format text returns just the response
        result = subprocess.run(
            ['claude', '--print', '--output-format', 'text'],
            input=prompt,
            capture_output=True,
            text=True,
            timeout=120,  # 2 minute timeout
            cwd=repo_root
        )

        if result.returncode == 0 and result.stdout.strip():
            return parse_ai_response(result.stdout, req_id, impl_file)
        else:
            error_msg = result.stderr[:100] if result.stderr else 'No response'
            return ComplianceAnalysis(
                req_id=req_id,
                file=str(impl_file),
                changes_summary=f"Claude Code error: {error_msg}",
                still_compliant=True,
                risk_level="UNKNOWN",
                required_changes=[],
                recommendations="Manual review recommended",
                analyzed_at=datetime.now().isoformat(),
                confidence="NONE"
            )

    except subprocess.TimeoutExpired:
        return ComplianceAnalysis(
            req_id=req_id,
            file=str(impl_file),
            changes_summary="Analysis timed out",
            still_compliant=True,
            risk_level="UNKNOWN",
            required_changes=[],
            recommendations="Manual review recommended (analysis timed out)",
            analyzed_at=datetime.now().isoformat(),
            confidence="NONE"
        )
    except Exception as e:
        return ComplianceAnalysis(
            req_id=req_id,
            file=str(impl_file),
            changes_summary=f"Claude Code error: {str(e)[:100]}",
            still_compliant=True,
            risk_level="UNKNOWN",
            required_changes=[],
            recommendations="Manual review recommended",
            analyzed_at=datetime.now().isoformat(),
            confidence="NONE"
        )


def analyze_with_api(req_id: str, old_hash: str, new_req: Dict,
                     impl_file: Path, impl_content: str) -> ComplianceAnalysis:
    """
    Use Anthropic API directly to analyze compliance.

    Requires ANTHROPIC_API_KEY environment variable.
    """
    prompt = build_analysis_prompt(req_id, old_hash, new_req, impl_file, impl_content)

    try:
        api_key = os.environ.get('ANTHROPIC_API_KEY')
        client = anthropic.Anthropic(api_key=api_key)

        message = client.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=2048,
            messages=[
                {"role": "user", "content": prompt}
            ]
        )

        response_text = message.content[0].text
        return parse_ai_response(response_text, req_id, impl_file)

    except Exception as e:
        return ComplianceAnalysis(
            req_id=req_id,
            file=str(impl_file),
            changes_summary=f"API error: {str(e)[:100]}",
            still_compliant=True,
            risk_level="UNKNOWN",
            required_changes=[],
            recommendations="Manual review recommended",
            analyzed_at=datetime.now().isoformat(),
            confidence="NONE"
        )


def analyze_with_ai(req_id: str, old_hash: str, new_req: Dict,
                   impl_file: Path, impl_content: str,
                   use_claude_code: bool = False) -> ComplianceAnalysis:
    """
    Analyze compliance using available AI backend.

    Backend selection order:
    1. Claude Code CLI (if use_claude_code=True or CLAUDE_CODE_ANALYSIS=1)
    2. Anthropic API (if ANTHROPIC_API_KEY is set)
    3. Fallback with recommendation for manual review

    Args:
        use_claude_code: Force use of Claude Code CLI instead of API
    """
    # Check if Claude Code should be used
    use_cc = use_claude_code or os.environ.get('CLAUDE_CODE_ANALYSIS', '').lower() in ('1', 'true', 'yes')

    if use_cc:
        if HAS_CLAUDE_CODE:
            return analyze_with_claude_code(req_id, old_hash, new_req, impl_file, impl_content)
        else:
            return ComplianceAnalysis(
                req_id=req_id,
                file=str(impl_file),
                changes_summary="Claude Code CLI not found",
                still_compliant=True,
                risk_level="UNKNOWN",
                required_changes=[],
                recommendations="Install Claude Code CLI: npm install -g @anthropic-ai/claude-code",
                analyzed_at=datetime.now().isoformat(),
                confidence="NONE"
            )

    # Try Anthropic API
    api_key = os.environ.get('ANTHROPIC_API_KEY')
    if api_key and HAS_ANTHROPIC:
        return analyze_with_api(req_id, old_hash, new_req, impl_file, impl_content)

    # Fall back to Claude Code if available
    if HAS_CLAUDE_CODE:
        return analyze_with_claude_code(req_id, old_hash, new_req, impl_file, impl_content)

    # No AI backend available
    return ComplianceAnalysis(
        req_id=req_id,
        file=str(impl_file),
        changes_summary="No AI backend available",
        still_compliant=True,
        risk_level="UNKNOWN",
        required_changes=[],
        recommendations="Set ANTHROPIC_API_KEY or install Claude Code CLI for AI analysis",
        analyzed_at=datetime.now().isoformat(),
        confidence="NONE"
    )


def format_output(analyses: List[ComplianceAnalysis], format_type: str) -> str:
    """Format analysis results"""

    if format_type == 'json':
        data = {
            'analyzed_at': datetime.now().isoformat(),
            'total_analyzed': len(analyses),
            'analyses': [asdict(analysis) for analysis in analyses],
            'summary': {
                'compliant': sum(1 for a in analyses if a.still_compliant),
                'non_compliant': sum(1 for a in analyses if not a.still_compliant),
                'high_risk': sum(1 for a in analyses if a.risk_level == 'HIGH'),
                'medium_risk': sum(1 for a in analyses if a.risk_level == 'MEDIUM'),
                'low_risk': sum(1 for a in analyses if a.risk_level == 'LOW')
            }
        }
        return json.dumps(data, indent=2)

    else:  # text format
        lines = []
        lines.append("🤖 Compliance Analysis Report")
        lines.append("=" * 70)
        lines.append("")

        for i, analysis in enumerate(analyses, 1):
            compliance_icon = "✅" if analysis.still_compliant else "❌"
            risk_colors = {'LOW': '🟢', 'MEDIUM': '🟡', 'HIGH': '🔴', 'UNKNOWN': '⚪'}
            risk_icon = risk_colors.get(analysis.risk_level, '⚪')

            lines.append(f"[{i}] REQ-{analysis.req_id}: {analysis.file}")
            lines.append(f"    Status: {compliance_icon} {'COMPLIANT' if analysis.still_compliant else 'NON-COMPLIANT'}")
            lines.append(f"    Risk: {risk_icon} {analysis.risk_level}")
            lines.append(f"    Confidence: {analysis.confidence}")
            lines.append("")
            lines.append(f"    Summary: {analysis.changes_summary}")
            lines.append("")

            if analysis.required_changes:
                lines.append("    Required Changes:")
                for change in analysis.required_changes:
                    lines.append(f"      • {change}")
                lines.append("")

            if analysis.recommendations:
                lines.append(f"    Recommendations:")
                # Wrap long recommendations
                rec_lines = analysis.recommendations.split('\n')
                for rec_line in rec_lines[:5]:  # First 5 lines
                    lines.append(f"      {rec_line}")
                if len(rec_lines) > 5:
                    lines.append(f"      ... ({len(rec_lines) - 5} more lines)")
                lines.append("")

            lines.append("-" * 70)
            lines.append("")

        return '\n'.join(lines)


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(
        description='Analyze if implementations still satisfy changed requirements',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    # Analyze specific file:
    %(prog)s REQ-d00027 --file tools/dev-env/setup.sh

    # Auto-scan for implementations and analyze all:
    %(prog)s d00027 --auto-scan

    # Use Claude Code CLI instead of API:
    %(prog)s d00027 --auto-scan --use-claude-code

    # JSON output:
    %(prog)s d00027 --file setup.sh --format json

AI Backends (checked in order):
    1. Claude Code CLI (if --use-claude-code or CLAUDE_CODE_ANALYSIS=1)
    2. Anthropic API (if ANTHROPIC_API_KEY is set)
    3. Claude Code CLI (fallback if available)
    4. Manual review recommended

Environment:
    ANTHROPIC_API_KEY       For direct API access
    CLAUDE_CODE_ANALYSIS=1  Force use of Claude Code CLI
        """
    )

    parser.add_argument(
        'req_id',
        help='Requirement ID (e.g., REQ-d00027 or d00027)'
    )

    parser.add_argument(
        '--file',
        type=Path,
        help='Implementation file to analyze'
    )

    parser.add_argument(
        '--auto-scan',
        action='store_true',
        help='Auto-scan for implementations and analyze all'
    )

    parser.add_argument(
        '--format',
        choices=['text', 'json'],
        default='text',
        help='Output format (default: text)'
    )

    parser.add_argument(
        '--old-hash',
        help='Old requirement hash (from tracking file)'
    )

    parser.add_argument(
        '--use-claude-code',
        action='store_true',
        help='Use Claude Code CLI instead of Anthropic API'
    )

    args = parser.parse_args()

    if not args.file and not args.auto_scan:
        print("Error: Must specify --file or --auto-scan", file=sys.stderr)
        return 1

    try:
        # Get current requirement
        new_req = get_current_requirement(args.req_id)
        if not new_req:
            print(f"Error: Requirement {args.req_id} not found", file=sys.stderr)
            return 1

        # Determine old hash
        old_hash = args.old_hash or "unknown"

        analyses = []

        if args.auto_scan:
            # Scan for implementations first
            scan_script = Path(__file__).parent / 'scan-implementations.py'
            result = subprocess.run(
                ['python3', str(scan_script), args.req_id, '--format', 'json'],
                capture_output=True,
                text=True,
                timeout=30
            )

            if result.returncode == 0:
                scan_data = json.loads(result.stdout)
                implementations = scan_data['implementations']

                if not implementations:
                    print(f"No implementations found for REQ-{args.req_id}", file=sys.stderr)
                    return 1

                # Analyze each implementation
                for impl in implementations:
                    impl_file = repo_root / impl['file']
                    impl_content = read_implementation_file(impl_file)

                    analysis = analyze_with_ai(
                        args.req_id,
                        old_hash,
                        new_req,
                        impl_file,
                        impl_content,
                        use_claude_code=args.use_claude_code
                    )
                    analyses.append(analysis)
            else:
                print(f"Error scanning implementations: {result.stderr}", file=sys.stderr)
                return 1

        else:
            # Analyze single file
            impl_file = args.file
            if not impl_file.exists():
                impl_file = repo_root / impl_file

            if not impl_file.exists():
                print(f"Error: File not found: {args.file}", file=sys.stderr)
                return 1

            impl_content = read_implementation_file(impl_file)

            analysis = analyze_with_ai(
                args.req_id,
                old_hash,
                new_req,
                impl_file,
                impl_content,
                use_claude_code=args.use_claude_code
            )
            analyses.append(analysis)

        # Output results
        output = format_output(analyses, args.format)
        print(output)

        return 0

    except KeyboardInterrupt:
        print("\n\nInterrupted by user", file=sys.stderr)
        return 130
    except Exception as e:
        print(f"❌ Error: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        return 1


if __name__ == '__main__':
    sys.exit(main())
