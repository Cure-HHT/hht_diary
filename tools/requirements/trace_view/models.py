"""
Data models for trace-view

Provides dataclasses for representing requirements and test information.
"""

from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List, Optional, Tuple

from .git_state import GitState


@dataclass
class TestInfo:
    """Represents test coverage for a requirement.

    Attributes:
        test_count: Number of automated tests
        manual_test_count: Number of manual tests
        test_status: Status ('not_tested', 'passed', 'failed', 'error', 'skipped')
        test_details: List of test result details
        notes: Additional notes about testing
    """
    test_count: int = 0
    manual_test_count: int = 0
    test_status: str = "not_tested"
    test_details: List[Dict] = field(default_factory=list)
    notes: str = ""


@dataclass
class Requirement:
    """Represents a requirement with traceability information.

    This is the primary data model for requirements in trace-view.
    It includes the requirement's metadata, content, and status information.

    Attributes:
        id: Requirement ID without REQ- prefix (e.g., 'p00001', 'd00027')
        title: Requirement title
        level: Level ('PRD', 'OPS', 'DEV')
        implements: List of parent requirement IDs this implements
        status: Status ('Active', 'Draft', 'Deprecated')
        file_path: Path to the source file
        line_number: Line number in source file
        hash: SHA-256 hash (first 8 chars) for change detection
        body: Requirement body text
        rationale: Rationale text (if present)
        test_info: Test coverage information (if available)
        implementation_files: List of (file_path, line_number) tuples for implementations
        is_roadmap: True if requirement is in spec/roadmap/ directory
        is_conflict: True if this roadmap REQ conflicts with an existing REQ
        conflict_with: ID of the conflicting requirement
        is_cycle: True if this REQ is part of a dependency cycle
        cycle_path: The cycle path string for display
    """
    id: str
    title: str
    level: str
    implements: List[str]
    status: str
    file_path: Path
    line_number: int
    hash: str = ''
    body: str = ''
    rationale: str = ''
    test_info: Optional[TestInfo] = None
    implementation_files: List[Tuple[str, int]] = field(default_factory=list)
    is_roadmap: bool = False
    is_conflict: bool = False
    conflict_with: str = ''
    is_cycle: bool = False
    cycle_path: str = ''

    def _get_spec_relative_path(self) -> str:
        """Get the spec-relative path for this requirement's file."""
        if self.is_roadmap:
            return f"spec/roadmap/{self.file_path.name}"
        return f"spec/{self.file_path.name}"

    def _is_in_untracked_file(self) -> bool:
        """Check if requirement is in an untracked (new) file."""
        rel_path = self._get_spec_relative_path()
        return rel_path in GitState.get_untracked()

    def _check_modified_in_fileset(self, file_set) -> bool:
        """Check if requirement is modified based on a set of changed files.

        For untracked files, all REQs are considered new.
        For modified files, requirement is considered changed if file is in the set.
        """
        rel_path = self._get_spec_relative_path()

        # Check if file is untracked (new) - all REQs in new files are new
        if rel_path in GitState.get_untracked():
            return True

        # Check if file is in the modified set
        return file_set and rel_path in file_set

    @property
    def is_uncommitted(self) -> bool:
        """Check if requirement has uncommitted changes (modified since last commit)."""
        return self._check_modified_in_fileset(GitState.get_uncommitted())

    @property
    def is_branch_changed(self) -> bool:
        """Check if requirement changed vs main branch."""
        return self._check_modified_in_fileset(GitState.get_branch_changed())

    @property
    def is_new(self) -> bool:
        """Check if requirement is in a new (untracked) file."""
        return self._is_in_untracked_file()

    @property
    def is_modified(self) -> bool:
        """Check if requirement has modified content but is not in a new file."""
        if self._is_in_untracked_file():
            return False  # New files are "new", not "modified"
        return self.is_uncommitted

    @property
    def is_moved(self) -> bool:
        """Check if requirement was moved from a different file.

        A requirement is considered moved if:
        - It exists in the committed state in a different file, OR
        - It's in a new file but has a non-TBD hash (suggesting it was copied/moved)
        """
        current_path = self._get_spec_relative_path()
        committed_path = GitState.get_committed_locations().get(self.id)

        if committed_path is not None:
            # REQ existed in committed state - check if path changed
            return committed_path != current_path

        # REQ doesn't exist in committed state
        # If it's in a new file but has a real hash, it was likely moved/copied
        if self._is_in_untracked_file() and self.hash and self.hash != 'TBD':
            return True

        return False

    @classmethod
    def from_elspais_json(cls, req_id: str, data: Dict) -> 'Requirement':
        """Create Requirement from elspais validate --json output.

        Args:
            req_id: Full requirement ID (e.g., 'REQ-d00027')
            data: Dict from elspais JSON with keys: title, level, status, body, rationale,
                  file, filePath, line, implements, hash, subdir, isConflict, conflictWith,
                  isCycle, cyclePath

                  When elspais [testing] is configured, also includes:
                  test_count, test_passed, test_result_files

        Returns:
            Requirement instance
        """
        # Map level to uppercase for consistency
        level_map = {
            'PRD': 'PRD', 'Ops': 'OPS', 'Dev': 'DEV',
            'prd': 'PRD', 'ops': 'OPS', 'dev': 'DEV'
        }
        level = data.get('level', '')
        is_roadmap = data.get('subdir', '') == 'roadmap'

        # Extract test info if provided by elspais (when [testing] is configured)
        test_info = None
        test_count = data.get('test_count', 0)
        if test_count > 0:
            test_passed = data.get('test_passed', 0)
            test_status = 'passed' if test_passed == test_count else 'failed'
            test_info = TestInfo(
                test_count=test_count,
                manual_test_count=0,
                test_status=test_status,
                test_details=data.get('test_result_files', []),
                notes=''
            )

        req = cls(
            id=req_id.replace('REQ-', ''),  # Strip REQ- prefix for internal use
            title=data.get('title', ''),
            level=level_map.get(level, level.upper()),
            implements=data.get('implements', []),
            status=data.get('status', 'Active'),
            file_path=Path(data.get('filePath', '')),
            line_number=data.get('line', 0),
            hash=data.get('hash', ''),
            body=data.get('body', ''),
            rationale=data.get('rationale', ''),
            is_roadmap=is_roadmap,
            is_conflict=data.get('isConflict', False),
            conflict_with=data.get('conflictWith', '') or '',
            is_cycle=data.get('isCycle', False),
            cycle_path=data.get('cyclePath', '') or ''
        )
        req.test_info = test_info
        return req


# Backward compatibility alias
TraceabilityRequirement = Requirement
