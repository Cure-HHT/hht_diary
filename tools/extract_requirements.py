#!/usr/bin/env python3
"""
Extract requirements from markdown files into individual requirement files.
This enables safe manipulation and reorganization without losing information.

Usage:
    python3 extract_requirements.py spec/prd-flutter-event-sourcing.md
    python3 extract_requirements.py --all  # Extract all spec files
"""

import re
import sys
from pathlib import Path
from typing import Dict, List, Tuple
import argparse


class RequirementExtractor:
    def __init__(self, output_dir: Path):
        self.output_dir = output_dir
        self.output_dir.mkdir(parents=True, exist_ok=True)

        # Track what we extract
        self.extracted_reqs: Dict[str, Dict] = {}

    def extract_from_file(self, file_path: Path) -> Dict:
        """Extract all requirements from a markdown file."""
        content = file_path.read_text()

        # Find all requirements
        # Pattern: ### REQ-[pod]NNNNN: Title
        req_pattern = r'^### (REQ-[pod]\d{5}): (.+?)$'

        matches = list(re.finditer(req_pattern, content, re.MULTILINE))

        if not matches:
            print(f"No requirements found in {file_path.name}")
            return {'file': file_path.name, 'requirements': []}

        result = {
            'file': file_path.name,
            'requirements': []
        }

        for i, match in enumerate(matches):
            req_id = match.group(1)
            req_title = match.group(2)

            # Find the end of this requirement (next ### heading or end of file)
            start_pos = match.start()
            if i + 1 < len(matches):
                end_pos = matches[i + 1].start()
            else:
                # Look for next ### heading
                next_heading = re.search(r'\n### ', content[match.end():])
                if next_heading:
                    end_pos = match.end() + next_heading.start()
                else:
                    end_pos = len(content)

            req_full_text = content[start_pos:end_pos].rstrip()

            # Extract metadata from requirement body
            metadata = self._extract_metadata(req_full_text)

            req_data = {
                'req_id': req_id,
                'title': req_title,
                'full_text': req_full_text,
                'source_file': file_path.name,
                'level': metadata['level'],
                'implements': metadata['implements'],
                'status': metadata['status']
            }

            # Save individual requirement file
            self._save_requirement(req_data)

            result['requirements'].append(req_data)
            self.extracted_reqs[req_id] = req_data

        print(f"Extracted {len(matches)} requirements from {file_path.name}")
        return result

    def _extract_metadata(self, req_text: str) -> Dict:
        """Extract Level, Implements, Status from requirement text."""
        metadata = {
            'level': 'Unknown',
            'implements': [],
            'status': 'Unknown'
        }

        # Look for: **Level**: PRD | **Implements**: ... | **Status**: Active
        meta_pattern = r'\*\*Level\*\*:\s*(\w+)\s*\|\s*\*\*Implements\*\*:\s*([^|]+)\|\s*\*\*Status\*\*:\s*(\w+)'
        match = re.search(meta_pattern, req_text)

        if match:
            metadata['level'] = match.group(1)
            implements_str = match.group(2).strip()
            if implements_str != '-':
                # Split by comma and clean up
                metadata['implements'] = [
                    impl.strip()
                    for impl in implements_str.split(',')
                    if impl.strip()
                ]
            metadata['status'] = match.group(3)

        return metadata

    def _save_requirement(self, req_data: Dict):
        """Save individual requirement to a file."""
        req_filename = f"{req_data['req_id']}.md"
        req_path = self.output_dir / req_filename

        # Add metadata header
        header = f"""---
req_id: {req_data['req_id']}
title: {req_data['title']}
level: {req_data['level']}
implements: {', '.join(req_data['implements']) if req_data['implements'] else '-'}
status: {req_data['status']}
source_file: {req_data['source_file']}
---

"""

        content = header + req_data['full_text']
        req_path.write_text(content)

    def extract_preamble(self, file_path: Path) -> str:
        """Extract everything before the first requirement."""
        content = file_path.read_text()

        # Find first requirement
        first_req = re.search(r'^### REQ-[pod]\d{5}:', content, re.MULTILINE)

        if first_req:
            preamble = content[:first_req.start()].rstrip()

            # Save preamble
            preamble_path = self.output_dir / f"{file_path.stem}_preamble.md"
            preamble_path.write_text(preamble)

            print(f"Extracted preamble from {file_path.name} ({len(preamble)} chars)")
            return preamble

        return ""

    def generate_manifest(self):
        """Generate manifest file listing all extracted requirements."""
        manifest_path = self.output_dir / "MANIFEST.md"

        lines = [
            "# Extracted Requirements Manifest",
            "",
            f"Total requirements extracted: {len(self.extracted_reqs)}",
            "",
            "## Requirements by Source File",
            ""
        ]

        # Group by source file
        by_file: Dict[str, List[str]] = {}
        for req_id, req_data in self.extracted_reqs.items():
            source = req_data['source_file']
            if source not in by_file:
                by_file[source] = []
            by_file[source].append(req_id)

        for source_file in sorted(by_file.keys()):
            lines.append(f"### {source_file}")
            lines.append("")
            for req_id in sorted(by_file[source_file]):
                req_data = self.extracted_reqs[req_id]
                lines.append(f"- **{req_id}**: {req_data['title']}")
                lines.append(f"  - Level: {req_data['level']}, Status: {req_data['status']}")
                if req_data['implements']:
                    lines.append(f"  - Implements: {', '.join(req_data['implements'])}")
            lines.append("")

        manifest_path.write_text('\n'.join(lines))
        print(f"\nManifest written to: {manifest_path}")


def main():
    parser = argparse.ArgumentParser(description='Extract requirements from spec files')
    parser.add_argument('files', nargs='*', help='Spec files to extract from')
    parser.add_argument('--all', action='store_true', help='Extract from all spec files')
    parser.add_argument('--output-dir', default='untracked-notes/extracted-reqs',
                        help='Output directory for extracted requirements')

    args = parser.parse_args()

    output_dir = Path(args.output_dir)
    extractor = RequirementExtractor(output_dir)

    files_to_process = []

    if args.all:
        spec_dir = Path('spec')
        files_to_process = list(spec_dir.glob('*.md'))
    elif args.files:
        files_to_process = [Path(f) for f in args.files]
    else:
        parser.print_help()
        return

    print(f"\n{'='*60}")
    print("EXTRACTING REQUIREMENTS")
    print(f"{'='*60}\n")

    for file_path in files_to_process:
        if not file_path.exists():
            print(f"Warning: {file_path} does not exist, skipping")
            continue

        # Extract preamble
        extractor.extract_preamble(file_path)

        # Extract requirements
        extractor.extract_from_file(file_path)

    # Generate manifest
    extractor.generate_manifest()

    print(f"\n{'='*60}")
    print(f"EXTRACTION COMPLETE")
    print(f"{'='*60}")
    print(f"Output directory: {output_dir}")
    print(f"Total requirements: {len(extractor.extracted_reqs)}")
    print(f"\nNext steps:")
    print(f"  1. Review extracted files in {output_dir}/")
    print(f"  2. Use transformation tools to modify requirements")
    print(f"  3. Use recombination tool to create new spec files")


if __name__ == '__main__':
    main()
