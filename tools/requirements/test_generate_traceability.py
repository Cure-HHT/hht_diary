#!/usr/bin/env python3
"""
Test suite for generate_traceability.py

Tests:
1. Requirement scanning and parsing
2. Implementation file detection
3. Markdown output format
4. HTML output format
5. CSV output format
6. Implementation file display in all formats

Usage:
    python3 tools/requirements/test_generate_traceability.py
"""

import sys
import unittest
import tempfile
import shutil
from pathlib import Path

# Add tools/requirements to path
sys.path.insert(0, str(Path(__file__).parent))

from generate_traceability import TraceabilityGenerator, Requirement


class TestRequirementParsing(unittest.TestCase):
    """Test requirement scanning and parsing"""

    def setUp(self):
        """Create temporary spec directory with test files"""
        self.test_dir = tempfile.mkdtemp()
        self.spec_dir = Path(self.test_dir) / "spec"
        self.spec_dir.mkdir()

        # Create test requirement file
        test_req_file = self.spec_dir / "test-requirements.md"
        test_req_file.write_text("""# Test Requirements

# REQ-p00001: Test Requirement One

**Level**: PRD | **Implements**: - | **Status**: Active

This is a test requirement.

**Rationale**: Testing purposes

**Acceptance Criteria**:
- Criterion 1
- Criterion 2

# REQ-d00001: Dev Implementation

**Level**: DEV | **Implements**: p00001 | **Status**: Active

Implementation of test requirement.
""")

    def tearDown(self):
        """Clean up temporary directory"""
        shutil.rmtree(self.test_dir)

    def test_requirement_scanning(self):
        """Test that requirements are correctly scanned from spec files"""
        gen = TraceabilityGenerator(self.spec_dir)
        gen._parse_requirements()

        self.assertEqual(len(gen.requirements), 2)
        self.assertIn('p00001', gen.requirements)
        self.assertIn('d00001', gen.requirements)

    def test_requirement_metadata(self):
        """Test that requirement metadata is correctly parsed"""
        gen = TraceabilityGenerator(self.spec_dir)
        gen._parse_requirements()

        req = gen.requirements['p00001']
        self.assertEqual(req.level, 'PRD')
        self.assertEqual(req.status, 'Active')
        self.assertEqual(req.title, 'Test Requirement One')
        self.assertEqual(req.implements, [])

        dev_req = gen.requirements['d00001']
        self.assertEqual(dev_req.level, 'DEV')
        self.assertIn('p00001', dev_req.implements)


class TestImplementationFileTracking(unittest.TestCase):
    """Test implementation file detection and tracking"""

    def setUp(self):
        """Create temporary directories with test files"""
        self.test_dir = tempfile.mkdtemp()
        self.spec_dir = Path(self.test_dir) / "spec"
        self.impl_dir = Path(self.test_dir) / "database"
        self.spec_dir.mkdir()
        self.impl_dir.mkdir()

        # Create test requirement
        test_req = self.spec_dir / "test-req.md"
        test_req.write_text("""# REQ-d00001: Database Schema

**Level**: DEV | **Implements**: - | **Status**: Active

Schema implementation.
""")

        # Create implementation file with requirement reference
        impl_file = self.impl_dir / "schema.sql"
        impl_file.write_text("""-- IMPLEMENTS REQUIREMENTS:
--   REQ-d00001: Database Schema

CREATE TABLE test (
    id SERIAL PRIMARY KEY
);
""")

    def tearDown(self):
        """Clean up temporary directory"""
        shutil.rmtree(self.test_dir)

    def test_implementation_file_detection(self):
        """Test that implementation files are correctly detected"""
        gen = TraceabilityGenerator(self.spec_dir, impl_dirs=[self.impl_dir])
        gen._parse_requirements()
        gen._scan_implementation_files()

        req = gen.requirements['d00001']
        self.assertGreater(len(req.implementation_files), 0)

        # Check that schema.sql is in the implementation files
        impl_files_str = ', '.join(req.implementation_files)
        self.assertIn('schema.sql', impl_files_str)


