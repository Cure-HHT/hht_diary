#!/usr/bin/env python3
"""
Requirement validation script for pre-commit hooks.

Runs validation checks including:
1. elspais validate - core requirement format validation
2. Duplicate REQ detection - ensures no REQ ID is defined in multiple files

Exit codes:
  0 - All validations passed
  1 - Validation failed
"""

import subprocess
import sys
from pathlib import Path


def run_elspais_validate() -> bool:
    """Run elspais validate and return True if successful."""
    try:
        result = subprocess.run(
            ['elspais', 'validate'],
            capture_output=True,
            text=True
        )
        # elspais validate outputs to stdout, errors to stderr
        if result.returncode != 0:
            print("❌ elspais validate failed:")
            if result.stderr:
                print(result.stderr)
            if result.stdout:
                print(result.stdout)
            return False

        # Print success output (shows requirement count)
        for line in result.stdout.split('\n'):
            if line.strip() and not line.strip().startswith('{'):
                print(f"   {line}")
        return True
    except FileNotFoundError:
        print("⚠️  elspais not found - skipping format validation")
        print("   Install with: pip install elspais")
        return True  # Don't fail if elspais not installed


def run_duplicate_check() -> bool:
    """Check for duplicate REQ definitions across files."""
    # Find repo root
    repo_root = Path(__file__).parent.parent.parent
    spec_dir = repo_root / 'spec'

    if not spec_dir.exists():
        print("⚠️  spec/ directory not found - skipping duplicate check")
        return True

    try:
        from trace_view.validation import find_duplicate_req_definitions
    except ImportError:
        # Try adding the requirements dir to path
        sys.path.insert(0, str(Path(__file__).parent))
        try:
            from trace_view.validation import find_duplicate_req_definitions
        except ImportError:
            print("⚠️  trace_view.validation not available - skipping duplicate check")
            return True

    duplicates = find_duplicate_req_definitions(spec_dir)

    if duplicates:
        print(f"❌ Found {len(duplicates)} duplicate REQ definition(s):")
        for dup in duplicates:
            files = ', '.join(f"{path}:{line}" for path, line in dup.locations)
            print(f"   REQ-{dup.req_id}: {files}")
        print()
        print("Each REQ ID must be defined in exactly one file.")
        return False

    print("   ✅ No duplicate REQ definitions")
    return True


def main() -> int:
    """Run all validations and return exit code."""
    print("Validating requirements...")
    print()

    all_passed = True

    # Run elspais validate
    print("📋 Running elspais validate...")
    if not run_elspais_validate():
        all_passed = False

    print()

    # Run duplicate check
    print("🔍 Checking for duplicate REQ definitions...")
    if not run_duplicate_check():
        all_passed = False

    print()

    if all_passed:
        print("✅ All requirement validations passed")
        return 0
    else:
        print("❌ Requirement validation failed")
        return 1


if __name__ == '__main__':
    sys.exit(main())
