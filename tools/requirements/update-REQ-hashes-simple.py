#!/usr/bin/env python3
"""
Simple hash updater - uses validator's parsing to ensure consistency.
"""

import sys
import re
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from validate_requirements import RequirementValidator, calculate_requirement_hash

def update_hashes():
    """Update all hashes using validator's calculation"""
    spec_dir = Path(__file__).parent.parent.parent / 'spec'
    index_path = spec_dir / 'INDEX.md'

    # Use validator to parse all requirements
    validator = RequirementValidator(spec_dir)
    validator._parse_requirements()

    print(f"📝 Updating requirement hashes...\n")

    updated_count = 0
    hash_updates = {}

    # For each requirement, update hash in file
    for req_id, req in validator.requirements.items():
        calc_hash = calculate_requirement_hash(req.body)

        if req.hash != calc_hash:
            # Read file content
            content = req.file_path.read_text(encoding='utf-8')

            # Find and replace hash in end marker
            # Pattern: *End* *{title}* | **Hash**: {old_hash}
            pattern = re.compile(
                rf'\*End\*\s+\*{re.escape(req.title)}\*\s+\|\s+\*\*Hash\*\*:\s+[a-f0-9]{{8}}',
                re.MULTILINE
            )

            replacement = f"*End* *{req.title}* | **Hash**: {calc_hash}"
            new_content, count = pattern.subn(replacement, content)

            if count > 0:
                req.file_path.write_text(new_content, encoding='utf-8')
                print(f"  ✓ REQ-{req_id}: {req.hash} → {calc_hash}")
                updated_count += 1
                hash_updates[req_id] = calc_hash

    # Update INDEX.md
    if hash_updates:
        print(f"\n📋 Updating INDEX.md...")
        content = index_path.read_text(encoding='utf-8')
        lines = content.split('\n')

        for i, line in enumerate(lines):
            match = re.match(r'^\|\s*REQ-([pod]\d{5})\s*\|', line)
            if match:
                req_id = match.group(1)
                if req_id in hash_updates:
                    parts = line.split('|')
                    if len(parts) >= 5:
                        parts[-2] = f" {hash_updates[req_id]} "
                        lines[i] = '|'.join(parts)

        index_path.write_text('\n'.join(lines), encoding='utf-8')
        print(f"  ✓ INDEX.md updated")

    print(f"\n{'='*60}")
    print(f"Summary: {updated_count} requirement(s) updated")
    print(f"✅ Hash update complete\n")

if __name__ == '__main__':
    update_hashes()
