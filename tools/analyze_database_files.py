#!/usr/bin/env python3
"""
Analyze database files for repetitive content and recommend consolidation.
Focus on ops-database* and dev-database* files.
"""

import re
from pathlib import Path
from typing import Dict, List, Set
from collections import defaultdict


def analyze_file(file_path: Path) -> Dict:
    """Analyze a single file for content patterns."""
    content = file_path.read_text()

    result = {
        'file': file_path.name,
        'size': len(content),
        'lines': len(content.split('\n')),
        'requirements': [],
        'sections': [],
        'key_terms': defaultdict(int)
    }

    # Find requirements
    req_pattern = r'### (REQ-[pod]\d{5}): (.+?)$'
    for match in re.finditer(req_pattern, content, re.MULTILINE):
        result['requirements'].append({
            'id': match.group(1),
            'title': match.group(2)
        })

    # Find major sections
    section_pattern = r'^## (.+?)$'
    for match in re.finditer(section_pattern, content, re.MULTILINE):
        result['sections'].append(match.group(1))

    # Count key terms
    key_terms = [
        'event sourcing', 'supabase', 'postgres', 'schema', 'migration',
        'trigger', 'function', 'policy', 'rls', 'audit', 'query',
        'table', 'index', 'backup', 'restore', 'deployment'
    ]

    content_lower = content.lower()
    for term in key_terms:
        count = content_lower.count(term)
        if count > 0:
            result['key_terms'][term] = count

    return result


def find_content_overlap(file1_path: Path, file2_path: Path) -> Dict:
    """Find overlapping content between two files."""
    content1 = file1_path.read_text().lower()
    content2 = file2_path.read_text().lower()

    # Split into paragraphs
    paragraphs1 = set([p.strip() for p in content1.split('\n\n') if len(p.strip()) > 50])
    paragraphs2 = set([p.strip() for p in content2.split('\n\n') if len(p.strip()) > 50])

    # Find exact matches
    exact_overlap = paragraphs1 & paragraphs2

    # Find similar content (same sentences)
    sentences1 = set([s.strip() for s in content1.split('.') if len(s.strip()) > 30])
    sentences2 = set([s.strip() for s in content2.split('.') if len(s.strip()) > 30])

    sentence_overlap = sentences1 & sentences2

    return {
        'file1': file1_path.name,
        'file2': file2_path.name,
        'exact_paragraphs': len(exact_overlap),
        'similar_sentences': len(sentence_overlap),
        'overlap_score': len(sentence_overlap) / max(len(sentences1), len(sentences2)) if sentences1 and sentences2 else 0
    }


def main():
    spec_dir = Path('spec')

    # Analyze all database files
    database_files = [
        'dev-database.md',
        'dev-database-queries.md',
        'dev-database-reference.md',
        'ops-database-setup.md',
        'ops-database-migration.md'
    ]

    print("\n" + "="*80)
    print("DATABASE FILES ANALYSIS")
    print("="*80 + "\n")

    analyses = {}
    for filename in database_files:
        file_path = spec_dir / filename
        if file_path.exists():
            analysis = analyze_file(file_path)
            analyses[filename] = analysis

            print(f"📄 {filename}")
            print(f"   Size: {analysis['size']:,} bytes ({analysis['lines']:,} lines)")
            print(f"   Requirements: {len(analysis['requirements'])}")
            if analysis['requirements']:
                for req in analysis['requirements']:
                    print(f"      • {req['id']}: {req['title']}")
            print(f"   Major Sections: {len(analysis['sections'])}")
            for section in analysis['sections'][:5]:
                print(f"      • {section}")
            if len(analysis['sections']) > 5:
                print(f"      ... and {len(analysis['sections']) - 5} more")

            print(f"   Top Key Terms:")
            sorted_terms = sorted(analysis['key_terms'].items(), key=lambda x: x[1], reverse=True)
            for term, count in sorted_terms[:5]:
                print(f"      • {term}: {count} mentions")
            print()

    print("\n" + "="*80)
    print("CONTENT OVERLAP ANALYSIS")
    print("="*80 + "\n")

    # Compare pairs of files
    comparisons = [
        ('dev-database.md', 'dev-database-queries.md'),
        ('dev-database.md', 'dev-database-reference.md'),
        ('dev-database-queries.md', 'dev-database-reference.md'),
        ('ops-database-setup.md', 'ops-database-migration.md'),
    ]

    for file1, file2 in comparisons:
        path1 = spec_dir / file1
        path2 = spec_dir / file2
        if path1.exists() and path2.exists():
            overlap = find_content_overlap(path1, path2)
            print(f"📊 {file1} ↔️ {file2}")
            print(f"   Exact paragraph matches: {overlap['exact_paragraphs']}")
            print(f"   Similar sentences: {overlap['similar_sentences']}")
            print(f"   Overlap score: {overlap['overlap_score']:.1%}")
            print()

    print("\n" + "="*80)
    print("RECOMMENDATIONS")
    print("="*80 + "\n")

    # Generate recommendations
    print("Based on the analysis, here are consolidation opportunities:\n")

    # Check for files without requirements
    for filename, analysis in analyses.items():
        if not analysis['requirements']:
            print(f"⚠️  {filename}")
            print(f"   • No formal requirements (REQ-*)")
            print(f"   • {analysis['size']:,} bytes of content")
            print(f"   • Consider: Can this be merged into a requirements-bearing file?")
            print()

    # Check for files with high key term overlap
    print("🔍 Files with potential topic overlap:\n")

    dev_db = analyses.get('dev-database.md', {})
    dev_queries = analyses.get('dev-database-queries.md', {})
    dev_ref = analyses.get('dev-database-reference.md', {})

    if dev_db and dev_queries:
        db_terms = set(dev_db.get('key_terms', {}).keys())
        query_terms = set(dev_queries.get('key_terms', {}).keys())
        overlap = db_terms & query_terms
        print(f"   dev-database.md ↔️ dev-database-queries.md")
        print(f"   • Shared topics: {len(overlap)} terms")
        print(f"   • {', '.join(list(overlap)[:5])}")
        print()

    if dev_db and dev_ref:
        db_terms = set(dev_db.get('key_terms', {}).keys())
        ref_terms = set(dev_ref.get('key_terms', {}).keys())
        overlap = db_terms & ref_terms
        print(f"   dev-database.md ↔️ dev-database-reference.md")
        print(f"   • Shared topics: {len(overlap)} terms")
        print(f"   • {', '.join(list(overlap)[:5])}")
        print()

    print("\n" + "="*80)
    print("DETAILED ANALYSIS SAVED")
    print("="*80)
    print("\nDetailed report: untracked-notes/database-files-analysis.txt")


if __name__ == '__main__':
    main()
