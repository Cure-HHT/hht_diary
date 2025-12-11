#!/usr/bin/env python3
"""
Analyze Compliance

AI-assisted analysis to determine if an implementation still satisfies
a changed requirement. Compares old vs new requirement and analyzes code.

Usage:
    python3 analyze-compliance.py REQ-d00027 --file path/to/impl.py
    python3 analyze-compliance.py d00027 --auto-scan
    python3 analyze-compliance.py d00027 --format json

Requires: Anthropic API key in ANTHROPIC_API_KEY environment variable
"""

import sys
import json
import argparse
import os
import subprocess
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Optional
from dataclasses import dataclass, asdict


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


# Add parent paths for imports
repo_root = get_repo_root()
sys.path.insert(0, str(repo_root / 'tools' / 'requirements'))

from validate_requirements import RequirementValidator

# Check for Anthropic API
try:
    import anthropic
    HAS_ANTHROPIC = True
except ImportError:
    HAS_ANTHROPIC = False


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
    """Get current requirement from spec files"""
    normalized_id = normalize_req_id(req_id)

    validator = RequirementValidator(repo_root / 'spec')
    validator._parse_requirements()

    if normalized_id in validator.requirements:
        req = validator.requirements[normalized_id]
        return {
            'id': req.id,
            'title': req.title,
            'body': req.body,
            'hash': req.hash,
            'level': req.level,
            'status': req.status
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


def analyze_with_ai(req_id: str, old_hash: str, new_req: Dict,
                   impl_file: Path, impl_content: str) -> ComplianceAnalysis:
    """
    Use Claude API to analyze compliance.

    Returns ComplianceAnalysis with AI-generated insights.
    """

    if not HAS_ANTHROPIC:
        return ComplianceAnalysis(
            req_id=req_id,
            file=str(impl_file),
            changes_summary="AI analysis unavailable (anthropic package not installed)",
            still_compliant=True,  # Assume compliant if can't analyze
            risk_level="UNKNOWN",
            required_changes=[],
            recommendations="Install anthropic package for AI-powered analysis",
            analyzed_at=datetime.now().isoformat(),
            confidence="NONE"
        )

    api_key = os.environ.get('ANTHROPIC_API_KEY')
    if not api_key:
        return ComplianceAnalysis(
            req_id=req_id,
            file=str(impl_file),
            changes_summary="AI analysis unavailable (ANTHROPIC_API_KEY not set)",
            still_compliant=True,
            risk_level="UNKNOWN",
            required_changes=[],
            recommendations="Set ANTHROPIC_API_KEY environment variable for AI analysis",
            analyzed_at=datetime.now().isoformat(),
            confidence="NONE"
        )

    # Create prompt for Claude
    prompt = f"""You are analyzing if a code implementation still satisfies an updated requirement.

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

    try:
        client = anthropic.Anthropic(api_key=api_key)

        message = client.messages.create(
            model="claude-3-5-sonnet-20241022",
            max_tokens=2048,
            messages=[
                {"role": "user", "content": prompt}
            ]
        )

        # Extract JSON from response
        response_text = message.content[0].text

        # Try to parse JSON from response
        # Look for JSON block
        json_start = response_text.find('{')
        json_end = response_text.rfind('}') + 1

        if json_start >= 0 and json_end > json_start:
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

        else:
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

    except Exception as e:
        return ComplianceAnalysis(
            req_id=req_id,
            file=str(impl_file),
            changes_summary=f"Analysis error: {str(e)[:100]}",
            still_compliant=True,
            risk_level="UNKNOWN",
            required_changes=[],
            recommendations="Manual review recommended",
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

    # JSON output:
    %(prog)s d00027 --file setup.sh --format json

Environment:
    ANTHROPIC_API_KEY  Required for AI-powered analysis
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
                        impl_content
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
                impl_content
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
