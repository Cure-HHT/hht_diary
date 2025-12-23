#!/usr/bin/env python3
"""
REQ-d00002: Requirements validation tool (New Format)

Validates requirement format with hash at end:
- Unique requirement IDs
- Proper format compliance (status line, end marker)
- Valid "Implements" links
- Hash validation
- No high-level headings in body
- Whitespace-only between title and status
"""

import argparse
import re
import sys
from pathlib import Path
from typing import Dict, List, Set
from requirement_hash import calculate_requirement_hash
from requirement_parser import Requirement, RequirementParser


class RequirementValidator:
    """Validates requirements across all spec files"""

    VALID_STATUSES = {'Active', 'Draft', 'Deprecated'}
    VALID_LEVELS = {'PRD', 'Ops', 'Dev'}

    def __init__(self, spec_dir: Path, core_spec_dir: Path = None):
        self.spec_dir = spec_dir
        self.repo_root = spec_dir.parent
        self.core_spec_dir = core_spec_dir  # For sponsor repos referencing core requirements
        self.requirements: Dict[str, Requirement] = {}
        self.core_requirements: Dict[str, Requirement] = {}  # Requirements from core repo
        self.errors: List[str] = []
        self.warnings: List[str] = []
        self.info: List[str] = []
        self.implemented_in_code: Set[str] = set()

    def validate_all(self) -> bool:
        """Run all validation checks. Returns True if valid."""
        print(f"🔍 Scanning {self.spec_dir} for requirements...\n")

        self._parse_requirements()

        # Parse core requirements if a core repo was specified
        if self.core_spec_dir:
            self._parse_core_requirements()

        if not self.requirements:
            print("⚠️  No requirements found")
            return True

        print(f"📋 Found {len(self.requirements)} requirements\n")

        # Scan implementation files
        print(f"🔎 Scanning implementation files for requirement references...\n")
        self._scan_implementation_files()
        if self.implemented_in_code:
            print(f"📝 Found {len(self.implemented_in_code)} requirements referenced in code\n")

        # Run validation checks
        self._check_unique_ids()
        self._check_id_format()
        self._check_implements_links()
        self._check_orphaned_requirements()
        self._check_level_consistency()
        self._check_hash_validity()
        self._check_body_headings_all()

        # Print results
        self._print_results()

        return len(self.errors) == 0

    def _parse_requirements(self):
        """Parse all requirements from spec files using shared parser"""
        parser = RequirementParser(self.spec_dir)
        result = parser.parse_all()

        self.requirements = result.requirements

        # Convert parse errors to validation errors
        for error in result.errors:
            self.errors.append(str(error))

    def _parse_core_requirements(self):
        """Parse requirements from core repo (for sponsor repo validation)"""
        print(f"🔍 Also scanning core repo: {self.core_spec_dir}\n")
        parser = RequirementParser(self.core_spec_dir)
        result = parser.parse_all()

        self.core_requirements = result.requirements
        print(f"📋 Found {len(self.core_requirements)} core requirements\n")
        # Note: We don't add core parse errors - those should be caught when validating the core repo

    def _check_body_headings_all(self):
        """Check for headings at same or higher level in all requirement bodies"""
        for req_id, req in self.requirements.items():
            self._check_body_headings(req)

    def _check_body_headings(self, req: Requirement):
        """Check for headings at same or higher level in requirement body

        Requirement bodies should only contain headings at a LOWER level than
        the requirement heading itself. For example, if requirement is level 1 (#),
        body can use ##, ###, etc., but not #.
        """
        for line in req.body.split('\n'):
            match = re.match(r'^(#{1,6})\s+', line)
            if match:
                heading_level = len(match.group(1))
                if heading_level <= req.heading_level:
                    self.errors.append(
                        f"{req.file_path.name}:{req.line_number} - REQ-{req.id}: "
                        f"Invalid heading level in body: {line.strip()[:50]}..."
                    )

    def _check_unique_ids(self):
        """Check that all requirement IDs are unique"""
        seen_ids: Dict[str, Path] = {}

        for req_id, req in self.requirements.items():
            if req_id in seen_ids:
                self.errors.append(
                    f"Duplicate requirement ID: {req_id} "
                    f"in {req.file_path.name} and {seen_ids[req_id].name}"
                )
            else:
                seen_ids[req_id] = req.file_path

    def _check_id_format(self):
        """Check that requirement IDs follow the correct format

        Supports both core IDs (d00001) and sponsor-specific IDs (CAL-d00001)
        """
        # Match optional sponsor prefix + standard ID format
        id_pattern = re.compile(r'^(?:[A-Z]{2,4}-)?[pod]\d{5}$')

        for req_id, req in self.requirements.items():
            if not id_pattern.match(req_id):
                self.errors.append(
                    f"{req.file_path.name}:{req.line_number} - "
                    f"Invalid ID format: {req_id} (expected: [pod]NNNNN or [SPONSOR]-[pod]NNNNN)"
                )

            # Check level prefix matches stated level
            level_map = {'p': 'PRD', 'o': 'Ops', 'd': 'Dev'}
            expected_level = level_map.get(req.level_prefix)
            if expected_level != req.level:
                self.errors.append(
                    f"{req.file_path.name}:{req.line_number} - "
                    f"REQ-{req_id}: Level mismatch - ID prefix '{req.level_prefix}' "
                    f"doesn't match stated level '{req.level}'"
                )

    def _check_implements_links(self):
        """Check that all 'Implements' references exist"""
        # Combine local and core requirements for link checking
        all_known_requirements = set(self.requirements.keys())
        all_known_requirements.update(self.core_requirements.keys())

        for req_id, req in self.requirements.items():
            for parent_id in req.implements:
                if parent_id not in all_known_requirements:
                    self.errors.append(
                        f"{req.file_path.name}:{req.line_number} - "
                        f"REQ-{req_id}: References non-existent requirement '{parent_id}'"
                    )

    def _scan_implementation_files(self):
        """Scan implementation files for 'IMPLEMENTS REQUIREMENTS:' declarations"""
        impl_pattern = re.compile(r'IMPLEMENTS\s+REQUIREMENTS?:\s*\n?(.*?)(?=\n\s*\n|\Z)', re.IGNORECASE | re.DOTALL)
        # Match both core (d00001) and sponsor-specific (CAL-d00001) REQ IDs
        req_pattern = re.compile(r'REQ-(?:([A-Z]{2,4})-)?([pod]\d{5})', re.IGNORECASE)

        patterns = [
            '.github/workflows/**/*.yml',
            '.github/workflows/**/*.yaml',
            'database/**/*.sql',
            'tools/**/*.sh',
            'tools/**/*.py',
            'tools/**/*.js',
            'tools/**/*.ts',
            'tools/dev-env/docker/**/*Dockerfile*',
        ]

        for pattern in patterns:
            for file_path in self.repo_root.glob(pattern):
                if file_path.is_file():
                    try:
                        content = file_path.read_text(encoding='utf-8', errors='ignore')
                        for match in impl_pattern.finditer(content):
                            req_block = match.group(1)
                            for req_match in req_pattern.finditer(req_block):
                                sponsor_prefix = req_match.group(1)
                                base_id = req_match.group(2).lower()
                                # Construct full ID with sponsor prefix if present
                                req_id = f"{sponsor_prefix}-{base_id}" if sponsor_prefix else base_id
                                self.implemented_in_code.add(req_id)
                    except Exception:
                        continue

    def _check_orphaned_requirements(self):
        """Find requirements that aren't implemented by any child requirements or code"""
        implemented = set()
        for req in self.requirements.values():
            implemented.update(req.implements)

        for req_id, req in self.requirements.items():
            if req.level in ['PRD', 'Ops'] and req.status == 'Active':
                if req_id not in implemented and req_id not in self.implemented_in_code:
                    self.warnings.append(
                        f"{req.file_path.name}:{req.line_number} - "
                        f"REQ-{req_id}: No child requirements implement this and not found in implementation files"
                    )

    def _check_level_consistency(self):
        """Check that requirement hierarchy makes sense (PRD -> Ops -> Dev)

        Same-level implementations (PRD -> PRD, Ops -> Ops, Dev -> Dev) are allowed
        and reported as INFO. Only invalid hierarchies (child higher than parent) are errors.
        """
        level_hierarchy = {'PRD': 0, 'Ops': 1, 'Dev': 2}

        for req_id, req in self.requirements.items():
            for parent_id in req.implements:
                # Look up parent in local requirements first, then core
                parent = self.requirements.get(parent_id) or self.core_requirements.get(parent_id)
                if parent is None:
                    continue

                child_level = level_hierarchy[req.level]
                parent_level = level_hierarchy[parent.level]

                if child_level == parent_level:
                    # Same-level implementation is allowed (e.g., PRD refining another PRD)
                    self.info.append(
                        f"{req.file_path.name}:{req.line_number} - "
                        f"REQ-{req_id}: Same-level implementation: {req.level} implements {parent.level} ({parent_id})"
                    )
                elif child_level < parent_level:
                    # Invalid: child is higher level than parent (e.g., PRD implementing Dev)
                    self.errors.append(
                        f"{req.file_path.name}:{req.line_number} - "
                        f"REQ-{req_id}: Invalid hierarchy - {req.level} cannot implement {parent.level}"
                    )

    def _check_hash_validity(self):
        """Validate that stored hashes match calculated hashes"""
        for req_id, req in self.requirements.items():
            if req.hash == 'TBD':
                self.warnings.append(
                    f"{req.file_path.name}:{req.line_number} - "
                    f"REQ-{req_id}: Hash is TBD (needs calculation)"
                )
                continue

            # Calculate hash from full content (body + rationale) for backward compatibility
            full_content = req.body
            if hasattr(req, 'rationale') and req.rationale:
                full_content = f"{req.body}\n\n**Rationale**: {req.rationale}"
            calculated_hash = calculate_requirement_hash(full_content)
            if req.hash != calculated_hash:
                self.errors.append(
                    f"{req.file_path.name}:{req.line_number} - "
                    f"REQ-{req_id}: Hash mismatch! Stored: {req.hash}, Calculated: {calculated_hash}"
                )

    def _print_results(self):
        """Print validation results"""
        if self.info:
            print("\nℹ️  INFO:")
            for msg in self.info:
                print(f"  {msg}")

        if self.warnings:
            print(f"\n⚠️  {len(self.warnings)} WARNING(S):")
            for msg in self.warnings:
                print(f"  {msg}")

        if self.errors:
            print(f"\n❌ {len(self.errors)} ERROR(S):")
            for msg in self.errors:
                print(f"  {msg}")
            print("\nValidation FAILED")
        else:
            print("\n✅ All validations passed!")


