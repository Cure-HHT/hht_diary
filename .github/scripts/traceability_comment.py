#!/usr/bin/env python3
"""Render the verified-coverage traceability PR comment (CUR-1556).

The full per-requirement matrix has hundreds of requirements and >1000
assertions, so it is artifact-only (downloadable for the elspais viewer). This
comment is the *summary*: it leads with the curated ``Status: Active`` focus
set, keeps the heavy detail in collapsible <details> sections, and links the
downloadable artifacts.

Inputs (all optional except --trace):
  --trace        elspais `trace --format json` array (per-req, assertion-level
                 ``tested``/``verified`` fractions + ``status``). The source of
                 truth for the Active focus numbers.
  --gaps         elspais `gaps --format json` (untested/failing assertion lists).
  --coverage-tsv per-package lcov tsv  (path \\t pct \\t hit \\t found, + TOTAL row).
  --checks       teed `elspais checks --tests` stdout (official REQ-level
                 Tested/Verified, used in the collapsed rollup as a cross-check).
  --marker       upsert marker comment (first line).
  --run-url      Actions run URL for the artifact footer.

Emits the comment markdown to stdout. See traceability_comment_test.py.
"""
import argparse
import json
import re
import sys

# Statuses elspais credits as "active" (.elspais.toml [rules.format.status_roles]
# active = ["Active", "Draft"]). Used for the repo-wide rollup so Legacy/retired
# requirements don't dilute the denominator.
CREDITABLE = {"Active", "Draft"}

_FRACTION = re.compile(r"\s*(\d+)\s*/\s*(\d+)")


def parse_fraction(s):
    """'12/47 (25%)' -> (12, 47); 'n/a'/''/None -> None."""
    if not s:
        return None
    m = _FRACTION.match(s)
    return (int(m.group(1)), int(m.group(2))) if m else None


def bar(pct, width=20):
    """ASCII progress bar, e.g. bar(50, 10) -> '[#####-----]'."""
    filled = int(round(pct / 100.0 * width))
    filled = max(0, min(width, filled))
    return "[" + "#" * filled + "-" * (width - filled) + "]"


def summarize(nodes, statuses, dim):
    """Assertion-level rollup of one coverage dimension over a status subset.

    Returns counts: num/den assertions, reqs counted, and ``green`` (reqs whose
    assertions are all covered in this dimension). Nodes whose dimension is
    'n/a' (non-fraction) are skipped entirely.
    """
    num = den = reqs = green = 0
    for n in nodes:
        if n.get("status") not in statuses:
            continue
        fr = parse_fraction(n.get(dim, ""))
        if fr is None:
            continue
        a, b = fr
        num += a
        den += b
        reqs += 1
        if b > 0 and a == b:
            green += 1
    return {"num": num, "den": den, "reqs": reqs, "green": green}


def gap_map(gaps, key):
    """{req_id: [assertion_id, ...]} from a gaps.json list.

    Items are [req_id, title] or [req_id, title, [assertion_ids]].
    """
    out = {}
    for item in gaps.get(key, []):
        if not item:
            continue
        rid = item[0]
        asserts = item[2] if len(item) > 2 and isinstance(item[2], list) else []
        out[rid] = list(asserts)
    return out


def assertion_label(rid, aid):
    """'DIARY-PRD-a-C' under 'DIARY-PRD-a' -> 'C'; foreign id passes through."""
    prefix = rid + "-"
    return aid[len(prefix):] if aid.startswith(prefix) else aid


def active_ids(nodes):
    return [n["id"] for n in nodes if n.get("status") == "Active"]


def active_failing_count(nodes, gaps):
    """Count failing assertions belonging to Active requirements."""
    actives = set(active_ids(nodes))
    fmap = gap_map(gaps, "failing")
    total = 0
    for rid, asserts in fmap.items():
        if rid in actives:
            total += len(asserts) if asserts else 1
    return total


def _pct(num, den):
    return (100.0 * num / den) if den else 0.0