class TestOutputFormats(unittest.TestCase):
    """Test output format generation"""

    def setUp(self):
        """Create temporary directory with test requirement"""
        self.test_dir = tempfile.mkdtemp()
        self.spec_dir = Path(self.test_dir) / "spec"
        self.impl_dir = Path(self.test_dir) / "impl"
        self.spec_dir.mkdir()
        self.impl_dir.mkdir()

        # Create test requirement
        test_req = self.spec_dir / "test-req.md"
        test_req.write_text("""# REQ-p00001: Test Requirement

**Level**: PRD | **Implements**: - | **Status**: Active

Test requirement.
""")

        # Create implementation file
        impl_file = self.impl_dir / "impl.py"
        impl_file.write_text("""# REQ-p00001: Implementation
def test():
    pass
""")

        self.gen = TraceabilityGenerator(self.spec_dir, impl_dirs=[self.impl_dir])
        self.gen._parse_requirements()
        self.gen._scan_implementation_files()
        self.gen._load_test_results()

    def tearDown(self):
        """Clean up temporary directory"""
        shutil.rmtree(self.test_dir)

    def test_markdown_generation(self):
        """Test markdown output generation"""
        markdown = self.gen._generate_markdown()

        self.assertIn('REQ-p00001', markdown)
        self.assertIn('Test Requirement', markdown)
        self.assertIn('PRD', markdown)

    def test_markdown_implementation_display(self):
        """Test that implementation files are shown in markdown"""
        markdown = self.gen._generate_markdown()
        req = self.gen.requirements['p00001']

        if req.implementation_files:
            self.assertIn('Implementation:', markdown)

    def test_csv_generation(self):
        """Test CSV output generation"""
        csv_output = self.gen._generate_csv()

        # Check header
        self.assertIn('Implementation Files', csv_output)
        self.assertIn('Requirement ID', csv_output)

        # Check data
        self.assertIn('p00001', csv_output)

    def test_html_generation(self):
        """Test HTML output generation"""
        html = self.gen._generate_html()

        # Check for essential HTML elements
        self.assertIn('<html', html.lower())
        self.assertIn('REQ-p00001', html)
        self.assertIn('req-implementation', html)


class TestEdgeCases(unittest.TestCase):
    """Test edge cases and error handling"""

    def test_empty_spec_directory(self):
        """Test handling of empty spec directory"""
        with tempfile.TemporaryDirectory() as tmpdir:
            spec_dir = Path(tmpdir) / "spec"
            spec_dir.mkdir()

            gen = TraceabilityGenerator(spec_dir, Path(tmpdir))
            self.assertEqual(len(gen.requirements), 0)

    def test_no_implementation_files(self):
        """Test requirements with no implementation files"""
        with tempfile.TemporaryDirectory() as tmpdir:
            spec_dir = Path(tmpdir) / "spec"
            spec_dir.mkdir()

            test_req = spec_dir / "test.md"
            test_req.write_text("""# REQ-p00001: Test

**Level**: PRD | **Implements**: - | **Status**: Active

Test.
""")

            gen = TraceabilityGenerator(spec_dir)
            gen._parse_requirements()
            req = gen.requirements['p00001']

            self.assertEqual(len(req.implementation_files), 0)

            # Test CSV output doesn't break
            csv_output = gen._generate_csv()
            self.assertIn('-', csv_output)  # Should show '-' for no implementation


def run_tests():
    """Run all tests"""
    print("="*70)
    print("Testing generate_traceability.py")
    print("="*70)

    loader = unittest.TestLoader()
    suite = unittest.TestSuite()

    # Add all test classes
    suite.addTests(loader.loadTestsFromTestCase(TestRequirementParsing))
    suite.addTests(loader.loadTestsFromTestCase(TestImplementationFileTracking))
    suite.addTests(loader.loadTestsFromTestCase(TestOutputFormats))
    suite.addTests(loader.loadTestsFromTestCase(TestEdgeCases))

    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)

    print("\n" + "="*70)
    if result.wasSuccessful():
        print("✅ All tests passed!")
        return 0
    else:
        print("❌ Some tests failed")
        return 1


if __name__ == '__main__':
    sys.exit(run_tests())
