#!/usr/bin/env python3
"""Tests for traceability_comment.py (CUR-1556).

Self-contained: run with `python3 traceability_comment_test.py`. Exits non-zero
on the first failed assertion. No pytest dependency (CI containers may not have
it; the .githooks/tests suite is likewise dependency-light).
"""
import importlib.util
import os
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location(
    "traceability_comment", os.path.join(_HERE, "traceability_comment.py")
)
tc = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(tc)

_failures = []


def check(label, got, want):
    if got != want:
        _failures.append(f"{label}: got {got!r}, want {want!r}")


def check_in(label, needle, haystack):
    if needle not in haystack:
        _failures.append(f"{label}: {needle!r} not found in output")


def check_not_in(label, needle, haystack):
    if needle in haystack:
        _failures.append(f"{label}: {needle!r} unexpectedly present")


# --- parse_fraction ---------------------------------------------------------
check("frac basic", tc.parse_fraction("0/13 (0%)"), (0, 13))
check("frac no pct", tc.parse_fraction("3/5"), (3, 5))
check("frac spaces", tc.parse_fraction(" 12 / 47 (25%)"), (12, 47))
check("frac n/a", tc.parse_fraction("n/a"), None)
check("frac empty", tc.parse_fraction(""), None)
check("frac none", tc.parse_fraction(None), None)

# --- bar --------------------------------------------------------------------
check("bar 0", tc.bar(0, 20), "[" + "-" * 20 + "]")
check("bar 100", tc.bar(100, 20), "[" + "#" * 20 + "]")
check("bar 50/10", tc.bar(50, 10), "[#####-----]")
check("bar rounds", tc.bar(26, 20), "[" + "#" * 5 + "-" * 15 + "]")  # 26% -> 5.2 -> 5

# --- summarize (assertion-level rollup over a status set) --------------------
NODES = [
    {"id": "DIARY-PRD-a", "status": "Active", "tested": "0/13 (0%)", "verified": "0/13 (0%)"},
    {"id": "DIARY-PRD-b", "status": "Active", "tested": "5/15 (33%)", "verified": "3/15 (20%)"},
    {"id": "DIARY-GUI-c", "status": "Active", "tested": "9/9 (100%)", "verified": "9/9 (100%)"},
    {"id": "DIARY-PRD-d", "status": "Draft", "tested": "2/10 (20%)", "verified": "1/10 (10%)"},
    {"id": "DIARY-OLD-e", "status": "Legacy", "tested": "1/4 (25%)", "verified": "1/4 (25%)"},
    {"id": "DIARY-PRD-f", "status": "Active", "tested": "n/a", "verified": "n/a"},  # skipped
]
act = tc.summarize(NODES, {"Active"}, "verified")
check("active den", act["den"], 13 + 15 + 9)   # 37; the n/a node contributes nothing
check("active num", act["num"], 0 + 3 + 9)     # 12
check("active reqs", act["reqs"], 3)           # n/a node excluded
check("active green", act["green"], 1)         # only c is fully verified
repo = tc.summarize(NODES, tc.CREDITABLE, "verified")
check("repo den excludes legacy", repo["den"], 13 + 15 + 9 + 10)  # 47, no Legacy
check("repo num", repo["num"], 0 + 3 + 9 + 1)  # 13

# --- gap_map / assertion labels ---------------------------------------------
GAPS = {
    "uncovered": [
        ["DIARY-PRD-a", "Title A", ["DIARY-PRD-a-A", "DIARY-PRD-a-C"]],
        ["DIARY-PRD-d", "Title D"],  # no assertion list
    ],
    "failing": [
        ["DIARY-PRD-b", "Title B", ["DIARY-PRD-b-H"]],
    ],
}
gm = tc.gap_map(GAPS, "uncovered")
check("gap_map assertions", gm["DIARY-PRD-a"], ["DIARY-PRD-a-A", "DIARY-PRD-a-C"])
check("gap_map empty list", gm["DIARY-PRD-d"], [])
check("assertion label", tc.assertion_label("DIARY-PRD-a", "DIARY-PRD-a-C"), "C")
check("assertion label foreign", tc.assertion_label("DIARY-PRD-a", "OTHER-X"), "OTHER-X")
check("active failing count", tc.active_failing_count(NODES, GAPS), 1)