def _active_gap_section(nodes, gaps):
    """Per-Active-REQ worklist of untested + failing assertions.

    'uncovered' is elspais's per-assertion list of assertions with no covering
    test (it carries the full assertion list even for a fully-uncovered req,
    which 'untested' does not), so it is the right source for a focus campaign
    that starts from zero coverage.
    """
    actives = active_ids(nodes)
    vmap = {n["id"]: parse_fraction(n.get("verified", "")) for n in nodes}
    uncovered = gap_map(gaps, "uncovered")
    failing = gap_map(gaps, "failing")

    blocks = []
    total_items = 0
    for rid in actives:
        items = []
        for aid in uncovered.get(rid, []):
            items.append(f"  /{assertion_label(rid, aid)} untested")
        for aid in failing.get(rid, []):
            items.append(f"  /{assertion_label(rid, aid)} failing")
        if not items:
            continue
        total_items += len(items)
        fr = vmap.get(rid) or (0, 0)
        blocks.append(f"{rid}   {fr[0]}/{fr[1]} assertions traced")
        blocks.extend(items)

    if not blocks:
        return []
    out = [
        "<details>",
        f"<summary>Active gaps — {total_items} assertions need work</summary>",
        "",
        "```text",
        *blocks,
        "```",
        "</details>",
        "",
    ]
    return out


def _status_histogram(nodes):
    counts = {}
    for n in nodes:
        counts[n.get("status", "?")] = counts.get(n.get("status", "?"), 0) + 1
    total = sum(counts.values())
    ordered = sorted(counts.items(), key=lambda kv: (-kv[1], kv[0]))
    parts = ", ".join(f"{s} {c}" for s, c in ordered)
    return f"Status: {parts} (total {total})"


def render(marker, nodes, gaps, coverage_rows, coverage_total,
           checks_tested, checks_verified, run_url,
           checks_indirect=None, checks_passed=None):
    gaps = gaps or {}
    # Active focus tracks assertion-level DIRECT traceability (each assertion
    # carries a `// Verifies: REQ/A` annotation proven by a passing test — the
    # mandated unit). That is the focus campaign; it is deliberately NOT the
    # repo-health number below, which is REQ-level (direct assertion credit is
    # ~0 today because most annotations cite REQs, not individual assertions).
    active = summarize(nodes, {"Active"}, "verified")

    L = [marker, "## Verified-Coverage Traceability Matrix", ""]

    # --- Headline: Active traceability campaign + repo context + failing -----
    if active["reqs"] > 0:
        p = _pct(active["num"], active["den"])
        L.append(
            f"`ACTIVE FOCUS`  {bar(p)}  {p:.0f}%   "
            f"{active['num']}/{active['den']} assertions traced · "
            f"{active['green']}/{active['reqs']} REQs fully traced"
        )
    else:
        L.append(
            "_No requirements marked `Status: Active` yet — "
            "tracking repo-wide coverage below._"
        )

    cov = (f"{coverage_total[0]}% ({coverage_total[1]} of {coverage_total[2]} lines)"
           if coverage_total else "n/a")
    ver = checks_verified or "n/a"
    ind = f", {checks_indirect}" if checks_indirect else ""  # already ends "indirect (NN%)"
    L.append(f"`COVERAGE`      verified {ver}{ind} · line {cov}")

    if active["reqs"] > 0:
        nf = active_failing_count(nodes, gaps)
        verb = "has" if nf == 1 else "have"
        noun = "assertion" if nf == 1 else "assertions"
        fail_line = f"`FAILING`       {nf} Active {noun} {verb} red tests"
        if checks_passed:
            fail_line += f" · {checks_passed} tests passing"
        L.append(fail_line)
    L.append("")
    L.append(
        "_Active focus = assertion-level traceability (`// Verifies: REQ/A`, the "
        "campaign goal); `COVERAGE` = repo-wide REQ-level verified + line coverage._"
    )
    L.append("")

    # --- Collapsed: Active gap worklist --------------------------------------
    L.extend(_active_gap_section(nodes, gaps))

    # --- Collapsed: whole-repo rollup & status pipeline ----------------------
    rollup = ["<details>", "<summary>Whole-repo rollup & status pipeline</summary>", ""]
    if checks_tested or checks_verified:
        rollup.append(
            f"Tested: {checks_tested or 'n/a'} · Verified: {checks_verified or 'n/a'} "
            "(elspais, Legacy excluded)"
        )
        rollup.append("")
    rollup.append(_status_histogram(nodes))
    # Top uncovered Active REQs by uncovered-assertion count.
    uncovered = gap_map(gaps, "uncovered")
    top = sorted(
        ((rid, len(uncovered.get(rid, []))) for rid in active_ids(nodes)),
        key=lambda kv: -kv[1],
    )[:5]
    top = [t for t in top if t[1] > 0]
    if top:
        rollup.append("")
        rollup.append(
            "Top uncovered Active REQs: "
            + ", ".join(f"{rid} ({c})" for rid, c in top)
        )
    rollup.extend(["</details>", ""])
    L.extend(rollup)

    # --- Collapsed: line coverage by package ---------------------------------
    if coverage_rows:
        L.extend([
            "<details>",
            f"<summary>Line coverage by package ({len(coverage_rows)})</summary>",
            "",
            "| Package | Line % | Hit | Found |",
            "|---------|-------:|----:|------:|",
        ])
        for path, pct, hit, found in sorted(coverage_rows):
            L.append(f"| {path} | {pct}% | {hit} | {found} |")
        L.extend(["</details>", ""])

    # --- Footer: downloadable artifacts --------------------------------------
    L.append(
        f"[Full matrix · static viewer (`viewer.html`) · `trace.json` in artifacts]({run_url})"
    )
    return "\n".join(L)


