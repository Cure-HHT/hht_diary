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
sys.path.insert(0, str(Path(__file__).parent.parent))

from generate_traceability import TraceabilityGenerator, Requirement
from requirement_hash import calculate_requirement_hash


def make_requirement(req_id: str, title: str, level: str, implements: str, status: str, body: str) -> str:
    """Helper to create a requirement in the new format with end marker"""
    # Body should NOT include leading/trailing newlines for hash calculation
    # but when written to file, it will have surrounding newlines
    parsed_body = f"\n{body}"  # Leading newline as parser extracts it
    req_hash = calculate_requirement_hash(parsed_body)
    return f"""# REQ-{req_id}: {title}

**Level**: {level} | **Implements**: {implements} | **Status**: {status}

{body}

*End* *{title}* | **Hash**: {req_hash}
"""


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

        # Create test requirement file with new format
        test_req_file = self.spec_dir / "test-requirements.md"
        content = make_requirement('p00001', 'Test Requirement One', 'PRD', '-', 'Active',
                                   'This is a test requirement.')
        content += "\n" + make_requirement('d00001', 'Dev Implementation', 'Dev', 'p00001', 'Active',
                                           'Implementation of test requirement.')
        test_req_file.write_text(content)

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

        # Create test requirement with new format
        test_req = self.spec_dir / "test-req.md"
        test_req.write_text(make_requirement('d00001', 'Database Schema', 'Dev', '-', 'Active',
                                             'Schema implementation.'))

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

        # Create test requirement with new format
        test_req = self.spec_dir / "test-req.md"
        test_req.write_text(make_requirement('p00001', 'Test Requirement', 'PRD', '-', 'Active',
                                             'Test requirement.'))

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
            test_req.write_text(make_requirement('p00001', 'Test', 'PRD', '-', 'Active', 'Test.'))

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

        # Create test requirement with new format
        test_req = self.spec_dir / "test.md"
        test_req.write_text(make_requirement('p00001', 'Test Requirement', 'PRD', '-', 'Active',
                                             'Test requirement for validation.'))

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
        self.assertIn('impl-file', html)  # Implementation file class for child items

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


def make_requirement_with_rationale(req_id: str, title: str, level: str, implements: str,
                                     status: str, body: str, rationale: str) -> str:
    """Helper to create a requirement with separate body and rationale sections"""
    full_body = f"{body}\n\n**Rationale**: {rationale}" if rationale else body
    parsed_body = f"\n{full_body}"
    req_hash = calculate_requirement_hash(parsed_body)
    return f"""# REQ-{req_id}: {title}

**Level**: {level} | **Implements**: {implements} | **Status**: {status}

{full_body}

*End* *{title}* | **Hash**: {req_hash}
"""


class TestRationaleExtraction(unittest.TestCase):
    """Test Phase 2: Rationale extraction from requirements"""

    def setUp(self):
        """Create temporary directory with test requirements"""
        self.test_dir = tempfile.mkdtemp()
        self.spec_dir = Path(self.test_dir) / "spec"
        self.spec_dir.mkdir()

    def tearDown(self):
        """Clean up temporary directory"""
        shutil.rmtree(self.test_dir)

    def test_parser_extracts_rationale(self):
        """Parser should extract rationale section separately"""
        from requirement_parser import RequirementParser

        test_req = self.spec_dir / "prd-test.md"
        test_req.write_text(make_requirement_with_rationale(
            'p00001', 'Test Requirement', 'PRD', '-', 'Active',
            'The system SHALL do something.',
            'This is needed because of business reasons.'
        ))

        parser = RequirementParser(self.spec_dir)
        result = parser.parse_all()

        req = result.requirements['p00001']
        self.assertIn('business reasons', req.rationale)

    def test_parser_body_excludes_rationale(self):
        """Body should not include rationale section"""
        from requirement_parser import RequirementParser

        test_req = self.spec_dir / "prd-test.md"
        test_req.write_text(make_requirement_with_rationale(
            'p00001', 'Test Requirement', 'PRD', '-', 'Active',
            'The system SHALL do something.',
            'This is the rationale text.'
        ))

        parser = RequirementParser(self.spec_dir)
        result = parser.parse_all()

        req = result.requirements['p00001']
        # Body should contain the requirement statement
        self.assertIn('SHALL do something', req.body)
        # Body should NOT contain rationale marker or text
        self.assertNotIn('**Rationale**', req.body)
        self.assertNotIn('rationale text', req.body)

    def test_requirement_without_rationale(self):
        """Requirements without rationale should have empty rationale field"""
        from requirement_parser import RequirementParser

        test_req = self.spec_dir / "prd-test.md"
        test_req.write_text(make_requirement('p00001', 'Test Requirement', 'PRD', '-', 'Active',
                                             'The system SHALL do something.'))

        parser = RequirementParser(self.spec_dir)
        result = parser.parse_all()

        req = result.requirements['p00001']
        self.assertEqual(req.rationale, '')


