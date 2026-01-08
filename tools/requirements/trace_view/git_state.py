"""
Git state management for trace-view

Provides functions to query git status and a singleton class
to manage git state shared across the application.
"""

import re
import json
import subprocess
from pathlib import Path
from typing import Dict, Set, Tuple, Optional


def get_requirements_via_cli() -> Dict[str, Dict]:
    """Get all requirements by running elspais validate --json.

    Returns:
        Dict mapping requirement ID (e.g., 'REQ-d00027') to requirement data
    """
    try:
        result = subprocess.run(
            ['elspais', 'validate', '--json'],
            capture_output=True,
            text=True
        )

        output = result.stdout
        json_start = output.find('{')
        if json_start == -1:
            return {}

        json_str = output[json_start:]
        return json.loads(json_str)
    except (subprocess.CalledProcessError, json.JSONDecodeError, FileNotFoundError) as e:
        print(f"   ⚠️  Failed to get requirements via elspais: {e}")
        return {}


def get_elspais_config() -> Dict:
    """Get elspais configuration via elspais config show --json.

    Returns:
        Dict with elspais configuration including:
        - directories.spec: spec directory path
        - directories.code: list of implementation directories
        - directories.database: database directory path
        - traceability.output_dir: default output directory
    """
    try:
        result = subprocess.run(
            ['elspais', 'config', 'show', '--json'],
            capture_output=True,
            text=True
        )

        output = result.stdout
        json_start = output.find('{')
        if json_start == -1:
            return {}

        json_str = output[json_start:]
        return json.loads(json_str)
    except (subprocess.CalledProcessError, json.JSONDecodeError, FileNotFoundError) as e:
        print(f"   ⚠️  Failed to get elspais config: {e}")
        return {}


def get_git_modified_files(repo_root: Path) -> Tuple[Set[str], Set[str]]:
    """Get sets of modified and untracked files according to git status.

    Args:
        repo_root: Path to repository root

    Returns:
        Tuple of (modified_files, untracked_files):
        - modified_files: Tracked files with changes (M, A, R, etc.)
        - untracked_files: New files not yet tracked (??)

    This allows detection of:
    - Requirements with stale hashes (modified files - need hash check)
    - New requirements (untracked files - all REQs are new, no hash check needed)
    """
    try:
        result = subprocess.run(
            ['git', 'status', '--porcelain', '--untracked-files=all'],
            cwd=repo_root,
            capture_output=True,
            text=True,
            check=True
        )
        modified_files: Set[str] = set()
        untracked_files: Set[str] = set()
        # Don't strip stdout - it would remove leading space from first line's " M" prefix
        for line in result.stdout.split('\n'):
            if line and len(line) >= 3:
                # Format: "XY filename" or "XY orig -> renamed"
                # XY = two-letter status (e.g., " M", "??", "A ", "R ")
                # Position 0-1: XY status, Position 2: space, Position 3+: filename
                status_code = line[:2]
                file_path = line[3:].strip()
                # Handle renames: "orig -> new"
                if ' -> ' in file_path:
                    file_path = file_path.split(' -> ')[1]
                if file_path:
                    if status_code == '??':
                        untracked_files.add(file_path)
                    else:
                        modified_files.add(file_path)
        return modified_files, untracked_files
    except (subprocess.CalledProcessError, FileNotFoundError):
        # Git not available or not a git repo - return empty sets
        return set(), set()


def get_git_changed_vs_main(repo_root: Path, main_branch: str = 'main') -> Set[str]:
    """Get set of files changed between current branch and main branch.

    Uses git diff to find files that differ from the main branch.
    This catches all changes on the current feature branch.

    Args:
        repo_root: Path to repository root
        main_branch: Name of main branch (default: 'main')

    Returns:
        Set of file paths changed vs main branch
    """
    try:
        # Get files changed between main and HEAD (current branch)
        result = subprocess.run(
            ['git', 'diff', '--name-only', f'{main_branch}...HEAD'],
            cwd=repo_root,
            capture_output=True,
            text=True,
            check=True
        )
        changed_files: Set[str] = set()
        for line in result.stdout.split('\n'):
            if line.strip():
                changed_files.add(line.strip())
        return changed_files
    except subprocess.CalledProcessError:
        # If main branch doesn't exist or other git error, try origin/main
        try:
            result = subprocess.run(
                ['git', 'diff', '--name-only', f'origin/{main_branch}...HEAD'],
                cwd=repo_root,
                capture_output=True,
                text=True,
                check=True
            )
            changed_files = set()
            for line in result.stdout.split('\n'):
                if line.strip():
                    changed_files.add(line.strip())
            return changed_files
        except (subprocess.CalledProcessError, FileNotFoundError):
            return set()
    except FileNotFoundError:
        return set()


