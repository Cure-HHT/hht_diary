#!/usr/bin/env python3
"""
REQ-d00002: Requirements validation tool

Validates requirement format and IDs across all specification files.
Checks for:
- Unique requirement IDs
- Proper format compliance
- Valid "Implements" links
- Orphaned requirements
- Consistent status values
"""

import re
import sys
from pathlib import Path
from typing import Dict, List, Set, Tuple
from dataclasses import dataclass

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

    @property
    def level_prefix(self) -> str:
        """Extract level prefix (p, o, d) from ID"""
        match = re.match(r'^([pod])(\d{5})$', self.id)
        return match.group(1) if match else ''

    @property
    def number(self) -> int:
        """Extract numeric part of ID"""
        match = re.match(r'^([pod])(\d{5})$', self.id)
        return int(match.group(2)) if match else 0


class RequirementValidator:
    """Validates requirements across all spec files"""

    # Regex patterns
    REQ_HEADER_PATTERN = re.compile(r'^###\s+REQ-([pod]\d{5}):\s+(.+)$', re.MULTILINE)
    METADATA_PATTERN = re.compile(
        r'\*\*Level\*\*:\s+(PRD|Ops|Dev)\s+\|\s+\*\*Implements\*\*:\s+([^\|]+)\s+\|\s+\*\*Status\*\*:\s+(Active|Draft|Deprecated)',
        re.MULTILINE
    )
    TRACED_BY_PATTERN = re.compile(r'\*\*Traced by\*\*:\s+(.+)$', re.MULTILINE)

    VALID_STATUSES = {'Active', 'Draft', 'Deprecated'}
    VALID_LEVELS = {'PRD', 'Ops', 'Dev'}

    def __init__(self, spec_dir: Path):
        self.spec_dir = spec_dir
        self.requirements: Dict[str, Requirement] = {}
        self.errors: List[str] = []
        self.warnings: List[str] = []

    def validate_all(self) -> bool:
        """Run all validation checks. Returns True if valid."""
        print(f"🔍 Scanning {self.spec_dir} for requirements...\n")

        # Find and parse all requirements
        self._parse_requirements()

        if not self.requirements:
            print("⚠️  No requirements found")
            return True

        print(f"📋 Found {len(self.requirements)} requirements\n")

        # Run validation checks
        self._check_unique_ids()
        self._check_id_format()
        self._check_implements_links()
        self._check_orphaned_requirements()
        self._check_level_consistency()

        # Report results
        self._print_results()

        return len(self.errors) == 0

    def _parse_requirements(self):
        """Parse all requirements from spec files"""
        for spec_file in self.spec_dir.glob('*.md'):
            if spec_file.name == 'requirements-format.md':
                continue  # Skip the format spec itself

            self._parse_file(spec_file)

    def _parse_file(self, file_path: Path):
        """Parse requirements from a single file"""
        try:
            content = file_path.read_text(encoding='utf-8')
        except UnicodeDecodeError:
            # Try with error handling for non-UTF8 files
            content = file_path.read_text(encoding='utf-8', errors='ignore')
        lines = content.split('\n')

        # Find all requirement headers
        for match in self.REQ_HEADER_PATTERN.finditer(content):
            req_id = match.group(1)
            title = match.group(2).strip()
            line_num = content[:match.start()].count('\n') + 1

            # Extract metadata from following lines
            remaining_content = content[match.end():]
            metadata_match = self.METADATA_PATTERN.search(remaining_content[:500])

            if not metadata_match:
                self.errors.append(
                    f"{file_path.name}:{line_num} - REQ-{req_id}: Missing or malformed metadata line"
                )
                continue

            level = metadata_match.group(1)
            implements_str = metadata_match.group(2).strip()
            status = metadata_match.group(3)

            # Parse implements list
            implements = []
            if implements_str != '-':
                implements = [
                    impl.strip()
                    for impl in implements_str.split(',')
                    if impl.strip()
                ]

            # Parse traced_by
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
        """Check that requirement IDs follow the correct format"""
        id_pattern = re.compile(r'^[pod]\d{5}$')

        for req_id, req in self.requirements.items():
            if not id_pattern.match(req_id):
                self.errors.append(
                    f"{req.file_path.name}:{req.line_number} - "
                    f"Invalid ID format: {req_id} (expected: [pod]NNNNN)"
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

    def _check_orphaned_requirements(self):
        """Find requirements that aren't implemented by any child requirements"""
        implemented = set()
        for req in self.requirements.values():
            implemented.update(req.implements)

        for req_id, req in self.requirements.items():
            # PRD and Ops requirements should have children (unless deprecated)
            if req.level in ['PRD', 'Ops'] and req.status == 'Active':
                if req_id not in implemented and not req.traced_by:
                    self.warnings.append(
                        f"{req.file_path.name}:{req.line_number} - "
                        f"REQ-{req_id}: No child requirements implement this (may need dev/ops work)"
                    )

    def _check_level_consistency(self):
        """Check that requirement hierarchy makes sense (PRD -> Ops -> Dev)"""
        level_hierarchy = {'PRD': 0, 'Ops': 1, 'Dev': 2}

        for req_id, req in self.requirements.items():
            for parent_id in req.implements:
                if parent_id not in self.requirements:
                    continue  # Already caught by _check_implements_links

                parent = self.requirements[parent_id]

                # Check hierarchy flows downward
                if level_hierarchy[req.level] <= level_hierarchy[parent.level]:
                    self.warnings.append(
                        f"{req.file_path.name}:{req.line_number} - "
                        f"REQ-{req_id} ({req.level}) implements "
                        f"REQ-{parent_id} ({parent.level}): "
                        f"Unusual hierarchy (expected: PRD -> Ops -> Dev)"
                    )

    def _print_results(self):
        """Print validation results"""
        print("\n" + "="*70)

        if self.errors:
            print(f"\n❌ {len(self.errors)} ERROR(S) FOUND:\n")
            for error in self.errors:
                print(f"  • {error}")

        if self.warnings:
            print(f"\n⚠️  {len(self.warnings)} WARNING(S):\n")
            for warning in self.warnings:
                print(f"  • {warning}")

        if not self.errors and not self.warnings:
            print("\n✅ ALL REQUIREMENTS VALID\n")
            self._print_summary()
        elif not self.errors:
            print("\n✅ No errors (warnings can be addressed)\n")
            self._print_summary()
        else:
            print(f"\n❌ Validation failed with {len(self.errors)} error(s)\n")

        print("="*70 + "\n")

    def _print_summary(self):
        """Print summary statistics"""
        by_level = {'PRD': 0, 'Ops': 0, 'Dev': 0}
        by_status = {'Active': 0, 'Draft': 0, 'Deprecated': 0}

        for req in self.requirements.values():
            by_level[req.level] = by_level.get(req.level, 0) + 1
            by_status[req.status] = by_status.get(req.status, 0) + 1

        print("📊 SUMMARY:")
        print(f"  Total requirements: {len(self.requirements)}")
        print(f"  By level: PRD={by_level['PRD']}, Ops={by_level['Ops']}, Dev={by_level['Dev']}")
        print(f"  By status: Active={by_status['Active']}, Draft={by_status['Draft']}, Deprecated={by_status['Deprecated']}")


def main():
    """Main entry point"""
    # Find spec directory
    script_dir = Path(__file__).parent
    repo_root = script_dir.parent.parent
    spec_dir = repo_root / 'spec'

    if not spec_dir.exists():
        print(f"❌ Spec directory not found: {spec_dir}")
        sys.exit(1)

    validator = RequirementValidator(spec_dir)
    is_valid = validator.validate_all()

    sys.exit(0 if is_valid else 1)


if __name__ == '__main__':
    main()