class TestPlanningExports(unittest.TestCase):
    """Test Phase 5: Planning exports for sprint planning"""

    def setUp(self):
        """Create temporary directory with mixed requirements"""
        self.test_dir = tempfile.mkdtemp()
        self.spec_dir = Path(self.test_dir) / "spec"
        self.impl_dir = Path(self.test_dir) / "src"
        self.spec_dir.mkdir()
        self.impl_dir.mkdir()

        # Create requirements with different statuses
        prd_file = self.spec_dir / "prd-test.md"
        content = make_requirement('p00001', 'Active PRD', 'PRD', '-', 'Active', 'Active requirement.')
        content += "\n" + make_requirement('p00002', 'Draft PRD', 'PRD', '-', 'Draft', 'Draft requirement.')
        prd_file.write_text(content)

        # Create implemented dev requirement
        dev_file = self.spec_dir / "dev-test.md"
        dev_file.write_text(make_requirement('d00001', 'Implemented Dev', 'Dev', 'p00001', 'Active',
                                             'Has implementation.'))

        # Create implementation file
        impl_file = self.impl_dir / "impl.py"
        impl_file.write_text("# REQ-d00001: Implementation\ndef test(): pass")

        self.gen = TraceabilityGenerator(self.spec_dir, impl_dirs=[self.impl_dir])
        self.gen._parse_requirements()
        self.gen._scan_implementation_files()

    def tearDown(self):
        """Clean up temporary directory"""
        shutil.rmtree(self.test_dir)

    def test_planning_csv_has_required_columns(self):
        """Planning CSV should have all specified columns"""
        csv_output = self.gen._generate_planning_csv()
        # Check for required columns
        self.assertIn('REQ ID', csv_output)
        self.assertIn('Title', csv_output)
        self.assertIn('Level', csv_output)
        self.assertIn('Status', csv_output)
        self.assertIn('Impl Status', csv_output)

    def test_planning_csv_filters_actionable(self):
        """Planning export should include Active items, exclude fully-traced"""
        csv_output = self.gen._generate_planning_csv()
        # Should include active unimplemented (p00001 has child but not fully traced)
        self.assertIn('p00001', csv_output)
        # Should include draft (needs work)
        self.assertIn('p00002', csv_output)

    def test_coverage_report_format(self):
        """Coverage report should show summary statistics"""
        report = self.gen._generate_coverage_report()
        # Should have summary stats
        self.assertIn('Total', report)
        self.assertIn('PRD', report)
        # Should show coverage percentages or counts
        self.assertTrue('%' in report or 'Unimplemented' in report or 'Full' in report)


