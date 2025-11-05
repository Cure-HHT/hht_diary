#!/usr/bin/env python3
"""
Recombine extracted requirements into new spec files based on configuration.

Usage:
    python3 recombine_requirements.py --config refactor-config.yaml
    python3 recombine_requirements.py --create-config  # Generate template config
"""

import re
from pathlib import Path
from typing import Dict, List
import argparse
import json


class RequirementRecombiner:
    def __init__(self, reqs_dir: Path):
        self.reqs_dir = reqs_dir

    def load_requirement(self, req_id: str) -> Dict:
        """Load a requirement file."""
        req_path = self.reqs_dir / f"{req_id}.md"

        if not req_path.exists():
            raise FileNotFoundError(f"Requirement {req_id} not found at {req_path}")

        content = req_path.read_text()

        # Parse metadata
        metadata = {}
        req_body = content

        # Extract metadata block
        if content.startswith('---'):
            end_meta = content.find('---', 3)
            if end_meta > 0:
                meta_block = content[3:end_meta].strip()
                req_body = content[end_meta + 3:].strip()

                for line in meta_block.split('\n'):
                    if ':' in line:
                        key, value = line.split(':', 1)
                        metadata[key.strip()] = value.strip()

        # Extract just the requirement portion (without metadata header in body)
        # Find the ### REQ- line
        req_start = re.search(r'^### REQ-', req_body, re.MULTILINE)
        if req_start:
            req_body = req_body[req_start.start():]

        return {
            'req_id': req_id,
            'metadata': metadata,
            'body': req_body
        }

    def load_preamble(self, preamble_name: str) -> str:
        """Load a preamble file."""
        preamble_path = self.reqs_dir / preamble_name

        if not preamble_path.exists():
            print(f"Warning: Preamble {preamble_name} not found")
            return ""

        return preamble_path.read_text()

    def create_spec_file(self, config: Dict, output_path: Path):
        """Create a spec file from configuration."""
        sections = []

        # Add preamble if specified
        if 'preamble' in config:
            preamble = self.load_preamble(config['preamble'])
            if preamble:
                sections.append(preamble)

        # Add requirements in order
        if 'requirements' in config:
            for req_id in config['requirements']:
                try:
                    req_data = self.load_requirement(req_id)
                    sections.append(req_data['body'])
                except FileNotFoundError as e:
                    print(f"Warning: {e}")

        # Add custom sections
        if 'custom_sections' in config:
            for section in config['custom_sections']:
                sections.append(section)

        # Combine with proper spacing
        content = '\n\n---\n\n'.join(sections)

        # Ensure trailing newline
        if not content.endswith('\n'):
            content += '\n'

        output_path.write_text(content)
        print(f"Created {output_path}")

    def create_from_config_file(self, config_path: Path):
        """Create spec files from a configuration file."""
        if not config_path.exists():
            print(f"Error: Config file {config_path} not found")
            return

        with open(config_path) as f:
            config = json.load(f)

        output_dir = Path(config.get('output_dir', 'spec'))
        output_dir.mkdir(parents=True, exist_ok=True)

        for file_config in config['files']:
            filename = file_config['filename']
            output_path = output_dir / filename

            print(f"\nCreating {filename}...")
            self.create_spec_file(file_config, output_path)

        print(f"\nAll files created in {output_dir}/")


def create_template_config():
    """Create a template configuration file."""
    template = {
        "output_dir": "spec",
        "files": [
            {
                "filename": "prd-event-sourcing-system.md",
                "description": "Generic event-sourcing system PRD",
                "preamble": "prd-flutter-event-sourcing_preamble.md",
                "requirements": [
                    "REQ-p01000",
                    "REQ-p01001",
                    "REQ-p01002",
                    "REQ-p01003",
                    "REQ-p01004",
                    "REQ-p01005",
                    "REQ-p01006",
                    "REQ-p01007",
                    "REQ-p01008",
                    "REQ-p01009",
                    "REQ-p01010",
                    "REQ-p01011",
                    "REQ-p01012",
                    "REQ-p01013",
                    "REQ-p01014",
                    "REQ-p01015",
                    "REQ-p01016",
                    "REQ-p01017",
                    "REQ-p01018",
                    "REQ-p01019"
                ],
                "custom_sections": []
            },
            {
                "filename": "prd-diary-database.md",
                "description": "Diary-specific database requirements (refinement of generic)",
                "preamble": "prd-database_preamble.md",
                "requirements": [
                    "REQ-p00003",
                    "REQ-p00013"
                ],
                "custom_sections": [
                    "## Implementation Notes\n\nThis document refines the generic event-sourcing system (prd-event-sourcing-system.md) for clinical diary applications.\n\n**See**: prd-event-sourcing-system.md for generic event sourcing architecture"
                ]
            }
        ]
    }

    config_path = Path('untracked-notes/refactor-config-template.json')
    config_path.parent.mkdir(parents=True, exist_ok=True)

    with open(config_path, 'w') as f:
        json.dump(template, f, indent=2)

    print(f"Template configuration created: {config_path}")
    print("\nEdit this file to specify:")
    print("  - Which requirements go in which files")
    print("  - Which preambles to use")
    print("  - Custom sections to add")
    print("\nThen run:")
    print(f"  python3 recombine_requirements.py --config {config_path}")


def main():
    parser = argparse.ArgumentParser(description='Recombine extracted requirements into spec files')
    parser.add_argument('--reqs-dir', default='untracked-notes/extracted-reqs',
                        help='Directory containing extracted requirements')
    parser.add_argument('--config', type=Path,
                        help='Configuration file specifying how to combine requirements')
    parser.add_argument('--create-config', action='store_true',
                        help='Create template configuration file')

    args = parser.parse_args()

    if args.create_config:
        create_template_config()
        return

    if not args.config:
        parser.print_help()
        print("\nTip: Use --create-config to generate a template")
        return

    reqs_dir = Path(args.reqs_dir)
    if not reqs_dir.exists():
        print(f"Error: Directory {reqs_dir} does not exist")
        print(f"Run extract_requirements.py first")
        return

    recombiner = RequirementRecombiner(reqs_dir)
    recombiner.create_from_config_file(args.config)


if __name__ == '__main__':
    main()
