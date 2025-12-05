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
from typing import Dict, List, Set, Tuple
from dataclasses import dataclass
from requirement_hash import calculate_requirement_hash, clean_requirement_body

@dataclass
class Requirement:
    """Represents a parsed requirement"""
    id: str
    title: str
    level: str
    implements: List[str]
    status: str
    hash: str  # SHA-256 hash (first 8 chars)
    body: str  # Body text for hash calculation (between status and end marker)
    file_path: Path
    line_number: int
    heading_level: int  # Heading level (1-6)

    @property
    def level_prefix(self) -> str:
        """Extract level prefix (p, o, d) from ID

        Supports both core IDs (d00001) and sponsor-specific IDs (CAL-d00001)
        """
        # Match optional sponsor prefix + level prefix
        match = re.match(r'^(?:[A-Z]{2,4}-)?([pod])(\d{5})$', self.id)
        return match.group(1) if match else ''

    @property
    def number(self) -> int:
        """Extract numeric part of ID

        Supports both core IDs (d00001) and sponsor-specific IDs (CAL-d00001)
        """
        match = re.match(r'^(?:[A-Z]{2,4}-)?([pod])(\d{5})$', self.id)
        return int(match.group(2)) if match else 0

    @property
    def sponsor_prefix(self) -> str:
        """Extract sponsor prefix if present (e.g., 'CAL' from 'CAL-d00001')"""
        match = re.match(r'^([A-Z]{2,4})-[pod]\d{5}$', self.id)
        return match.group(1) if match else ''


# calculate_requirement_hash is now imported from requirement_hash module


