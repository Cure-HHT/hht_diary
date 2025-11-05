#!/usr/bin/env python3

"""
IMPLEMENTS REQUIREMENTS:
  REQ-o00013: Requirements Format Validation
  REQ-p00020: System Validation and Traceability

Validates that spec/INDEX.md is accurate and complete by:
1. Scanning all spec/*.md files for REQ-# entries
2. Extracting requirement IDs and titles from markdown headers
3. Comparing against INDEX.md
4. Reporting discrepancies (missing, wrong file, wrong title, obsolete not in spec)

Exit codes:
  0 - All validations passed
  1 - Validation errors found
"""

import re
import sys
from pathlib import Path
from typing import Dict, Set, Tuple

# Paths
REPO_ROOT = Path(__file__).parent.parent.parent
SPEC_DIR = REPO_ROOT / "spec"
INDEX_FILE = SPEC_DIR / "INDEX.md"

# Pattern to match requirement headers in spec files
# Matches: ### REQ-p00001: Title or #### REQ-o00005: Title
REQ_HEADER_PATTERN = re.compile(r'^#{2,4}\s+(REQ-[pod]\d{5}):\s*(.+)$', re.MULTILINE)

# Pattern to match INDEX.md rows
# Matches: | REQ-p00001 | prd-security.md | Complete Multi-Sponsor Data Separation |
INDEX_ROW_PATTERN = re.compile(r'^\|\s*(REQ-[pod]\d{5})\s*\|\s*([^\|]+?)\s*\|\s*([^\|]*?)\s*\|$', re.MULTILINE)


def scan_spec_files() -> Dict[str, Tuple[str, str]]:
    """
    Scan all spec/*.md files for requirement headers.

    Returns:
        Dict mapping REQ-ID to (filename, title)
    """
    requirements = {}

    for spec_file in SPEC_DIR.glob("*.md"):
        if spec_file.name == "INDEX.md":
            continue

        content = spec_file.read_text(encoding='utf-8')

        for match in REQ_HEADER_PATTERN.finditer(content):
            req_id = match.group(1)
            title = match.group(2).strip()

            if req_id in requirements:
                print(f"⚠️  WARNING: Duplicate requirement {req_id} found in:")
                print(f"    - {requirements[req_id][0]}")
                print(f"    - {spec_file.name}")

            requirements[req_id] = (spec_file.name, title)

    return requirements


def parse_index() -> Dict[str, Tuple[str, str]]:
    """
    Parse spec/INDEX.md to extract all requirement entries.

    Returns:
        Dict mapping REQ-ID to (filename, title)
    """
    if not INDEX_FILE.exists():
        print(f"❌ ERROR: {INDEX_FILE} does not exist")
        sys.exit(1)

    content = INDEX_FILE.read_text(encoding='utf-8')
    index_entries = {}

    for match in INDEX_ROW_PATTERN.finditer(content):
        req_id = match.group(1)
        filename = match.group(2).strip()
        title = match.group(3).strip()

        if req_id in index_entries:
            print(f"⚠️  WARNING: Duplicate entry for {req_id} in INDEX.md")

        index_entries[req_id] = (filename, title)

    return index_entries


