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
    assert ids == [
        "rem:spec/prd-rbac.md:1",       # DIARY REMAINDER
        "rem:cal:spec/prd-rbac.md:1",   # CAL REMAINDER (after DIARY's first REMAINDER block)
        "DIARY-PRD-rbac",               # DIARY REQ (no CAL pair)
        "DIARY-PRD-action-inventory",   # DIARY REQ (no CAL pair)
        "DIARY-PRD-role-definitions",   # DIARY REQ
        "CAL-PRD-role-definitions",     # CAL pair, inserted right after
        "rem:spec/prd-rbac.md:2",       # DIARY REMAINDER
        "DIARY-GUI-role-switching",     # DIARY REQ (no CAL pair)
    ]


def test_interleave_single_file_no_cal_counterpart(sample_graph_dict):
    g = Graph.from_dict(sample_graph_dict)
    diary_file = g.get_node("file:spec/prd-rbac.md")
    emitted = list(interleave_section(g, [diary_file]))
    # No CAL file -> just DIARY children in source order
    ids = [n.id for _, n in emitted]
    assert ids == list(diary_file.children)


def test_trailing_unpaired_cal_appended():
    # Build a tiny graph where CAL has a REQ with no DIARY pair
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
                "content": {"title": "Foo"}, "children": [], "edges": [],
            },
            "CAL-PRD-cal-only": {
                "id": "CAL-PRD-cal-only", "kind": "REQUIREMENT", "label": "Cal Only",
                "content": {"title": "Cal Only"}, "children": [], "edges": [],
            },
        },
        "roots": [], "metadata": {},
    })
    diary = g.get_node("file:spec/foo.md")
    cal = g.get_node("file:spec/foo.md@cal")
    ids = [n.id for _, n in interleave_section(g, [diary, cal])]
    assert ids == ["DIARY-PRD-foo", "CAL-PRD-cal-only"]