def get_committed_req_locations(repo_root: Path) -> Dict[str, str]:
    """Get REQ ID -> file path mapping from committed state (HEAD).

    This allows detection of moved requirements by comparing current location
    to where the REQ was in the last commit.

    Args:
        repo_root: Path to repository root

    Returns:
        Dict mapping REQ ID (e.g., 'd00001') to relative file path (e.g., 'spec/dev-app.md')
    """
    req_locations: Dict[str, str] = {}
    req_pattern = re.compile(r'^#{1,6}\s+REQ-(?:[A-Z]{2,4}-)?([pod]\d{5}):', re.MULTILINE)

    try:
        # Get list of spec files in committed state
        result = subprocess.run(
            ['git', 'ls-tree', '-r', '--name-only', 'HEAD', 'spec/'],
            cwd=repo_root,
            capture_output=True,
            text=True,
            check=True
        )

        for file_path in result.stdout.strip().split('\n'):
            if not file_path.endswith('.md'):
                continue
            if any(skip in file_path for skip in ['INDEX.md', 'README.md', 'requirements-format.md']):
                continue

            # Get file content from committed state
            try:
                content_result = subprocess.run(
                    ['git', 'show', f'HEAD:{file_path}'],
                    cwd=repo_root,
                    capture_output=True,
                    text=True,
                    check=True
                )
                content = content_result.stdout

                # Find all REQ IDs in this file
                for match in req_pattern.finditer(content):
                    req_id = match.group(1)  # Just the ID part (e.g., 'd00001')
                    req_locations[req_id] = file_path

            except subprocess.CalledProcessError:
                # File might not exist in HEAD (new file)
                continue

    except (subprocess.CalledProcessError, FileNotFoundError):
        # Git not available or not a git repo
        pass

    return req_locations


class GitState:
    """Singleton for managing git state shared across the application.

    This class maintains the state of git-modified files that is used
    by Requirement instances to determine their modification status.

    Usage:
        # Set state (typically done once at startup)
        GitState.set_state(uncommitted, untracked, branch_changed, locations)

        # Access state
        if file_path in GitState.get_uncommitted():
            print("File has uncommitted changes")
    """

    _uncommitted: Set[str] = set()
    _untracked: Set[str] = set()
    _branch_changed: Set[str] = set()
    _committed_locations: Dict[str, str] = {}

    @classmethod
    def set_state(cls, uncommitted: Set[str], untracked: Set[str],
                  branch_changed: Set[str],
                  committed_locations: Optional[Dict[str, str]] = None) -> None:
        """Set the git state.

        Args:
            uncommitted: Set of files with uncommitted changes
            untracked: Set of untracked files
            branch_changed: Set of files changed vs main branch
            committed_locations: Optional dict of REQ ID -> file path in committed state
        """
        cls._uncommitted = uncommitted
        cls._untracked = untracked
        cls._branch_changed = branch_changed
        if committed_locations is not None:
            cls._committed_locations = committed_locations

    @classmethod
    def get_uncommitted(cls) -> Set[str]:
        """Get set of files with uncommitted changes."""
        return cls._uncommitted

    @classmethod
    def get_untracked(cls) -> Set[str]:
        """Get set of untracked files."""
        return cls._untracked

    @classmethod
    def get_branch_changed(cls) -> Set[str]:
        """Get set of files changed vs main branch."""
        return cls._branch_changed

    @classmethod
    def get_committed_locations(cls) -> Dict[str, str]:
        """Get REQ ID -> file path mapping from committed state."""
        return cls._committed_locations

    @classmethod
    def reset(cls) -> None:
        """Reset all git state (useful for testing)."""
        cls._uncommitted = set()
        cls._untracked = set()
        cls._branch_changed = set()
        cls._committed_locations = {}


# Legacy backward compatibility function
def set_git_modified_files(uncommitted: Set[str], untracked: Set[str],
                           branch_changed: Set[str],
                           committed_req_locations: Optional[Dict[str, str]] = None) -> None:
    """Set the git-modified files for modified detection.

    DEPRECATED: Use GitState.set_state() instead.

    This function is maintained for backward compatibility with existing code.
    """
    GitState.set_state(uncommitted, untracked, branch_changed, committed_req_locations)


# Legacy module-level variables for backward compatibility
# These are properties that delegate to GitState
# Note: Direct assignment to these won't work - use set_git_modified_files() or GitState.set_state()
_git_uncommitted_files: Set[str] = set()
_git_untracked_files: Set[str] = set()
_git_branch_changed_files: Set[str] = set()
_git_committed_req_locations: Dict[str, str] = {}


def _sync_legacy_globals() -> None:
    """Sync legacy globals with GitState (called by set_git_modified_files)."""
    global _git_uncommitted_files, _git_untracked_files, _git_branch_changed_files, _git_committed_req_locations
    _git_uncommitted_files = GitState.get_uncommitted()
    _git_untracked_files = GitState.get_untracked()
    _git_branch_changed_files = GitState.get_branch_changed()
    _git_committed_req_locations = GitState.get_committed_locations()
