#!/usr/bin/env python3
"""
Scan Implementations

Finds all code files that implement a specific requirement by searching for:
1. Explicit declarations: # Implements: REQ-d00027
2. File headers (first 50 lines)
3. Git commit messages

Usage:
    python3 scan-implementations.py REQ-d00027
    python3 scan-implementations.py d00027 --format json
    python3 scan-implementations.py d00027 --include-commits
"""

import sys
import json
import argparse
import re
import subprocess
from pathlib import Path
from datetime import datetime
from typing import List, Dict, Optional
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


# Repo root
repo_root = get_repo_root()

# File patterns to search
SEARCH_PATTERNS = [
    '**/*.py',
    '**/*.js',
    '**/*.ts',
    '**/*.jsx',
    '**/*.tsx',
    '**/*.sh',
    '**/*.bash',
    '**/*.md',
    '**/*.yaml',
    '**/*.yml',
    '**/Dockerfile',
    '**/Makefile',
]

# Directories to exclude
EXCLUDE_DIRS = {
    '.git',
    'node_modules',
    '__pycache__',
    '.venv',
    'venv',
    'build',
    'dist',
    '.pytest_cache',
}


@dataclass
class Implementation:
    """Represents a found implementation"""
    file: str
    line: int
    type: str  # File extension or 'dockerfile', 'makefile'
    declaration: str
    context: str  # Surrounding lines for context
    last_modified: Optional[str] = None


@dataclass
class Commit:
    """Represents a commit mentioning the requirement"""
    sha: str
    message: str
    author: str
    date: str
    files_changed: List[str]


def normalize_req_id(req_id: str) -> str:
    """Normalize requirement ID (remove REQ- prefix if present)"""
    if req_id.upper().startswith('REQ-'):
        req_id = req_id[4:]
    return req_id.lower()


def get_file_type(file_path: Path) -> str:
    """Determine file type from path"""
    name = file_path.name.lower()

    if name == 'dockerfile' or name.startswith('dockerfile.'):
        return 'dockerfile'
    if name == 'makefile' or name.startswith('makefile.'):
        return 'makefile'

    suffix = file_path.suffix.lstrip('.')
    return suffix if suffix else 'unknown'


def get_file_last_modified(file_path: Path) -> Optional[str]:
    """Get last modified date from git"""
    try:
        result = subprocess.run(
            ['git', 'log', '-1', '--format=%aI', '--', str(file_path)],
            cwd=repo_root,
            capture_output=True,
            text=True,
            timeout=5
        )
        if result.returncode == 0 and result.stdout.strip():
            return result.stdout.strip()
    except Exception:
        pass
    return None


def get_context_lines(lines: List[str], line_num: int, context: int = 2) -> str:
    """Get surrounding lines for context"""
    start = max(0, line_num - context)
    end = min(len(lines), line_num + context + 1)

    context_lines = []
    for i in range(start, end):
        prefix = '> ' if i == line_num else '  '
        context_lines.append(f"{prefix}{i+1:4d}: {lines[i].rstrip()}")

    return '\n'.join(context_lines)


def search_file_for_requirement(file_path: Path, req_id: str) -> List[Implementation]:
    """Search a single file for requirement references"""
    implementations = []

    # Patterns to match
    # Case-insensitive match for: Implements: REQ-d00027 or # Implements REQ-d00027
    pattern = re.compile(
        rf'(?:implements?|requirements?)[:\s]+REQ-{req_id}\b',
        re.IGNORECASE
    )

    try:
        content = file_path.read_text(encoding='utf-8', errors='ignore')
        lines = content.split('\n')

        # Search first 50 lines (file headers)
        search_limit = min(50, len(lines))

        for i in range(search_limit):
            line = lines[i]
            if pattern.search(line):
                implementations.append(Implementation(
                    file=str(file_path.relative_to(repo_root)),
                    line=i + 1,
                    type=get_file_type(file_path),
                    declaration=line.strip(),
                    context=get_context_lines(lines, i),
                    last_modified=get_file_last_modified(file_path)
                ))

        # Also search full file if not too large (< 10k lines)
        if len(lines) <= 10000:
            for i in range(search_limit, len(lines)):
                line = lines[i]
                if pattern.search(line):
                    implementations.append(Implementation(
                        file=str(file_path.relative_to(repo_root)),
                        line=i + 1,
                        type=get_file_type(file_path),
                        declaration=line.strip(),
                        context=get_context_lines(lines, i),
                        last_modified=get_file_last_modified(file_path)
                    ))

    except Exception as e:
        # Skip files that can't be read
        pass

    return implementations


