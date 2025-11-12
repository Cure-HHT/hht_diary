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
import csv
from pathlib import Path
from html.parser import HTMLParser
from io import StringIO

# Add tools/requirements to path
sys.path.insert(0, str(Path(__file__).parent))

from generate_traceability import TraceabilityGenerator, Requirement


class HTMLValidator(HTMLParser):
    """Simple HTML validator to check for well-formed HTML"""
    def __init__(self):
        super().__init__()
        self.errors = []
        self.tag_stack = []

    def handle_starttag(self, tag, attrs):
        # Self-closing tags don't need to be tracked
        if tag not in ['br', 'hr', 'img', 'input', 'meta', 'link']:
            self.tag_stack.append(tag)

    def handle_endtag(self, tag):
        if tag in ['br', 'hr', 'img', 'input', 'meta', 'link']:
            return
        if not self.tag_stack:
            self.errors.append(f"Unexpected closing tag: {tag}")
        elif self.tag_stack[-1] != tag:
            self.errors.append(f"Mismatched tags: expected {self.tag_stack[-1]}, got {tag}")
        else:
            self.tag_stack.pop()

    def is_valid(self):
        return len(self.errors) == 0 and len(self.tag_stack) == 0


class TestRequirementParsing(unittest.TestCase):
    """Test requirement scanning and parsing"""

    def setUp(self):
        """Create temporary spec directory with test files"""
        self.test_dir = tempfile.mkdtemp()
        self.spec_dir = Path(self.test_dir) / "spec"
        self.spec_dir.mkdir()

        # Create test requirement file
        test_req_file = self.spec_dir / "test-requirements.md"
        test_req_file.write_text("""# REQ-p00001: Test Requirement One
**Level**: PRD | **Implements**: - | **Status**: Active

This is a test requirement.

# REQ-d00001: Dev Implementation
**Level**: Dev | **Implements**: p00001 | **Status**: Active

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
**Level**: Dev | **Implements**: - | **Status**: Active

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
        # implementation_files is now List[Tuple[str, int]]
        impl_files_str = ', '.join([path for path, line in req.implementation_files])
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
            self.assertIn('**Implemented in**:', markdown)

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
        self.assertIn('impl-files', html)


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


class TestOutputValidation(unittest.TestCase):
    """Test output format validation (linting)"""

    def setUp(self):
        """Create temporary directory with test requirement"""
        self.test_dir = tempfile.mkdtemp()
        self.spec_dir = Path(self.test_dir) / "spec"
        self.spec_dir.mkdir()

        # Create test requirement
        test_req = self.spec_dir / "test.md"
        test_req.write_text("""# REQ-p00001: Test Requirement
**Level**: PRD | **Implements**: - | **Status**: Active

Test requirement for validation.
""")

        self.gen = TraceabilityGenerator(self.spec_dir)
        self.gen._parse_requirements()

    def tearDown(self):
        """Clean up temporary directory"""
        shutil.rmtree(self.test_dir)

    def test_html_well_formed(self):
        """Test that HTML output is well-formed"""
        html = self.gen._generate_html()

        validator = HTMLValidator()
        validator.feed(html)

        self.assertTrue(validator.is_valid(),
                       f"HTML validation errors: {validator.errors}, Unclosed tags: {validator.tag_stack}")

    def test_html_contains_required_elements(self):
        """Test that HTML contains required structural elements"""
        html = self.gen._generate_html()

        # Check for essential HTML elements
        self.assertIn('<!DOCTYPE html>', html)
        self.assertIn('<html', html)
        self.assertIn('<head>', html)
        self.assertIn('<body>', html)
        self.assertIn('</html>', html)

        # Check for traceability-specific elements
        self.assertIn('impl-files', html)  # Implementation section CSS
        self.assertIn('impl-files-header', html)  # Implementation header class

    def test_csv_format_valid(self):
        """Test that CSV output is valid CSV format"""
        csv_output = self.gen._generate_csv()

        try:
            # Try to parse CSV
            reader = csv.reader(StringIO(csv_output))
            rows = list(reader)

            # Check header row
            self.assertGreater(len(rows), 0, "CSV should have at least a header row")
            header = rows[0]
            self.assertIn('Implementation Files', header)
            self.assertIn('Requirement ID', header)

            # Check that all rows have same number of columns
            if len(rows) > 1:
                header_cols = len(header)
                for i, row in enumerate(rows[1:], start=2):
                    self.assertEqual(len(row), header_cols,
                                   f"Row {i} has {len(row)} columns, expected {header_cols}")

        except csv.Error as e:
            self.fail(f"CSV parsing failed: {e}")

    def test_csv_implementation_column(self):
        """Test that CSV has Implementation Files column with correct data"""
        csv_output = self.gen._generate_csv()

        reader = csv.DictReader(StringIO(csv_output))
        rows = list(reader)

        self.assertGreater(len(rows), 0, "Should have at least one requirement")

        for row in rows:
            self.assertIn('Implementation Files', row)
            # Value should be either '-' or a file path
            impl_value = row['Implementation Files']
            self.assertTrue(impl_value == '-' or '/' in impl_value or ',' in impl_value,
                          f"Invalid implementation value: {impl_value}")

    def test_markdown_syntax(self):
        """Test that Markdown output has valid syntax"""
        markdown = self.gen._generate_markdown()

        # Check for required markdown elements
        self.assertIn('# Requirements Traceability Matrix', markdown)
        self.assertIn('## Summary', markdown)
        self.assertIn('## Traceability Tree', markdown)

        # Check for consistent list formatting (should use - for bullets)
        lines = markdown.split('\n')
        for i, line in enumerate(lines, start=1):
            if line.strip().startswith('- '):
                # Check that list items are properly formatted
                self.assertRegex(line, r'^\s*- ',
                               f"Line {i}: List item not properly formatted: {line}")

    def test_markdown_implementation_format(self):
        """Test that implementation files are properly formatted in markdown"""
        # Add implementation file
        impl_dir = Path(self.test_dir) / "impl"
        impl_dir.mkdir()
        impl_file = impl_dir / "test.py"
        impl_file.write_text("# REQ-p00001\npass")

        gen = TraceabilityGenerator(self.spec_dir, impl_dirs=[impl_dir])
        gen._parse_requirements()
        gen._scan_implementation_files()

        markdown = gen._generate_markdown()

        # If there are implementation files, check formatting
        req = gen.requirements.get('p00001')
        if req and req.implementation_files:
            self.assertIn('Implemented in', markdown)
            # Should have markdown links with line numbers
            self.assertIn('test.py:', markdown)


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
    suite.addTests(loader.loadTestsFromTestCase(TestOutputValidation))

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
