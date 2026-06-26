#!/usr/bin/env python3
"""Render the "Active requirement coverage" comment section (CUR-1556).

Reads the elspais traceability matrix (markdown) and gap report (JSON) and
emits a requirement-level table of every Status=Active requirement with its
tested / verified status. Coverage is reported per REQUIREMENT, not per
assertion: elspais credits requirements (the references do not cite individual
assertions for indirect coverage), so the requirement is the natural unit.

The `implemented` dimension is intentionally omitted: elspais credits ~1/177
requirements as implemented today (the code `// Implements:` references are not
yet reconciled with the URS-v1 spec tree / spec-archive), so an implemented
column would read "gap" for essentially every requirement and carry no signal.

Usage: active-coverage.py <traceability_matrix.md> <gaps.json>
Prints nothing if there are no Active requirements (section is omitted).
"""
import json
import re
import sys

MATRIX_ROW = re.compile(r"^\| (DIARY|CAL|HHT|EVS)-")


def active_req_ids(matrix_path):
    ids = []
    with open(matrix_path) as fh:
        for line in fh:
            if not MATRIX_ROW.match(line):
                continue
            cols = [c.strip() for c in line.split("|")]
            # | <id> | <title> | <level> | <status> | ...
            if len(cols) > 5 and cols[4] == "Active":
                ids.append(cols[1])
    return sorted(ids)


def gap_ids(gaps, key):
    return {(x[0] if isinstance(x, list) else x) for x in gaps.get(key, [])}


def main():
    matrix_path, gaps_path = sys.argv[1], sys.argv[2]
    active = active_req_ids(matrix_path)
    if not active:
        return
    with open(gaps_path) as fh:
        gaps = json.load(fh)
    untested = gap_ids(gaps, "untested")
    failing = gap_ids(gaps, "failing")

    rows = []
    for rid in active:
        tested = "ok" if rid not in untested else "gap"
        verified = "ok" if (rid not in untested and rid not in failing) else "gap"
        rows.append(f"| {rid} | {tested} | {verified} |")

    print("### Active requirement coverage")
    print()
    print("| Requirement | Tested | Verified |")
    print("|-------------|:------:|:--------:|")
    print("\n".join(rows))
    print()
    print(
        "_Requirement-level. `implemented` omitted pending spec-archive "
        "reconciliation (elspais credits ~1/177 today)._"
    )


if __name__ == "__main__":
    main()