# --- _grep_checks (anchor to the right lines, not the first "N passed") -----
import tempfile, os as _os
_CHECKS_TXT = """\
  ~ CONFIG (4 passed, 0 failed, 1 skipped)
  ~ tests.tested: Tested: 108/178 REQs (61%), 2/975 assertions direct (0%), 560.9 indirect (58%) [26 legacy excluded]
  ~ tests.verified: Verified: 108/178 REQs (61%), 2/975 assertions direct (0%), 557.1 indirect (57%) [26 legacy excluded]
  ~ tests.results: All tests passing: 2498 passed, 1 skipped
  ~ tests.results_stale: Test results are stale -- 9999 passed earlier
"""
_fd, _p = tempfile.mkstemp()
with _os.fdopen(_fd, "w") as _fh:
    _fh.write(_CHECKS_TXT)
_c = tc._grep_checks(_p)
_os.unlink(_p)
check("checks verified req-level", _c["verified"], "108/178 REQs (61%)")
check("checks tested req-level", _c["tested"], "108/178 REQs (61%)")
check("checks indirect", _c["indirect"], "557.1 indirect (57%)")
check("checks passed = tests.results not first match", _c["passed"], "2498")

# --- end-to-end render ------------------------------------------------------
body = tc.render(
    marker="<!-- m -->",
    nodes=NODES,
    gaps=GAPS,
    coverage_rows=[("packages/x", "41.3", 410, 660)],
    coverage_total=("41.3", 410, 660),
    checks_tested="14/178 REQs (8%)",
    checks_verified="8/178 REQs (4%)",
    checks_indirect="557.1 indirect (57%)",
    checks_passed="2498",
    run_url="https://example/run/1",
    viewer_url="https://cure-hht.github.io/hht_diary/pr-801/viewer.html",
)
check_in("marker first", "<!-- m -->", body.splitlines()[0])
check_in("title", "## Verified-Coverage Traceability Matrix", body)
check_in("active focus label", "ACTIVE FOCUS", body)
# Active focus is assertion-level *traceability* (direct), not REQ-level verified.
check_in("active fraction", "12/37 assertions traced", body)
check_in("active reqs traced", "1/3 REQs fully traced", body)
# Repo context line shows the meaningful REQ-level number + indirect + line cov,
# NOT a direct-assertion sum.
check_in("coverage req-level", "verified 8/178 REQs (4%)", body)
check_in("indirect shown", "indirect (57%)", body)
check_in("line cov", "41.3%", body)
check_not_in("no misleading direct repo sum", "repo verified", body)
check_in("failing line", "1 Active assertion", body)
check_in("tests passing", "2498 tests passing", body)
check_in("legend", "assertion-level traceability", body)
check_in("collapsible gaps", "<details>", body)
check_in("worklist untested", "/A untested", body)
check_in("repo rollup official", "8/178 REQs (4%)", body)
check_in("status pipeline", "Active 4", body)
check_in("artifact link", "https://example/run/1", body)
check_in("viewer link", "https://cure-hht.github.io/hht_diary/pr-801/viewer.html", body)
check_in("viewer link label", "Open the interactive matrix viewer", body)

# viewer_url omitted -> no viewer link, artifact link still present
body_noviewer = tc.render(
    marker="<!-- m -->", nodes=NODES, gaps=GAPS, coverage_rows=[], coverage_total=None,
    checks_tested=None, checks_verified=None, run_url="https://example/run/9",
)
check_not_in("no viewer link when url absent", "interactive matrix viewer", body_noviewer)
check_in("artifact link still present", "https://example/run/9", body_noviewer)

# --- render with ZERO active (graceful degrade) -----------------------------
nodes_no_active = [n for n in NODES if n["status"] != "Active"]
body0 = tc.render(
    marker="<!-- m -->",
    nodes=nodes_no_active,
    gaps={},
    coverage_rows=[],
    coverage_total=None,
    checks_tested=None,
    checks_verified=None,
    run_url="https://example/run/2",
)
check_in("no-active note", "No requirements marked", body0)
check_not_in("no bar when zero active", "ACTIVE FOCUS  [", body0)

if _failures:
    print("FAIL:")
    for f in _failures:
        print("  -", f)
    sys.exit(1)
print("ok - all traceability_comment tests passed")
