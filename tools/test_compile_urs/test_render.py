from urs_compile.graph_loader import Graph
from urs_compile.render import render_node, render_remainder, render_requirement


def test_remainder_emits_verbatim(sample_graph_dict):
    g = Graph.from_dict(sample_graph_dict)
    node = g.get_node("rem:spec/prd-rbac.md:1")
    assert render_remainder(node) == "# User Roles and Permissions\n\nIntro prose for the section."


def test_requirement_renders_title_body_assertions(sample_graph_dict):
    g = Graph.from_dict(sample_graph_dict)
    node = g.get_node("DIARY-PRD-rbac")
    out = render_requirement(node)
    assert "Customizable Role-Based Access Control" in out
    assert "DIARY-PRD-rbac" in out
    assert "**A.** The System SHALL support customizable roles." in out


def test_requirement_renders_refines_edge(sample_graph_dict):
    g = Graph.from_dict(sample_graph_dict)
    node = g.get_node("CAL-PRD-role-definitions")
    out = render_requirement(node)
    assert "Refines:" in out
    assert "DIARY-PRD-role-definitions" in out


def test_render_node_dispatches_on_kind(sample_graph_dict):
    g = Graph.from_dict(sample_graph_dict)
    req = g.get_node("DIARY-PRD-rbac")
    rem = g.get_node("rem:spec/prd-rbac.md:1")
    assert "Customizable" in render_node(req)
    assert "Intro prose" in render_node(rem)