class TestImplementationCoverage(unittest.TestCase):
    """Test Phase 4: Implementation coverage indicators and filtering"""

    def setUp(self):
        """Create temporary directory with hierarchical requirements"""
        self.test_dir = tempfile.mkdtemp()
        self.spec_dir = Path(self.test_dir) / "spec"
        self.impl_dir = Path(self.test_dir) / "src"
        self.spec_dir.mkdir()
        self.impl_dir.mkdir()

        # Create PRD requirement (parent)
        prd_file = self.spec_dir / "prd-test.md"
        prd_file.write_text(make_requirement('p00001', 'Parent Requirement', 'PRD', '-', 'Active',
                                             'The system SHALL have children.'))

        # Create Dev requirement (child that implements PRD)
        dev_file = self.spec_dir / "dev-test.md"
        dev_file.write_text(make_requirement('d00001', 'Child Implementation', 'Dev', 'p00001', 'Active',
                                             'Implementation of parent.'))

        # Create implementation file that references the Dev req
        impl_file = self.impl_dir / "impl.py"
        impl_file.write_text("# REQ-d00001: Implementation\ndef test(): pass")

        self.gen = TraceabilityGenerator(self.spec_dir, impl_dirs=[self.impl_dir])
        self.gen._parse_requirements()
        self.gen._scan_implementation_files()

    def tearDown(self):
        """Clean up temporary directory"""
        shutil.rmtree(self.test_dir)

    def test_coverage_calculation(self):
        """Should calculate children traced for each REQ"""
        # p00001 has 1 child (d00001)
        coverage = self.gen._calculate_coverage('p00001')
        self.assertIn('children', coverage)
        self.assertIn('traced', coverage)
        self.assertEqual(coverage['children'], 1)

    def test_coverage_indicator_format(self):
        """Coverage should display using indicator symbols"""
        html = self.gen._generate_html()
        # Should have coverage indicator in output (filled/empty circles)
        self.assertTrue('●' in html or '○' in html or 'coverage' in html.lower())

    def test_implementation_status_unimplemented(self):
        """Unimplemented status for PRD with no children or code refs"""
        # Create orphan PRD requirement
        orphan_file = self.spec_dir / "prd-orphan.md"
        orphan_file.write_text(make_requirement('p00002', 'Orphan Requirement', 'PRD', '-', 'Active',
                                                'This has no implementations.'))

        gen = TraceabilityGenerator(self.spec_dir)
        gen._parse_requirements()

        status = gen._get_implementation_status('p00002')
        self.assertEqual(status, 'Unimplemented')

    def test_implementation_status_full(self):
        """Full status for requirement with complete traceability"""
        # d00001 has code reference
        status = self.gen._get_implementation_status('d00001')
        self.assertEqual(status, 'Full')


class TestEmbeddedContentMode(unittest.TestCase):
    """Test Phase 3: Embedded content mode with side panel"""

    def setUp(self):
        """Create temporary directory with test requirements"""
        self.test_dir = tempfile.mkdtemp()
        self.spec_dir = Path(self.test_dir) / "spec"
        self.spec_dir.mkdir()

        # Create test requirement with rationale
        test_req = self.spec_dir / "prd-test.md"
        test_req.write_text(make_requirement_with_rationale(
            'p00001', 'Test Requirement', 'PRD', '-', 'Active',
            'The system SHALL do something.',
            'This is the rationale.'
        ))

        self.gen = TraceabilityGenerator(self.spec_dir)
        self.gen._parse_requirements()

    def tearDown(self):
        """Clean up temporary directory"""
        shutil.rmtree(self.test_dir)

    def test_embedded_html_has_json_data(self):
        """Embedded HTML should contain REQ content as JSON"""
        html = self.gen._generate_html(embed_content=True)
        # Should have JSON data script tag
        self.assertIn('<script id="req-content-data" type="application/json">', html)
        # Should contain REQ data
        self.assertIn('"p00001"', html)

    def test_embedded_html_has_side_panel(self):
        """Embedded HTML should have side panel container"""
        html = self.gen._generate_html(embed_content=True)
        # Should have side panel div
        self.assertIn('id="req-panel"', html)
        self.assertIn('class="side-panel', html)

    def test_json_contains_body_and_rationale(self):
        """JSON data should include body and rationale fields"""
        html = self.gen._generate_html(embed_content=True)
        # Should contain body content
        self.assertIn('SHALL do something', html)
        # Should contain rationale
        self.assertIn('rationale', html.lower())

    def test_non_embedded_mode_no_json(self):
        """Non-embedded mode should not include JSON data"""
        html = self.gen._generate_html(embed_content=False)
        # Should NOT have JSON data script tag
        self.assertNotIn('<script id="req-content-data"', html)

    def test_side_panel_javascript_functions(self):
        """Embedded HTML should include side panel JS functions"""
        html = self.gen._generate_html(embed_content=True)
        # Should have key JavaScript functions
        self.assertIn('openReqPanel', html)
        self.assertIn('closeReqCard', html)
        self.assertIn('closeAllCards', html)

    def test_embedded_mode_uses_onclick_not_href(self):
        """In embedded mode, REQ clicks should open side panel, not navigate away"""
        html = self.gen._generate_html(embed_content=True)
        # Should have onclick handler to open panel
        self.assertIn("onclick", html)
        self.assertIn("openReqPanel", html)
        # REQ title clicks should NOT navigate to external file in embedded mode
        # (links should either use onclick or href="#" to prevent navigation)
        self.assertNotIn('href="../spec/', html)