def main():
    parser = argparse.ArgumentParser(
        description='Validate requirements format and consistency',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog='''
Examples:
  # Validate current repo (auto-detects .core-repo for sponsor repos)
  python validate_requirements.py

  # Validate a different repo
  python validate_requirements.py --path /path/to/other/repo

  # Override core repo path (normally auto-detected from .core-repo)
  python validate_requirements.py --core-repo ../hht_diary
'''
    )
    parser.add_argument(
        '--path',
        type=Path,
        help='Path to repository root (default: auto-detect from script location)'
    )
    parser.add_argument(
        '--core-repo',
        type=Path,
        help='Path to core repository (default: auto-detect from .core-repo file)'
    )
    args = parser.parse_args()

    if args.path:
        repo_root = args.path.resolve()
        spec_dir = repo_root / "spec"
    else:
        script_dir = Path(__file__).parent
        repo_root = script_dir.parent.parent
        spec_dir = repo_root / "spec"

    if not spec_dir.exists():
        print(f"❌ Error: Spec directory not found: {spec_dir}")
        sys.exit(1)

    # Resolve core repo spec dir
    # Priority: 1) --core-repo arg, 2) .core-repo file, 3) None (core repo itself)
    core_spec_dir = None
    if args.core_repo:
        # Explicit command-line argument
        core_spec_dir = (args.core_repo.resolve() / "spec")
        if not core_spec_dir.exists():
            print(f"❌ Error: Core repo spec directory not found: {core_spec_dir}")
            sys.exit(1)
    else:
        # Check for .core-repo file (indicates this is a sponsor repo)
        core_repo_file = repo_root / ".core-repo"
        if core_repo_file.exists():
            core_repo_path = core_repo_file.read_text().strip()
            if core_repo_path:
                # Resolve relative to repo root
                core_repo_resolved = (repo_root / core_repo_path).resolve()
                core_spec_dir = core_repo_resolved / "spec"
                if not core_spec_dir.exists():
                    print(f"⚠️  Warning: Core repo from .core-repo not found: {core_spec_dir}")
                    print(f"   Run tools/setup-repo.sh to configure core repo path")
                    core_spec_dir = None

    validator = RequirementValidator(spec_dir, core_spec_dir)
    success = validator.validate_all()

    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
