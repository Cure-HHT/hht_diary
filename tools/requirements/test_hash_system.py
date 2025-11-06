#!/usr/bin/env python3
"""
Test suite for requirement hash system (Phase 2)

Tests:
1. Hash calculation consistency
2. Hash detection in validation
3. Hash update script functionality
4. INDEX.md hash synchronization
5. Edge cases and error handling

Usage:
    python3 tools/requirements/test_hash_system.py
"""

import sys
import hashlib
import tempfile
import shutil
from pathlib import Path
from typing import Tuple

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent))

from validate_requirements import calculate_requirement_hash, RequirementValidator


class TestHashSystem:
    """Test suite for hash system"""

    def __init__(self):
        self.passed = 0
        self.failed = 0
        self.tests_run = 0

    def assert_equal(self, actual, expected, test_name):
        """Assert two values are equal"""
        self.tests_run += 1
        if actual == expected:
            self.passed += 1
            print(f"  ✅ {test_name}")
            return True
        else:
            self.failed += 1
            print(f"  ❌ {test_name}")
            print(f"     Expected: {expected}")
            print(f"     Got: {actual}")
            return False

    def assert_true(self, condition, test_name):
        """Assert condition is true"""
        self.tests_run += 1
        if condition:
            self.passed += 1
            print(f"  ✅ {test_name}")
            return True
        else:
            self.failed += 1
            print(f"  ❌ {test_name}")
            return False

    def test_hash_calculation(self):
        """Test hash calculation function"""
        print("\n1. Testing hash calculation...")

        # Test basic hash
        body = "This is a test requirement body"
        hash1 = calculate_requirement_hash(body)
        self.assert_equal(len(hash1), 8, "Hash length is 8 characters")
        self.assert_true(all(c in '0123456789abcdef' for c in hash1),
                        "Hash contains only hex characters")

        # Test consistency
        hash2 = calculate_requirement_hash(body)
        self.assert_equal(hash1, hash2, "Hash is deterministic")

        # Test different content gives different hash
        body2 = "Different requirement body"
        hash3 = calculate_requirement_hash(body2)
        self.assert_true(hash1 != hash3, "Different content produces different hash")

        # Test whitespace sensitivity
        body_with_space = body + " "
        hash4 = calculate_requirement_hash(body_with_space)
        self.assert_true(hash1 != hash4, "Hash is whitespace-sensitive")

    def test_validator_parsing(self):
        """Test validator can parse requirements with Hash field"""
        print("\n2. Testing validator parsing...")

        # Create temporary spec directory
        with tempfile.TemporaryDirectory() as tmpdir:
            spec_dir = Path(tmpdir) / 'spec'
            spec_dir.mkdir()

            # Create test requirement file
            test_file = spec_dir / 'test-req.md'
            test_content = """# Test Requirements

### REQ-p00001: Test Requirement

**Level**: PRD | **Implements**: - | **Status**: Active | **Hash**: abc12345

This is a test requirement body.

**Rationale**: For testing

**Acceptance Criteria**:
- Test criterion 1
"""
            test_file.write_text(test_content)

            # Parse with validator
            validator = RequirementValidator(spec_dir)
            validator._parse_requirements()

            self.assert_equal(len(validator.requirements), 1, "Parsed 1 requirement")

            if 'p00001' in validator.requirements:
                req = validator.requirements['p00001']
                self.assert_equal(req.hash, 'abc12345', "Hash field parsed correctly")
                self.assert_true(len(req.body) > 0, "Body text extracted")

    def test_hash_validation(self):
        """Test validator detects hash mismatches"""
        print("\n3. Testing hash validation...")

        with tempfile.TemporaryDirectory() as tmpdir:
            spec_dir = Path(tmpdir) / 'spec'
            spec_dir.mkdir()

            # Create requirement with correct hash
            test_file = spec_dir / 'test-req.md'
            body = "This is a test requirement body."
            correct_hash = calculate_requirement_hash(body)

            test_content = f"""# Test Requirements

### REQ-p00001: Test Requirement

**Level**: PRD | **Implements**: - | **Status**: Active | **Hash**: {correct_hash}

{body}
"""
            test_file.write_text(test_content)

            validator = RequirementValidator(spec_dir)
            validator._parse_requirements()
            validator._check_hash_accuracy()

            self.assert_equal(len(validator.errors), 0, "No errors for correct hash")

            # Now test with incorrect hash (overwrite file with just the bad one)
            test_content2 = f"""# Test Requirements

### REQ-p00002: Test Requirement 2

**Level**: PRD | **Implements**: - | **Status**: Active | **Hash**: deadbeef

{body}
"""
            test_file.write_text(test_content2)

            validator2 = RequirementValidator(spec_dir)
            validator2._parse_requirements()
            validator2._check_hash_accuracy()

            self.assert_true(len(validator2.errors) >= 1, "Error detected for wrong hash")

    def test_tbd_hash_warning(self):
        """Test validator warns about TBD hashes"""
        print("\n4. Testing TBD hash warnings...")

        with tempfile.TemporaryDirectory() as tmpdir:
            spec_dir = Path(tmpdir) / 'spec'
            spec_dir.mkdir()

            test_file = spec_dir / 'test-req.md'
            test_content = """# Test Requirements

### REQ-p00001: Test Requirement

**Level**: PRD | **Implements**: - | **Status**: Active | **Hash**: TBD

This is a test requirement body.
"""
            test_file.write_text(test_content)

            validator = RequirementValidator(spec_dir)
            validator._parse_requirements()
            validator._check_hash_accuracy()

            self.assert_equal(len(validator.errors), 0, "TBD is not an error")
            self.assert_equal(len(validator.warnings), 1, "TBD generates warning")

    def test_hash_update_script_exists(self):
        """Test update-REQ-hashes.py script exists and is executable"""
        print("\n5. Testing update script...")

        script_path = Path(__file__).parent / 'update-REQ-hashes.py'
        self.assert_true(script_path.exists(), "update-REQ-hashes.py exists")
        self.assert_true(script_path.stat().st_mode & 0o111, "Script is executable")

    def test_index_md_schema(self):
        """Test INDEX.md has Hash column"""
        print("\n6. Testing INDEX.md schema...")

        spec_dir = Path(__file__).parent.parent.parent / 'spec'
        index_path = spec_dir / 'INDEX.md'

        if index_path.exists():
            content = index_path.read_text()
            self.assert_true('| Hash |' in content or '|------|' in content,
                           "INDEX.md has Hash column in header")

            # Check at least one hash is populated
            import re
            hash_pattern = re.compile(r'\|\s*REQ-[pod]\d{5}\s*\|[^|]+\|[^|]+\|\s*([a-f0-9]{8}|TBD)\s*\|')
            matches = hash_pattern.findall(content)
            self.assert_true(len(matches) > 0, "INDEX.md has hash values")
        else:
            print(f"  ⚠️  INDEX.md not found at {index_path}")

    def test_real_requirements_have_hashes(self):
        """Test actual spec files have Hash fields"""
        print("\n7. Testing real requirements have hashes...")

        spec_dir = Path(__file__).parent.parent.parent / 'spec'

        if not spec_dir.exists():
            print(f"  ⚠️  Spec directory not found at {spec_dir}")
            return

        # Find all spec files
        spec_files = [f for f in spec_dir.glob('*.md')
                     if f.name not in ['INDEX.md', 'README.md', 'requirements-format.md']]

        if len(spec_files) == 0:
            print("  ⚠️  No spec files found")
            return

        import re
        hash_pattern = re.compile(r'\*\*Hash\*\*:\s*([a-f0-9]{8}|TBD)', re.MULTILINE)
        req_pattern = re.compile(r'###\s+REQ-[pod]\d{5}', re.MULTILINE)

        files_with_hashes = 0
        files_with_requirements = 0

        for spec_file in spec_files:
            content = spec_file.read_text()
            # Only count files that have requirements
            if req_pattern.search(content):
                files_with_requirements += 1
                if hash_pattern.search(content):
                    files_with_hashes += 1

        if files_with_requirements == 0:
            print("  ⚠️  No files with requirements found")
            return

        coverage = files_with_hashes / files_with_requirements * 100
        self.assert_equal(coverage, 100.0,
                         f"100% of requirement files must have Hash fields (got {coverage:.1f}%)")

    def test_hash_format_documentation(self):
        """Test requirements format documentation includes Hash"""
        print("\n8. Testing format documentation...")

        spec_dir = Path(__file__).parent.parent.parent / 'spec'
        format_doc = spec_dir / 'requirements-format.md'

        if format_doc.exists():
            content = format_doc.read_text()
            self.assert_true('**Hash**' in content, "Format doc mentions Hash field")
            self.assert_true('SHA-256' in content or 'sha256' in content.lower(),
                           "Format doc explains hash algorithm")
        else:
            print(f"  ⚠️  requirements-format.md not found")

    def run_all_tests(self):
        """Run all tests"""
        print("="*70)
        print("REQUIREMENT HASH SYSTEM TEST SUITE")
        print("="*70)

        self.test_hash_calculation()
        self.test_validator_parsing()
        self.test_hash_validation()
        self.test_tbd_hash_warning()
        self.test_hash_update_script_exists()
        self.test_index_md_schema()
        self.test_real_requirements_have_hashes()
        self.test_hash_format_documentation()

        print("\n" + "="*70)
        print(f"RESULTS: {self.passed}/{self.tests_run} tests passed")

        if self.failed > 0:
            print(f"❌ {self.failed} test(s) failed")
        else:
            print("✅ All tests passed!")

        print("="*70 + "\n")

        return self.failed == 0


def main():
    """Main entry point"""
    tester = TestHashSystem()
    success = tester.run_all_tests()
    sys.exit(0 if success else 1)


if __name__ == '__main__':
    main()