def validate_index():
    """
    Main validation logic.
    """
    print("=" * 70)
    print("INDEX.md Validation")
    print("=" * 70)
    print()

    # Scan spec files
    print("📖 Scanning spec/ files for requirements...")
    spec_requirements = scan_spec_files()
    print(f"   Found {len(spec_requirements)} requirements in spec files")
    print()

    # Parse INDEX.md
    print("📋 Parsing INDEX.md...")
    index_entries = parse_index()
    print(f"   Found {len(index_entries)} entries in INDEX.md")
    print()

    errors = []
    warnings = []

    # Check 1: Every requirement in spec files should be in INDEX
    print("🔍 Checking: Requirements in spec files are in INDEX...")
    missing_from_index = set(spec_requirements.keys()) - set(index_entries.keys())
    if missing_from_index:
        errors.append("Requirements found in spec files but missing from INDEX.md:")
        for req_id in sorted(missing_from_index):
            filename, title = spec_requirements[req_id]
            errors.append(f"  - {req_id} in {filename}: {title}")
    else:
        print("   ✅ All spec requirements are in INDEX.md")
    print()

    # Check 2: Every non-obsolete INDEX entry should exist in spec files
    print("🔍 Checking: Non-obsolete INDEX entries exist in spec files...")
    extra_in_index = []
    for req_id, (filename, title) in index_entries.items():
        if filename.lower() != 'obsolete' and req_id not in spec_requirements:
            extra_in_index.append((req_id, filename, title))

    if extra_in_index:
        errors.append("Requirements in INDEX.md but not found in spec files (should be marked obsolete?):")
        for req_id, filename, title in sorted(extra_in_index):
            errors.append(f"  - {req_id} listed in {filename}: {title}")
    else:
        print("   ✅ All non-obsolete INDEX entries exist in spec files")
    print()

    # Check 3: File references should match
    print("🔍 Checking: File references match...")
    file_mismatches = []
    for req_id in spec_requirements:
        if req_id in index_entries:
            spec_file, _ = spec_requirements[req_id]
            index_file, _ = index_entries[req_id]

            if index_file.lower() != 'obsolete' and spec_file != index_file:
                file_mismatches.append((req_id, spec_file, index_file))

    if file_mismatches:
        errors.append("File reference mismatches between spec files and INDEX.md:")
        for req_id, spec_file, index_file in sorted(file_mismatches):
            errors.append(f"  - {req_id}: in {spec_file} but INDEX says {index_file}")
    else:
        print("   ✅ All file references match")
    print()

    # Check 4: Titles should match (warning only, as titles may be updated)
    print("🔍 Checking: Titles match...")
    title_mismatches = []
    for req_id in spec_requirements:
        if req_id in index_entries:
            _, spec_title = spec_requirements[req_id]
            index_file, index_title = index_entries[req_id]

            if index_file.lower() != 'obsolete' and spec_title != index_title:
                title_mismatches.append((req_id, spec_title, index_title))

    if title_mismatches:
        warnings.append("Title mismatches between spec files and INDEX.md:")
        for req_id, spec_title, index_title in sorted(title_mismatches):
            warnings.append(f"  - {req_id}:")
            warnings.append(f"      Spec:  {spec_title}")
            warnings.append(f"      INDEX: {index_title}")
    else:
        print("   ✅ All titles match")
    print()

    # Check 5: Obsolete entries should not exist in spec files
    print("🔍 Checking: Obsolete entries are truly obsolete...")
    obsolete_errors = []
    for req_id, (filename, title) in index_entries.items():
        if filename.lower() == 'obsolete' and req_id in spec_requirements:
            spec_file, spec_title = spec_requirements[req_id]
            obsolete_errors.append((req_id, spec_file, spec_title))

    if obsolete_errors:
        errors.append("Requirements marked obsolete in INDEX.md but still exist in spec files:")
        for req_id, spec_file, spec_title in sorted(obsolete_errors):
            errors.append(f"  - {req_id} in {spec_file}: {spec_title}")
    else:
        print("   ✅ All obsolete entries are correctly removed from spec files")
    print()

    # Report results
    print("=" * 70)
    print("Validation Results")
    print("=" * 70)
    print()

    if warnings:
        print("⚠️  WARNINGS:")
        print()
        for warning in warnings:
            print(warning)
        print()

    if errors:
        print("❌ ERRORS:")
        print()
        for error in errors:
            print(error)
        print()
        print("=" * 70)
        print("Validation FAILED - please fix the errors above")
        print("=" * 70)
        sys.exit(1)
    else:
        print("✅ All validations passed!")
        print()
        print(f"📊 Summary:")
        print(f"   - Total requirements in spec files: {len(spec_requirements)}")
        print(f"   - Total entries in INDEX.md: {len(index_entries)}")
        obsolete_count = sum(1 for _, (f, _) in index_entries.items() if f.lower() == 'obsolete')
        if obsolete_count > 0:
            print(f"   - Obsolete requirements: {obsolete_count}")
        print()
        print("=" * 70)
        sys.exit(0)


if __name__ == "__main__":
    validate_index()