class TestDeepLinksAndLegend(unittest.TestCase):
    """Test Phase 1: Deep links to source files and symbol legend"""

    def setUp(self):
        """Create temporary directory with test requirement"""
        self.test_dir = tempfile.mkdtemp()
        self.spec_dir = Path(self.test_dir) / "spec"
        self.spec_dir.mkdir()

        # Create test requirement file: prd-test.md with p00001
        test_req = self.spec_dir / "prd-test.md"
        test_req.write_text(make_requirement('p00001', 'Test Requirement', 'PRD', '-', 'Active',
                                             'This requirement SHALL be tested.'))

        self.gen = TraceabilityGenerator(self.spec_dir)
        self.gen._parse_requirements()

    def tearDown(self):
        """Clean up temporary directory"""
        shutil.rmtree(self.test_dir)

    def test_html_req_title_is_link(self):
        """REQ title should link to source file with anchor"""
        html = self.gen._generate_html()
        # Should have link to source file with REQ anchor
        # Path is relative to output file location (which defaults to repo root in tests)
        self.assertIn('href="spec/prd-test.md#REQ-p00001"', html)

    def test_html_file_line_is_link(self):
        """File:Line should link to source with line anchor"""
        html = self.gen._generate_html()
        # Should have link to source file with line anchor
        # The requirement is at line 1 in the test file
        self.assertIn('href="spec/prd-test.md#L', html)

    def test_html_has_legend_section(self):
        """HTML output should include symbol legend"""
        html = self.gen._generate_html()
        # Should have legend section with key symbols
        self.assertIn('Legend', html)
        self.assertIn('✅', html)  # Active
        self.assertIn('🚧', html)  # Draft
        self.assertIn('⚠️', html)  # Deprecated

    def test_markdown_req_has_link(self):
        """Markdown REQ should have clickable link to source"""
        markdown = self.gen._generate_markdown()
        # Should have markdown link format
        # Path is relative to output file location (which defaults to repo root in tests)
        self.assertIn('[REQ-p00001', markdown)
        self.assertIn('spec/prd-test.md', markdown)

    def test_markdown_has_legend_section(self):
        """Markdown output should include symbol legend"""
        markdown = self.gen._generate_markdown()
        # Should have legend section
        self.assertIn('## Legend', markdown)
        self.assertIn('✅', markdown)  # Active
        self.assertIn('🚧', markdown)  # Draft


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
    suite.addTests(loader.loadTestsFromTestCase(TestDeepLinksAndLegend))
    suite.addTests(loader.loadTestsFromTestCase(TestRationaleExtraction))
    suite.addTests(loader.loadTestsFromTestCase(TestEmbeddedContentMode))
    suite.addTests(loader.loadTestsFromTestCase(TestImplementationCoverage))
    suite.addTests(loader.loadTestsFromTestCase(TestPlanningExports))

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