# --- input parsing ----------------------------------------------------------
def _load_json(path, default):
    if not path:
        return default
    try:
        with open(path) as fh:
            return json.load(fh)
    except (OSError, ValueError):
        return default


def _parse_coverage_tsv(path):
    rows, total = [], None
    if not path:
        return rows, total
    try:
        with open(path) as fh:
            for line in fh:
                parts = line.rstrip("\n").split("\t")
                if len(parts) != 4:
                    continue
                name, pct, hit, found = parts
                if name == "TOTAL":
                    total = (pct, int(hit), int(found))
                else:
                    rows.append((name, pct, int(hit), int(found)))
    except OSError:
        pass
    return rows, total


def _grep_checks(path):
    """Pull REQ-level coverage + test totals from the `checks --tests` text.

    Lines look like:
      ~ tests.verified: Verified: 108/178 REQs (61%), 2/975 assertions direct
                        (0%), 557.1 indirect (57%) [26 legacy excluded]
      ~ tests.results: All tests passing: 2498 passed, 1 skipped
    """
    out = {"tested": None, "verified": None, "indirect": None, "passed": None}
    if not path:
        return out
    try:
        with open(path) as fh:
            text = fh.read()
    except OSError:
        return out
    mt = re.search(r"Tested:\s*(\d+/\d+ REQs \(\d+%\))", text)
    mv = re.search(r"Verified:\s*(\d+/\d+ REQs \(\d+%\))", text)
    # The indirect figure belongs to the Verified line specifically.
    mi = re.search(r"Verified:[^\n]*?([\d.]+ indirect \(\d+%\))", text)
    # Anchor to the tests.results line — NOT the first "N passed" (per-check
    # summaries like "(4 passed, 0 failed)" appear earlier). "tests.results:"
    # excludes "tests.results_stale:" (no colon right after "results").
    mp = re.search(r"tests\.results:[^\n]*?(\d+)\s+passed", text)
    out["tested"] = mt.group(1) if mt else None
    out["verified"] = mv.group(1) if mv else None
    out["indirect"] = mi.group(1) if mi else None
    out["passed"] = mp.group(1) if mp else None
    return out


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--marker", required=True)
    ap.add_argument("--trace", required=True)
    ap.add_argument("--gaps")
    ap.add_argument("--coverage-tsv")
    ap.add_argument("--checks")
    ap.add_argument("--run-url", default="")
    args = ap.parse_args(argv)

    nodes = _load_json(args.trace, [])
    if not isinstance(nodes, list):
        print(f"error: {args.trace} is not a JSON array", file=sys.stderr)
        return 1
    gaps = _load_json(args.gaps, {})
    rows, total = _parse_coverage_tsv(args.coverage_tsv)
    checks = _grep_checks(args.checks)

    sys.stdout.write(render(
        marker=args.marker,
        nodes=nodes,
        gaps=gaps,
        coverage_rows=rows,
        coverage_total=total,
        checks_tested=checks["tested"],
        checks_verified=checks["verified"],
        checks_indirect=checks["indirect"],
        checks_passed=checks["passed"],
        run_url=args.run_url,
    ) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
