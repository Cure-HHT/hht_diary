#!/usr/bin/env python3
"""
Transform extracted requirements - make them generic, update references, etc.

Usage:
    python3 transform_requirements.py --deflutter untracked-notes/extracted-reqs/
    python3 transform_requirements.py --update-implements REQ-p01000:REQ-p02000
"""

import re
from pathlib import Path
from typing import Dict, List
import argparse


class RequirementTransformer:
    def __init__(self, reqs_dir: Path):
        self.reqs_dir = reqs_dir

    def deflutter_requirement(self, req_path: Path) -> bool:
        """Remove Flutter/Dart specific references, make generic."""
        content = req_path.read_text()
        original = content

        # Transformations to make generic
        transformations = [
            # Flutter/Dart specific -> Generic
            (r'Flutter Event Sourcing Module', 'Event Sourcing System'),
            (r'Flutter/Dart package', 'software module'),
            (r'Dart/Flutter', 'application'),
            (r'Flutter', 'application'),
            (r'Dart classes', 'strongly-typed data structures'),
            (r'Dart models', 'strongly-typed models'),
            (r'Dart', 'programming language'),
            (r'mobile applications', 'client applications'),
            (r'mobile', 'client'),
            (r'SQLite/Hive', 'local persistent storage'),
            (r'experienced Flutter developer', 'experienced developer'),
            (r'Flutter Application Layer', 'Application Layer'),
        ]

        for pattern, replacement in transformations:
            content = re.sub(pattern, replacement, content, flags=re.IGNORECASE)

        # Update title in metadata if it contains Flutter
        title_pattern = r'^title: (.+)$'
        def replace_title(match):
            title = match.group(1)
            for pattern, replacement in transformations:
                title = re.sub(pattern, replacement, title, flags=re.IGNORECASE)
            return f"title: {title}"

        content = re.sub(title_pattern, replace_title, content, flags=re.MULTILINE)

        if content != original:
            req_path.write_text(content)
            print(f"  ✓ De-fluttered {req_path.name}")
            return True

        return False

    def deflutter_all(self) -> int:
        """De-flutter all requirements in directory."""
        print(f"\nDe-fluttering requirements in {self.reqs_dir}/\n")

        count = 0
        for req_file in sorted(self.reqs_dir.glob('REQ-*.md')):
            if self.deflutter_requirement(req_file):
                count += 1

        print(f"\nModified {count} requirements")
        return count

    def update_implements(self, req_id: str, new_implements: List[str]):
        """Update the 'Implements' field for a requirement."""
        req_path = self.reqs_dir / f"{req_id}.md"

        if not req_path.exists():
            print(f"Warning: {req_id}.md not found")
            return False

        content = req_path.read_text()

        # Update metadata
        meta_pattern = r'^implements: (.+)$'
        new_impl_str = ', '.join(new_implements) if new_implements else '-'
        content = re.sub(meta_pattern, f'implements: {new_impl_str}', content, flags=re.MULTILINE)

        # Update in body
        body_pattern = r'\*\*Implements\*\*:\s*[^|]+'
        content = re.sub(body_pattern, f'**Implements**: {new_impl_str}', content)

        req_path.write_text(content)
        print(f"  ✓ Updated implements for {req_id}: {new_impl_str}")
        return True

    def rename_requirement(self, old_id: str, new_id: str):
        """Rename a requirement ID."""
        old_path = self.reqs_dir / f"{old_id}.md"
        new_path = self.reqs_dir / f"{new_id}.md"

        if not old_path.exists():
            print(f"Warning: {old_id}.md not found")
            return False

        # Update content
        content = old_path.read_text()
        content = content.replace(old_id, new_id)

        # Update metadata
        content = re.sub(r'^req_id: .+$', f'req_id: {new_id}', content, flags=re.MULTILINE)

        # Save with new name
        new_path.write_text(content)
        old_path.unlink()

        print(f"  ✓ Renamed {old_id} -> {new_id}")
        return True

    def add_context_note(self, req_id: str, note: str):
        """Add a context note to a requirement."""
        req_path = self.reqs_dir / f"{req_id}.md"

        if not req_path.exists():
            print(f"Warning: {req_id}.md not found")
            return False

        content = req_path.read_text()

        # Add after the metadata block
        lines = content.split('\n')
        insert_pos = 0

        # Find end of --- metadata block
        in_metadata = False
        for i, line in enumerate(lines):
            if line.strip() == '---':
                if not in_metadata:
                    in_metadata = True
                else:
                    insert_pos = i + 1
                    break

        # Insert note
        note_text = f"\n> **Context Note**: {note}\n"
        lines.insert(insert_pos, note_text)

        req_path.write_text('\n'.join(lines))
        print(f"  ✓ Added context note to {req_id}")
        return True


def main():
    parser = argparse.ArgumentParser(description='Transform extracted requirements')
    parser.add_argument('--reqs-dir', default='untracked-notes/extracted-reqs',
                        help='Directory containing extracted requirements')
    parser.add_argument('--deflutter', action='store_true',
                        help='Remove Flutter/Dart references, make generic')
    parser.add_argument('--update-implements', metavar='REQ:NEW_IMPL',
                        help='Update implements field: REQ-p01000:REQ-p02000,REQ-p02001')
    parser.add_argument('--rename', metavar='OLD:NEW',
                        help='Rename requirement ID: REQ-p01000:REQ-p02000')
    parser.add_argument('--add-note', metavar='REQ:NOTE',
                        help='Add context note to requirement')

    args = parser.parse_args()

    reqs_dir = Path(args.reqs_dir)
    if not reqs_dir.exists():
        print(f"Error: Directory {reqs_dir} does not exist")
        print(f"Run extract_requirements.py first")
        return

    transformer = RequirementTransformer(reqs_dir)

    if args.deflutter:
        transformer.deflutter_all()

    if args.update_implements:
        req_id, new_impl = args.update_implements.split(':')
        new_impls = [impl.strip() for impl in new_impl.split(',')]
        transformer.update_implements(req_id, new_impls)

    if args.rename:
        old_id, new_id = args.rename.split(':')
        transformer.rename_requirement(old_id, new_id)

    if args.add_note:
        req_id, note = args.add_note.split(':', 1)
        transformer.add_context_note(req_id, note)


if __name__ == '__main__':
    main()
