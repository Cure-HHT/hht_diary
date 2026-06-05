#!/usr/bin/env python3
"""Resolve the local path of the associated sponsor repo (e.g. hht_diary_callisto).

This toolkit lives in the *core* repo (hht_diary). The core path is the
toolkit's own checkout (git rev-parse --show-toplevel), so it needs no
resolution. What DOES need resolving is the *sponsor* repo, which supplies
the per-sponsor build inputs: deployment/base-config.json, the sponsor
portal-final.Dockerfile, content/, and the portal seed-users file.

Resolution order (first match wins):
  1. The `SPONSOR_REPO` env var, if set (absolute path).
  2. `[associated.sponsor].path` from `<toolkit>/.local-stack.toml`, overlaid
     with `<toolkit>/.local-stack.local.toml` if present. Relative paths are
     resolved against the toolkit root.

Either way the target is validated by a marker file that only a sponsor repo
carries: deployment/base-config.json.

Usage: resolve-sponsor-path.py --toolkit /path/to/<core>/deployment/local-stack
Exit codes: 0 success (absolute path on stdout), 2 misconfiguration.
"""
from __future__ import annotations

import argparse
import os
import sys

if sys.version_info < (3, 11):
    print(
        f"Python 3.11+ required (have {sys.version.split()[0]}); "
        "tomllib was added in 3.11.\n"
        "Fix options:\n"
        "  • pyenv:  pyenv install 3.11 && pyenv local 3.11\n"
        "  • Ubuntu: ln -sf /usr/bin/python3.11 ~/.local/bin/python3\n"
        "  • macOS:  brew install python@3.11 (and ensure it precedes python3 in PATH)",
        file=sys.stderr,
    )
    sys.exit(2)

import tomllib
from pathlib import Path

# A file that exists in a sponsor repo but not in core. base-config.json
# carries the sponsor id + per-sponsor deployment config.
MARKER = "deployment/base-config.json"


def die(msg: str) -> None:
    print(msg, file=sys.stderr)
    sys.exit(2)


def load_toml(path: Path) -> dict:
    if not path.exists():
        return {}
    with path.open("rb") as f:
        return tomllib.load(f)


def deep_merge(base: dict, over: dict) -> dict:
    out = dict(base)
    for k, v in over.items():
        if isinstance(v, dict) and isinstance(out.get(k), dict):
            out[k] = deep_merge(out[k], v)
        else:
            out[k] = v
    return out


def validate(target: Path, *, source: str, raw: str | None) -> Path:
    if not target.exists():
        die(
            f"Sponsor repo path does not exist: {target}\n"
            f"(resolved from {source})\n"
            "\n"
            "The toolkit now lives in the core repo and resolves the *sponsor*\n"
            "repo. The default '../hht_diary_<sponsor>' assumes the canonical\n"
            "sibling layout:\n"
            "  <parent>/hht_diary            (core — this toolkit's home)\n"
            "  <parent>/hht_diary_<sponsor>  (sponsor)\n"
            "It does NOT resolve from a git worktree (one level deeper) or any\n"
            "other non-default layout.\n"
            "\n"
            "Fix options:\n"
            "  • Export an absolute path:\n"
            "      SPONSOR_REPO=/abs/path/to/hht_diary_<sponsor> ./local-stack portal\n"
            "  • Or create .local-stack.local.toml alongside .local-stack.toml\n"
            "    (in deployment/local-stack/) with an absolute path override:\n"
            "      [associated.sponsor]\n"
            '      path = "/abs/path/to/hht_diary_<sponsor>"\n'
            "\n"
            "See deployment/local-stack/.local-stack.toml for the full explanation."
        )

    if not (target / MARKER).exists():
        die(
            f"{target} does not look like a sponsor repo: "
            f"missing marker file {MARKER}.\n"
            "Point SPONSOR_REPO (or [associated.sponsor].path) at a sponsor "
            "checkout (e.g. hht_diary_callisto)."
        )

    return target


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--toolkit",
        required=True,
        help="Path to <core>/deployment/local-stack (the toolkit root)",
    )
    args = parser.parse_args()

    toolkit = Path(args.toolkit).resolve()

    # 1. SPONSOR_REPO env var wins outright.
    env_sponsor = os.environ.get("SPONSOR_REPO", "").strip()
    if env_sponsor:
        target = Path(env_sponsor)
        if not target.is_absolute():
            die(
                f"SPONSOR_REPO must be an absolute path (got {env_sponsor!r}).\n"
                "Export it as e.g. SPONSOR_REPO=/abs/path/to/hht_diary_<sponsor>."
            )
        target = target.resolve()
        print(validate(target, source="$SPONSOR_REPO", raw=env_sponsor))
        return 0

    # 2. Fall back to .local-stack.toml (+ .local-stack.local.toml override)
    #    at the toolkit root.
    base = load_toml(toolkit / ".local-stack.toml")
    over = load_toml(toolkit / ".local-stack.local.toml")
    merged = deep_merge(base, over)

    associated = (merged.get("associated") or {}).get("sponsor")
    if not associated or "path" not in associated:
        die(
            "No sponsor repo configured. Either:\n"
            "  • export SPONSOR_REPO=/abs/path/to/hht_diary_<sponsor>, or\n"
            f"  • add [associated.sponsor] to {toolkit}/.local-stack.toml\n"
            "    (optionally overridden by .local-stack.local.toml):\n"
            "      [associated.sponsor]\n"
            '      repo = "Cure-HHT/hht_diary_<sponsor>"\n'
            '      path = "../hht_diary_<sponsor>"'
        )

    raw = associated["path"]
    target = Path(raw)
    if not target.is_absolute():
        target = (toolkit / target).resolve()
    else:
        target = target.resolve()

    print(validate(target, source=f"[associated.sponsor].path = {raw!r}", raw=raw))
    return 0


if __name__ == "__main__":
    sys.exit(main())