def scan_implementations(req_id: str) -> List[Implementation]:
    """Scan repository for all implementations of a requirement"""
    normalized_id = normalize_req_id(req_id)
    implementations = []

    for pattern in SEARCH_PATTERNS:
        for file_path in repo_root.glob(pattern):
            # Skip excluded directories
            if any(excl in file_path.parts for excl in EXCLUDE_DIRS):
                continue

            # Skip if not a file
            if not file_path.is_file():
                continue

            found = search_file_for_requirement(file_path, normalized_id)
            implementations.extend(found)

    return implementations


def search_commits(req_id: str, max_results: int = 50) -> List[Commit]:
    """Search git history for commits mentioning the requirement"""
    normalized_id = normalize_req_id(req_id)
    commits = []

    # Search pattern
    search_pattern = f'REQ-{normalized_id}'

    try:
        # Get commits mentioning requirement
        result = subprocess.run(
            [
                'git', 'log',
                '--all',
                '--grep', search_pattern,
                '--format=%H|%s|%an|%aI',
                f'-{max_results}'
            ],
            cwd=repo_root,
            capture_output=True,
            text=True,
            timeout=10
        )

        if result.returncode != 0:
            return commits

        for line in result.stdout.strip().split('\n'):
            if not line:
                continue

            parts = line.split('|', 3)
            if len(parts) != 4:
                continue

            sha, message, author, date = parts

            # Get files changed in this commit
            files_result = subprocess.run(
                ['git', 'diff-tree', '--no-commit-id', '--name-only', '-r', sha],
                cwd=repo_root,
                capture_output=True,
                text=True,
                timeout=5
            )

            files_changed = []
            if files_result.returncode == 0:
                files_changed = [f.strip() for f in files_result.stdout.strip().split('\n') if f.strip()]

            commits.append(Commit(
                sha=sha[:8],
                message=message,
                author=author,
                date=date,
                files_changed=files_changed
            ))

    except Exception as e:
        # Return what we have so far
        pass

    return commits


def format_output(req_id: str, implementations: List[Implementation],
                 commits: List[Commit], format_type: str) -> str:
    """Format output as JSON or text"""

    if format_type == 'json':
        data = {
            'req_id': normalize_req_id(req_id),
            'full_id': f'REQ-{normalize_req_id(req_id)}',
            'scanned_at': datetime.now().isoformat(),
            'implementations': [asdict(impl) for impl in implementations],
            'commits': [asdict(commit) for commit in commits],
            'summary': {
                'implementation_count': len(implementations),
                'commit_count': len(commits)
            }
        }
        return json.dumps(data, indent=2)

    else:  # text format
        lines = []
        lines.append(f"🔍 Implementation Scan: REQ-{normalize_req_id(req_id)}")
        lines.append("=" * 70)
        lines.append("")

        if not implementations and not commits:
            lines.append("❌ No implementations found")
            lines.append("")
            lines.append("This requirement may not be implemented yet, or implementations")
            lines.append("may not have proper REQ references in their code/commits.")
            return '\n'.join(lines)

        # Implementations section
        if implementations:
            lines.append(f"📝 Found {len(implementations)} Implementation(s):")
            lines.append("")

            for i, impl in enumerate(implementations, 1):
                lines.append(f"  [{i}] {impl.file}:{impl.line}")
                lines.append(f"      Type: {impl.type}")
                lines.append(f"      Declaration: {impl.declaration}")
                if impl.last_modified:
                    lines.append(f"      Last Modified: {impl.last_modified}")
                lines.append("")

        # Commits section
        if commits:
            lines.append(f"📋 Found {len(commits)} Commit(s):")
            lines.append("")

            for i, commit in enumerate(commits, 1):
                lines.append(f"  [{i}] {commit.sha} - {commit.author}")
                lines.append(f"      Date: {commit.date}")
                lines.append(f"      Message: {commit.message}")
                if commit.files_changed:
                    lines.append(f"      Files: {', '.join(commit.files_changed[:3])}")
                    if len(commit.files_changed) > 3:
                        lines.append(f"             ... and {len(commit.files_changed) - 3} more")
                lines.append("")

        return '\n'.join(lines)


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(
        description='Scan codebase for implementations of a requirement',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    %(prog)s REQ-d00027
    %(prog)s d00027 --format json
    %(prog)s d00027 --include-commits
    %(prog)s d00027 --format json --include-commits
        """
    )

    parser.add_argument(
        'req_id',
        help='Requirement ID (e.g., REQ-d00027 or d00027)'
    )

    parser.add_argument(
        '--format',
        choices=['text', 'json'],
        default='text',
        help='Output format (default: text)'
    )

    parser.add_argument(
        '--include-commits',
        action='store_true',
        help='Include git commit history search'
    )

    args = parser.parse_args()

    try:
        # Scan for implementations
        implementations = scan_implementations(args.req_id)

        # Search commits if requested
        commits = []
        if args.include_commits:
            commits = search_commits(args.req_id)

        # Format and output
        output = format_output(args.req_id, implementations, commits, args.format)
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
