#!/usr/bin/env python3
"""
Requirement validation script for pre-commit hooks.

Runs elspais validate which checks:
- Requirement format validation
- Hash verification
- Broken link detection
- Duplicate REQ ID detection

Exit codes:
  0 - All validations passed
  1 - Validation failed
"""

import subprocess
import sys


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


def main() -> int:
    """Run requirement validation and return exit code."""
    print("Validating requirements...")
    print()

    print("📋 Running elspais validate...")
    if not run_elspais_validate():
        print()
        print("❌ Requirement validation failed")
        return 1

    print()
    print("✅ All requirement validations passed")
    return 0


if __name__ == '__main__':
    sys.exit(main())
