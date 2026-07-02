#!/usr/bin/env python3
"""Compute the set of `[[scanning.test.targets]]` affected by a PR diff.

CUR-1557 Part 2: the per-PR traceability matrix runs only the *changed* test
targets (and their dependents) via `elspais ... --targets`, carrying the rest
forward from the last-known baseline. This script produces that fresh set.

Approach (dependency-aware, safe):
  1. Read the target names from `.elspais.toml` (name == repo-relative cwd).
  2. Discover *every* Dart package in the repo (any dir with a pubspec.yaml)
     and build a reverse-dependency graph from `path:` deps in
     dependencies/dev_dependencies.
  3. Map each changed file to its owning package; expand to that package plus
     ALL transitive dependents; intersect with the target set.
  4. Fail safe: any changed file that is NOT inside a discovered package
     (e.g. `spec/**`, `.elspais.toml`, `database/**`, the workflow itself)
     forces a FULL run -- its blast radius can't be reasoned about per-package.

Output (stdout), one of:
  * ``__ALL__``            -> run every target (omit --targets: full regression)
  * ``<name>\n<name>...``  -> the affected target names (the fresh set)

Exit code is 0 on success; the script never partially-selects on error -- on
any parse problem it prints ``__ALL__`` (safe) and exits 0.
"""
from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
import tomllib
from pathlib import Path

ALL = "__ALL__"


def _log(msg: str) -> None:
    print(f"changed_test_targets: {msg}", file=sys.stderr)


def read_targets(config_path: Path) -> list[str]:
    """Target names from .elspais.toml (name == repo-relative cwd)."""
    with config_path.open("rb") as fh:
        cfg = tomllib.load(fh)
    targets = cfg.get("scanning", {}).get("test", {}).get("targets", [])
    names = [t["name"] for t in targets if t.get("name")]
    if not names:
        raise ValueError("no [[scanning.test.targets]] with a name in config")
    return names


def _package_name(pubspec: Path) -> str | None:
    # pubspec.yaml is small + regular; a line-level `name:` read avoids a YAML dep.
    for line in pubspec.read_text(encoding="utf-8", errors="replace").splitlines():
        m = re.match(r"^name:\s*(\S+)", line)
        if m:
            return m.group(1)
    return None


_PATH_DEP = re.compile(r"^\s+path:\s*(\S+)\s*$")


def _path_deps(pubspec: Path) -> list[str]:
    """Relative `path:` dependency targets declared in a pubspec.

    Only lines under dependency blocks matter, but `path:` appears almost
    exclusively in dependency specs; the one false-positive family in this repo
    is flutter asset config (`image_path:`), which this regex excludes by
    requiring the key to be exactly `path`.
    """
    deps: list[str] = []
    for line in pubspec.read_text(encoding="utf-8", errors="replace").splitlines():
        m = _PATH_DEP.match(line)
        if m:
            deps.append(m.group(1).strip().strip('"').strip("'"))
    return deps


def discover_packages(repo_root: Path) -> dict[str, Path]:
    """Map repo-relative package dir -> pubspec path, for every package."""
    pkgs: dict[str, Path] = {}
    for pubspec in repo_root.rglob("pubspec.yaml"):
        # Skip anything inside build/ephemeral dirs.
        rel_parts = pubspec.relative_to(repo_root).parts
        if any(p in (".dart_tool", "build", ".fvm", "ephemeral") for p in rel_parts):
            continue
        pkg_dir = pubspec.parent.relative_to(repo_root).as_posix()
        pkgs[pkg_dir] = pubspec
    return pkgs


def build_reverse_deps(repo_root: Path, pkgs: dict[str, Path]) -> dict[str, set[str]]:
    """dir -> set of package dirs that directly depend on it (path deps)."""
    pkg_dirs = set(pkgs)
    reverse: dict[str, set[str]] = {d: set() for d in pkg_dirs}
    for pkg_dir, pubspec in pkgs.items():
        for rel in _path_deps(pubspec):
            # Resolve the dep path relative to the depending package's dir.
            dep_dir = os.path.normpath(os.path.join(pkg_dir, rel))
            dep_dir = Path(dep_dir).as_posix()
            if dep_dir in pkg_dirs:
                reverse[dep_dir].add(pkg_dir)
    return reverse


def owning_package(rel_file: str, pkg_dirs: set[str]) -> str | None:
    """Longest package-dir prefix that contains the file, or None."""
    best: str | None = None
    for d in pkg_dirs:
        if rel_file == d or rel_file.startswith(d + "/"):
            if best is None or len(d) > len(best):
                best = d
    return best


def transitive_dependents(seeds: set[str], reverse: dict[str, set[str]]) -> set[str]:
    seen = set(seeds)
    stack = list(seeds)
    while stack:
        cur = stack.pop()
        for dep in reverse.get(cur, ()):
            if dep not in seen:
                seen.add(dep)
                stack.append(dep)
    return seen


def changed_files(repo_root: Path, base: str) -> list[str]:
    merge_base = subprocess.run(
        ["git", "-C", str(repo_root), "merge-base", base, "HEAD"],
        capture_output=True, text=True,
    )
    ref = merge_base.stdout.strip() if merge_base.returncode == 0 else base
    out = subprocess.run(
        ["git", "-C", str(repo_root), "diff", "--name-only", f"{ref}...HEAD"],
        capture_output=True, text=True, check=True,
    )
    return [ln for ln in out.stdout.splitlines() if ln.strip()]


def compute(repo_root: Path, config_path: Path, files: list[str]) -> str:
    targets = set(read_targets(config_path))
    pkgs = discover_packages(repo_root)
    pkg_dirs = set(pkgs)
    reverse = build_reverse_deps(repo_root, pkgs)

    changed_pkgs: set[str] = set()
    for f in files:
        owner = owning_package(f, pkg_dirs)
        if owner is None:
            # A change we can't attribute to a package -> full run (safe).
            _log(f"non-package change forces full run: {f}")
            return ALL
        changed_pkgs.add(owner)

    if not changed_pkgs:
        # No changes at all (or empty diff) -> nothing to run selectively; be safe.
        return ALL

    affected = transitive_dependents(changed_pkgs, reverse)
    affected_targets = sorted(affected & targets)
    return "\n".join(affected_targets)


def main() -> int:
    ap = argparse.ArgumentParser(description="Affected test targets for a PR diff.")
    ap.add_argument("--base", default="origin/main", help="base ref to diff against")
    ap.add_argument("--config", default=".elspais.toml")
    ap.add_argument("--repo-root", default=".")
    ap.add_argument(
        "--files-from",
        help="read changed file list from this path (or '-' for stdin) instead of git",
    )
    args = ap.parse_args()

    repo_root = Path(args.repo_root).resolve()
    config_path = (repo_root / args.config).resolve()
    try:
        if args.files_from == "-":
            files = [ln.strip() for ln in sys.stdin if ln.strip()]
        elif args.files_from:
            files = [ln.strip() for ln in Path(args.files_from).read_text().splitlines() if ln.strip()]
        else:
            files = changed_files(repo_root, args.base)
        print(compute(repo_root, config_path, files))
        return 0
    except Exception as exc:  # never partially-select on error
        _log(f"error ({exc!r}); defaulting to full run")
        print(ALL)
        return 0


if __name__ == "__main__":
    raise SystemExit(main())
