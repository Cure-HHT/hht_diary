import pytest

from urs_compile.graph_loader import Graph
from urs_compile.interleave import (
    interleave_section,
    kebab_stripped_name,
)


def test_kebab_stripped_name_diary():
    assert kebab_stripped_name("DIARY-PRD-role-definitions") == "role-definitions"


def test_kebab_stripped_name_cal():
    assert kebab_stripped_name("CAL-PRD-role-definitions") == "role-definitions"


def test_kebab_stripped_name_handles_gui_prefix():
    # GUI/OPS/DEV second segment also stripped
    assert kebab_stripped_name("DIARY-GUI-role-switching") == "role-switching"


def test_interleave_pairs_diary_and_cal(sample_graph_dict):
    g = Graph.from_dict(sample_graph_dict)
    diary_file = g.get_node("file:spec/prd-rbac.md")
    cal_file = g.get_node("file:spec/prd-rbac.md@callisto")
    emitted = list(interleave_section(g, [diary_file, cal_file]))
    ids = [n.id for _kind, n in emitted]
    # The interleaver walks the surviving FILE node's REMAINDERs for
    # ordering and pulls REQs from `content.source_file == relpath`. CAL
    # REMAINDERs from a sibling FILE are NOT visited (federation collapses
    # FILE nodes in production graphs, leaving only one surviving FILE).
    assert ids == [
        "rem:spec/prd-rbac.md:1",       # DIARY REMAINDER (first)
        "DIARY-PRD-rbac",               # DIARY REQ (no CAL pair)
        "DIARY-PRD-action-inventory",   # DIARY REQ (no CAL pair)
        "DIARY-PRD-role-definitions",   # DIARY REQ
        "CAL-PRD-role-definitions",     # CAL pair (via REFINES / kebab match)
        "rem:spec/prd-rbac.md:2",       # DIARY REMAINDER (second)
        "DIARY-GUI-role-switching",     # DIARY REQ (no CAL pair)
    ]


def test_interleave_single_file_no_cal_counterpart(sample_graph_dict):
    g = Graph.from_dict(sample_graph_dict)
    diary_file = g.get_node("file:spec/prd-rbac.md")
    emitted = list(interleave_section(g, [diary_file]))
    # With CAL REQs reachable via source_file, the CAL pair still surfaces
    # even when only the DIARY FILE node is passed in. (The interleaver
    # routes purely through source_file == relpath now.)
    ids = [n.id for _, n in emitted]
    assert "DIARY-PRD-rbac" in ids
    assert "CAL-PRD-role-definitions" in ids
    # CAL pair sits adjacent to its DIARY refines target.
    diary_pos = ids.index("DIARY-PRD-role-definitions")
    cal_pos = ids.index("CAL-PRD-role-definitions")
    assert cal_pos == diary_pos + 1


def test_trailing_unpaired_cal_appended():
    # Build a tiny graph where CAL has a REQ with no DIARY pair. Both REQs
    # reach the interleaver via `content.source_file`.
    g = Graph.from_dict({
        "nodes": {
            "file:spec/foo.md": {
                "id": "file:spec/foo.md", "kind": "FILE", "label": "foo",
                "content": {"relative_path": "spec/foo.md", "repo": None},
                "children": ["DIARY-PRD-foo"],
                "edges": [],
            },
            "file:spec/foo.md@cal": {
                "id": "file:spec/foo.md@cal", "kind": "FILE", "label": "foo",
                "content": {"relative_path": "spec/foo.md", "repo": "callisto"},
                "children": ["CAL-PRD-cal-only"],
                "edges": [],
            },
            "DIARY-PRD-foo": {
                "id": "DIARY-PRD-foo", "kind": "REQUIREMENT", "label": "Foo",
                "content": {"title": "Foo", "source_file": "spec/foo.md", "parse_line": 5},
                "children": [], "edges": [],
            },
            "CAL-PRD-cal-only": {
                "id": "CAL-PRD-cal-only", "kind": "REQUIREMENT", "label": "Cal Only",
                "content": {"title": "Cal Only", "source_file": "spec/foo.md", "parse_line": 10},
                "children": [], "edges": [],
            },
        },
        "roots": [], "metadata": {},
    })
    diary = g.get_node("file:spec/foo.md")
    cal = g.get_node("file:spec/foo.md@cal")
    ids = [n.id for _, n in interleave_section(g, [diary, cal])]
    assert ids == ["DIARY-PRD-foo", "CAL-PRD-cal-only"]
