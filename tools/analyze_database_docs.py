#!/usr/bin/env python3
"""
Analyze database documentation to identify generic vs diary-specific content.
This helps plan refactoring into reusable event-sourcing components.
"""

import re
import sys
from pathlib import Path
from typing import Dict, List, Set, Tuple

# Keywords that indicate diary-specific content
DIARY_KEYWORDS = [
    'diary', 'patient', 'symptom', 'questionnaire', 'clinical trial',
    'investigator', 'site', 'sponsor', 'enrollment', 'adverse event'
]

# Keywords that indicate generic event-sourcing content
GENERIC_KEYWORDS = [
    'event store', 'event sourcing', 'CQRS', 'materialized view',
    'read model', 'command', 'query', 'aggregate', 'event log',
    'append-only', 'immutable', 'audit trail', 'conflict resolution',
    'optimistic concurrency', 'version', 'sequence'
]

class RequirementAnalyzer:
    def __init__(self, spec_dir: Path):
        self.spec_dir = spec_dir
        self.requirements: Dict[str, Dict] = {}
        self.diary_specific_reqs: Set[str] = set()
        self.generic_reqs: Set[str] = set()

    def analyze_file(self, file_path: Path) -> Dict:
        """Analyze a single markdown file."""
        content = file_path.read_text()

        result = {
            'file': file_path.name,
            'total_lines': len(content.split('\n')),
            'requirements': [],
            'diary_mentions': 0,
            'generic_mentions': 0,
            'diary_score': 0,
            'generic_score': 0
        }

        # Find all requirements
        req_pattern = r'### (REQ-[pod]\d{5}): (.+?)$'
        for match in re.finditer(req_pattern, content, re.MULTILINE):
            req_id = match.group(1)
            req_title = match.group(2)

            # Extract requirement body
            start_pos = match.end()
            next_heading = re.search(r'\n### ', content[start_pos:])
            if next_heading:
                req_body = content[start_pos:start_pos + next_heading.start()]
            else:
                req_body = content[start_pos:start_pos + 1000]  # Next 1000 chars

            # Analyze requirement
            req_analysis = self._analyze_requirement(req_id, req_title, req_body)
            result['requirements'].append(req_analysis)
            self.requirements[req_id] = req_analysis

            if req_analysis['is_diary_specific']:
                self.diary_specific_reqs.add(req_id)
            if req_analysis['is_generic']:
                self.generic_reqs.add(req_id)

        # Count mentions in full file
        content_lower = content.lower()
        for keyword in DIARY_KEYWORDS:
            count = content_lower.count(keyword)
            result['diary_mentions'] += count
            result['diary_score'] += count * 10  # Weight

        for keyword in GENERIC_KEYWORDS:
            count = content_lower.count(keyword)
            result['generic_mentions'] += count
            result['generic_score'] += count * 10

        return result

    def _analyze_requirement(self, req_id: str, title: str, body: str) -> Dict:
        """Analyze a single requirement."""
        text = (title + ' ' + body).lower()

        diary_matches = []
        generic_matches = []

        for keyword in DIARY_KEYWORDS:
            if keyword in text:
                count = text.count(keyword)
                diary_matches.append((keyword, count))

        for keyword in GENERIC_KEYWORDS:
            if keyword in text:
                count = text.count(keyword)
                generic_matches.append((keyword, count))

        diary_score = sum(count for _, count in diary_matches)
        generic_score = sum(count for _, count in generic_matches)

        # Determine classification
        if diary_score > generic_score * 2:
            classification = 'diary-specific'
        elif generic_score > diary_score * 2:
            classification = 'generic'
        elif diary_score > 0 and generic_score > 0:
            classification = 'mixed'
        else:
            classification = 'unknown'

        return {
            'req_id': req_id,
            'title': title,
            'diary_keywords': diary_matches,
            'generic_keywords': generic_matches,
            'diary_score': diary_score,
            'generic_score': generic_score,
            'classification': classification,
            'is_diary_specific': diary_score > 0,
            'is_generic': generic_score > 0
        }

    def analyze_all_database_files(self) -> Dict:
        """Analyze all database-related files."""
        results = []

        patterns = ['*database*.md', 'prd-flutter-event-sourcing.md']
        for pattern in patterns:
            for file_path in self.spec_dir.glob(pattern):
                if file_path.is_file():
                    result = self.analyze_file(file_path)
                    results.append(result)

        return {
            'files': results,
            'summary': self._generate_summary(results)
        }

    def _generate_summary(self, results: List[Dict]) -> Dict:
        """Generate summary statistics."""
        total_reqs = sum(len(r['requirements']) for r in results)

        req_classifications = {}
        for result in results:
            for req in result['requirements']:
                req_classifications[req['req_id']] = req['classification']

        classification_counts = {
            'generic': sum(1 for c in req_classifications.values() if c == 'generic'),
            'diary-specific': sum(1 for c in req_classifications.values() if c == 'diary-specific'),
            'mixed': sum(1 for c in req_classifications.values() if c == 'mixed'),
            'unknown': sum(1 for c in req_classifications.values() if c == 'unknown')
        }

        return {
            'total_files': len(results),
            'total_requirements': total_reqs,
            'classification_counts': classification_counts,
            'diary_specific_reqs': sorted(list(self.diary_specific_reqs)),
            'generic_reqs': sorted(list(self.generic_reqs))
        }

    def generate_report(self, output_path: Path = None):
        """Generate markdown report."""
        analysis = self.analyze_all_database_files()

        report = ["# Database Documentation Analysis",
                  "",
                  "## Summary",
                  "",
                  f"- **Total Files Analyzed**: {analysis['summary']['total_files']}",
                  f"- **Total Requirements**: {analysis['summary']['total_requirements']}",
                  "",
                  "### Requirement Classification",
                  ""]

        for classification, count in analysis['summary']['classification_counts'].items():
            pct = (count / analysis['summary']['total_requirements'] * 100) if analysis['summary']['total_requirements'] > 0 else 0
            report.append(f"- **{classification.title()}**: {count} ({pct:.1f}%)")

        report.extend(["", "---", "", "## File Analysis", ""])

        for file_result in analysis['files']:
            report.append(f"### {file_result['file']}")
            report.append("")
            report.append(f"- Lines: {file_result['total_lines']}")
            report.append(f"- Requirements: {len(file_result['requirements'])}")
            report.append(f"- Diary Score: {file_result['diary_score']} ({file_result['diary_mentions']} mentions)")
            report.append(f"- Generic Score: {file_result['generic_score']} ({file_result['generic_mentions']} mentions)")

            if file_result['diary_score'] > file_result['generic_score']:
                report.append(f"- **Assessment**: Diary-specific ({file_result['diary_score']/max(file_result['generic_score'],1):.1f}x more diary content)")
            elif file_result['generic_score'] > file_result['diary_score']:
                report.append(f"- **Assessment**: Generic/Reusable ({file_result['generic_score']/max(file_result['diary_score'],1):.1f}x more generic content)")
            else:
                report.append("- **Assessment**: Balanced/Mixed")

            report.append("")
            report.append("#### Requirements:")
            for req in file_result['requirements']:
                report.append(f"- **{req['req_id']}**: {req['title']}")
                report.append(f"  - Classification: `{req['classification']}`")
                if req['diary_keywords']:
                    keywords = ', '.join(f"{kw} ({cnt})" for kw, cnt in req['diary_keywords'][:5])
                    report.append(f"  - Diary keywords: {keywords}")
                if req['generic_keywords']:
                    keywords = ', '.join(f"{kw} ({cnt})" for kw, cnt in req['generic_keywords'][:5])
                    report.append(f"  - Generic keywords: {keywords}")

            report.append("")

        report.extend(["---", "", "## Refactoring Recommendations", ""])

        # Group requirements by classification
        report.append("### Requirements by Classification")
        report.append("")

        for classification in ['generic', 'mixed', 'diary-specific', 'unknown']:
            reqs_in_class = [
                (req_id, self.requirements[req_id])
                for req_id in sorted(self.requirements.keys())
                if self.requirements[req_id]['classification'] == classification
            ]

            if reqs_in_class:
                report.append(f"#### {classification.title()} ({len(reqs_in_class)} requirements)")
                report.append("")
                for req_id, req_data in reqs_in_class:
                    report.append(f"- **{req_id}**: {req_data['title']}")
                report.append("")

        report_text = '\n'.join(report)

        if output_path:
            output_path.write_text(report_text)
            print(f"Report written to: {output_path}")

        return report_text


def main():
    spec_dir = Path(__file__).parent.parent / 'spec'
    analyzer = RequirementAnalyzer(spec_dir)

    # Generate report
    output_path = Path(__file__).parent.parent / 'untracked-notes' / 'database-refactoring-analysis.md'
    output_path.parent.mkdir(exist_ok=True)

    report = analyzer.generate_report(output_path)

    # Also print summary to console
    analysis = analyzer.analyze_all_database_files()
    print("\n" + "="*60)
    print("DATABASE DOCUMENTATION ANALYSIS SUMMARY")
    print("="*60)
    print(f"\nTotal Requirements: {analysis['summary']['total_requirements']}")
    print("\nClassification Breakdown:")
    for classification, count in analysis['summary']['classification_counts'].items():
        pct = (count / analysis['summary']['total_requirements'] * 100) if analysis['summary']['total_requirements'] > 0 else 0
        print(f"  {classification:20s}: {count:3d} ({pct:5.1f}%)")

    print(f"\nDetailed report: {output_path}")


if __name__ == '__main__':
    main()
