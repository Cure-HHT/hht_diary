from urs_compile.graph_loader import Graph
from urs_compile.render import render_node, render_remainder, render_requirement


def test_remainder_emits_verbatim(sample_graph_dict):
    g = Graph.from_dict(sample_graph_dict)
    node = g.get_node("rem:spec/prd-rbac.md:1")
    assert render_remainder(node) == "# User Roles and Permissions\n\nIntro prose for the section."


def test_requirement_renders_title_rationale_assertions(sample_graph_dict):
    g = Graph.from_dict(sample_graph_dict)
    node = g.get_node("DIARY-PRD-rbac")
    out = render_requirement(node, g)
    assert "### Customizable Role-Based Access Control" in out
    assert "DIARY-PRD-rbac" in out
    # Rationale from content.rationale
    assert "#### Rationale" in out
    assert "Body prose for RBAC." in out
    # Assertion child (DIARY-PRD-rbac-A) — def-list entry (label term + body)
    assert "#### Assertions" in out
    assert "A.  The System SHALL support customizable roles." in out


def test_requirement_renders_remainder_sections_above_rationale(sample_graph_dict):
    g = Graph.from_dict(sample_graph_dict)
    node = g.get_node("DIARY-PRD-rbac")
    out = render_requirement(node, g)
    # REMAINDER child "Overview" should appear as #### Overview before Rationale
    assert "#### Overview" in out
    assert "Section prose." in out
    overview_pos = out.find("#### Overview")
    rationale_pos = out.find("#### Rationale")
    assert 0 < overview_pos < rationale_pos


def test_requirement_renders_refines_edge(sample_graph_dict):
    g = Graph.from_dict(sample_graph_dict)
    node = g.get_node("CAL-PRD-role-definitions")
    out = render_requirement(node, g)
    assert "Refines:" in out
    assert "DIARY-PRD-role-definitions" in out


def test_requirement_omits_rationale_block_when_empty(sample_graph_dict):
    g = Graph.from_dict(sample_graph_dict)
    # DIARY-PRD-action-inventory has rationale="" — no Rationale heading
    node = g.get_node("DIARY-PRD-action-inventory")
    out = render_requirement(node, g)
    assert "#### Rationale" not in out
    # But the Assertions block still renders (as a def-list)
    assert "#### Assertions" in out
    assert "A.  Inventory all actions." in out


def test_render_node_dispatches_on_kind(sample_graph_dict):
    g = Graph.from_dict(sample_graph_dict)
    req = g.get_node("DIARY-PRD-rbac")
    rem = g.get_node("rem:spec/prd-rbac.md:1")
    assert "Customizable" in render_node(req, g)
    assert "Intro prose" in render_node(rem)