class RequirementValidator:
    """Validates requirements across all spec files"""

    # Regex patterns for new format
    # Convention (not enforced): REQ headers typically use level 1 (#), freeing up levels 2-6 for body structure
    # Supports both core REQs (REQ-d00001) and sponsor-specific REQs (REQ-CAL-d00001)
    REQ_HEADER_PATTERN = re.compile(r'^(#{1,6})\s+REQ-(?:([A-Z]{2,4})-)?([pod]\d{5}):\s+(.+)$', re.MULTILINE)
    STATUS_PATTERN = re.compile(
        r'^\*\*Level\*\*:\s+(PRD|Ops|Dev)\s+\|\s+'
        r'\*\*Implements\*\*:\s+([^\|]+?)\s+\|\s+'
        r'\*\*Status\*\*:\s+(Active|Draft|Deprecated)\s*$',
        re.MULTILINE
    )
    END_MARKER_PATTERN = re.compile(
        r'^\*End\*\s+\*(.+?)\*\s+\|\s+\*\*Hash\*\*:\s+([a-f0-9]{8}|TBD)\s*$',
        re.MULTILINE
    )

    VALID_STATUSES = {'Active', 'Draft', 'Deprecated'}
    VALID_LEVELS = {'PRD', 'Ops', 'Dev'}

    def __init__(self, spec_dir: Path):
        self.spec_dir = spec_dir
        self.repo_root = spec_dir.parent
        self.requirements: Dict[str, Requirement] = {}
        self.errors: List[str] = []
        self.warnings: List[str] = []
        self.info: List[str] = []
        self.implemented_in_code: Set[str] = set()

    def validate_all(self) -> bool:
        """Run all validation checks. Returns True if valid."""
        print(f"🔍 Scanning {self.spec_dir} for requirements...\n")

        self._parse_requirements()

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

        # Print results
        self._print_results()

        return len(self.errors) == 0

    def _parse_requirements(self):
        """Parse all requirements from spec files"""
        for file_path in self.spec_dir.glob("*.md"):
            if file_path.name in ['INDEX.md', 'README.md', 'requirements-format.md']:
                continue

            content = file_path.read_text(encoding='utf-8')
            self._parse_file(file_path, content)

    def _parse_file(self, file_path: Path, content: str):
        """Parse all requirements from a single file"""

        # Find all REQ headers
        for header_match in self.REQ_HEADER_PATTERN.finditer(content):
            heading_marks = header_match.group(1)
            heading_level = len(heading_marks)
            sponsor_prefix = header_match.group(2)  # Optional, e.g., "CAL"
            base_id = header_match.group(3)  # e.g., "d00001"
            title = header_match.group(4).strip()
            line_num = content[:header_match.start()].count('\n') + 1

            # Construct full req_id (with or without sponsor prefix)
            req_id = f"{sponsor_prefix}-{base_id}" if sponsor_prefix else base_id

            # Extract content after header until end of file
            req_start = header_match.end()
            remaining = content[req_start:]

            # Find status line (should be first after whitespace)
            status_match = self.STATUS_PATTERN.search(remaining)
            if not status_match:
                self.errors.append(
                    f"{file_path.name}:{line_num} - REQ-{req_id}: Missing or malformed status line"
                )
                continue

            # Check whitespace-only between header and status
            between_header_status = remaining[:status_match.start()]
            if between_header_status.strip():
                self.errors.append(
                    f"{file_path.name}:{line_num} - REQ-{req_id}: Non-whitespace content between header and status line"
                )

            level = status_match.group(1)
            implements_str = status_match.group(2).strip()
            status = status_match.group(3)

            # Find end marker
            end_marker_match = self.END_MARKER_PATTERN.search(remaining[status_match.end():])
            if not end_marker_match:
                self.errors.append(
                    f"{file_path.name}:{line_num} - REQ-{req_id}: Missing end marker with hash"
                )
                continue

            end_title = end_marker_match.group(1).strip()
            hash_value = end_marker_match.group(2)

            # Validate title matches
            if end_title != title:
                self.errors.append(
                    f"{file_path.name}:{line_num} - REQ-{req_id}: Title mismatch - "
                    f"header='{title}' vs end='{end_title}' (MANUAL FIX REQUIRED: likely parsing error from before end markers existed)"
                )

            # Extract body (between status line and end marker)
            body_start = status_match.end()
            # end_marker_match.start() is relative to remaining[status_match.end():], so add offset
            body_end = status_match.end() + end_marker_match.start()
            body_text = remaining[body_start:body_end]

            # Clean body using shared function
            body = clean_requirement_body(body_text)

            # Validate no high-level headings in body
            self._check_body_headings(file_path, line_num, req_id, body, heading_level)

            # Parse implements list
            implements = []
            if implements_str != '-':
                implements = [impl.strip() for impl in implements_str.split(',') if impl.strip()]

            req = Requirement(
                id=req_id,
                title=title,
                level=level,
                implements=implements,
                status=status,
                hash=hash_value,
                body=body,
                file_path=file_path,
                line_number=line_num,
                heading_level=heading_level
            )

            self.requirements[req_id] = req

    def _check_body_headings(self, file_path: Path, line_num: int, req_id: str,
                            body: str, req_heading_level: int):
        """Check for headings at same or higher level in requirement body

        Requirement bodies should only contain headings at a LOWER level than
        the requirement heading itself. For example, if requirement is level 1 (#),
        body can use ##, ###, etc., but not #.
        """
        for line in body.split('\n'):
            match = re.match(r'^(#{1,6})\s+', line)
            if match:
                heading_level = len(match.group(1))
                if heading_level <= req_heading_level:
                    self.errors.append(
                        f"{file_path.name}:{line_num} - REQ-{req_id}: "
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
        for req_id, req in self.requirements.items():
            for parent_id in req.implements:
                if parent_id not in self.requirements:
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
                if parent_id not in self.requirements:
                    continue

                parent = self.requirements[parent_id]
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

            calculated_hash = calculate_requirement_hash(req.body)
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
  # Validate current repo
  python validate_requirements.py

  # Validate a different repo
  python validate_requirements.py --path /path/to/other/repo

  # Validate sibling repo
  python validate_requirements.py --path ../sibling-repo
'''
    )
    parser.add_argument(
        '--path',
        type=Path,
        help='Path to repository root (default: auto-detect from script location)'
    )
    args = parser.parse_args()

    if args.path:
        repo_root = args.path.resolve()
        spec_dir = repo_root / "spec"
    else:
        script_dir = Path(__file__).parent
        spec_dir = script_dir.parent.parent / "spec"

    if not spec_dir.exists():
        print(f"❌ Error: Spec directory not found: {spec_dir}")
        sys.exit(1)

    validator = RequirementValidator(spec_dir)
    success = validator.validate_all()

    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
